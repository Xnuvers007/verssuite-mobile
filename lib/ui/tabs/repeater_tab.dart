import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/http_models.dart';

class RepeaterTab extends StatefulWidget {
  const RepeaterTab({super.key});

  @override
  State<RepeaterTab> createState() => _RepeaterTabState();
}

class _RepeaterTabState extends State<RepeaterTab> {
  final TextEditingController _requestController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  String _responseText = '';
  bool _loading = false;
  int _viewMode = 0; // 0=raw, 1=headers, 2=hex

  @override
  void initState() {
    super.initState();
    _urlController.text = 'https://httpbin.org/get';
    _requestController.text =
        'GET / HTTP/1.1\r\nHost: httpbin.org\r\nUser-Agent: VersSuite/1.0\r\nAccept: */*\r\n\r\n';
  }

  @override
  void dispose() {
    _requestController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    setState(() {
      _loading = true;
      _responseText = '';
    });

    try {
      final request = ProxyRequest.fromRaw(_requestController.text);
      // Override URL if set
      if (_urlController.text.isNotEmpty) {
        request.url = _urlController.text;
        final uri = Uri.parse(request.url);
        request.headers.set('host', uri.host);
      }

      final client = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true
        ..connectionTimeout = const Duration(seconds: 15);

      final uri = Uri.parse(request.url);
      final httpReq = await client.openUrl(request.method, uri);

      request.headers.entries.forEach((e) {
        if (e.key != 'host') {
          httpReq.headers.add(e.key, e.value);
        }
      });

      if (request.body != null && request.body!.isNotEmpty) {
        httpReq.add(request.body!);
      }

      final stopwatch = Stopwatch()..start();
      final httpResp = await httpReq.close().timeout(
        const Duration(seconds: 30),
      );
      stopwatch.stop();

      final respHeaders = HttpHeaders();
      httpResp.headers.forEach((name, values) {
        for (final v in values) {
          respHeaders.add(name, v);
        }
      });

      final respBody = <int>[];
      await for (final chunk in httpResp) {
        respBody.addAll(chunk);
      }

      final response = ProxyResponse(
        statusCode: httpResp.statusCode,
        statusText: httpResp.reasonPhrase,
        headers: respHeaders,
        body: Uint8List.fromList(respBody),
        duration: stopwatch.elapsed,
      );

      client.close(force: true);

      setState(() {
        _responseText = response.toRaw();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _loading = false;
      });
    }
  }

  String _toHexDump(String text) {
    final bytes = utf8.encode(text);
    final buf = StringBuffer();
    for (var i = 0; i < bytes.length; i += 16) {
      // Offset
      buf.write(i.toRadixString(16).padLeft(8, '0'));
      buf.write('  ');

      // Hex
      for (var j = 0; j < 16; j++) {
        if (i + j < bytes.length) {
          buf.write(bytes[i + j].toRadixString(16).padLeft(2, '0'));
          buf.write(' ');
        } else {
          buf.write('   ');
        }
        if (j == 7) buf.write(' ');
      }

      buf.write(' |');
      // ASCII
      for (var j = 0; j < 16 && i + j < bytes.length; j++) {
        final b = bytes[i + j];
        buf.write(b >= 32 && b <= 126 ? String.fromCharCode(b) : '.');
      }
      buf.write('|\n');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  l.tr('repeater'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // URL bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: l.tr('enter_url'),
                      prefixIcon: const Icon(Icons.link, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l.tr('send')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Request editor (top half)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.tr('request'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: TextField(
                        controller: _requestController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Response viewer (bottom half)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l.tr('response'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const Spacer(),
                      _ViewModeChip(
                        label: l.tr('raw'),
                        selected: _viewMode == 0,
                        onTap: () => setState(() => _viewMode = 0),
                      ),
                      const SizedBox(width: 4),
                      _ViewModeChip(
                        label: l.tr('hex'),
                        selected: _viewMode == 1,
                        onTap: () => setState(() => _viewMode = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: _responseText.isEmpty
                          ? Center(
                              child: Text(
                                l.tr('no_response'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: SelectableText(
                                _viewMode == 1
                                    ? _toHexDump(_responseText)
                                    : _responseText,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ViewModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFF6C63FF) : Colors.white54,
          ),
        ),
      ),
    );
  }
}
