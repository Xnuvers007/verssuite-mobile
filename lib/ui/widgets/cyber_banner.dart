import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CyberBannerType {
  offline,
  online,
  portConflict,
  caWarning,
  interceptActive,
  interceptInactive,
  flowLimit,
  success,
  info,
}

class CyberBanner {
  static void show(
    BuildContext context, {
    required CyberBannerType type,
    String? title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    HapticFeedback.lightImpact();

    final config = _getBannerConfig(type);

    final resolvedTitle = title ?? config.defaultTitle;
    final resolvedMessage = message ?? config.defaultMessage;
    final resolvedAction = actionLabel ?? config.defaultActionLabel;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF131525).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: config.accentColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: config.accentColor.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: config.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: config.accentColor.withValues(alpha: 0.4)),
                ),
                child: Icon(config.icon, color: config.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: config.accentColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resolvedMessage,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onAction != null && resolvedAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: config.accentColor.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: config.accentColor.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Text(
                    resolvedAction,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: config.accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show a detailed modal alert dialog for critical testing scenarios
  static Future<void> showAlertDialog(
    BuildContext context, {
    required CyberBannerType type,
    required String title,
    required String message,
    String? confirmLabel,
    VoidCallback? onConfirm,
    String? cancelLabel,
  }) {
    final config = _getBannerConfig(type);

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131525),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: config.accentColor.withValues(alpha: 0.5), width: 1.5),
        ),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: config.accentColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(config.icon, color: config.accentColor, size: 28),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.75),
            height: 1.45,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (cancelLabel != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                cancelLabel,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: config.accentColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              confirmLabel ?? 'Tutup',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  static _BannerStyle _getBannerConfig(CyberBannerType type) {
    switch (type) {
      case CyberBannerType.offline:
        return _BannerStyle(
          icon: Icons.wifi_off_rounded,
          accentColor: const Color(0xFFFF5252),
          defaultTitle: '⚠️ Internet Terputus (Offline)',
          defaultMessage: 'Perangkat tidak terhubung ke jaringan internet.',
          defaultActionLabel: 'Cek Wi-Fi',
        );
      case CyberBannerType.online:
        return _BannerStyle(
          icon: Icons.wifi_rounded,
          accentColor: const Color(0xFF00E676),
          defaultTitle: '🌐 Internet Terhubung (Online)',
          defaultMessage: 'Koneksi internet kembali aktif & stabil.',
          defaultActionLabel: 'OK',
        );
      case CyberBannerType.portConflict:
        return _BannerStyle(
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFFF9100),
          defaultTitle: '⚠️ Port Sedang Digunakan',
          defaultMessage: 'Port proksi mengalami konflik dengan aplikasi lain.',
          defaultActionLabel: 'Ganti Port',
        );
      case CyberBannerType.caWarning:
        return _BannerStyle(
          icon: Icons.security_rounded,
          accentColor: const Color(0xFF00E5FF),
          defaultTitle: 'ℹ️ Sertifikat CA Belum Dipasang',
          defaultMessage: 'Pasang sertifikat Root CA agar HTTPS tidak error.',
          defaultActionLabel: 'Tutorial',
        );
      case CyberBannerType.interceptActive:
        return _BannerStyle(
          icon: Icons.pause_circle_filled_rounded,
          accentColor: const Color(0xFFB388FF),
          defaultTitle: '⏸️ Mode Intersep Aktif',
          defaultMessage: 'Permintaan web ditahan hingga diteruskan/dibuang.',
          defaultActionLabel: 'Lihat',
        );
      case CyberBannerType.interceptInactive:
        return _BannerStyle(
          icon: Icons.play_circle_fill_rounded,
          accentColor: const Color(0xFF00D4AA),
          defaultTitle: '▶️ Mode Intersep Nonaktif',
          defaultMessage: 'Semua lalu lintas data dialirkan secara langsung.',
          defaultActionLabel: 'OK',
        );
      case CyberBannerType.flowLimit:
        return _BannerStyle(
          icon: Icons.cleaning_services_rounded,
          accentColor: const Color(0xFF40C4FF),
          defaultTitle: '🧹 Batas Riwayat Tercapai',
          defaultMessage: 'Entri traffic terlama otomatis dibersihkan.',
          defaultActionLabel: 'OK',
        );
      case CyberBannerType.success:
        return _BannerStyle(
          icon: Icons.check_circle_rounded,
          accentColor: const Color(0xFF00D4AA),
          defaultTitle: '✅ Berhasil',
          defaultMessage: 'Aksi telah berhasil dijalankan.',
          defaultActionLabel: 'OK',
        );
      case CyberBannerType.info:
        return _BannerStyle(
          icon: Icons.info_outline_rounded,
          accentColor: const Color(0xFF6C63FF),
          defaultTitle: 'ℹ️ Informasi',
          defaultMessage: 'Pemberitahuan sistem VersSuite.',
          defaultActionLabel: 'OK',
        );
    }
  }
}

class _BannerStyle {
  final IconData icon;
  final Color accentColor;
  final String defaultTitle;
  final String defaultMessage;
  final String defaultActionLabel;

  const _BannerStyle({
    required this.icon,
    required this.accentColor,
    required this.defaultTitle,
    required this.defaultMessage,
    required this.defaultActionLabel,
  });
}
