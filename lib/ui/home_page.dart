import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'tabs/proxy_tab.dart';
import 'tabs/browser_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/intercept_tab.dart';
import 'tabs/repeater_tab.dart';
import 'tabs/settings_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Init CA on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().initCA();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();

    final tabs = [
      const ProxyTab(),
      const BrowserTab(),
      const HistoryTab(),
      const InterceptTab(),
      const RepeaterTab(),
      const SettingsTab(),
    ];

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.wifi_tethering_outlined, size: 20),
        selectedIcon: const Icon(Icons.wifi_tethering, size: 20),
        label: l.tr('proxy'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.travel_explore_outlined, size: 20),
        selectedIcon: const Icon(Icons.travel_explore, size: 20),
        label: l.tr('browser'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.history_outlined, size: 20),
        selectedIcon: const Icon(Icons.history, size: 20),
        label: l.tr('history'),
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: appState.interceptQueue.isNotEmpty,
          label: Text('${appState.interceptQueue.length}'),
          child: const Icon(Icons.pause_circle_outline, size: 20),
        ),
        selectedIcon: Badge(
          isLabelVisible: appState.interceptQueue.isNotEmpty,
          label: Text('${appState.interceptQueue.length}'),
          child: const Icon(Icons.pause_circle_filled, size: 20),
        ),
        label: l.tr('intercept'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.replay_outlined, size: 20),
        selectedIcon: const Icon(Icons.replay, size: 20),
        label: l.tr('repeater'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined, size: 20),
        selectedIcon: const Icon(Icons.settings, size: 20),
        label: l.tr('settings'),
      ),
    ];

    return Scaffold(
      // Use IndexedStack to preserve Browser & Flow states across tab switches
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
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
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}
