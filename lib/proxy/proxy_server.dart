import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/http_models.dart';
import '../models/proxy_config.dart';
import 'certificate_authority.dart';

/// Core proxy server that handles HTTP and HTTPS (CONNECT) traffic.
class ProxyServer {
  final ProxyConfig config;
  final CertificateAuthority? ca;
  final void Function(HttpFlow flow) onFlow;
  final Future<ProxyRequest?> Function(HttpFlow flow)? onIntercept;

  HttpServer? _server;
  bool _running = false;
  bool get running => _running;
  int _flowCounter = 0;

  ProxyServer({
    required this.config,
    this.ca,
    required this.onFlow,
    this.onIntercept,
  });

  Future<void> start() async {
    if (_running) return;

    _server = await HttpServer.bind(
      config.bindAddress,
      config.port,
      shared: true,
    );
    _running = true;

    _server!.listen(
      _handleClient,
      onError: (e) => print('[ProxyServer] Server error: $e'),
    );
  }

  Future<void> stop() async {
    _running = false;
    await _server?.close(force: true);
    _server = null;
  }

  void _handleClient(HttpRequest clientRequest) async {
    try {
      if (clientRequest.method == 'CONNECT') {
        await _handleConnect(clientRequest);
      } else {
        await _handleHttp(clientRequest);
      }
    } catch (e) {
      print('[ProxyServer] Error handling request: $e');
      try {
        clientRequest.response.statusCode = 502;
        clientRequest.response.write('Proxy Error: $e');
        await clientRequest.response.close();
      } catch (_) {}
    }
  }

  /// Handle regular HTTP requests (non-CONNECT).
  Future<void> _handleHttp(HttpRequest clientRequest) async {
    final uri = clientRequest.uri;
    final host = uri.host.isNotEmpty
        ? uri.host
        : clientRequest.headers.host ?? 'localhost';
    final port = uri.port != 0 ? uri.port : 80;

    // Build ProxyRequest
    final headers = HttpHeaders();
    clientRequest.headers.forEach((name, values) {
      for (final v in values) {
        headers.add(name, v);
      }
    });
    headers.stripHopByHop();

    // Read request body
    final bodyBytes = await _readBody(clientRequest);

    final flowId = 'flow_${_flowCounter++}';
    final proxyReq = ProxyRequest(
      method: clientRequest.method,
      url: uri.toString(),
      headers: headers,
      body: bodyBytes.isNotEmpty ? Uint8List.fromList(bodyBytes) : null,
    );

    final flow = HttpFlow(
      id: flowId,
      request: proxyReq,
      isHttps: false,
    );

    // Intercept if enabled
    ProxyRequest requestToSend = proxyReq;
    if (onIntercept != null) {
      flow.state = FlowState.intercepted;
      onFlow(flow);
      final modified = await onIntercept!(flow);
      if (modified == null) {
        flow.state = FlowState.dropped;
        onFlow(flow);
        clientRequest.response.statusCode = 403;
        clientRequest.response.write('Request dropped by interceptor');
        await clientRequest.response.close();
        return;
      }
      requestToSend = modified;
    }

    flow.state = FlowState.forwarded;
    onFlow(flow);

    // Forward request upstream
    try {
      final stopwatch = Stopwatch()..start();
      final upstream = await HttpClient().openUrl(
        requestToSend.method,
        Uri.parse(requestToSend.url),
      );

      // Copy headers to upstream request
      requestToSend.headers.entries.forEach((e) {
        if (e.key != 'host') {
          upstream.headers.add(e.key, e.value);
        }
      });

      if (requestToSend.body != null) {
        upstream.add(requestToSend.body!);
      }

      final upstreamResponse = await upstream.close()
          .timeout(Duration(seconds: config.connectionTimeout));
      stopwatch.stop();

      // Build ProxyResponse
      final respHeaders = HttpHeaders();
      upstreamResponse.headers.forEach((name, values) {
        for (final v in values) {
          respHeaders.add(name, v);
        }
      });
      respHeaders.stripHopByHop();

      final respBody = await _readStream(upstreamResponse);

      flow.response = ProxyResponse(
        statusCode: upstreamResponse.statusCode,
        statusText: upstreamResponse.reasonPhrase,
        headers: respHeaders,
        body: Uint8List.fromList(respBody),
        duration: stopwatch.elapsed,
      );
      flow.state = FlowState.completed;
      onFlow(flow);

      // Send response to client
      clientRequest.response.statusCode = upstreamResponse.statusCode;
      upstreamResponse.headers.forEach((name, values) {
        for (final v in values) {
          if (name.toLowerCase() != 'transfer-encoding') {
            clientRequest.response.headers.add(name, v);
          }
        }
      });
      clientRequest.response.add(Uint8List.fromList(respBody));
      await clientRequest.response.close();
    } catch (e) {
      flow.state = FlowState.error;
      flow.response = ProxyResponse(
        statusCode: 502,
        statusText: 'Bad Gateway',
      );
      onFlow(flow);
      clientRequest.response.statusCode = 502;
      clientRequest.response.write('Upstream error: $e');
      await clientRequest.response.close();
    }
  }

  /// Handle CONNECT tunneling (for HTTPS).
  Future<void> _handleConnect(HttpRequest clientRequest) async {
    final target = clientRequest.requestedUri.toString();
    final parts = target.contains(':') ? target.split(':') : [target, '443'];
    final host = parts[0];
    final port = int.tryParse(parts.length > 1 ? parts[1] : '443') ?? 443;

    // If HTTPS interception is disabled or host is excluded, tunnel directly
    if (ca == null ||
        !config.httpsInterception ||
        config.shouldExclude(host)) {
      await _tunnelDirect(clientRequest, host, port);
      return;
    }

    // MITM: Accept the CONNECT, then do TLS interception
    await _tunnelMitm(clientRequest, host, port);
  }

  /// Direct TCP tunnel (no interception).
  Future<void> _tunnelDirect(
      HttpRequest clientRequest, String host, int port) async {
    try {
      final upstream = await Socket.connect(host, port,
          timeout: Duration(seconds: config.connectionTimeout));

      final clientSocket = await clientRequest.response.detachSocket();
      clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      await clientSocket.flush();

      upstream.listen(
        clientSocket.add,
        onDone: () => clientSocket.close(),
        onError: (_) => clientSocket.close(),
      );
      clientSocket.listen(
        upstream.add,
        onDone: () => upstream.close(),
        onError: (_) => upstream.close(),
      );
    } catch (e) {
      try {
        clientRequest.response.statusCode = 502;
        clientRequest.response.write('Tunnel error: $e');
        await clientRequest.response.close();
      } catch (_) {}
    }
  }

  /// MITM tunnel: TLS intercept, read requests, forward, capture.
  Future<void> _tunnelMitm(
      HttpRequest clientRequest, String host, int port) async {
    Socket? clientSocket;
    try {
      clientSocket = await clientRequest.response.detachSocket();
      clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      await clientSocket.flush();

      // Create TLS server context with our leaf cert
      final serverContext = ca!.createContextForHost(host);

      // Upgrade client connection to TLS (we act as the server)
      final secureClient = await SecureSocket.secureServer(
        clientSocket,
        serverContext,
        bufferedData: null,
      );

      // Now read HTTP requests from the secure client
      await _handleMitmConnection(secureClient, host, port);
    } catch (e) {
      print('[ProxyServer] MITM error for $host: $e');
      try {
        clientSocket?.close();
      } catch (_) {}
    }
  }

  Future<void> _handleMitmConnection(
      SecureSocket secureClient, String host, int port) async {
    try {
      // Read the raw request from the client
      final requestData = await _readUntilHeaderEnd(secureClient);
      if (requestData.isEmpty) {
        secureClient.close();
        return;
      }

      final requestText = utf8.decode(requestData, allowMalformed: true);
      final lines = requestText.split('\r\n');
      if (lines.isEmpty) {
        secureClient.close();
        return;
      }

      // Parse request line
      final reqLineParts = lines[0].split(' ');
      final method = reqLineParts.isNotEmpty ? reqLineParts[0] : 'GET';
      final path = reqLineParts.length > 1 ? reqLineParts[1] : '/';

      final headers = HttpHeaders();
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].isEmpty) break;
        final idx = lines[i].indexOf(':');
        if (idx > 0) {
          headers.add(
            lines[i].substring(0, idx).trim(),
            lines[i].substring(idx + 1).trim(),
          );
        }
      }

      // Read body if content-length is present
      Uint8List? body;
      final clStr = headers.get('content-length');
      if (clStr != null) {
        final cl = int.tryParse(clStr) ?? 0;
        if (cl > 0) {
          body = await _readBytes(secureClient, cl);
        }
      }

      final url = 'https://$host${port != 443 ? ':$port' : ''}$path';
      final flowId = 'flow_${_flowCounter++}';
      final proxyReq = ProxyRequest(
        method: method,
        url: url,
        headers: headers,
        body: body,
      );

      final flow = HttpFlow(
        id: flowId,
        request: proxyReq,
        isHttps: true,
      );

      // Intercept
      ProxyRequest requestToSend = proxyReq;
      if (onIntercept != null) {
        flow.state = FlowState.intercepted;
        onFlow(flow);
        final modified = await onIntercept!(flow);
        if (modified == null) {
          flow.state = FlowState.dropped;
          onFlow(flow);
          final resp = 'HTTP/1.1 403 Forbidden\r\nContent-Length: 7\r\n\r\nDropped';
          secureClient.add(utf8.encode(resp));
          await secureClient.close();
          return;
        }
        requestToSend = modified;
      }

      flow.state = FlowState.forwarded;
      onFlow(flow);

      // Forward upstream over TLS
      try {
        final stopwatch = Stopwatch()..start();
        final httpClient = HttpClient()
          ..badCertificateCallback = (cert, host, port) => true;

        final upstream = await httpClient.openUrl(
          requestToSend.method,
          Uri.parse(requestToSend.url),
        );

        requestToSend.headers.entries.forEach((e) {
          if (e.key != 'host') {
            upstream.headers.add(e.key, e.value);
          }
        });

        if (requestToSend.body != null) {
          upstream.add(requestToSend.body!);
        }

        final upstreamResponse = await upstream.close()
            .timeout(Duration(seconds: config.connectionTimeout));
        stopwatch.stop();

        final respHeaders = HttpHeaders();
        upstreamResponse.headers.forEach((name, values) {
          for (final v in values) {
            respHeaders.add(name, v);
          }
        });

        final respBody = await _readStream(upstreamResponse);

        flow.response = ProxyResponse(
          statusCode: upstreamResponse.statusCode,
          statusText: upstreamResponse.reasonPhrase,
          headers: respHeaders,
          body: Uint8List.fromList(respBody),
          duration: stopwatch.elapsed,
        );
        flow.state = FlowState.completed;
        onFlow(flow);

        // Send response back to client through TLS
        final respLine =
            'HTTP/1.1 ${upstreamResponse.statusCode} ${upstreamResponse.reasonPhrase}\r\n';
        final respHeaderStr = respHeaders.toWireFormat();
        final respHead = '$respLine$respHeaderStr\r\n\r\n';

        secureClient.add(utf8.encode(respHead));
        if (respBody.isNotEmpty) {
          secureClient.add(Uint8List.fromList(respBody));
        }
        await secureClient.flush();
        await secureClient.close();

        httpClient.close(force: true);
      } catch (e) {
        flow.state = FlowState.error;
        onFlow(flow);
        try {
          secureClient.add(utf8.encode(
              'HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n'));
          await secureClient.close();
        } catch (_) {}
      }
    } catch (e) {
      print('[ProxyServer] MITM connection error: $e');
      try { secureClient.close(); } catch (_) {}
    }
  }

  Future<List<int>> _readBody(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > config.maxBodySize) break;
    }
    return bytes;
  }

  Future<List<int>> _readStream(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > config.maxBodySize) break;
    }
    return bytes;
  }

  Future<Uint8List> _readUntilHeaderEnd(Socket socket) async {
    final buffer = <int>[];
    final completer = Completer<Uint8List>();
    Timer? timeoutTimer;
    StreamSubscription? sub;

    void finish(Uint8List res) {
      timeoutTimer?.cancel();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(res);
    }

    sub = socket.listen(
      (data) {
        buffer.addAll(data);
        for (var i = 3; i < buffer.length; i++) {
          if (buffer[i - 3] == 13 &&
              buffer[i - 2] == 10 &&
              buffer[i - 1] == 13 &&
              buffer[i] == 10) {
            finish(Uint8List.fromList(buffer.sublist(0, i + 1)));
            return;
          }
        }
        if (buffer.length > config.maxBodySize) {
          finish(Uint8List.fromList(buffer));
        }
      },
      onError: (_) => finish(Uint8List(0)),
      onDone: () => finish(Uint8List.fromList(buffer)),
      cancelOnError: true,
    );

    timeoutTimer = Timer(Duration(seconds: config.connectionTimeout), () {
      finish(Uint8List.fromList(buffer));
    });

    return completer.future;
  }

  Future<Uint8List> _readBytes(Socket socket, int count) async {
    final buffer = <int>[];
    final completer = Completer<Uint8List>();
    Timer? timeoutTimer;
    StreamSubscription? sub;

    void finish(Uint8List res) {
      timeoutTimer?.cancel();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(res);
    }

    sub = socket.listen(
      (data) {
        buffer.addAll(data);
        if (buffer.length >= count) {
          finish(Uint8List.fromList(buffer.sublist(0, count)));
        }
      },
      onError: (_) => finish(Uint8List.fromList(buffer)),
      onDone: () => finish(Uint8List.fromList(buffer)),
      cancelOnError: true,
    );

    timeoutTimer = Timer(Duration(seconds: config.connectionTimeout), () {
      finish(Uint8List.fromList(buffer));
    });

    return completer.future;
  }
}
