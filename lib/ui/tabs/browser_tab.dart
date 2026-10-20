import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  late final WebViewController _controller;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  double _loadingProgress = 0.0;
  bool _isLoading = false;
  bool _isDesktopMode = false;
  String _currentTitle = 'Browser';

  static const String _desktopUA =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _urlController.text = 'https://www.google.com';

    final appState = context.read<AppState>();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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

    _controller.loadRequest(Uri.parse(_urlController.text));
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

    Uri? targetUri;
    // Check if it's a domain/URL or search query
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      targetUri = Uri.tryParse(trimmed);
    } else if (trimmed.contains('.') && !trimmed.contains(' ')) {
      targetUri = Uri.tryParse('https://$trimmed');
    } else {
      // Search Google
      final encodedQuery = Uri.encodeComponent(trimmed);
      targetUri = Uri.parse('https://www.google.com/search?q=$encodedQuery');
    }

    if (targetUri != null) {
      _controller.loadRequest(targetUri);
    }
  }

  Future<void> _toggleDesktopMode() async {
    setState(() => _isDesktopMode = !_isDesktopMode);
    await _controller.setUserAgent(_isDesktopMode ? _desktopUA : null);
    await _controller.reload();
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final isProxyRunning = appState.proxyRunning;

    return SafeArea(
      child: Column(
        children: [
          // Proxy Status Bar
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

          // Browser Navigation & Address Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      await _controller.goBack();
                    }
                  },
                ),
                // Forward Button
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    if (await _controller.canGoForward()) {
                      await _controller.goForward();
                    }
                  },
                ),

                // Address / Search Input
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12122A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Icon(
                          _urlController.text.startsWith('https')
                              ? Icons.lock
                              : Icons.search,
                          size: 14,
                          color: _urlController.text.startsWith('https')
                              ? const Color(0xFF00D4AA)
                              : Colors.white38,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            focusNode: _urlFocusNode,
                            style: const TextStyle(fontSize: 12),
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
                        if (_isLoading)
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _controller.loadRequest(Uri.parse('about:blank')),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _controller.reload(),
                          ),
                      ],
                    ),
                  ),
                ),

                // More Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) {
                    switch (val) {
                      case 'desktop':
                        _toggleDesktopMode();
                        break;
                      case 'clear':
                        _clearCacheAndCookies();
                        break;
                      case 'home':
                        _loadUrl('https://www.google.com');
                        break;
                      case 'httpbin':
                        _loadUrl('https://httpbin.org');
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'home',
                      child: const Row(
                        children: [
                          Icon(Icons.home, size: 16),
                          SizedBox(width: 8),
                          Text('Google Home', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'httpbin',
                      child: const Row(
                        children: [
                          Icon(Icons.bug_report_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('HttpBin Target', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'desktop',
                      child: Row(
                        children: [
                          Icon(
                            _isDesktopMode ? Icons.phone_android : Icons.desktop_mac,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isDesktopMode ? l.tr('mobile_mode') : l.tr('desktop_mode'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_sweep, size: 16, color: Color(0xFFFF6B6B)),
                          const SizedBox(width: 8),
                          Text(l.tr('clear_cache'), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Loading Progress Bar
          if (_isLoading && _loadingProgress > 0 && _loadingProgress < 1.0)
            LinearProgressIndicator(
              value: _loadingProgress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),

          // Quick Preset Shortcuts
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _QuickChip(label: 'Google', onTap: () => _loadUrl('https://www.google.com')),
                _QuickChip(label: 'HttpBin', onTap: () => _loadUrl('https://httpbin.org')),
                _QuickChip(label: 'Example.com', onTap: () => _loadUrl('https://example.com')),
                _QuickChip(label: 'IP Check', onTap: () => _loadUrl('https://httpbin.org/ip')),
                _QuickChip(label: 'Postman Echo', onTap: () => _loadUrl('https://postman-echo.com/get')),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // WebView Widget
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

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: ActionChip(
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
