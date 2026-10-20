import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/proxy_config.dart';
import '../../state/app_state.dart';

/// Full-featured in-app browser with custom UA, IP simulation, search engines,
/// and browser controls matching modern desktop & mobile inspection tools.
class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => BrowserTabState();
}

class BrowserTabState extends State<BrowserTab> {
  late final WebViewController _controller;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  double _loadingProgress = 0.0;
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentTitle = 'Browser';

  // Expose for HomePage double-back handler
  bool get canGoBack => _canGoBack;
  Future<void> goBack() async {
    if (_canGoBack) {
      await _controller.goBack();
      _updateNavState();
    }
  }

  @override
  void initState() {
    super.initState();
    _urlController.text = 'https://github.com/Xnuvers007/verssuite-mobile';

    final appState = context.read<AppState>();
    final config = appState.config;

    _controller = WebViewController()
      ..setJavaScriptMode(
        config.javascriptEnabled
            ? JavaScriptMode.unrestricted
            : JavaScriptMode.disabled,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress / 100.0);
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _urlController.text = url;
              });
              _updateNavState();
            }
          },
          onPageFinished: (url) async {
            final title = await _controller.getTitle();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _loadingProgress = 0.0;
                _urlController.text = url;
                if (title != null && title.isNotEmpty) {
                  _currentTitle = title;
                }
              });
              _updateNavState();
            }
          },
          onWebResourceError: (error) {
            debugPrint('[InAppBrowser] Resource error: ${error.description}');
          },
          onSslAuthError: (sslError) {
            // Auto-bypass self-signed MITM certificate warnings if configured
            if (appState.config.bypassSslWarnings) {
              sslError.proceed();
            } else {
              sslError.cancel();
            }
          },
        ),
      );

    // Set initial custom User Agent if configured
    final initialUA = config.effectiveUserAgent;
    if (initialUA.isNotEmpty) {
      _controller.setUserAgent(initialUA);
    }

    _controller.loadRequest(Uri.parse(_urlController.text));
  }

  Future<void> _updateNavState() async {
    try {
      final back = await _controller.canGoBack();
      final forward = await _controller.canGoForward();
      if (mounted) {
        setState(() {
          _canGoBack = back;
          _canGoForward = forward;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _loadUrl(String input) {
    _urlFocusNode.unfocus();
    String trimmed = input.trim();
    if (trimmed.isEmpty) return;

    final appState = context.read<AppState>();
    final config = appState.config;

    Uri? targetUri;
    // Check if it's a direct URL or domain
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      targetUri = Uri.tryParse(trimmed);
    } else if (trimmed.contains('.') && !trimmed.contains(' ')) {
      targetUri = Uri.tryParse('https://$trimmed');
    } else {
      // Use configured search engine
      final searchUrl = config.buildSearchUrl(trimmed);
      targetUri = Uri.tryParse(searchUrl);
    }

    if (targetUri != null) {
      final headers = <String, String>{};
      if (config.customForwardedIp.trim().isNotEmpty) {
        headers['X-Forwarded-For'] = config.customForwardedIp.trim();
        headers['X-Real-IP'] = config.customForwardedIp.trim();
        headers['Client-IP'] = config.customForwardedIp.trim();
      }
      _controller.loadRequest(targetUri, headers: headers);
    }
  }

  Future<void> _clearCacheAndCookies() async {
    await _controller.clearCache();
    await _controller.clearLocalStorage();
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();

    if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tr('cache_cleared'))),
      );
    }
  }

  void _openCustomizationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BrowserCustomizationModal(
        controller: _controller,
        onRefresh: () => _controller.reload(),
        onClearCache: _clearCacheAndCookies,
        onNavigate: _loadUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final isProxyRunning = appState.proxyRunning;
    final isHttps = _urlController.text.startsWith('https');
    final isHttp = _urlController.text.startsWith('http:');

    return SafeArea(
      child: Column(
        children: [
          // ─── Top Proxy Status Bar ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isProxyRunning
                  ? const Color(0xFF00D4AA).withValues(alpha: 0.12)
                  : const Color(0xFFFF6B6B).withValues(alpha: 0.12),
              border: Border(
                bottom: BorderSide(
                  color: isProxyRunning
                      ? const Color(0xFF00D4AA).withValues(alpha: 0.25)
                      : const Color(0xFFFF6B6B).withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isProxyRunning ? Icons.security : Icons.warning_amber_rounded,
                  size: 14,
                  color: isProxyRunning
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFFFF6B6B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isProxyRunning
                        ? '${l.tr('proxy_active_intercepting')} · :${appState.config.port}'
                        : l.tr('proxy_inactive'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isProxyRunning
                          ? const Color(0xFF00D4AA)
                          : const Color(0xFFFF6B6B),
                    ),
                  ),
                ),
                if (!isProxyRunning)
                  GestureDetector(
                    onTap: () => appState.startProxy(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l.tr('start_proxy_now'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Browser Controls & Address Bar ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 6, 4),
            child: Row(
              children: [
                // 1. Previous Button (Panah Kiri)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: l.tr('nav_previous'),
                  color: _canGoBack ? Colors.white : Colors.white24,
                  onPressed: _canGoBack
                      ? () async {
                          await _controller.goBack();
                          _updateNavState();
                        }
                      : null,
                ),

                // 2. Next Button (Panah Kanan)
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: l.tr('nav_next'),
                  color: _canGoForward ? Colors.white : Colors.white24,
                  onPressed: _canGoForward
                      ? () async {
                          await _controller.goForward();
                          _updateNavState();
                        }
                      : null,
                ),

                // 3. Refresh Button (Garis Bulet)
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6C63FF),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: l.tr('nav_refresh'),
                  color: Colors.white70,
                  onPressed: () {
                    if (_isLoading) {
                      _controller.loadRequest(Uri.parse('about:blank'));
                    } else {
                      _controller.reload();
                    }
                  },
                ),

                // 4. Home Button
                IconButton(
                  icon: const Icon(Icons.home_outlined, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: l.tr('nav_home'),
                  color: Colors.white70,
                  onPressed: () => _loadUrl('https://github.com/Xnuvers007/verssuite-mobile'),
                ),

                // 5. Address Bar with Lock Icon (Inputan URL kayak di gambar)
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12122A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isHttps
                            ? const Color(0xFF00D4AA).withValues(alpha: 0.35)
                            : isHttp
                                ? const Color(0xFFFFAA33).withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        // Security Lock / Search Icon inside
                        Icon(
                          isHttps
                              ? Icons.lock
                              : isHttp
                                  ? Icons.lock_open
                                  : Icons.search,
                          size: 15,
                          color: isHttps
                              ? const Color(0xFF00D4AA)
                              : isHttp
                                  ? const Color(0xFFFFAA33)
                                  : Colors.white38,
                        ),
                        const SizedBox(width: 8),

                        // URL Text Input
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            focusNode: _urlFocusNode,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: l.tr('search_or_enter_url'),
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.go,
                            onSubmitted: _loadUrl,
                          ),
                        ),

                        // Clear or Enter button
                        if (_urlController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            visualDensity: VisualDensity.compact,
                            color: Colors.white38,
                            onPressed: () {
                              _urlController.clear();
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // 6. Customization / Settings Action Button (User-Agent, IP, Search Engine)
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: l.tr('browser_customization'),
                  color: const Color(0xFF6C63FF),
                  onPressed: () => _openCustomizationSheet(context),
                ),
              ],
            ),
          ),

          // ─── Loading Progress Bar ───────────────────────────────
          if (_isLoading && _loadingProgress > 0 && _loadingProgress < 1.0)
            LinearProgressIndicator(
              value: _loadingProgress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),

          // ─── Quick Shortcuts Bar ────────────────────────────────
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _QuickChip(
                  label: 'GitHub Repo',
                  icon: Icons.code,
                  onTap: () => _loadUrl('https://github.com/Xnuvers007/verssuite-mobile'),
                ),
                _QuickChip(
                  label: 'HttpBin',
                  icon: Icons.bug_report_outlined,
                  onTap: () => _loadUrl('https://httpbin.org'),
                ),
                _QuickChip(
                  label: 'Check IP',
                  icon: Icons.my_location,
                  onTap: () => _loadUrl('https://httpbin.org/ip'),
                ),
                _QuickChip(
                  label: 'Postman Echo',
                  icon: Icons.send_outlined,
                  onTap: () => _loadUrl('https://postman-echo.com/get'),
                ),
                _QuickChip(
                  label: 'DuckDuckGo',
                  icon: Icons.search,
                  onTap: () => _loadUrl('https://duckduckgo.com'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ─── WebView Area ──────────────────────────────────────
          Expanded(
            child: Container(
              color: Colors.white,
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Browser Customization Sheet (UA, IP, Search Engine, etc.)
// ─────────────────────────────────────────────────────────────
class _BrowserCustomizationModal extends StatefulWidget {
  final WebViewController controller;
  final VoidCallback onRefresh;
  final VoidCallback onClearCache;
  final void Function(String) onNavigate;

  const _BrowserCustomizationModal({
    required this.controller,
    required this.onRefresh,
    required this.onClearCache,
    required this.onNavigate,
  });

  @override
  State<_BrowserCustomizationModal> createState() =>
      _BrowserCustomizationModalState();
}

class _BrowserCustomizationModalState
    extends State<_BrowserCustomizationModal> {
  late TextEditingController _customUaController;
  late TextEditingController _customIpController;
  late TextEditingController _customSearchController;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppState>().config;
    _customUaController = TextEditingController(text: config.customUserAgent);
    _customIpController = TextEditingController(text: config.customForwardedIp);
    _customSearchController =
        TextEditingController(text: config.customSearchEngineUrl);
  }

  @override
  void dispose() {
    _customUaController.dispose();
    _customIpController.dispose();
    _customSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final config = appState.config;
    final isIndonesian = l.locale.languageCode == 'id';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF6C63FF), size: 24),
              const SizedBox(width: 10),
              Text(
                l.tr('browser_customization'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── 1. User Agent Selection ──────────────────────────
          _HeaderLabel(
            title: l.tr('user_agent'),
            subtitle: isIndonesian
                ? 'Pilih preset identitas browser atau buat custom UA'
                : 'Choose browser identity preset or customize string',
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _UaOption(
                    title: isIndonesian ? 'Default (Android Mobile)' : 'Default (Android Mobile)',
                    value: 'default',
                    groupValue: config.userAgentPreset,
                    onSelected: (val) async {
                      config.userAgentPreset = val;
                      await widget.controller.setUserAgent(null);
                      appState.saveConfig();
                      setState(() {});
                    },
                  ),
                  _UaOption(
                    title: 'Windows Chrome 125 (Desktop)',
                    value: 'desktop_windows',
                    groupValue: config.userAgentPreset,
                    onSelected: (val) async {
                      config.userAgentPreset = val;
                      await widget.controller.setUserAgent(ProxyConfig.uaDesktopWindows);
                      appState.saveConfig();
                      setState(() {});
                    },
                  ),
                  _UaOption(
                    title: 'Apple iPhone (iOS Safari)',
                    value: 'iphone',
                    groupValue: config.userAgentPreset,
                    onSelected: (val) async {
                      config.userAgentPreset = val;
                      await widget.controller.setUserAgent(ProxyConfig.uaIPhone);
                      appState.saveConfig();
                      setState(() {});
                    },
                  ),
                  _UaOption(
                    title: 'Apple iPad (Tablet Safari)',
                    value: 'ipad',
                    groupValue: config.userAgentPreset,
                    onSelected: (val) async {
                      config.userAgentPreset = val;
                      await widget.controller.setUserAgent(ProxyConfig.uaIPad);
                      appState.saveConfig();
                      setState(() {});
                    },
                  ),
                  _UaOption(
                    title: 'macOS Safari (Desktop Mac)',
                    value: 'mac',
                    groupValue: config.userAgentPreset,
                    onSelected: (val) async {
                      config.userAgentPreset = val;
                      await widget.controller.setUserAgent(ProxyConfig.uaMac);
                      appState.saveConfig();
                      setState(() {});
                    },
                  ),
                  _UaOption(
                    title: isIndonesian ? 'Custom User Agent' : 'Custom User Agent String',
                    value: 'custom',
                    groupValue: config.userAgentPreset,
                    onSelected: (val) async {
                      config.userAgentPreset = val;
                      if (config.customUserAgent.isNotEmpty) {
                        await widget.controller.setUserAgent(config.customUserAgent);
                      }
                      appState.saveConfig();
                      setState(() {});
                    },
                  ),
                  if (config.userAgentPreset == 'custom')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: _customUaController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: l.tr('custom_ua_hint'),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          config.customUserAgent = val;
                          widget.controller.setUserAgent(val);
                          appState.saveConfig();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── 2. Search Engine Selection ───────────────────────
          _HeaderLabel(
            title: l.tr('search_engine'),
            subtitle: isIndonesian
                ? 'Mesin pencari saat mengetik kata kunci di address bar'
                : 'Search provider used when typing queries in address bar',
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: config.searchEngine,
                    dropdownColor: const Color(0xFF16162A),
                    decoration: const InputDecoration(isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'google', child: Text('Google Search')),
                      DropdownMenuItem(value: 'duckduckgo', child: Text('DuckDuckGo')),
                      DropdownMenuItem(value: 'bing', child: Text('Microsoft Bing')),
                      DropdownMenuItem(value: 'brave', child: Text('Brave Search')),
                      DropdownMenuItem(value: 'yahoo', child: Text('Yahoo! Search')),
                      DropdownMenuItem(value: 'startpage', child: Text('Startpage')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom Search URL')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        config.searchEngine = val;
                        appState.saveConfig();
                        setState(() {});
                      }
                    },
                  ),
                  if (config.searchEngine == 'custom')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: _customSearchController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: l.tr('custom_search_url_hint'),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          config.customSearchEngineUrl = val;
                          appState.saveConfig();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── 3. IP Spoofing & Inspection ──────────────────────
          _HeaderLabel(
            title: l.tr('ip_spoofing'),
            subtitle: isIndonesian
                ? 'Injeksi header X-Forwarded-For & Client-IP ke request browser'
                : 'Injects X-Forwarded-For & Client-IP headers into requests',
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _customIpController,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: l.tr('ip_spoofing_hint'),
                      prefixIcon: const Icon(Icons.public, size: 18),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      config.customForwardedIp = val;
                      appState.saveConfig();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onNavigate('https://httpbin.org/ip');
                          },
                          icon: const Icon(Icons.my_location, size: 16),
                          label: Text(l.tr('check_ip')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00D4AA),
                            side: const BorderSide(color: Color(0xFF00D4AA)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── 4. Quick Actions (JS, Clear Cache) ───────────────
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l.tr('toggle_javascript')),
                  subtitle: Text(
                    isIndonesian ? 'Matikan untuk menguji site tanpa JS' : 'Disable to test non-JS behaviors',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  value: config.javascriptEnabled,
                  activeColor: const Color(0xFF00D4AA),
                  onChanged: (val) async {
                    config.javascriptEnabled = val;
                    await widget.controller.setJavaScriptMode(
                      val ? JavaScriptMode.unrestricted : JavaScriptMode.disabled,
                    );
                    appState.saveConfig();
                    widget.onRefresh();
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Color(0xFFFF6B6B)),
                  title: Text(l.tr('clear_cache')),
                  subtitle: Text(
                    isIndonesian
                        ? 'Hapus seluruh cookies, cache, dan local storage'
                        : 'Purge all cookies, disk cache, and local storage',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  onTap: () {
                    widget.onClearCache();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeaderLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}

class _UaOption extends StatelessWidget {
  final String title;
  final String value;
  final String groupValue;
  final void Function(String) onSelected;

  const _UaOption({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: selected ? const Color(0xFF6C63FF) : Colors.white38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: ActionChip(
        avatar: Icon(icon, size: 12, color: const Color(0xFF6C63FF)),
        label: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        backgroundColor: const Color(0xFF1A1A2E),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      ),
    );
  }
}
