import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/connectivity_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../state/locale_state.dart';
import '../state/native_bridge.dart';
import 'dialogs/update_dialog.dart';
import 'pages/tutorial_page.dart';
import 'tabs/proxy_tab.dart';
import 'tabs/browser_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/intercept_tab.dart';
import 'tabs/repeater_tab.dart';
import 'tabs/settings_tab.dart';
import 'widgets/cyber_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  final GlobalKey<BrowserTabState> _browserKey = GlobalKey<BrowserTabState>();
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    // Init CA on startup, check updates, and monitor internet connectivity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().initCA();
      _checkForUpdatesQuietly();
      _initConnectivityMonitoring();
    });
  }

  void _initConnectivityMonitoring() {
    final service = ConnectivityService();
    service.startMonitoring();
    _connectivitySub = service.onConnectivityChanged.listen((isOnline) {
      if (!mounted) return;
      if (!isOnline) {
        CyberBanner.show(
          context,
          type: CyberBannerType.offline,
          title: '⚠️ Internet Terputus (Offline)',
          message: 'Koneksi Wi-Fi/Data mati. Permintaan proxy upstream akan gagal.',
          actionLabel: 'Detail',
          onAction: () {
            CyberBanner.showAlertDialog(
              context,
              type: CyberBannerType.offline,
              title: 'Koneksi Internet Terputus',
              message:
                  'Perangkat Anda terdeteksi tidak memiliki koneksi internet aktif. Pastikan Wi-Fi atau data seluler aktif agar VersSuite Mobile dapat meneruskan request web ke server tujuan.',
              confirmLabel: 'Mengerti',
            );
          },
        );
      } else {
        CyberBanner.show(
          context,
          type: CyberBannerType.online,
          title: '🌐 Internet Terhubung Kembali',
          message: 'Koneksi jaringan aktif. Proxy siap meneruskan lalu lintas web.',
        );
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdatesQuietly() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    try {
      final latest = await UpdateService.checkForUpdate(checkDismissed: true);
      if (latest != null && mounted) {
        final currentVer = await UpdateService.getCurrentVersion();
        final deviceAbi = await NativeBridge.getDeviceAbi();
        await UpdateDialog.show(
          context,
          updateInfo: latest,
          currentVersion: currentVer,
          deviceAbi: deviceAbi,
        );
      }
    } catch (_) {}
  }

  void _handleBackPress(BuildContext context, AppLocalizations l) {
    // If currently on Browser tab and can go back in WebView history, do that first!
    if (_currentIndex == 1 && _browserKey.currentState?.canGoBack == true) {
      _browserKey.currentState?.goBack();
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.touch_app, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(l.tr('press_back_again_to_exit')),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      // User tapped back twice within 2 seconds: cleanly exit app
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final localeState = context.watch<LocaleState>();
    final langKey = localeState.locale.languageCode;

    final tabs = [
      ProxyTab(key: ValueKey('proxy_$langKey')),
      BrowserTab(key: _browserKey),
      HistoryTab(key: ValueKey('history_$langKey')),
      InterceptTab(key: ValueKey('intercept_$langKey')),
      RepeaterTab(key: ValueKey('repeater_$langKey')),
      SettingsTab(key: ValueKey('settings_$langKey')),
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

    final railDestinations = [
      NavigationRailDestination(
        icon: const Icon(Icons.wifi_tethering_outlined, size: 22),
        selectedIcon: const Icon(Icons.wifi_tethering, size: 22),
        label: Text(l.tr('proxy')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.travel_explore_outlined, size: 22),
        selectedIcon: const Icon(Icons.travel_explore, size: 22),
        label: Text(l.tr('browser')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.history_outlined, size: 22),
        selectedIcon: const Icon(Icons.history, size: 22),
        label: Text(l.tr('history')),
      ),
      NavigationRailDestination(
        icon: Badge(
          isLabelVisible: appState.interceptQueue.isNotEmpty,
          label: Text('${appState.interceptQueue.length}'),
          child: const Icon(Icons.pause_circle_outline, size: 22),
        ),
        selectedIcon: Badge(
          isLabelVisible: appState.interceptQueue.isNotEmpty,
          label: Text('${appState.interceptQueue.length}'),
          child: const Icon(Icons.pause_circle_filled, size: 22),
        ),
        label: Text(l.tr('intercept')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.replay_outlined, size: 22),
        selectedIcon: const Icon(Icons.replay, size: 22),
        label: Text(l.tr('repeater')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined, size: 22),
        selectedIcon: const Icon(Icons.settings, size: 22),
        label: Text(l.tr('settings')),
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress(context, l);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 640;
          final isDesktop = constraints.maxWidth >= 1024;

          if (isWide) {
            // Tablet / iPad / Laptop / Android TV Layout: Side NavigationRail
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (i) => setState(() => _currentIndex = i),
                    extended: isDesktop,
                    minExtendedWidth: 190,
                    backgroundColor: const Color(0xFF12122A),
                    indicatorColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield, color: Colors.white, size: 24),
                          ),
                          if (isDesktop) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'VersSuite',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: IconButton(
                            icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF00D4AA)),
                            tooltip: l.tr('tutorial'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TutorialPage()),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    destinations: railDestinations,
                  ),
                  const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: tabs,
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile Phone Layout: Bottom NavigationBar
          return Scaffold(
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
        },
      ),
    );
  }
}
