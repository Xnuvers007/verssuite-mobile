import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

class ProxyTab extends StatelessWidget {
  const ProxyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final running = appState.proxyRunning;
    final config = appState.config;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(l.tr('app_title')),
            centerTitle: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Status Card
                _StatusCard(running: running, l: l),
                const SizedBox(height: 16),

                // Start/Stop Button
                _ProxyButton(
                  running: running,
                  l: l,
                  onPressed: () async {
                    if (running) {
                      await appState.stopProxy();
                    } else {
                      await appState.startProxy();
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Config Info Card
                _ConfigInfoCard(config: config, l: l),
                const SizedBox(height: 16),

                // CA Status Card
                _CAStatusCard(
                  status: appState.caStatus,
                  l: l,
                ),
                const SizedBox(height: 16),

                // Quick Stats
                _QuickStatsCard(
                  flowCount: appState.flows.length,
                  interceptCount: appState.interceptQueue.length,
                  l: l,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool running;
  final AppLocalizations l;
  const _StatusCard({required this.running, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: running
              ? [const Color(0xFF00D4AA).withValues(alpha: 0.15), const Color(0xFF00D4AA).withValues(alpha: 0.05)]
              : [const Color(0xFF6C63FF).withValues(alpha: 0.15), const Color(0xFF6C63FF).withValues(alpha: 0.05)],
        ),
        border: Border.all(
          color: running
              ? const Color(0xFF00D4AA).withValues(alpha: 0.3)
              : const Color(0xFF6C63FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: running
                  ? const Color(0xFF00D4AA).withValues(alpha: 0.2)
                  : const Color(0xFF6C63FF).withValues(alpha: 0.2),
            ),
            child: Icon(
              running ? Icons.shield : Icons.shield_outlined,
              color: running ? const Color(0xFF00D4AA) : const Color(0xFF6C63FF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? l.tr('proxy_running') : l.tr('proxy_stopped'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: running ? const Color(0xFF00D4AA) : Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  running ? 'Port ${context.read<AppState>().config.port}' : '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (running)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF00D4AA),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF00D4AA),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProxyButton extends StatelessWidget {
  final bool running;
  final AppLocalizations l;
  final VoidCallback onPressed;
  const _ProxyButton({required this.running, required this.l, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: running ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 24),
            const SizedBox(width: 8),
            Text(
              running ? l.tr('stop_proxy') : l.tr('start_proxy'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigInfoCard extends StatelessWidget {
  final dynamic config;
  final AppLocalizations l;
  const _ConfigInfoCard({required this.config, required this.l});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  l.tr('proxy_config_title'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l.tr('wifi_proxy_hint'),
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(
                  text: '${config.bindAddress == '0.0.0.0' ? 'localhost' : config.bindAddress}:${config.port}',
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.tr('copied'))),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${config.bindAddress}:${config.port}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.copy, size: 16, color: Colors.white.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CAStatusCard extends StatelessWidget {
  final String status;
  final AppLocalizations l;
  const _CAStatusCard({required this.status, required this.l});

  @override
  Widget build(BuildContext context) {
    final ready = status == 'Ready';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready
                    ? const Color(0xFF00D4AA).withValues(alpha: 0.2)
                    : const Color(0xFFFFAA33).withValues(alpha: 0.2),
              ),
              child: Icon(
                ready ? Icons.verified_user : Icons.hourglass_top,
                size: 20,
                color: ready ? const Color(0xFF00D4AA) : const Color(0xFFFFAA33),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.tr('ca_certificate'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: ready ? const Color(0xFF00D4AA) : const Color(0xFFFFAA33),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  final int flowCount;
  final int interceptCount;
  final AppLocalizations l;
  const _QuickStatsCard({required this.flowCount, required this.interceptCount, required this.l});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: l.tr('history'),
            value: '$flowCount',
            icon: Icons.history,
            color: const Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: l.tr('intercept'),
            value: '$interceptCount',
            icon: Icons.pause_circle_outline,
            color: const Color(0xFFFFAA33),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
