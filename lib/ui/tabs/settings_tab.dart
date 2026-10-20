import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/locale_state.dart';
import '../../state/native_bridge.dart';

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
