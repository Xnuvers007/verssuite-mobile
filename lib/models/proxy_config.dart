/// Proxy server configuration.
class ProxyConfig {
  int port;
  String bindAddress;
  bool httpsInterception;
  int connectionTimeout; // seconds
  int maxBodySize; // bytes
  List<String> excludeHosts;

  ProxyConfig({
    this.port = 8080,
    this.bindAddress = '0.0.0.0',
    this.httpsInterception = true,
    this.connectionTimeout = 30,
    this.maxBodySize = 10 * 1024 * 1024, // 10MB
    List<String>? excludeHosts,
  }) : excludeHosts = excludeHosts ?? [];

  bool shouldExclude(String host) {
    for (final pattern in excludeHosts) {
      if (pattern.startsWith('*.')) {
        if (host.endsWith(pattern.substring(1))) return true;
      } else {
        if (host == pattern) return true;
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
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
        port: json['port'] ?? 8080,
        bindAddress: json['bindAddress'] ?? '0.0.0.0',
        httpsInterception: json['httpsInterception'] ?? true,
        connectionTimeout: json['connectionTimeout'] ?? 30,
        maxBodySize: json['maxBodySize'] ?? 10 * 1024 * 1024,
        excludeHosts: (json['excludeHosts'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}
