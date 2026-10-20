/// Proxy server & developer configuration.
class ProxyConfig {
  int port;
  String bindAddress;
  bool httpsInterception;
  int connectionTimeout; // seconds
  int maxBodySize; // bytes
  List<String> excludeHosts;

  // Developer Settings
  bool inAppBrowserAutoProxy;
  bool bypassSslWarnings;
  bool stripAcceptEncoding;
  bool debugLogging;
  int maxFlowHistory;
  String customUserAgent;

  // Browser Customization Settings
  String searchEngine; // google, duckduckgo, bing, brave, yahoo, startpage, custom
  String customSearchEngineUrl;
  String userAgentPreset; // default, desktop_windows, iphone, ipad, mac, custom
  String customForwardedIp; // e.g. '1.1.1.1' for X-Forwarded-For injection
  bool javascriptEnabled;

  ProxyConfig({
    this.port = 8080,
    this.bindAddress = '0.0.0.0',
    this.httpsInterception = true,
    this.connectionTimeout = 30,
    this.maxBodySize = 10 * 1024 * 1024, // 10MB
    List<String>? excludeHosts,
    this.inAppBrowserAutoProxy = true,
    this.bypassSslWarnings = true,
    this.stripAcceptEncoding = false,
    this.debugLogging = false,
    this.maxFlowHistory = 500,
    this.customUserAgent = '',
    this.searchEngine = 'google',
    this.customSearchEngineUrl = 'https://www.google.com/search?q=',
    this.userAgentPreset = 'default',
    this.customForwardedIp = '',
    this.javascriptEnabled = true,
  }) : excludeHosts = excludeHosts ?? defaultExcludeHosts;

  static List<String> get defaultExcludeHosts => [
        '*.google.com',
        'google.com',
        '*.google.co.id',
        'google.co.id',
        '*.gstatic.com',
        '*.googleapis.com',
        '*.googleusercontent.com',
        '*.gvt1.com',
        '*.gvt2.com',
      ];

  static const String uaDesktopWindows =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

  static const String uaIPhone =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';

  static const String uaIPad =
      'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';

  static const String uaMac =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.5 Safari/605.1.15';

  static const String uaAndroid =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';

  String get effectiveUserAgent {
    switch (userAgentPreset) {
      case 'desktop_windows':
        return uaDesktopWindows;
      case 'iphone':
        return uaIPhone;
      case 'ipad':
        return uaIPad;
      case 'mac':
        return uaMac;
      case 'android':
        return uaAndroid;
      case 'custom':
        return customUserAgent.trim().isNotEmpty
            ? customUserAgent.trim()
            : uaDesktopWindows;
      case 'default':
      default:
        return '';
    }
  }

  String buildSearchUrl(String query) {
    final encoded = Uri.encodeComponent(query);
    switch (searchEngine) {
      case 'duckduckgo':
        return 'https://duckduckgo.com/?q=$encoded';
      case 'bing':
        return 'https://www.bing.com/search?q=$encoded';
      case 'brave':
        return 'https://search.brave.com/search?q=$encoded';
      case 'yahoo':
        return 'https://search.yahoo.com/search?q=$encoded';
      case 'startpage':
        return 'https://www.startpage.com/sp/search?query=$encoded';
      case 'custom':
        if (customSearchEngineUrl.contains('%s')) {
          return customSearchEngineUrl.replaceAll('%s', encoded);
        }
        return '$customSearchEngineUrl$encoded';
      case 'google':
      default:
        return 'https://www.google.com/search?q=$encoded';
    }
  }

  bool shouldExclude(String host) {
    final lowerHost = host.toLowerCase().trim();
    if (lowerHost == 'google.com' ||
        lowerHost.endsWith('.google.com') ||
        lowerHost == 'google.co.id' ||
        lowerHost.endsWith('.google.co.id') ||
        lowerHost.endsWith('.gstatic.com') ||
        lowerHost.endsWith('.googleapis.com') ||
        lowerHost.endsWith('.googleusercontent.com')) {
      return true;
    }
    for (final pattern in excludeHosts) {
      final p = pattern.toLowerCase().trim();
      if (p.startsWith('*.')) {
        final suffix = p.substring(2);
        if (lowerHost == suffix || lowerHost.endsWith('.$suffix')) return true;
      } else {
        if (lowerHost == p) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'port': port,
        'bindAddress': bindAddress,
        'httpsInterception': httpsInterception,
        'connectionTimeout': connectionTimeout,
        'maxBodySize': maxBodySize,
        'excludeHosts': excludeHosts,
        'inAppBrowserAutoProxy': inAppBrowserAutoProxy,
        'bypassSslWarnings': bypassSslWarnings,
        'stripAcceptEncoding': stripAcceptEncoding,
        'debugLogging': debugLogging,
        'maxFlowHistory': maxFlowHistory,
        'customUserAgent': customUserAgent,
        'searchEngine': searchEngine,
        'customSearchEngineUrl': customSearchEngineUrl,
        'userAgentPreset': userAgentPreset,
        'customForwardedIp': customForwardedIp,
        'javascriptEnabled': javascriptEnabled,
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) {
    final rawExclude = (json['excludeHosts'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final effectiveExclude = (rawExclude == null || rawExclude.isEmpty)
        ? defaultExcludeHosts
        : rawExclude;

    return ProxyConfig(
      port: json['port'] ?? 8080,
      bindAddress: json['bindAddress'] ?? '0.0.0.0',
      httpsInterception: json['httpsInterception'] ?? true,
      connectionTimeout: json['connectionTimeout'] ?? 30,
      maxBodySize: json['maxBodySize'] ?? 10 * 1024 * 1024,
      excludeHosts: effectiveExclude,
      inAppBrowserAutoProxy: json['inAppBrowserAutoProxy'] ?? true,
      bypassSslWarnings: json['bypassSslWarnings'] ?? true,
      stripAcceptEncoding: json['stripAcceptEncoding'] ?? false,
      debugLogging: json['debugLogging'] ?? false,
      maxFlowHistory: json['maxFlowHistory'] ?? 500,
        customUserAgent: json['customUserAgent'] ?? '',
        searchEngine: json['searchEngine'] ?? 'google',
        customSearchEngineUrl:
            json['customSearchEngineUrl'] ?? 'https://www.google.com/search?q=',
        userAgentPreset: json['userAgentPreset'] ?? 'default',
        customForwardedIp: json['customForwardedIp'] ?? '',
        javascriptEnabled: json['javascriptEnabled'] ?? true,
      );
  }
}
