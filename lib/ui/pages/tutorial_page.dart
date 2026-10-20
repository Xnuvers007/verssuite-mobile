import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Interactive visual tutorial and setup guide for VersSuite Mobile.
class TutorialPage extends StatefulWidget {
  final int initialTab;
  const TutorialPage({super.key, this.initialTab = 0});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('tutorial')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF6C63FF),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              text: l.tr('cert_install_tutorial'),
            ),
            Tab(
              icon: const Icon(Icons.numbers_outlined, size: 18),
              text: l.tr('port_tutorial'),
            ),
            Tab(
              icon: const Icon(Icons.wifi_outlined, size: 18),
              text: l.tr('wifi_tutorial'),
            ),
            Tab(
              icon: const Icon(Icons.travel_explore_outlined, size: 18),
              text: l.tr('inapp_tutorial'),
            ),
            Tab(
              icon: const Icon(Icons.lock_reset_outlined, size: 18),
              text: l.tr('pinning_tutorial'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CertInstallTab(appState: appState, l: l),
          _PortConfigTab(appState: appState, l: l),
          _WifiSetupTab(appState: appState, l: l),
          _InAppBrowserTab(appState: appState, l: l),
          _SslPinningTab(l: l),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 1: Pasang Sertifikat CA
// ─────────────────────────────────────────────────────────────
class _CertInstallTab extends StatelessWidget {
  final AppState appState;
  final AppLocalizations l;
  const _CertInstallTab({required this.appState, required this.l});

  @override
  Widget build(BuildContext context) {
    final isIndonesian = l.locale.languageCode == 'id';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Action Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isIndonesian
                          ? 'Ekspor & Pasang Sertifikat CA'
                          : 'Export & Install CA Certificate',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isIndonesian
                    ? 'Sertifikat CA diperlukan agar VersSuite dapat mendekripsi trafik HTTPS (port 443) secara aman di HP Anda.'
                    : 'A root CA certificate is required so VersSuite can safely decrypt and inspect HTTPS (port 443) traffic on your device.',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final ok = await appState.exportCA();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? (isIndonesian
                                ? '✅ Sertifikat diekspor ke folder Downloads (verssuite_ca.pem)!'
                                : '✅ Certificate exported to Downloads (verssuite_ca.pem)!')
                            : 'Gagal mengekspor sertifikat'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download, size: 16),
                label: Text(
                  isIndonesian ? 'Ekspor Sertifikat Sekarang' : 'Export CA Certificate Now',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF12122A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Steps
        _StepItem(
          stepNumber: '1',
          title: isIndonesian ? 'Ekspor File Sertifikat' : 'Export Certificate File',
          desc: isIndonesian
              ? 'Tekan tombol "Ekspor Sertifikat Sekarang" di atas. File bernama "verssuite_ca.pem" akan disimpan di folder Downloads.'
              : 'Press the "Export CA Certificate Now" button above. The file "verssuite_ca.pem" will be saved to your Downloads directory.',
        ),
        _StepItem(
          stepNumber: '2',
          title: isIndonesian ? 'Buka Pengaturan Keamanan Android' : 'Open Android Security Settings',
          desc: isIndonesian
              ? '• Android 11–15: Masuk ke Settings (Pengaturan HP) ➔ Keamanan & Privasi (Security & Privacy) ➔ Pengaturan Keamanan Lainnya ➔ Enkripsi & Kredensial (Encryption & Credentials) ➔ Pasang Sertifikat (Install a certificate) ➔ Sertifikat CA (CA certificate).\n• Android 8–10: Settings ➔ Keamanan ➔ Kredensial ➔ Pasang dari penyimpanan.'
              : '• Android 11–15: Go to device Settings ➔ Security & Privacy ➔ More Security Settings ➔ Encryption & Credentials ➔ Install a Certificate ➔ CA Certificate.\n• Android 8–10: Settings ➔ Security ➔ Install from storage.',
        ),
        _StepItem(
          stepNumber: '3',
          title: isIndonesian ? 'Konfirmasi Peringatan Keamanan' : 'Confirm Security Warning',
          desc: isIndonesian
              ? 'Android akan menampilkan peringatan keamanan tentang sertifikat CA pribadi. Pilih "Tetap Pasang" (Install anyway) lalu konfirmasi PIN/Sidik Jari HP Anda.'
              : 'Android will warn that personal CA certificates can monitor network activity. Select "Install Anyway" and enter your device PIN/Fingerprint.',
        ),
        _StepItem(
          stepNumber: '4',
          title: isIndonesian ? 'Pilih File verssuite_ca.pem' : 'Select verssuite_ca.pem File',
          desc: isIndonesian
              ? 'Di file picker, buka folder "Downloads" lalu pilih file "verssuite_ca.pem". Sertifikat akan aktif seketika!'
              : 'In the system file picker, navigate to Downloads and pick "verssuite_ca.pem". The CA is immediately activated.',
        ),

        const SizedBox(height: 12),
        // Root / Magisk Tip
        _InfoCard(
          icon: Icons.shield,
          title: isIndonesian ? 'Tips Pengguna Root / Magisk / KernelSU' : 'Root / Magisk / KernelSU Users',
          desc: isIndonesian
              ? 'Jika Anda menggunakan perangkat Root, Anda dapat memasang sertifikat ke System Trust Store (/system/etc/security/cacerts/) menggunakan modul Magisk "AlwaysTrustUserCerts" atau "TrustMeAlready" agar semua aplikasi otomatis mempercayai VersSuite tanpa modifikasi APK.'
              : 'On rooted devices, you can install the CA directly to the System Store using the Magisk/KernelSU module "AlwaysTrustUserCerts" or "TrustMeAlready" to intercept all apps without modifying APK files.',
          color: const Color(0xFF00D4AA),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 2: Ubah Port & Bind Address
// ─────────────────────────────────────────────────────────────
class _PortConfigTab extends StatelessWidget {
  final AppState appState;
  final AppLocalizations l;
  const _PortConfigTab({required this.appState, required this.l});

  @override
  Widget build(BuildContext context) {
    final isIndonesian = l.locale.languageCode == 'id';
    final config = appState.config;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          icon: Icons.info_outline,
          title: isIndonesian ? 'Mengapa Perlu Mengubah Port?' : 'Why Change the Port?',
          desc: isIndonesian
              ? 'Port default adalah 8080. Jika port tersebut sudah dipakai oleh aplikasi lain (seperti Termux, web server lokal, atau proxy lain), server akan gagal berjalan (Address already in use). Anda cukup menggantinya ke port lain seperti 8081, 8888, atau 9090.'
              : 'The default port is 8080. If another app (such as Termux, a local server, or another proxy) already uses this port, binding fails. Change it to 8081, 8888, or 9090.',
          color: const Color(0xFF6C63FF),
        ),
        const SizedBox(height: 16),

        _StepItem(
          stepNumber: '1',
          title: isIndonesian ? 'Buka Tab Pengaturan (Settings)' : 'Open the Settings Tab',
          desc: isIndonesian
              ? 'Pilih ikon Settings di bar navigasi VersSuite Mobile.'
              : 'Tap the Settings icon on the VersSuite navigation bar.',
        ),
        _StepItem(
          stepNumber: '2',
          title: isIndonesian ? 'Ubah Nilai Port' : 'Change the Port Value',
          desc: isIndonesian
              ? 'Ketik nomor port yang diinginkan (antara 1024 hingga 65535, disarankan 8081 atau 8888) pada kolom "Port".'
              : 'Enter any valid port between 1024 and 65535 (recommended: 8081 or 8888) in the "Port" field.',
        ),
        _StepItem(
          stepNumber: '3',
          title: isIndonesian ? 'Pilih Bind Address' : 'Configure Bind Address',
          desc: isIndonesian
              ? '• 0.0.0.0 (Default): Proksi dapat diakses oleh HP ini dan perangkat lain yang terhubung ke satu Wi-Fi atau Hotspot HP Anda.\n• 127.0.0.1 (Localhost): Hanya dapat diakses oleh aplikasi di dalam HP ini saja.'
              : '• 0.0.0.0 (Default): Allows other devices on your Wi-Fi or Mobile Hotspot to connect to this proxy.\n• 127.0.0.1 (Localhost): Restricts connections strictly to apps running on this device.',
        ),
        _StepItem(
          stepNumber: '4',
          title: isIndonesian ? 'Mulai Ulang Proksi' : 'Restart the Proxy',
          desc: isIndonesian
              ? 'Kembali ke tab Proxy, tekan Hentikan Proksi (Stop) lalu Mulai Proksi (Start) kembali agar perubahan port diterapkan.'
              : 'Go back to the Proxy tab, press Stop and Start again to apply the new port.',
        ),

        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIndonesian ? 'Status Port Saat Ini' : 'Current Port Configuration',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${config.bindAddress}:${config.port}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      appState.proxyRunning
                          ? (isIndonesian ? '🟢 Sedang Berjalan' : '🟢 Running')
                          : (isIndonesian ? '🔴 Berhenti' : '🔴 Stopped'),
                      style: TextStyle(
                        color: appState.proxyRunning ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 3: Setup Wi-Fi Proxy Android
// ─────────────────────────────────────────────────────────────
class _WifiSetupTab extends StatelessWidget {
  final AppState appState;
  final AppLocalizations l;
  const _WifiSetupTab({required this.appState, required this.l});

  @override
  Widget build(BuildContext context) {
    final isIndonesian = l.locale.languageCode == 'id';
    final config = appState.config;
    final proxyHost = config.bindAddress == '0.0.0.0' ? '127.0.0.1' : config.bindAddress;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StepItem(
          stepNumber: '1',
          title: isIndonesian ? 'Mulai Proksi VersSuite' : 'Start the VersSuite Proxy',
          desc: isIndonesian
              ? 'Pastikan tombol "Mulai Proksi" pada tab Proxy sudah aktif dan berwarna hijau.'
              : 'Make sure "Start Proxy" on the Proxy tab is running (green status).',
        ),
        _StepItem(
          stepNumber: '2',
          title: isIndonesian ? 'Buka Pengaturan Wi-Fi HP' : 'Open Device Wi-Fi Settings',
          desc: isIndonesian
              ? 'Buka Settings Android ➔ Wi-Fi ➔ Tekan ikon roda gigi (Pengaturan) di samping nama Wi-Fi Anda yang sedang terhubung.'
              : 'Open Android Settings ➔ Wi-Fi ➔ Tap the gear icon next to your currently connected Wi-Fi network.',
        ),
        _StepItem(
          stepNumber: '3',
          title: isIndonesian ? 'Ubah ke Proxy Manual' : 'Set Proxy to Manual',
          desc: isIndonesian
              ? 'Pilih Ubah / Edit Jaringan (ikon pensil) ➔ Buka Opsi Lanjutan (Advanced) ➔ Ubah Proxy dari "Tidak ada" (None) ke "Manual".'
              : 'Tap Modify / Edit network ➔ Expand Advanced Options ➔ Change Proxy from "None" to "Manual".',
        ),
        _StepItem(
          stepNumber: '4',
          title: isIndonesian ? 'Masukkan Host & Port' : 'Enter Proxy Host & Port',
          desc: isIndonesian
              ? '• Nama Host Proksi: $proxyHost\n• Port Proksi: ${config.port}\n• Bypass proxy: biarkan kosong atau localhost.'
              : '• Proxy hostname: $proxyHost\n• Proxy port: ${config.port}\n• Bypass proxy: leave blank or localhost.',
        ),
        _StepItem(
          stepNumber: '5',
          title: isIndonesian ? 'Simpan & Tes Koneksi' : 'Save and Verify',
          desc: isIndonesian
              ? 'Tekan Simpan. Buka Chrome atau aplikasi apa saja di HP Anda, maka semua aliran trafik akan muncul secara real-time di tab History VersSuite!'
              : 'Tap Save. Open Chrome or any target app; all network flows will appear immediately in the History tab!',
        ),

        const SizedBox(height: 12),
        // One-Click Copy Helper
        Card(
          color: const Color(0xFF16162A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIndonesian ? 'Parameter Proxy Anda:' : 'Your Proxy Parameters:',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$proxyHost : ${config.port}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00D4AA),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '$proxyHost:${config.port}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.tr('copied'))),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: Text(l.tr('copy')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 4: Browser Bawaan (In-App Browser)
// ─────────────────────────────────────────────────────────────
class _InAppBrowserTab extends StatelessWidget {
  final AppState appState;
  final AppLocalizations l;
  const _InAppBrowserTab({required this.appState, required this.l});

  @override
  Widget build(BuildContext context) {
    final isIndonesian = l.locale.languageCode == 'id';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          icon: Icons.star_rounded,
          title: isIndonesian ? 'Intersepsi Tanpa Ubah Setting Wi-Fi!' : 'Intercept Without Changing Wi-Fi!',
          desc: isIndonesian
              ? 'VersSuite Mobile menyediakan tab Browser bawaan yang otomatis terhubung ke engine proxy. Anda dapat langsung membuka website target, menguji form, dan mengintersep paket tanpa root dan tanpa perlu setting Wi-Fi HP!'
              : 'VersSuite Mobile includes an integrated In-App Browser automatically wired to the local proxy engine. Inspect, modify, and audit target sites without root or touching Wi-Fi settings!',
          color: const Color(0xFF00D4AA),
        ),
        const SizedBox(height: 16),

        _StepItem(
          stepNumber: '1',
          title: isIndonesian ? 'Navigasi Lengkap' : 'Rich Navigation Controls',
          desc: isIndonesian
              ? 'Gunakan tombol panah kiri (←) untuk kembali, panah kanan (→) untuk maju, ikon melingkar (↻) untuk refresh, dan ikon beranda (🏠) untuk kembali ke halaman utama.'
              : 'Use the left arrow (←) for previous, right arrow (→) for next, circular arrow (↻) to refresh, and home icon (🏠) for home.',
        ),
        _StepItem(
          stepNumber: '2',
          title: isIndonesian ? 'Kustomisasi User-Agent' : 'Custom User-Agent',
          desc: isIndonesian
              ? 'Tekan ikon pengaturan (⚙️/tune) di address bar untuk mengubah User Agent menjadi Desktop Chrome Windows, Safari iPhone/iPad, Mac, atau custom User Agent Anda sendiri.'
              : 'Tap the settings icon on the address bar to switch User-Agent to Windows Desktop Chrome, iPhone/iPad Safari, macOS, or custom strings.',
        ),
        _StepItem(
          stepNumber: '3',
          title: isIndonesian ? 'Pilihan Mesin Pencari' : 'Search Engine Presets',
          desc: isIndonesian
              ? 'Ketik langsung kata kunci pencarian di address bar. Anda dapat memilih mesin pencari favorit: Google, DuckDuckGo, Bing, Brave, Yahoo, Startpage, atau custom search URL.'
              : 'Type keywords directly into the address bar. Choose your search engine: Google, DuckDuckGo, Bing, Brave, Yahoo, Startpage, or custom URL.',
        ),
        _StepItem(
          stepNumber: '4',
          title: isIndonesian ? 'Simulasi IP & Cek IP' : 'IP Spoofing & IP Check',
          desc: isIndonesian
              ? 'Tersedia tombol "Cek IP Saya" untuk memeriksa IP publik, serta fitur injeksi header X-Forwarded-For untuk simulasi asal IP target.'
              : 'Includes a 1-tap "Check My IP" utility and custom X-Forwarded-For header simulation.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 5: SSL Pinning & Troubleshooting
// ─────────────────────────────────────────────────────────────
class _SslPinningTab extends StatelessWidget {
  final AppLocalizations l;
  const _SslPinningTab({required this.l});

  @override
  Widget build(BuildContext context) {
    final isIndonesian = l.locale.languageCode == 'id';

    const fridaScript =
        'frida --codeshare akabe1/frida-multiple-unpinning -U -f com.target.app';

    const networkConfigXml = '''<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>''';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          icon: Icons.warning_amber_rounded,
          title: isIndonesian ? 'Apa itu SSL Pinning?' : 'What is SSL Pinning?',
          desc: isIndonesian
              ? 'Banyak aplikasi perbankan dan e-commerce menolak sertifikat CA pihak ketiga meskipun sudah dipasang di HP. Koneksi aplikasi tersebut akan putus (SSL Handshake Error). Berikut solusi bypass yang terbukti berhasil:'
              : 'Many banking and modern apps reject user CA certificates even if installed. Their connections fail with SSL Handshake errors. Here are proven bypass solutions:',
          color: const Color(0xFFFFAA33),
        ),
        const SizedBox(height: 16),

        // Method 1: Frida
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal, color: Color(0xFF6C63FF), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isIndonesian ? 'Metode 1: Frida Universal Unpinning' : 'Method 1: Frida Universal Unpinning',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isIndonesian
                      ? 'Jalankan perintah ini di terminal PC Anda yang terhubung dengan HP (USB debugging aktif):'
                      : 'Run this command on your PC with USB debugging active:',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          fridaScript,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Color(0xFF00D4AA),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: fridaScript));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.tr('copied'))),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Method 2: LSPosed Module
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.extension_outlined, color: Color(0xFF00D4AA), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isIndonesian ? 'Metode 2: LSPosed / Xposed Module' : 'Method 2: LSPosed / Xposed Module',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isIndonesian
                      ? 'Jika HP Anda sudah di-root dengan Magisk / KernelSU, gunakan modul:\n• TrustMeAlready (Otomatis bypass OkHttp, WebView, TrustManager)\n• JustTrustMe\n• Disable-FLAG_SECURE'
                      : 'For rooted devices with Magisk / KernelSU, install:\n• TrustMeAlready (Auto-bypasses OkHttp, WebView, TrustManager)\n• JustTrustMe\n• Disable-FLAG_SECURE',
                  style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Method 3: Network Security Config
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code, color: Color(0xFFFFAA33), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isIndonesian ? 'Metode 3: Modifikasi APK (Developer / QA)' : 'Method 3: APK Recompilation (Dev / QA)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isIndonesian
                      ? 'Decompile APK dengan apktool, lalu tambahkan file res/xml/network_security_config.xml berikut:'
                      : 'Decompile APK via apktool, then place this in res/xml/network_security_config.xml:',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          networkConfigXml,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Color(0xFFFFAA33),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: networkConfigXml));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.tr('copied'))),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable UI Helpers
// ─────────────────────────────────────────────────────────────
class _StepItem extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String desc;
  const _StepItem({
    required this.stepNumber,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF6C63FF),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
