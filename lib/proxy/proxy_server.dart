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
      final httpClient = HttpClient();
      httpClient.badCertificateCallback = (cert, host, port) => true;
      httpClient.findProxy = (uri) => 'DIRECT'; // NEVER loop back to local proxy!
      httpClient.autoUncompress = false;

      final upstream = await httpClient.openUrl(
        requestToSend.method,
        Uri.parse(requestToSend.url),
      );

      // Copy headers to upstream request
      requestToSend.headers.entries.forEach((e) {
        final key = e.key.toLowerCase();
        if (key != 'host' && key != 'content-length') {
          if (key == 'accept-encoding') {
            if (config.stripAcceptEncoding) {
              return;
            } else {
              upstream.headers.set('accept-encoding', 'gzip, deflate');
              return;
            }
          }
          upstream.headers.add(e.key, e.value);
        }
      });

      if (config.customForwardedIp.trim().isNotEmpty) {
        upstream.headers.set('x-forwarded-for', config.customForwardedIp.trim());
      }

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
      respHeaders.remove('transfer-encoding');
      respHeaders.set('content-length', respBody.length.toString());
      respHeaders.set('connection', 'close');

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
      respHeaders.entries.forEach((e) {
        clientRequest.response.headers.add(e.key, e.value);
      });
      clientRequest.response.add(Uint8List.fromList(respBody));
      await clientRequest.response.close();
      httpClient.close(force: true);
    } catch (e) {
      flow.state = FlowState.error;
      flow.response = ProxyResponse(
        statusCode: 502,
        statusText: 'Bad Gateway',
        headers: HttpHeaders(),
        body: Uint8List.fromList(utf8.encode('Upstream error: $e')),
      );
      onFlow(flow);
      clientRequest.response.statusCode = 502;
      clientRequest.response.write('Upstream error: $e');
      await clientRequest.response.close();
    }
  }

  /// Handle CONNECT tunneling (for HTTPS).
  Future<void> _handleConnect(HttpRequest clientRequest) async {
    String target = clientRequest.headers.value('host') ?? clientRequest.uri.toString();
    if (target.startsWith('http://') || target.startsWith('https://')) {
      final u = Uri.tryParse(target);
      if (u != null && u.host.isNotEmpty) {
        target = '${u.host}:${u.port != 0 ? u.port : 443}';
      }
    }
    final lastColon = target.lastIndexOf(':');
    final String host;
    final int port;
    if (lastColon != -1 && !target.endsWith(']')) {
      host = target.substring(0, lastColon).replaceAll('[', '').replaceAll(']', '').trim();
      port = int.tryParse(target.substring(lastColon + 1).trim()) ?? 443;
    } else {
      host = target.replaceAll('[', '').replaceAll(']', '').trim();
      port = 443;
    }

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

      final clientSocket = await clientRequest.response.detachSocket(writeHeaders: false);
      clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      await clientSocket.flush();

      // Log direct tunnel in history so user sees active traffic
      final flow = HttpFlow(
        id: 'flow_${_flowCounter++}',
        request: ProxyRequest(
          method: 'CONNECT',
          url: '$host:$port',
          headers: HttpHeaders(),
        ),
        response: ProxyResponse(
          statusCode: 200,
          statusText: 'Connection Established (Direct Tunnel)',
          headers: HttpHeaders(),
          body: Uint8List(0),
        ),
        state: FlowState.completed,
        isHttps: true,
      );
      onFlow(flow);

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
      clientSocket = await clientRequest.response.detachSocket(writeHeaders: false);
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
      final flow = HttpFlow(
        id: 'flow_${_flowCounter++}',
        request: ProxyRequest(
          method: 'CONNECT',
          url: 'https://$host:$port',
          headers: HttpHeaders(),
        ),
        response: ProxyResponse(
          statusCode: 502,
          statusText: 'MITM Handshake Failed',
          headers: HttpHeaders(),
          body: Uint8List.fromList(utf8.encode(
            'MITM Handshake Error: $e\n\n'
            'Penyebab umum: Sertifikat CA VersSuite belum diinstal/dipercaya di HP Android Anda, atau situs memiliki SSL Pinning (seperti google.com).\n'
            'Solusi:\n'
            '1. Pasang Sertifikat CA lewat menu Pengaturan VersSuite ➔ Pasang Sertifikat CA ke Android.\n'
            '2. Atau matikan switch "Intersepsi HTTPS" untuk mode Direct Tunnel tanpa error.',
          )),
        ),
        state: FlowState.error,
        isHttps: true,
      );
      onFlow(flow);
      try {
        clientSocket?.close();
      } catch (_) {}
    }
  }

  Future<void> _handleMitmConnection(
      SecureSocket secureClient, String host, int port) async {
    final reader = _BufferedSocketReader(secureClient);
    try {
      // Read the raw request from the client
      final requestData = await reader.readUntilHeaderEnd(
        timeout: Duration(seconds: config.connectionTimeout),
      );
      if (requestData == null || requestData.isEmpty) {
        reader.cancel();
        secureClient.close();
        return;
      }

      final requestText = utf8.decode(requestData, allowMalformed: true);
      final lines = requestText.split('\r\n');
      if (lines.isEmpty) {
        reader.cancel();
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
          body = await reader.readBytes(
            cl,
            timeout: Duration(seconds: config.connectionTimeout),
          );
        }
      }
      reader.cancel();

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
          final resp =
              'HTTP/1.1 403 Forbidden\r\nContent-Length: 7\r\nConnection: close\r\n\r\nDropped';
          secureClient.add(utf8.encode(resp));
          await secureClient.flush();
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
        final httpClient = HttpClient();
        httpClient.badCertificateCallback = (cert, host, port) => true;
        httpClient.findProxy = (uri) => 'DIRECT'; // NEVER loop back to local proxy!
        httpClient.autoUncompress = false; // Preserve upstream raw encoding!

        final upstream = await httpClient.openUrl(
          requestToSend.method,
          Uri.parse(requestToSend.url),
        );

        requestToSend.headers.entries.forEach((e) {
          final key = e.key.toLowerCase();
          if (key != 'host' && key != 'content-length') {
            if (key == 'accept-encoding') {
              if (config.stripAcceptEncoding) {
                return;
              } else {
                upstream.headers.set('accept-encoding', 'gzip, deflate');
                return;
              }
            }
            upstream.headers.add(e.key, e.value);
          }
        });

        if (config.customForwardedIp.trim().isNotEmpty) {
          upstream.headers.set('x-forwarded-for', config.customForwardedIp.trim());
        }

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

        // Strip hop-by-hop headers & fix chunked / content-length framing
        respHeaders.stripHopByHop();
        respHeaders.remove('transfer-encoding');
        respHeaders.set('content-length', respBody.length.toString());
        respHeaders.set('connection', 'close'); // Explicitly close HTTP/1.1 connection

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
        flow.response = ProxyResponse(
          statusCode: 502,
          statusText: 'Bad Gateway',
          headers: HttpHeaders(),
          body: Uint8List.fromList(utf8.encode('Upstream error: $e')),
        );
        onFlow(flow);
        try {
          secureClient.add(utf8.encode(
              'HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'));
          await secureClient.flush();
          await secureClient.close();
        } catch (_) {}
      }
    } catch (e) {
      reader.cancel();
      print('[ProxyServer] MITM connection error for $host: $e');
      try {
        secureClient.close();
      } catch (_) {}
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
}

/// Helper class to buffer bytes from a single-subscription Socket stream
/// and parse HTTP headers and bodies without stream errors or data loss.
class _BufferedSocketReader {
  final StreamSubscription<Uint8List> _subscription;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  Completer<void>? _dataCompleter;
  bool _isDone = false;

  _BufferedSocketReader(Stream<Uint8List> stream)
      : _subscription = stream.listen(null) {
    _subscription.onData((data) {
      _buffer.add(data);
      if (_dataCompleter != null && !_dataCompleter!.isCompleted) {
        _dataCompleter!.complete();
      }
    });
    _subscription.onDone(() {
      _isDone = true;
      if (_dataCompleter != null && !_dataCompleter!.isCompleted) {
        _dataCompleter!.complete();
      }
    });
    _subscription.onError((_) {
      _isDone = true;
      if (_dataCompleter != null && !_dataCompleter!.isCompleted) {
        _dataCompleter!.complete();
      }
    });
  }

  Future<Uint8List?> readUntilHeaderEnd(
      {Duration timeout = const Duration(seconds: 15)}) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      final bytes = _buffer.toBytes();
      for (var i = 3; i < bytes.length; i++) {
        if (bytes[i - 3] == 13 &&
            bytes[i - 2] == 10 &&
            bytes[i - 1] == 13 &&
            bytes[i] == 10) {
          final headerBytes = bytes.sublist(0, i + 1);
          final remaining = bytes.sublist(i + 1);
          _buffer.clear();
          if (remaining.isNotEmpty) {
            _buffer.add(remaining);
          }
          return headerBytes;
        }
      }
      if (_isDone) {
        if (_buffer.isNotEmpty) {
          final b = _buffer.takeBytes();
          return b;
        }
        return null;
      }
      if (stopwatch.elapsed >= timeout) return null;

      _dataCompleter = Completer<void>();
      final remainingTimeout = timeout - stopwatch.elapsed;
      if (remainingTimeout <= Duration.zero) return null;
      try {
        await _dataCompleter!.future.timeout(remainingTimeout);
      } catch (_) {
        return null;
      }
    }
  }

  Future<Uint8List> readBytes(int count,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final stopwatch = Stopwatch()..start();
    while (_buffer.length < count) {
      if (_isDone) break;
      if (stopwatch.elapsed >= timeout) break;

      _dataCompleter = Completer<void>();
      final remainingTimeout = timeout - stopwatch.elapsed;
      if (remainingTimeout <= Duration.zero) break;
      try {
        await _dataCompleter!.future.timeout(remainingTimeout);
      } catch (_) {
        break;
      }
    }

    final bytes = _buffer.toBytes();
    if (bytes.length <= count) {
      _buffer.clear();
      return bytes;
    } else {
      final result = bytes.sublist(0, count);
      final remaining = bytes.sublist(count);
      _buffer.clear();
      if (remaining.isNotEmpty) {
        _buffer.add(remaining);
      }
      return result;
    }
  }

  void cancel() {
    try {
      _subscription.cancel();
    } catch (_) {}
  }
}
