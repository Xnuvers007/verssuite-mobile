import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Full-featured In-App Web DevTools Inspector modal:
/// - Elements (DOM Tree, HTML source, tag counts, visual element picker)
/// - Console (JavaScript REPL, execution history, quick presets)
/// - Application / Storage (Cookies, LocalStorage, SessionStorage inspector)
/// - Network (MITM proxy integration with Intercept & History)
/// - Remote Debugging (chrome://inspect guide for PC desktop DevTools)
/// - Eruda Mobile DevTools one-tap launcher
class WebDevToolsModal extends StatefulWidget {
  final WebViewController controller;
  final String currentUrl;
  final VoidCallback? onSwitchToHistory;
  final VoidCallback? onSwitchToIntercept;

  const WebDevToolsModal({
    super.key,
    required this.controller,
    required this.currentUrl,
    this.onSwitchToHistory,
    this.onSwitchToIntercept,
  });

  static Future<void> show(
    BuildContext context, {
    required WebViewController controller,
    required String currentUrl,
    VoidCallback? onSwitchToHistory,
    VoidCallback? onSwitchToIntercept,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WebDevToolsModal(
        controller: controller,
        currentUrl: currentUrl,
        onSwitchToHistory: onSwitchToHistory,
        onSwitchToIntercept: onSwitchToIntercept,
      ),
    );
  }

  /// Injects and launches Eruda directly onto the web page.
  static Future<void> launchEruda(WebViewController controller, BuildContext context) async {
    const js = '''
(function () {
  if (window.eruda) {
    if (window.eruda._isInit) {
      window.eruda.show();
    } else {
      window.eruda.init();
      window.eruda.show();
    }
    return;
  }
  var script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/eruda';
  script.onload = function () {
    eruda.init();
    eruda.show();
  };
  script.onerror = function() {
    alert('Gagal memuat Eruda dari CDN (Periksa koneksi internet / CSP situs).');
  };
  document.body.appendChild(script);
})();
''';
    try {
      await controller.runJavaScript(js);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.terminal, color: Color(0xFF00D4AA), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Eruda DevTools aktif! Ketuk ikon gear/tombol melayang di halaman web untuk membuka Elements, Console, & Network.',
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF1E1E38),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal injeksi Eruda: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  @override
  State<WebDevToolsModal> createState() => _WebDevToolsModalState();
}

class _WebDevToolsModalState extends State<WebDevToolsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Elements Tab State
  bool _isLoadingDom = true;
  String _htmlSource = '';
  String _domError = '';
  String _searchFilter = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _domStats = {};

  // Console Tab State
  final TextEditingController _consoleInputController = TextEditingController();
  final List<_ConsoleLogItem> _consoleLogs = [];
  bool _isExecutingJs = false;

  // Storage Tab State
  bool _isLoadingStorage = true;
  String _rawCookies = '';
  Map<String, String> _localStorageItems = {};
  Map<String, String> _sessionStorageItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _consoleInputController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchDom(),
      _fetchStorage(),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch Elements / DOM
  // ─────────────────────────────────────────────────────────────
  Future<void> _fetchDom() async {
    setState(() => _isLoadingDom = true);
    try {
      final result = await widget.controller.runJavaScriptReturningResult(
        'document.documentElement ? document.documentElement.outerHTML : ""',
      );

      String html = result.toString();
      // Handle JSON-encoded string return from webview_flutter
      if (html.startsWith('"') && html.endsWith('"')) {
        try {
          html = jsonDecode(html) as String;
        } catch (_) {}
      }

      // Fetch tag statistics
      final statsResult = await widget.controller.runJavaScriptReturningResult('''
(function() {
  return JSON.stringify({
    scripts: document.querySelectorAll('script').length,
    links: document.querySelectorAll('link').length,
    forms: document.querySelectorAll('form').length,
    inputs: document.querySelectorAll('input').length,
    images: document.querySelectorAll('img').length,
    anchors: document.querySelectorAll('a').length,
    totalNodes: document.querySelectorAll('*').length
  });
})()
''');

      Map<String, int> stats = {};
      try {
        String jsonStr = statsResult.toString();
        if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
          jsonStr = jsonDecode(jsonStr) as String;
        }
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        stats = parsed.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}

      if (mounted) {
        setState(() {
          _htmlSource = html;
          _domStats = stats;
          _domError = '';
          _isLoadingDom = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _domError = e.toString();
          _isLoadingDom = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch Storage (Cookies, LocalStorage, SessionStorage)
  // ─────────────────────────────────────────────────────────────
  Future<void> _fetchStorage() async {
    setState(() => _isLoadingStorage = true);
    try {
      // Cookies
      final cookieRes = await widget.controller.runJavaScriptReturningResult('document.cookie || ""');
      String cookies = cookieRes.toString();
      if (cookies.startsWith('"') && cookies.endsWith('"')) {
        try {
          cookies = jsonDecode(cookies) as String;
        } catch (_) {}
      }

      // LocalStorage
      final localRes = await widget.controller.runJavaScriptReturningResult('''
(function() {
  try {
    var items = {};
    for (var i = 0; i < localStorage.length; i++) {
      var key = localStorage.key(i);
      items[key] = localStorage.getItem(key);
    }
    return JSON.stringify(items);
  } catch (e) {
    return "{}";
  }
})()
''');
      Map<String, String> localItems = {};
      try {
        String jsonStr = localRes.toString();
        if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
          jsonStr = jsonDecode(jsonStr) as String;
        }
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        localItems = parsed.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      } catch (_) {}

      // SessionStorage
      final sessionRes = await widget.controller.runJavaScriptReturningResult('''
(function() {
  try {
    var items = {};
    for (var i = 0; i < sessionStorage.length; i++) {
      var key = sessionStorage.key(i);
      items[key] = sessionStorage.getItem(key);
    }
    return JSON.stringify(items);
  } catch (e) {
    return "{}";
  }
})()
''');
      Map<String, String> sessionItems = {};
      try {
        String jsonStr = sessionRes.toString();
        if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
          jsonStr = jsonDecode(jsonStr) as String;
        }
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        sessionItems = parsed.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      } catch (_) {}

      if (mounted) {
        setState(() {
          _rawCookies = cookies;
          _localStorageItems = localItems;
          _sessionStorageItems = sessionItems;
          _isLoadingStorage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStorage = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Console Execution
  // ─────────────────────────────────────────────────────────────
  Future<void> _executeJs(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isExecutingJs = true);
    final stopwatch = Stopwatch()..start();

    try {
      final result = await widget.controller.runJavaScriptReturningResult(
        '(function() { try { var res = eval(${jsonEncode(trimmed)}); return typeof res === "object" ? JSON.stringify(res, null, 2) : String(res); } catch(err) { return "ERROR: " + err.message; } })()',
      );
      stopwatch.stop();

      String output = result.toString();
      if (output.startsWith('"') && output.endsWith('"')) {
        try {
          output = jsonDecode(output) as String;
        } catch (_) {}
      }

      final isError = output.startsWith('ERROR:');
      if (mounted) {
        setState(() {
          _consoleLogs.insert(
            0,
            _ConsoleLogItem(
              command: trimmed,
              output: isError ? output.substring(6).trim() : output,
              isError: isError,
              durationMs: stopwatch.elapsedMilliseconds,
              timestamp: DateTime.now(),
            ),
          );
          _isExecutingJs = false;
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _consoleLogs.insert(
            0,
            _ConsoleLogItem(
              command: trimmed,
              output: e.toString(),
              isError: true,
              durationMs: stopwatch.elapsedMilliseconds,
              timestamp: DateTime.now(),
            ),
          );
          _isExecutingJs = false;
        });
      }
    }
  }

  // Visual element outline toggle
  Future<void> _toggleElementOutlines() async {
    const js = '''
(function() {
  var id = '__verssuite_inspector_outlines__';
  var existing = document.getElementById(id);
  if (existing) {
    existing.remove();
    return "Outlines removed";
  }
  var style = document.createElement('style');
  style.id = id;
  style.innerHTML = '* { outline: 1px solid rgba(0, 212, 170, 0.45) !important; outline-offset: -1px !important; } *:hover { outline: 2px solid #FF6B6B !important; }';
  document.head.appendChild(style);
  return "Outlines enabled";
})()
''';
    await widget.controller.runJavaScriptReturningResult(js);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visual Element Inspector Outline diaktifkan/dinonaktifkan pada halaman.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isIndonesian = l.locale.languageCode == 'id';

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ─── Drag Handle ───────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // ─── Header & Eruda Launcher ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.developer_mode_rounded,
                    color: Color(0xFF00D4AA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIndonesian ? 'Opsi Pengembang Peramban' : 'Browser DevTools',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.currentUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Eruda One-Tap Launcher
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    WebDevToolsModal.launchEruda(widget.controller, context);
                  },
                  icon: const Icon(Icons.rocket_launch, size: 14),
                  label: const Text('Eruda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh DevTools',
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                  onPressed: _refreshAll,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.white54,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── Tab Bar ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF00D4AA),
              indicatorWeight: 3,
              labelColor: const Color(0xFF00D4AA),
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.code_rounded, size: 16), text: 'Elements'),
                Tab(icon: Icon(Icons.terminal_rounded, size: 16), text: 'Console'),
                Tab(icon: Icon(Icons.storage_rounded, size: 16), text: 'Application'),
                Tab(icon: Icon(Icons.swap_horiz_rounded, size: 16), text: 'Network'),
                Tab(icon: Icon(Icons.laptop_chromebook_rounded, size: 16), text: 'Remote PC'),
              ],
            ),
          ),

          // ─── Tab Content ───────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildElementsTab(isIndonesian),
                _buildConsoleTab(isIndonesian),
                _buildStorageTab(isIndonesian),
                _buildNetworkTab(isIndonesian),
                _buildRemoteTab(isIndonesian),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. ELEMENTS TAB (HTML DOM Tree Inspector)
  // ─────────────────────────────────────────────────────────────
  Widget _buildElementsTab(bool isIndonesian) {
    if (_isLoadingDom) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D4AA)),
      );
    }

    if (_domError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFFF6B6B)),
              const SizedBox(height: 12),
              Text(
                'Gagal mengekstrak DOM: $_domError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchDom,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    // Filter lines if search query is entered
    final lines = _htmlSource.split('\n');
    final filteredLines = _searchFilter.isEmpty
        ? lines
        : lines.where((l) => l.toLowerCase().contains(_searchFilter.toLowerCase())).toList();

    return Column(
      children: [
        // Tag Stats Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF16162A),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatBadge(label: 'Total Nodes', value: '${_domStats['totalNodes'] ?? 0}'),
                const SizedBox(width: 8),
                _StatBadge(label: 'Scripts', value: '${_domStats['scripts'] ?? 0}'),
                const SizedBox(width: 8),
                _StatBadge(label: 'Forms', value: '${_domStats['forms'] ?? 0}'),
                const SizedBox(width: 8),
                _StatBadge(label: 'Inputs', value: '${_domStats['inputs'] ?? 0}'),
                const SizedBox(width: 8),
                _StatBadge(label: 'Images', value: '${_domStats['images'] ?? 0}'),
                const SizedBox(width: 8),
                _StatBadge(label: 'Links', value: '${_domStats['anchors'] ?? 0}'),
              ],
            ),
          ),
        ),

        // Action Toolbar & Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E38),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
                      hintText: isIndonesian ? 'Cari elemen, tag, class, id...' : 'Search tags, class, id...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon: _searchFilter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14, color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchFilter = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchFilter = val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Visual Outline Inspector Toggle
              IconButton.filledTonal(
                icon: const Icon(Icons.crop_free, size: 18),
                tooltip: 'Sorot Elemen Visual (Outline Picker)',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA).withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFF00D4AA),
                ),
                onPressed: _toggleElementOutlines,
              ),
              const SizedBox(width: 4),
              // Copy HTML
              IconButton.filledTonal(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Salin Seluruh HTML',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFF6C63FF),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _htmlSource));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('HTML DOM berhasil disalin ke papan klip.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Live DOM Content
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: filteredLines.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada tag/elemen yang cocok dengan pencarian.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLines.length,
                    itemBuilder: (ctx, index) {
                      final line = filteredLines[index];
                      return Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.4,
                          color: _highlightHtmlTagColor(line),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Color _highlightHtmlTagColor(String line) {
    final trimmed = line.trim();
    if (trimmed.startsWith('<!--')) return const Color(0xFF6A9955);
    if (trimmed.startsWith('</')) return const Color(0xFFE5C07B);
    if (trimmed.startsWith('<script') || trimmed.contains('javascript:')) {
      return const Color(0xFFFFB74D);
    }
    if (trimmed.startsWith('<form') || trimmed.startsWith('<input')) {
      return const Color(0xFFFF6B6B);
    }
    if (trimmed.startsWith('<style') || trimmed.startsWith('<link')) {
      return const Color(0xFFC678DD);
    }
    if (trimmed.startsWith('<')) return const Color(0xFF61AFEF);
    return const Color(0xFFABB2BF);
  }

  // ─────────────────────────────────────────────────────────────
  // 2. CONSOLE TAB (JavaScript Interactive Terminal)
  // ─────────────────────────────────────────────────────────────
  Widget _buildConsoleTab(bool isIndonesian) {
    return Column(
      children: [
        // Quick Presets Bar
        Container(
          height: 38,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SnippetChip(label: 'document.cookie', onTap: () => _executeJs('document.cookie')),
              _SnippetChip(label: 'localStorage', onTap: () => _executeJs('JSON.stringify(window.localStorage)')),
              _SnippetChip(label: 'document.title', onTap: () => _executeJs('document.title')),
              _SnippetChip(label: 'location.href', onTap: () => _executeJs('window.location.href')),
              _SnippetChip(label: 'Forms count', onTap: () => _executeJs('document.forms.length')),
              _SnippetChip(label: 'XSS PoC alert', onTap: () => _executeJs("alert('VersSuite Mobile XSS Test!')")),
              _SnippetChip(label: 'navigator.userAgent', onTap: () => _executeJs('navigator.userAgent')),
            ],
          ),
        ),

        // Console History
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: _consoleLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.terminal_rounded, size: 40, color: Colors.white24),
                        const SizedBox(height: 8),
                        Text(
                          isIndonesian
                              ? 'Konsol JavaScript Siap.\nKetik perintah JS atau gunakan preset di atas.'
                              : 'JavaScript Console Ready.\nType JS code or use quick presets above.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _consoleLogs.length,
                    itemBuilder: (ctx, index) {
                      final item = _consoleLogs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.isError
                              ? const Color(0xFFFF6B6B).withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.isError
                                ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
                                : Colors.white12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('> ', style: TextStyle(color: Color(0xFF00D4AA), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    item.command,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.durationMs}ms',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12, color: Colors.white10),
                            SelectableText(
                              item.output,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: item.isError ? const Color(0xFFFF6B6B) : const Color(0xFF00D4AA),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Console Input Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E38),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Text('> ', style: TextStyle(color: Color(0xFF00D4AA), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: TextField(
                          controller: _consoleInputController,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'eval JavaScript code...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.white38),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (code) {
                            _executeJs(code);
                            _consoleInputController.clear();
                          },
                        ),
                      ),
                      if (_consoleLogs.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          tooltip: 'Clear Console',
                          color: Colors.white38,
                          onPressed: () => setState(() => _consoleLogs.clear()),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: _isExecutingJs
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  _executeJs(_consoleInputController.text);
                  _consoleInputController.clear();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. STORAGE TAB (Cookies, LocalStorage, SessionStorage)
  // ─────────────────────────────────────────────────────────────
  Widget _buildStorageTab(bool isIndonesian) {
    if (_isLoadingStorage) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4AA)));
    }

    final cookiePairs = _rawCookies
        .split(';')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cookies Section
        _StorageSectionHeader(
          title: 'Document Cookies (${cookiePairs.length})',
          icon: Icons.cookie_outlined,
          color: const Color(0xFFFFAA33),
          onClear: () async {
            await widget.controller.runJavaScript('document.cookie.split(";").forEach(function(c) { document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/"); });');
            _fetchStorage();
          },
        ),
        const SizedBox(height: 8),
        if (cookiePairs.isEmpty)
          const _EmptyStorageCard(text: 'Tidak ada cookie yang tersimpan untuk domain ini.')
        else
          Card(
            color: const Color(0xFF141428),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: cookiePairs.map((pair) {
                  final split = pair.split('=');
                  final key = split.first;
                  final value = split.skip(1).join('=');
                  return _StorageRow(itemKey: key, itemValue: value);
                }).toList(),
              ),
            ),
          ),

        const SizedBox(height: 20),

        // LocalStorage Section
        _StorageSectionHeader(
          title: 'LocalStorage (${_localStorageItems.length})',
          icon: Icons.storage_rounded,
          color: const Color(0xFF6C63FF),
          onClear: () async {
            await widget.controller.runJavaScript('localStorage.clear()');
            _fetchStorage();
          },
        ),
        const SizedBox(height: 8),
        if (_localStorageItems.isEmpty)
          const _EmptyStorageCard(text: 'LocalStorage kosong.')
        else
          Card(
            color: const Color(0xFF141428),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _localStorageItems.entries.map((e) {
                  return _StorageRow(itemKey: e.key, itemValue: e.value);
                }).toList(),
              ),
            ),
          ),

        const SizedBox(height: 20),

        // SessionStorage Section
        _StorageSectionHeader(
          title: 'SessionStorage (${_sessionStorageItems.length})',
          icon: Icons.access_time_rounded,
          color: const Color(0xFF00D4AA),
          onClear: () async {
            await widget.controller.runJavaScript('sessionStorage.clear()');
            _fetchStorage();
          },
        ),
        const SizedBox(height: 8),
        if (_sessionStorageItems.isEmpty)
          const _EmptyStorageCard(text: 'SessionStorage kosong.')
        else
          Card(
            color: const Color(0xFF141428),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _sessionStorageItems.entries.map((e) {
                  return _StorageRow(itemKey: e.key, itemValue: e.value);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. NETWORK TAB (MITM Proxy Integration)
  // ─────────────────────────────────────────────────────────────
  Widget _buildNetworkTab(bool isIndonesian) {
    return Padding(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF16162A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub_outlined, color: Color(0xFF00D4AA)),
                    SizedBox(width: 10),
                    Text(
                      'Pemeriksa Jaringan (Network Inspector)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isIndonesian
                      ? 'Seluruh lalu lintas peramban ini (XHR, Fetch, WebSocket, CSS, JS, Gambar) secara otomatis dialirkan melalui mesin proksi VersSuite Mobile.'
                      : 'All traffic from this browser (XHR, Fetch, WebSocket, CSS, JS, Images) is routed through VersSuite Mobile\'s proxy engine.',
                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.7), height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSwitchToHistory?.call();
                        },
                        icon: const Icon(Icons.history, size: 16),
                        label: Text(isIndonesian ? 'Buka History Aliran' : 'Open History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSwitchToIntercept?.call();
                        },
                        icon: const Icon(Icons.pause_circle_outline, size: 16),
                        label: Text(isIndonesian ? 'Buka Intersep' : 'Open Intercept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4AA),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. REMOTE PC TAB (chrome://inspect Guide)
  // ─────────────────────────────────────────────────────────────
  Widget _buildRemoteTab(bool isIndonesian) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00D4AA).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF00D4AA), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'WebView Remote Debugging AKTIF secara default di VersSuite Mobile!',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00D4AA),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isIndonesian ? 'Cara Membuka Chrome DevTools Desktop di PC:' : 'How to Open Desktop Chrome DevTools on PC:',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 12),
        _StepTile(
          number: '1',
          title: 'Aktifkan USB Debugging di HP',
          desc: 'Buka Pengaturan HP ➔ Opsi Pengembang ➔ Nyalakan "USB Debugging".',
        ),
        _StepTile(
          number: '2',
          title: 'Colokkan HP ke Komputer / Laptop',
          desc: 'Gunakan kabel data USB dan izinkan pop-up USB debugging di layar HP Anda.',
        ),
        _StepTile(
          number: '3',
          title: 'Buka URL Khusus Ini di Google Chrome PC',
          desc: 'Ketik di bilah alamat Chrome laptop Anda:\nchrome://inspect/#devices',
        ),
        _StepTile(
          number: '4',
          title: 'Klik Tombol "Inspect"',
          desc: 'Anda akan melihat nama model HP Anda dan halaman web yang sedang aktif di VersSuite. Klik "inspect" untuk membuka Chrome DevTools lengkap (Elements, Console, Sources, Network, Application) persis seperti tangkapan layar Anda!',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets & Helpers
// ─────────────────────────────────────────────────────────────
class _ConsoleLogItem {
  final String command;
  final String output;
  final bool isError;
  final int durationMs;
  final DateTime timestamp;

  _ConsoleLogItem({
    required this.command,
    required this.output,
    required this.isError,
    required this.durationMs,
    required this.timestamp,
  });
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00D4AA),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnippetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SnippetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label),
        labelStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70),
        backgroundColor: const Color(0xFF1E1E38),
        side: const BorderSide(color: Colors.white12),
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _StorageSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onClear;

  const _StorageSectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        TextButton(
          onPressed: onClear,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            visualDensity: VisualDensity.compact,
            foregroundColor: const Color(0xFFFF6B6B),
          ),
          child: const Text('Hapus Semua', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

class _StorageRow extends StatelessWidget {
  final String itemKey;
  final String itemValue;
  const _StorageRow({required this.itemKey, required this.itemValue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              itemKey,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              itemValue,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStorageCard extends StatelessWidget {
  final String text;
  const _EmptyStorageCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141428),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: Colors.white38),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  const _StepTile({required this.number, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF6C63FF),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
