import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Ordered, duplicate-preserving HTTP header collection.
class HttpHeaders {
  final List<MapEntry<String, String>> _entries = [];

  void add(String name, String value) {
    _entries.add(MapEntry(name.toLowerCase(), value));
  }

  void set(String name, String value) {
    remove(name);
    add(name, value);
  }

  void remove(String name) {
    final lower = name.toLowerCase();
    _entries.removeWhere((e) => e.key == lower);
  }

  String? get(String name) {
    final lower = name.toLowerCase();
    for (final e in _entries) {
      if (e.key == lower) return e.value;
    }
    return null;
  }

  List<String> getAll(String name) {
    final lower = name.toLowerCase();
    return _entries.where((e) => e.key == lower).map((e) => e.value).toList();
  }

  bool has(String name) => get(name) != null;

  List<MapEntry<String, String>> get entries =>
      List.unmodifiable(_entries);

  int get length => _entries.length;

  HttpHeaders clone() {
    final h = HttpHeaders();
    for (final e in _entries) {
      h.add(e.key, e.value);
    }
    return h;
  }

  /// Serialize to HTTP wire format lines (without trailing CRLF CRLF).
  String toWireFormat() {
    return _entries.map((e) => '${e.key}: ${e.value}').join('\r\n');
  }

  /// Parse from raw header lines.
  static HttpHeaders parse(String raw) {
    final h = HttpHeaders();
    for (final line in raw.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        h.add(line.substring(0, idx).trim(), line.substring(idx + 1).trim());
      }
    }
    return h;
  }

  /// Remove hop-by-hop headers for forwarding.
  void stripHopByHop() {
    const hopByHop = {
      'connection', 'keep-alive', 'proxy-authenticate',
      'proxy-authorization', 'te', 'trailer',
      'transfer-encoding', 'upgrade', 'proxy-connection',
    };
    _entries.removeWhere((e) => hopByHop.contains(e.key));
  }

  @override
  String toString() => toWireFormat();
}

/// Represents a captured HTTP request.
class ProxyRequest {
  String method;
  String url;
  String httpVersion;
  HttpHeaders headers;
  Uint8List? body;
  DateTime timestamp;

  ProxyRequest({
    required this.method,
    required this.url,
    this.httpVersion = 'HTTP/1.1',
    HttpHeaders? headers,
    this.body,
    DateTime? timestamp,
  })  : headers = headers ?? HttpHeaders(),
        timestamp = timestamp ?? DateTime.now();

  String get host => headers.get('host') ?? Uri.parse(url).host;
  int get port {
    final h = headers.get('host');
    if (h != null && h.contains(':')) {
      return int.tryParse(h.split(':').last) ?? 80;
    }
    return url.startsWith('https') ? 443 : 80;
  }

  String get path {
    try {
      final p = Uri.parse(url).path;
      return p.isEmpty ? '/' : p;
    } catch (_) {
      return '/';
    }
  }

  /// Serialize to raw HTTP request text.
  String toRaw() {
    final path = Uri.parse(url).path.isEmpty ? '/' : Uri.parse(url).path;
    final query = Uri.parse(url).query;
    final target = query.isNotEmpty ? '$path?$query' : path;
    final buf = StringBuffer();
    buf.write('$method $target $httpVersion\r\n');
    buf.write('${headers.toWireFormat()}\r\n');
    buf.write('\r\n');
    if (body != null && body!.isNotEmpty) {
      buf.write(String.fromCharCodes(body!));
    }
    return buf.toString();
  }

  /// Parse from raw HTTP request text.
  static ProxyRequest fromRaw(String raw) {
    final headerBodySplit = raw.indexOf('\r\n\r\n');
    final headerPart = headerBodySplit > 0
        ? raw.substring(0, headerBodySplit)
        : raw;
    final bodyPart = headerBodySplit > 0
        ? raw.substring(headerBodySplit + 4)
        : '';

    final lines = headerPart.split('\r\n');
    final reqLine = lines.first.split(' ');
    final method = reqLine.isNotEmpty ? reqLine[0] : 'GET';
    final target = reqLine.length > 1 ? reqLine[1] : '/';
    final version = reqLine.length > 2 ? reqLine[2] : 'HTTP/1.1';

    final headers = HttpHeaders();
    for (var i = 1; i < lines.length; i++) {
      final idx = lines[i].indexOf(':');
      if (idx > 0) {
        headers.add(
          lines[i].substring(0, idx).trim(),
          lines[i].substring(idx + 1).trim(),
        );
      }
    }

    final host = headers.get('host') ?? 'localhost';
    final scheme = target.startsWith('https') ? 'https' : 'http';
    final url = target.startsWith('http') ? target : '$scheme://$host$target';

    return ProxyRequest(
      method: method,
      url: url,
      httpVersion: version,
      headers: headers,
      body: bodyPart.isNotEmpty ? Uint8List.fromList(bodyPart.codeUnits) : null,
    );
  }

  /// Export as cURL command.
  String toCurl() {
    final buf = StringBuffer("curl -X $method ");
    for (final e in headers.entries) {
      buf.write("-H '${e.key}: ${e.value}' ");
    }
    if (body != null && body!.isNotEmpty) {
      final bodyStr = String.fromCharCodes(body!).replaceAll("'", "\\'");
      buf.write("-d '$bodyStr' ");
    }
    buf.write("'$url'");
    return buf.toString();
  }
}

/// Represents a captured HTTP response.
class ProxyResponse {
  int statusCode;
  String statusText;
  String httpVersion;
  HttpHeaders headers;
  Uint8List? body;
  Duration? duration;

  ProxyResponse({
    required this.statusCode,
    this.statusText = '',
    this.httpVersion = 'HTTP/1.1',
    HttpHeaders? headers,
    this.body,
    this.duration,
  }) : headers = headers ?? HttpHeaders();

  int get bodySize => body?.length ?? 0;

  String get formattedSize {
    final bytes = bodySize;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get contentType => headers.get('content-type') ?? 'application/octet-stream';

  bool get isText {
    final ct = contentType.toLowerCase();
    return ct.contains('text') ||
        ct.contains('json') ||
        ct.contains('xml') ||
        ct.contains('html') ||
        ct.contains('javascript') ||
        ct.contains('css');
  }

  /// Returns the body bytes, decompressed if Content-Encoding is gzip or deflate.
  Uint8List? get decompressedBody {
    if (body == null || body!.isEmpty) return body;
    final ce = headers.get('content-encoding')?.toLowerCase().trim();
    if (ce == 'gzip') {
      try {
        return Uint8List.fromList(gzip.decode(body!));
      } catch (_) {}
    } else if (ce == 'deflate') {
      try {
        return Uint8List.fromList(zlib.decode(body!));
      } catch (_) {}
    }
    return body;
  }

  /// Serialize to raw HTTP response text.
  String toRaw() {
    final buf = StringBuffer();
    buf.write('$httpVersion $statusCode $statusText\r\n');
    buf.write('${headers.toWireFormat()}\r\n');
    buf.write('\r\n');
    final effective = decompressedBody;
    if (effective != null && effective.isNotEmpty) {
      if (isText) {
        buf.write(utf8.decode(effective, allowMalformed: true));
      } else {
        buf.write('[Binary data: ${effective.length} bytes]');
      }
    }
    return buf.toString();
  }
}

/// A complete request-response pair (a "flow").
class HttpFlow {
  final String id;
  final ProxyRequest request;
  ProxyResponse? response;
  bool isHttps;
  FlowState state;

  HttpFlow({
    required this.id,
    required this.request,
    this.response,
    this.isHttps = false,
    this.state = FlowState.pending,
  });

  String get displayUrl {
    try {
      final uri = Uri.parse(request.url);
      final path = uri.path.isEmpty ? '/' : uri.path;
      return path.length > 60 ? '${path.substring(0, 57)}...' : path;
    } catch (_) {
      return request.url;
    }
  }

  String get statusDisplay {
    if (response == null) return '...';
    return response!.statusCode.toString();
  }

  String get sizeDisplay {
    if (response == null) return '-';
    final bytes = response!.bodySize;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get durationDisplay {
    if (response?.duration == null) return '-';
    final ms = response!.duration!.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(2)}s';
  }
}

enum FlowState {
  pending,
  intercepted,
  forwarded,
  dropped,
  completed,
  error,
}
