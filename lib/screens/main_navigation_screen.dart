import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ranking_profile.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../widgets/focus_drawer.dart';
import 'dashboard_screen.dart';
import 'friends_screen.dart';
import 'habits_screen.dart';
import 'pomodoro_screen.dart';
import 'settings_screen.dart';
import 'subjects_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int? initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _startScreenApplied = false;

  final List<Widget> _screens = const [
    DashboardScreen(),
    PomodoroScreen(),
    SubjectsScreen(),
    HabitsScreen(),
    SettingsScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startScreenApplied) return;
    final startScreen = Provider.of<AppProvider>(context).settings.startScreen;
    _selectedIndex = widget.initialIndex ??
        switch (startScreen) {
          'pomodoro' => 1,
          'subjects' => 2,
          'habits' => 3,
          'settings' => 4,
          _ => 0,
        };
    if (_selectedIndex >= _screens.length) _selectedIndex = 0;
    _startScreenApplied = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
        actions: const [_ProfileAppBarButton()],
      ),
      drawer: FocusDrawer(selectedMainIndex: _selectedIndex),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedIndex = index;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Pomodoro',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Materias',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: 'Hábitos',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _ProfileAppBarButton extends StatelessWidget {
  const _ProfileAppBarButton();

  static const _defaultAsset = 'assets/profile_icons/focus_scholar.png';
  static const _profileAssets = [
    'assets/profile_icons/focus_scholar.png',
    'assets/profile_icons/focus_flame.png',
    'assets/profile_icons/focus_calm.png',
    'assets/profile_icons/focus_champion.png',
    'assets/profile_icons/focus_scholar_female.png',
    'assets/profile_icons/focus_flame_female.png',
    'assets/profile_icons/focus_calm_female.png',
    'assets/profile_icons/focus_champion_female.png',
  ];

  @override
  Widget build(BuildContext context) {
    if (RankingService.currentUser == null) {
      return _ProfileIconButton(
          asset: _defaultAsset, onTap: () => _openProfile(context));
    }
    return StreamBuilder<RankingProfile?>(
      stream: RankingService.profileStream(),
      builder: (context, snapshot) {
        return _ProfileIconButton(
          asset: _assetFromProfile(snapshot.data),
          onTap: () => _openProfile(context),
        );
      },
    );
  }

  static String _assetFromProfile(RankingProfile? profile) {
    final rawIndex = profile?.stats['socialMascotIndex'];
    final index = rawIndex is int ? rawIndex : int.tryParse('$rawIndex') ?? 0;
    if (index < 0 || index >= _profileAssets.length) return _defaultAsset;
    return _profileAssets[index];
  }

  static void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
    );
  }
}

class _ProfileIconButton extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;

  const _ProfileIconButton({
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.22);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Perfil',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              border: Border.all(color: borderColor),
            ),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
