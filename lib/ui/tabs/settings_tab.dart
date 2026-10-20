import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../state/app_state.dart';
import '../../state/locale_state.dart';
import '../../state/native_bridge.dart';
import '../dialogs/update_dialog.dart';
import '../pages/tutorial_page.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final localeState = context.watch<LocaleState>();
    final config = appState.config;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.tr('settings'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          // ─── Tutorial & Panduan ───────────────────────────
          _SectionHeader(title: l.tr('tutorial')),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF00D4AA), size: 22),
              ),
              title: Text(
                l.tr('tutorial'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              subtitle: Text(
                l.tr('tutorial_desc'),
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TutorialPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ─── Proxy Configuration ──────────────────────────
          _SectionHeader(title: l.tr('proxy_config_title')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.numbers,
                    label: l.tr('port'),
                    trailing: SizedBox(
                      width: 80,
                      child: TextField(
                        controller: TextEditingController(
                          text: config.port.toString(),
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onSubmitted: (val) {
                          final port = int.tryParse(val);
                          if (port != null && port > 0 && port <= 65535) {
                            config.port = port;
                            appState.saveConfig();
                          }
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.dns,
                    label: l.tr('bind_address'),
                    trailing: SizedBox(
                      width: 120,
                      child: TextField(
                        controller: TextEditingController(
                          text: config.bindAddress,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onSubmitted: (val) {
                          config.bindAddress = val.isNotEmpty ? val : '0.0.0.0';
                          appState.saveConfig();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── HTTPS Configuration ──────────────────────────
          _SectionHeader(title: l.tr('https_intercept')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.lock,
                    label: l.tr('https_intercept'),
                    trailing: Switch(
                      value: config.httpsInterception,
                      activeColor: const Color(0xFF00D4AA),
                      onChanged: (val) {
                        config.httpsInterception = val;
                        appState.saveConfig();
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.verified_user,
                    label: l.tr('ca_certificate'),
                    subtitle: appState.caStatus,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.download,
                          label: l.tr('export_ca'),
                          color: const Color(0xFF6C63FF),
                          onTap: () async {
                            final ok = await appState.exportCA();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? l.tr('ca_exported')
                                      : 'Export failed'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.refresh,
                          label: l.tr('regenerate_ca'),
                          color: const Color(0xFFFFAA33),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(l.tr('regenerate_ca')),
                                content: Text(l.tr('ca_regen_confirm')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(l.tr('cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      appState.regenerateCA();
                                    },
                                    child: Text(l.tr('confirm')),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Language ─────────────────────────────────────
          _SectionHeader(title: l.tr('language')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text(l.tr('english')),
                    subtitle: const Text('English'),
                    value: 'en',
                    groupValue: localeState.locale.languageCode,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (val) {
                      if (val != null) localeState.setLocale(Locale(val));
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(l.tr('indonesian')),
                    subtitle: const Text('Bahasa Indonesia'),
                    value: 'id',
                    groupValue: localeState.locale.languageCode,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (val) {
                      if (val != null) localeState.setLocale(Locale(val));
                    },
                  ),
                ],
              ),
            ),
          ),
          // ─── Developer Options ─────────────────────────────
          _SectionHeader(title: l.tr('developer_options')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.travel_explore,
                    label: l.tr('dev_auto_proxy_title'),
                    subtitle: l.tr('dev_auto_proxy_desc'),
                    trailing: Switch(
                      value: config.inAppBrowserAutoProxy,
                      activeColor: const Color(0xFF00D4AA),
                      onChanged: (val) {
                        config.inAppBrowserAutoProxy = val;
                        appState.saveConfig();
                        if (appState.proxyRunning) {
                          NativeBridge.setWebViewProxy(
                            port: config.port,
                            enabled: val,
                          );
                        }
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.gpp_maybe_outlined,
                    label: l.tr('dev_bypass_ssl_title'),
                    subtitle: l.tr('dev_bypass_ssl_desc'),
                    trailing: Switch(
                      value: config.bypassSslWarnings,
                      activeColor: const Color(0xFF00D4AA),
                      onChanged: (val) {
                        config.bypassSslWarnings = val;
                        appState.saveConfig();
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.compress,
                    label: l.tr('dev_strip_encoding_title'),
                    subtitle: l.tr('dev_strip_encoding_desc'),
                    trailing: Switch(
                      value: config.stripAcceptEncoding,
                      activeColor: const Color(0xFF00D4AA),
                      onChanged: (val) {
                        config.stripAcceptEncoding = val;
                        appState.saveConfig();
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.storage,
                    label: l.tr('dev_max_history_title'),
                    trailing: DropdownButton<int>(
                      value: config.maxFlowHistory,
                      dropdownColor: const Color(0xFF1A1A2E),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 100, child: Text('100 flows')),
                        DropdownMenuItem(value: 250, child: Text('250 flows')),
                        DropdownMenuItem(value: 500, child: Text('500 flows')),
                        DropdownMenuItem(value: 1000, child: Text('1000 flows')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          config.maxFlowHistory = val;
                          appState.saveConfig();
                        }
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  _SettingRow(
                    icon: Icons.timer_outlined,
                    label: l.tr('dev_timeout_title'),
                    trailing: DropdownButton<int>(
                      value: config.connectionTimeout,
                      dropdownColor: const Color(0xFF1A1A2E),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10s')),
                        DropdownMenuItem(value: 30, child: Text('30s')),
                        DropdownMenuItem(value: 60, child: Text('60s')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          config.connectionTimeout = val;
                          appState.saveConfig();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Pembaruan Aplikasi (App Update) ──────────────
          _SectionHeader(title: l.tr('check_update')),
          const SizedBox(height: 8),
          const _UpdateCheckCard(),
          const SizedBox(height: 16),

          // ─── About ────────────────────────────────────────
          _SectionHeader(title: l.tr('about')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.wifi_tethering, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VersSuite Mobile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${l.tr('version')} 1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.tr('about_desc'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LinkButton(
                    icon: Icons.system_update_alt_rounded,
                    label: 'GitHub Releases (Download APK Update)',
                    url: 'https://github.com/Xnuvers007/verssuite-mobile/releases',
                    color: const Color(0xFF00D4AA),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Dukungan & Donasi ─────────────────────────────
          _SectionHeader(title: l.tr('support_donation')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.tr('support_desc'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _LinkButton(
                          icon: Icons.coffee,
                          label: 'Trakteer',
                          url: 'https://trakteer.id/Xnuvers007',
                          color: const Color(0xFFFF5E5B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LinkButton(
                          icon: Icons.volunteer_activism,
                          label: 'Saweria',
                          url: 'https://saweria.co/Xnuvers007',
                          color: const Color(0xFFFFAA33),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Author ───────────────────────────────────────
          _SectionHeader(title: l.tr('author')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                        child: const Icon(Icons.person, color: Color(0xFF6C63FF)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Indra Dwi Aryadi',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '@Xnuvers007',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF00D4AA),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.tr('author_connect'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const Divider(height: 20),
                  _SocialTile(
                    title: 'GitHub',
                    subtitle: 'Xnuvers007',
                    url: 'https://github.com/Xnuvers007',
                    icon: Icons.code,
                  ),
                  _SocialTile(
                    title: 'GitHub Releases',
                    subtitle: 'verssuite-mobile/releases',
                    url: 'https://github.com/Xnuvers007/verssuite-mobile/releases',
                    icon: Icons.new_releases_outlined,
                  ),
                  _SocialTile(
                    title: 'YouTube',
                    subtitle: '@xnuvers0077',
                    url: 'https://www.youtube.com/@xnuvers0077',
                    icon: Icons.play_circle_outline,
                  ),
                  _SocialTile(
                    title: 'Instagram',
                    subtitle: '@indradwi.25',
                    url: 'https://www.instagram.com/indradwi.25',
                    icon: Icons.camera_alt_outlined,
                  ),
                  _SocialTile(
                    title: 'LinkedIn',
                    subtitle: 'Indra Dwi Aryadi',
                    url: 'https://www.linkedin.com/in/indradwiaryadi',
                    icon: Icons.work_outline,
                  ),
                  _SocialTile(
                    title: 'Facebook',
                    subtitle: 'indradwi.25',
                    url: 'https://www.facebook.com/indradwi.25',
                    icon: Icons.people_outline,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  const _SettingRow({required this.icon, required this.label, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;

  const _LinkButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final ok = await NativeBridge.openUrl(url);
        if (!ok) {
          await Clipboard.setData(ClipboardData(text: url));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('URL tersalin: $url')),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String url;
  final IconData icon;

  const _SocialTile({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final ok = await NativeBridge.openUrl(url);
        if (!ok) {
          await Clipboard.setData(ClipboardData(text: url));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Link tersalin: $url')),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _UpdateCheckCard extends StatefulWidget {
  const _UpdateCheckCard();

  @override
  State<_UpdateCheckCard> createState() => _UpdateCheckCardState();
}

class _UpdateCheckCardState extends State<_UpdateCheckCard> {
  bool _checking = false;
  String? _statusMessage;
  bool? _isUpToDate;
  String _currentVer = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final ver = await NativeBridge.getAppVersion();
    if (mounted) {
      setState(() => _currentVer = ver);
    }
  }

  Future<void> _checkUpdate(BuildContext context) async {
    setState(() {
      _checking = true;
      _statusMessage = null;
    });

    try {
      final currentVer = await NativeBridge.getAppVersion();
      final deviceAbi = await NativeBridge.getDeviceAbi();
      final latest = await UpdateService.getLatestReleaseInfo();

      if (!mounted) return;

      if (latest != null && UpdateService.isNewer(latest.tagName, currentVer)) {
        setState(() {
          _checking = false;
          _isUpToDate = false;
          _statusMessage = 'Update tersedia: ${latest.tagName}';
        });

        if (context.mounted) {
          await UpdateDialog.show(
            context,
            updateInfo: latest,
            currentVersion: currentVer,
            deviceAbi: deviceAbi,
          );
        }
      } else {
        setState(() {
          _checking = false;
          _isUpToDate = true;
          _statusMessage = 'Versi terkini: v$currentVer (Sudah Terbaru ✅)';
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aplikasi Anda sudah versi terbaru (v$currentVer) ✅'),
              backgroundColor: const Color(0xFF00D4AA),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _statusMessage = 'Gagal memeriksa pembaruan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isUpToDate == false
              ? const Color(0xFF00D4AA).withValues(alpha: 0.6)
              : const Color(0xFF6C63FF).withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  child: const Icon(Icons.autorenew_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.tr('check_update'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusMessage ?? '${l.tr('current_version')}: v$_currentVer',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isUpToDate == true
                              ? const Color(0xFF00D4AA)
                              : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _checking ? null : () => _checkUpdate(context),
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(_checking ? l.tr('checking_update') : l.tr('check_update')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => NativeBridge.openUrl('https://github.com/Xnuvers007/verssuite-mobile/releases'),
                  icon: const Icon(Icons.open_in_browser, size: 20),
                  tooltip: 'GitHub Releases',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

