import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/http_models.dart';
import '../models/proxy_config.dart';
import '../proxy/certificate_authority.dart';
import '../proxy/proxy_server.dart';
import 'native_bridge.dart';

/// Central app state: proxy lifecycle, flows, intercept queue.
class AppState extends ChangeNotifier {
  ProxyConfig _config = ProxyConfig();
  ProxyConfig get config => _config;

  ProxyServer? _server;
  bool get proxyRunning => _server?.running ?? false;
  String? _lastError;
  String? get lastError => _lastError;

  final List<HttpFlow> _flows = [];
  List<HttpFlow> get flows => List.unmodifiable(_flows);

  // Intercept
  bool _interceptEnabled = false;
  bool get interceptEnabled => _interceptEnabled;
  final List<HttpFlow> _interceptQueue = [];
  List<HttpFlow> get interceptQueue => List.unmodifiable(_interceptQueue);
  Completer<ProxyRequest?>? _currentInterceptCompleter;

  // Certificate Authority
  CertificateAuthority? _ca;
  CertificateAuthority? get ca => _ca;
  String _caStatus = 'Not initialized';
  String get caStatus => _caStatus;

  // Search / filter
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  AppState() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('proxy_config');
    if (json != null) {
      _config = ProxyConfig.fromJson(
        Map<String, dynamic>.from(
          const JsonDecoder().convert(json) as Map,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'proxy_config',
      const JsonEncoder().convert(_config.toJson()),
    );
    notifyListeners();
  }

  void updateConfig(ProxyConfig newConfig) {
    _config = newConfig;
    saveConfig();
  }

  // ─── Certificate Authority ──────────────────────────────────

  Future<void> initCA() async {
    try {
      _caStatus = 'Generating keys...';
      notifyListeners();

      final filesDir = await NativeBridge.getFilesDir();
      _ca = CertificateAuthority();
      await _ca!.init('$filesDir/ca');

      _caStatus = 'Ready';
      notifyListeners();
    } catch (e) {
      _caStatus = 'Error: $e';
      notifyListeners();
    }
  }

  Future<void> regenerateCA() async {
    try {
      _caStatus = 'Regenerating...';
      notifyListeners();

      if (_ca == null) {
        await initCA();
      } else {
        await _ca!.regenerate();
      }

      _caStatus = 'Ready';
      notifyListeners();
    } catch (e) {
      _caStatus = 'Error: $e';
      notifyListeners();
    }
  }

  Future<bool> exportCA() async {
    if (_ca == null || !_ca!.ready) return false;
    return await NativeBridge.saveCertToDownloads(
      _ca!.caCertBytes,
      'verssuite_ca.pem',
    );
  }

  Future<bool> installCA() async {
    if (_ca == null || !_ca!.ready) return false;
    return await NativeBridge.installCaCert(_ca!.caCertBytes);
  }

  // ─── Proxy Lifecycle ───────────────────────────────────────

  Future<bool> startProxy() async {
    if (proxyRunning) return true;
    _lastError = null;

    try {
      if (_ca == null || !_ca!.ready) {
        await initCA();
      }

      _server = ProxyServer(
        config: _config,
        ca: _config.httpsInterception ? _ca : null,
        onFlow: _onFlowUpdate,
        onIntercept: _interceptEnabled ? _onIntercept : null,
      );

      await _server!.start();
      await NativeBridge.startForegroundService();
      await NativeBridge.acquireWakeLock();
      if (_config.inAppBrowserAutoProxy) {
        await NativeBridge.setWebViewProxy(port: _config.port, enabled: true);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _server = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopProxy() async {
    await _server?.stop();
    _server = null;
    await NativeBridge.stopForegroundService();
    await NativeBridge.releaseWakeLock();
    if (_config.inAppBrowserAutoProxy) {
      await NativeBridge.setWebViewProxy(enabled: false);
    }
    notifyListeners();
  }

  void _onFlowUpdate(HttpFlow flow) {
    final idx = _flows.indexWhere((f) => f.id == flow.id);
    if (idx >= 0) {
      _flows[idx] = flow;
    } else {
      _flows.insert(0, flow);
      if (_flows.length > _config.maxFlowHistory) {
        _flows.removeRange(_config.maxFlowHistory, _flows.length);
      }
    }
    // Throttle notifications
    _scheduleNotify();
  }

  Timer? _notifyTimer;
  void _scheduleNotify() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 100), () {
      notifyListeners();
    });
  }

  // ─── Intercept ─────────────────────────────────────────────

  void setInterceptEnabled(bool enabled) {
    _interceptEnabled = enabled;
    // Rebuild proxy server with/without intercept callback
    if (proxyRunning) {
      // Hot-swap by restarting
      stopProxy().then((_) => startProxy());
    }
    notifyListeners();
  }

  Future<ProxyRequest?> _onIntercept(HttpFlow flow) async {
    _interceptQueue.add(flow);
    notifyListeners();

    final completer = Completer<ProxyRequest?>();
    _currentInterceptCompleter = completer;
    return completer.future;
  }

  void forwardIntercepted(HttpFlow flow, {ProxyRequest? modified}) {
    _interceptQueue.remove(flow);
    _currentInterceptCompleter?.complete(modified ?? flow.request);
    _currentInterceptCompleter = null;
    notifyListeners();
  }

  void dropIntercepted(HttpFlow flow) {
    _interceptQueue.remove(flow);
    _currentInterceptCompleter?.complete(null);
    _currentInterceptCompleter = null;
    notifyListeners();
  }

  // ─── History ───────────────────────────────────────────────

  void clearFlows() {
    _flows.clear();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<HttpFlow> get filteredFlows {
    if (_searchQuery.isEmpty) return _flows;
    final q = _searchQuery.toLowerCase();
    return _flows.where((f) {
      return f.request.url.toLowerCase().contains(q) ||
          f.request.method.toLowerCase().contains(q) ||
          f.request.host.toLowerCase().contains(q) ||
          (f.response?.statusCode.toString().contains(q) ?? false);
    }).toList();
  }
}
