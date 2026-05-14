import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/app_provider.dart';
import '../widgets/focus_drawer.dart';
import 'dashboard_screen.dart';
import 'habits_screen.dart';
import 'pomodoro_screen.dart';
import 'settings_screen.dart';

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
          'habits' => 2,
          'settings' => 3,
          _ => 0,
        };
    if (_selectedIndex >= _screens.length) _selectedIndex = 0;
    _startScreenApplied = true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
        actions: [
          IconButton(
            tooltip: 'Cambiar tema',
            icon: Icon(provider.settings.themeMode == ThemeModeSetting.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            onPressed: () =>
                Provider.of<AppProvider>(context, listen: false).toggleTheme(),
          ),
        ],
      ),
      drawer: FocusDrawer(selectedMainIndex: _selectedIndex),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _screens[_selectedIndex],
      ),
    );
  }
}
