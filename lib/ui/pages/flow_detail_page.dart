import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/http_models.dart';

class FlowDetailPage extends StatefulWidget {
  final HttpFlow flow;
  const FlowDetailPage({super.key, required this.flow});

  @override
  State<FlowDetailPage> createState() => _FlowDetailPageState();
}

class _FlowDetailPageState extends State<FlowDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final flow = widget.flow;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _methodColor(flow.request.method).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                flow.request.method,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: _methodColor(flow.request.method),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                flow.request.host,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // cURL export
          IconButton(
            icon: const Icon(Icons.code, size: 20),
            tooltip: l.tr('export_curl'),
            onPressed: () {
              final curl = flow.request.toCurl();
              Clipboard.setData(ClipboardData(text: curl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.tr('copied'))),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: l.tr('request')),
            Tab(text: l.tr('response')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RequestView(request: flow.request, l: l),
          _ResponseView(response: flow.response, l: l),
        ],
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return const Color(0xFF00D4AA);
      case 'POST': return const Color(0xFF6C63FF);
      case 'PUT': return const Color(0xFFFFAA33);
      case 'DELETE': return const Color(0xFFFF6B6B);
      default: return Colors.white70;
    }
  }
}

class _RequestView extends StatefulWidget {
  final ProxyRequest request;
  final AppLocalizations l;
  const _RequestView({required this.request, required this.l});

  @override
  State<_RequestView> createState() => _RequestViewState();
}

class _RequestViewState extends State<_RequestView> {
  int _viewMode = 0; // 0=headers, 1=raw, 2=hex

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // View mode selector
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Chip(label: widget.l.tr('headers'), selected: _viewMode == 0, onTap: () => setState(() => _viewMode = 0)),
              const SizedBox(width: 6),
              _Chip(label: widget.l.tr('raw'), selected: _viewMode == 1, onTap: () => setState(() => _viewMode = 1)),
              const SizedBox(width: 6),
              _Chip(label: widget.l.tr('hex'), selected: _viewMode == 2, onTap: () => setState(() => _viewMode = 2)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _viewMode == 0
                ? _HeadersView(headers: widget.request.headers, url: widget.request.url, method: widget.request.method)
                : SelectableText(
                    _viewMode == 1
                        ? widget.request.toRaw()
                        : _hexDump(widget.request.toRaw()),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ResponseView extends StatefulWidget {
  final ProxyResponse? response;
  final AppLocalizations l;
  const _ResponseView({required this.response, required this.l});

  @override
  State<_ResponseView> createState() => _ResponseViewState();
}

class _ResponseViewState extends State<_ResponseView> {
  int _viewMode = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.response == null) {
      return Center(
        child: Text(
          widget.l.tr('no_response'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      );
    }

    final resp = widget.response!;

    return Column(
      children: [
        // Status bar
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _statusColor(resp.statusCode).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _statusColor(resp.statusCode).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(
                '${resp.statusCode}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: _statusColor(resp.statusCode),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                resp.statusText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              if (resp.duration != null)
                Text(
                  '${resp.duration!.inMilliseconds}ms',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                    fontFamily: 'monospace',
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _formatBytes(resp.bodySize),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),

        // View mode selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _Chip(label: widget.l.tr('headers'), selected: _viewMode == 0, onTap: () => setState(() => _viewMode = 0)),
              const SizedBox(width: 6),
              _Chip(label: widget.l.tr('body'), selected: _viewMode == 1, onTap: () => setState(() => _viewMode = 1)),
              const SizedBox(width: 6),
              _Chip(label: widget.l.tr('raw'), selected: _viewMode == 2, onTap: () => setState(() => _viewMode = 2)),
              const SizedBox(width: 6),
              _Chip(label: widget.l.tr('hex'), selected: _viewMode == 3, onTap: () => setState(() => _viewMode = 3)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildContent(resp),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ProxyResponse resp) {
    switch (_viewMode) {
      case 0:
        return _HeadersView(headers: resp.headers);
      case 1:
        return _BodyView(response: resp);
      case 2:
        return SelectableText(
          resp.toRaw(),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
        );
      case 3:
        return SelectableText(
          _hexDump(resp.toRaw()),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
        );
      default:
        return const SizedBox();
    }
  }

  Color _statusColor(int code) {
    if (code >= 200 && code < 300) return const Color(0xFF00D4AA);
    if (code >= 300 && code < 400) return const Color(0xFFFFAA33);
    if (code >= 400 && code < 500) return const Color(0xFFFF6B6B);
    if (code >= 500) return const Color(0xFFFF4444);
    return Colors.white38;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _HeadersView extends StatelessWidget {
  final HttpHeaders headers;
  final String? url;
  final String? method;
  const _HeadersView({required this.headers, this.url, this.method});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url != null) ...[
          _HeaderRow(name: 'URL', value: url!),
          const Divider(height: 16),
        ],
        if (method != null) ...[
          _HeaderRow(name: 'Method', value: method!),
          const Divider(height: 16),
        ],
        ...headers.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _HeaderRow(name: e.key, value: e.value),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String name;
  final String value;
  const _HeaderRow({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6C63FF).withValues(alpha: 0.8),
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _BodyView extends StatelessWidget {
  final ProxyResponse response;
  const _BodyView({required this.response});

  @override
  Widget build(BuildContext context) {
    if (response.body == null || response.body!.isEmpty) {
      return Text(
        'Empty body',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      );
    }

    final ct = response.contentType.toLowerCase();

    // Try to pretty-print JSON
    if (ct.contains('json')) {
      try {
        final decoded = json.decode(utf8.decode(response.body!));
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        return SelectableText(
          pretty,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
        );
      } catch (_) {}
    }

    if (response.isText) {
      return SelectableText(
        utf8.decode(response.body!, allowMalformed: true),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
      );
    }

    return Text(
      '[Binary data: ${response.bodySize} bytes]',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

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

String _hexDump(String text) {
  final bytes = utf8.encode(text);
  final buf = StringBuffer();
  for (var i = 0; i < bytes.length && i < 4096; i += 16) {
    buf.write(i.toRadixString(16).padLeft(8, '0'));
    buf.write('  ');
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
    for (var j = 0; j < 16 && i + j < bytes.length; j++) {
      final b = bytes[i + j];
      buf.write(b >= 32 && b <= 126 ? String.fromCharCode(b) : '.');
    }
    buf.write('|\n');
  }
  return buf.toString();
}
