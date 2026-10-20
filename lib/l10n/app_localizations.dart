import 'package:flutter/widgets.dart';

/// Minimal i18n without codegen — just two maps keyed by locale.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'VersSuite Mobile',
      'proxy': 'Proxy',
      'history': 'History',
      'intercept': 'Intercept',
      'repeater': 'Repeater',
      'settings': 'Settings',
      'start_proxy': 'Start Proxy',
      'stop_proxy': 'Stop Proxy',
      'proxy_running': 'Proxy is running',
      'proxy_stopped': 'Proxy is stopped',
      'port': 'Port',
      'bind_address': 'Bind Address',
      'https_intercept': 'HTTPS Interception',
      'enabled': 'Enabled',
      'disabled': 'Disabled',
      'ca_certificate': 'CA Certificate',
      'export_ca': 'Export CA Certificate',
      'install_ca': 'Install CA Certificate',
      'regenerate_ca': 'Regenerate CA',
      'ca_exported': 'CA certificate exported to Downloads',
      'ca_regen_confirm': 'This will invalidate all existing connections. Continue?',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'request': 'Request',
      'response': 'Response',
      'headers': 'Headers',
      'body': 'Body',
      'raw': 'Raw',
      'hex': 'Hex',
      'method': 'Method',
      'url': 'URL',
      'status': 'Status',
      'size': 'Size',
      'time': 'Time',
      'host': 'Host',
      'no_flows': 'No traffic captured yet',
      'clear_history': 'Clear History',
      'forward': 'Forward',
      'drop': 'Drop',
      'send': 'Send',
      'intercept_on': 'Intercept is ON',
      'intercept_off': 'Intercept is OFF',
      'no_intercepted': 'No intercepted requests',
      'edit_request': 'Edit Request',
      'enter_url': 'Enter URL...',
      'repeater_hint': 'Edit the raw request and press Send',
      'language': 'Language',
      'english': 'English',
      'indonesian': 'Bahasa Indonesia',
      'about': 'About',
      'about_desc': 'HTTP/HTTPS traffic interceptor for Android. Inspect, modify, and replay network requests.',
      'proxy_config_title': 'Proxy Configuration',
      'wifi_proxy_hint': 'Set your device Wi-Fi proxy to:',
      'copy': 'Copy',
      'copied': 'Copied!',
      'filter': 'Filter',
      'search': 'Search...',
      'export_curl': 'Export as cURL',
      'no_response': 'No response yet',
      'connection_error': 'Connection error',
      'timeout': 'Timeout',
      'dark_mode': 'Dark Mode',
      'version': 'Version',
      'support_donation': 'Support & Donation',
      'support_desc': 'If this project helps you, consider supporting the developer!',
      'author': 'Author',
      'author_connect': 'Stay connected for more exciting updates!',
    },
    'id': {
      'app_title': 'VersSuite Mobile',
      'proxy': 'Proksi',
      'history': 'Riwayat',
      'intercept': 'Intersep',
      'repeater': 'Pengulang',
      'settings': 'Pengaturan',
      'start_proxy': 'Mulai Proksi',
      'stop_proxy': 'Hentikan Proksi',
      'proxy_running': 'Proksi sedang berjalan',
      'proxy_stopped': 'Proksi tidak aktif',
      'port': 'Port',
      'bind_address': 'Alamat Bind',
      'https_intercept': 'Intersepsi HTTPS',
      'enabled': 'Aktif',
      'disabled': 'Nonaktif',
      'ca_certificate': 'Sertifikat CA',
      'export_ca': 'Ekspor Sertifikat CA',
      'install_ca': 'Pasang Sertifikat CA',
      'regenerate_ca': 'Buat Ulang CA',
      'ca_exported': 'Sertifikat CA diekspor ke Downloads',
      'ca_regen_confirm': 'Ini akan membatalkan semua koneksi yang ada. Lanjutkan?',
      'confirm': 'Konfirmasi',
      'cancel': 'Batal',
      'request': 'Permintaan',
      'response': 'Respons',
      'headers': 'Header',
      'body': 'Isi',
      'raw': 'Mentah',
      'hex': 'Hex',
      'method': 'Metode',
      'url': 'URL',
      'status': 'Status',
      'size': 'Ukuran',
      'time': 'Waktu',
      'host': 'Host',
      'no_flows': 'Belum ada lalu lintas yang ditangkap',
      'clear_history': 'Hapus Riwayat',
      'forward': 'Teruskan',
      'drop': 'Buang',
      'send': 'Kirim',
      'intercept_on': 'Intersep AKTIF',
      'intercept_off': 'Intersep NONAKTIF',
      'no_intercepted': 'Tidak ada permintaan yang diintersep',
      'edit_request': 'Edit Permintaan',
      'enter_url': 'Masukkan URL...',
      'repeater_hint': 'Edit permintaan mentah dan tekan Kirim',
      'language': 'Bahasa',
      'english': 'English',
      'indonesian': 'Bahasa Indonesia',
      'about': 'Tentang',
      'about_desc': 'Pengintersep lalu lintas HTTP/HTTPS untuk Android. Periksa, modifikasi, dan ulangi permintaan jaringan.',
      'proxy_config_title': 'Konfigurasi Proksi',
      'wifi_proxy_hint': 'Atur proxy Wi-Fi perangkat Anda ke:',
      'copy': 'Salin',
      'copied': 'Tersalin!',
      'filter': 'Filter',
      'search': 'Cari...',
      'export_curl': 'Ekspor sebagai cURL',
      'no_response': 'Belum ada respons',
      'connection_error': 'Kesalahan koneksi',
      'timeout': 'Waktu habis',
      'dark_mode': 'Mode Gelap',
      'version': 'Versi',
      'support_donation': 'Dukungan & Donasi',
      'support_desc': 'Jika proyek ini membantu Anda, pertimbangkan untuk mendukung pengembang!',
      'author': 'Pengembang (Author)',
      'author_connect': 'Tetap terhubung untuk update menarik lainnya!',
    },
  };

  String tr(String key) {
    return _translations[locale.languageCode]?[key] ??
        _translations['en']?[key] ??
        key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'id'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

