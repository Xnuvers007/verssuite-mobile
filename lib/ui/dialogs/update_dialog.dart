import 'dart:io';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../state/native_bridge.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final String currentVersion;
  final String deviceAbi;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
    required this.deviceAbi,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    required String currentVersion,
    required String deviceAbi,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(
        updateInfo: updateInfo,
        currentVersion: currentVersion,
        deviceAbi: deviceAbi,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _downloadStatus = '';
  File? _downloadedFile;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final targetAsset = widget.updateInfo.getOptimalAsset(widget.deviceAbi);

    return Dialog(
      backgroundColor: const Color(0xFF131525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF6C63FF).withValues(alpha: 0.4), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with glowing icon and badge
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.tr('update_available'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'v${widget.currentVersion}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF00D4AA)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D4AA).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.updateInfo.tagName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00D4AA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Architecture information chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D36),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory_rounded, size: 16, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l.tr('detected_device')}: ${widget.deviceAbi.toUpperCase()} • ${targetAsset?.formattedSize ?? "~12 MB"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Changelog box
              Text(
                l.tr('changelog'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0C16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.updateInfo.changelog,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Progress Bar if downloading
              if (_isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.tr('downloading_update'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(_progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00D4AA),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4AA)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _downloadStatus,
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ],

              // Actions
              if (_downloadedFile != null) ...[
                FilledButton.icon(
                  onPressed: () => _triggerInstall(_downloadedFile!.path),
                  icon: const Icon(Icons.install_mobile_rounded, size: 18),
                  label: Text(l.tr('installing_update')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4AA),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else if (!_isDownloading) ...[
                FilledButton.icon(
                  onPressed: targetAsset != null ? () => _startDownload(targetAsset) : null,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(l.tr('download_and_install')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      NativeBridge.openUrl(widget.updateInfo.htmlUrl);
                    },
                    icon: const Icon(Icons.open_in_browser, size: 16, color: Colors.white60),
                    label: const Text(
                      'GitHub',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ),
                  TextButton(
                    onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      l.tr('update_later'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDownload(UpdateAsset asset) async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
      _downloadStatus = 'Menghubungkan ke GitHub...';
    });

    try {
      final file = await UpdateService.downloadApk(
        asset,
        onProgress: (received, total) {
          if (!mounted) return;
          final pct = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
          final mbRec = (received / (1024 * 1024)).toStringAsFixed(1);
          final mbTot = (total / (1024 * 1024)).toStringAsFixed(1);
          setState(() {
            _progress = pct;
            _downloadStatus = '$mbRec MB / $mbTot MB';
          });
        },
      );

      if (!mounted) return;

      if (file != null && await file.exists()) {
        setState(() {
          _isDownloading = false;
          _downloadedFile = file;
          _downloadStatus = 'Unduhan selesai! Membuka installer...';
        });

        // Trigger Android package installer automatically
        await _triggerInstall(file.path);
      } else {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Gagal mengunduh APK. Silakan periksa koneksi atau unduh dari browser.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Terjadi kesalahan saat mengunduh: $e';
      });
    }
  }

  Future<void> _triggerInstall(String filePath) async {
    final success = await UpdateService.installApk(filePath);
    if (!success && mounted) {
      setState(() {
        _errorMessage = 'Gagal membuka installer APK. Pastikan izin install aplikasi aktif.';
      });
    }
  }
}
