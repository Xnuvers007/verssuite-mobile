import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/native_bridge.dart';

class CaInstallDialog {
  static Future<void> show(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.exportCA();

    if (!context.mounted) return;

    final l = AppLocalizations.of(context);
    final isId = l.locale.languageCode == 'id';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16162C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF00D4AA),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isId
                            ? 'Pasang Sertifikat Root CA'
                            : 'Install Root CA Certificate',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isId
                            ? 'Wajib agar HTTPS & Web tidak error'
                            : 'Required for HTTPS & error-free web traffic',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF00D4AA), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isId
                          ? '✅ File "verssuite_ca.crt" & "verssuite_ca.pem" sudah otomatis tersimpan di folder Download.'
                          : '✅ Files "verssuite_ca.crt" & "verssuite_ca.pem" are saved in your Downloads folder.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isId ? 'Langkah pemasangan di Android:' : 'Installation steps in Android:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            _buildStepRow(
              '1',
              isId
                  ? 'Ketuk tombol "Buka Pengaturan Keamanan" di bawah ini.'
                  : 'Tap "Open Android Security Settings" button below.',
            ),
            _buildStepRow(
              '2',
              isId
                  ? 'Di menu Pengaturan HP, pilih: Enkripsi & Kredensial ➔ Pasang Sertifikat ➔ Sertifikat CA.'
                  : 'In Device Settings, choose: Encryption & credentials ➔ Install a certificate ➔ CA certificate.',
            ),
            _buildStepRow(
              '3',
              isId
                  ? 'Pilih "Tetap Instal" / "Install Anyway", lalu pilih file "verssuite_ca.crt" dari folder Download.'
                  : 'Tap "Install Anyway", then select the "verssuite_ca.crt" file from Downloads.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await NativeBridge.openSecuritySettings();
                },
                icon: const Icon(Icons.settings_suggest_rounded, size: 20),
                label: Text(
                  isId
                      ? 'Buka Pengaturan Keamanan Android'
                      : 'Open Android Security Settings',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6C63FF),
                width: 1,
              ),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8C82FF),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
