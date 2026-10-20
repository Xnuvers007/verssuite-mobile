import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Bridge to Android native code via MethodChannel.
class NativeBridge {
  static const _channel = MethodChannel('com.verssuite.mobile/native');

  static Future<String> getFilesDir() async {
    final result = await _channel.invokeMethod<String>('getFilesDir');
    return result ?? '/data/data/com.verssuite.mobile/files';
  }

  static Future<bool> startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
      return true;
    } catch (e) {
      print('[NativeBridge] startForegroundService error: $e');
      return false;
    }
  }

  static Future<bool> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
      return true;
    } catch (e) {
      print('[NativeBridge] stopForegroundService error: $e');
      return false;
    }
  }

  static Future<bool> saveCertToDownloads(
      Uint8List bytes, String filename) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'saveCertToDownloads',
        {'bytes': bytes, 'filename': filename},
      );
      return result ?? false;
    } catch (e) {
      print('[NativeBridge] saveCertToDownloads error: $e');
      return false;
    }
  }

  static Future<bool> installCaCert(
      Uint8List bytes, {String name = 'VersSuite CA'}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'installCaCert',
        {'bytes': bytes, 'name': name},
      );
      return result ?? false;
    } catch (e) {
      print('[NativeBridge] installCaCert error: $e');
      return false;
    }
  }

  static Future<bool> acquireWakeLock() async {
    try {
      await _channel.invokeMethod('acquireWakeLock');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> releaseWakeLock() async {
    try {
      await _channel.invokeMethod('releaseWakeLock');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> openUrl(String url) async {
    try {
      final res = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return res ?? true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> setWebViewProxy({
    String host = '127.0.0.1',
    int port = 8080,
    bool enabled = true,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('setWebViewProxy', {
        'host': host,
        'port': port,
        'enabled': enabled,
      });
      return res ?? true;
    } catch (e) {
      print('[NativeBridge] setWebViewProxy error: $e');
      return false;
    }
  }

  static Future<bool> installApk(String filePath) async {
    try {
      final res = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return res ?? false;
    } catch (e) {
      print('[NativeBridge] installApk error: $e');
      return false;
    }
  }

  static Future<String> getDeviceAbi() async {
    try {
      final res = await _channel.invokeMethod<String>('getDeviceAbi');
      return res ?? 'arm64-v8a';
    } catch (e) {
      return 'arm64-v8a';
    }
  }

  static Future<String> getAppVersion() async {
    try {
      final res = await _channel.invokeMethod<String>('getAppVersion');
      return res ?? '1.0.0';
    } catch (e) {
      return '1.0.0';
    }
  }

  static Future<bool> isNetworkConnected() async {
    try {
      final res = await _channel.invokeMethod<bool>('isNetworkConnected');
      return res ?? true;
    } catch (e) {
      return true;
    }
  }
}
