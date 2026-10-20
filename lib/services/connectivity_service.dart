import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../state/native_bridge.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _isSimulated = false;
  bool get isSimulated => _isSimulated;

  Timer? _pollTimer;
  bool _initialized = false;

  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  void startMonitoring() {
    if (_initialized) return;
    _initialized = true;

    // Check immediately
    checkNow();

    // Check every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isSimulated) {
        checkNow();
      }
    });
  }

  Future<void> checkNow() async {
    try {
      final nativeConnected = await NativeBridge.isNetworkConnected();
      if (!nativeConnected) {
        _setConnectivity(false);
        return;
      }

      // Quick DNS ping to verify active data passage
      try {
        final result = await InternetAddress.lookup('dns.google')
            .timeout(const Duration(milliseconds: 1500));
        final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        _setConnectivity(hasConnection);
      } catch (_) {
        // Fallback: if native says connected, give it benefit unless subsequent fail
        _setConnectivity(false);
      }
    } catch (_) {
      _setConnectivity(false);
    }
  }

  void _setConnectivity(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _connectivityController.add(online);
      notifyListeners();
    }
  }

  // ─── Simulation Mode for User Testing ─────────────────────────────

  void simulateOffline() {
    _isSimulated = true;
    _setConnectivity(false);
  }

  void simulateOnline() {
    _isSimulated = true;
    _setConnectivity(true);
    // After 10s resume real monitoring
    Timer(const Duration(seconds: 10), () {
      _isSimulated = false;
    });
  }

  void resetSimulation() {
    _isSimulated = false;
    checkNow();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connectivityController.close();
    super.dispose();
  }
}
