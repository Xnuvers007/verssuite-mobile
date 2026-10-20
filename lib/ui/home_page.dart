import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'tabs/proxy_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/intercept_tab.dart';
import 'tabs/repeater_tab.dart';
import 'tabs/settings_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _fabAnimController;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Init CA on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().initCA();
    });
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();

    final tabs = [
      const ProxyTab(),
      const HistoryTab(),
      const InterceptTab(),
      const RepeaterTab(),
      const SettingsTab(),
    ];

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.wifi_tethering_outlined),
        selectedIcon: const Icon(Icons.wifi_tethering),
        label: l.tr('proxy'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history),
        label: l.tr('history'),
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: appState.interceptQueue.isNotEmpty,
          label: Text('${appState.interceptQueue.length}'),
          child: const Icon(Icons.pause_circle_outline),
        ),
        selectedIcon: Badge(
          isLabelVisible: appState.interceptQueue.isNotEmpty,
          label: Text('${appState.interceptQueue.length}'),
          child: const Icon(Icons.pause_circle_filled),
        ),
        label: l.tr('intercept'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.replay_outlined),
        selectedIcon: const Icon(Icons.replay),
        label: l.tr('repeater'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: l.tr('settings'),
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: tabs[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: destinations,
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}
