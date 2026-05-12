import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../screens/about_screen.dart';
import '../screens/achievements_screen.dart';
import '../screens/exams_screen.dart';
import '../screens/help_screen.dart';
import '../screens/global_ranking_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/polytechnic_screen.dart';
import '../screens/resources_screen.dart';
import '../screens/subjects_screen.dart';

class FocusDrawer extends StatelessWidget {
  final int? selectedMainIndex;
  final String? selectedRoute;

  const FocusDrawer({super.key, this.selectedMainIndex, this.selectedRoute});

  @override
  Widget build(BuildContext context) {
    final duration =
        Provider.of<AppProvider>(context).settings.animationsEnabled
            ? const Duration(milliseconds: 180)
            : Duration.zero;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                    Color(0xFF111827),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFE0F2FE),
                    Color(0xFFDBEAFE),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Organiza materias, exámenes y sesiones de estudio.',
                      style: TextStyle(
                        color:
                            isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.dashboard,
                    label: 'Dashboard',
                    selected: selectedMainIndex == 0,
                    onTap: () => _goToMain(context, 0),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.timer,
                    label: 'Pomodoro',
                    selected: selectedMainIndex == 1,
                    onTap: () => _goToMain(context, 1),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.check_circle,
                    label: 'Hábitos',
                    selected: selectedMainIndex == 2,
                    onTap: () => _goToMain(context, 2),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.book,
                    label: 'Materias',
                    selected: selectedRoute == 'subjects',
                    onTap: () => _replace(context, const SubjectsScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.assignment,
                    label: 'Exámenes',
                    selected: selectedRoute == 'exams',
                    onTap: () => _replace(context, const ExamsScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.link_rounded,
                    label: 'Recursos',
                    selected: selectedRoute == 'resources',
                    onTap: () => _replace(context, const ResourcesScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.school_rounded,
                    label: 'Politécnica',
                    selected: selectedRoute == 'polytechnic',
                    onTap: () => _replace(context, const PolytechnicScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.emoji_events_rounded,
                    label: 'Logros',
                    selected: selectedRoute == 'achievements',
                    onTap: () => _replace(context, const AchievementsScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.public_rounded,
                    label: 'Ranking global',
                    selected: selectedRoute == 'ranking',
                    onTap: () => _replace(context, const GlobalRankingScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.bar_chart,
                    label: 'Estadísticas',
                    selected: selectedMainIndex == 3,
                    onTap: () => _goToMain(context, 3),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.help_outline_rounded,
                    label: 'Ayuda',
                    selected: selectedRoute == 'help',
                    onTap: () => _replace(context, const HelpScreen()),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tile(
                      context,
                      duration: duration,
                      icon: Icons.info_rounded,
                      label: 'About',
                      selected: selectedRoute == 'about',
                      onTap: () => _replace(context, const AboutScreen()),
                    ),
                    _tile(
                      context,
                      duration: duration,
                      icon: Icons.settings,
                      label: 'Configuración',
                      selected: selectedMainIndex == 4,
                      onTap: () => _goToMain(context, 4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required Duration duration,
    required IconData icon,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: selected
            ? (isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.92))
            : Colors.transparent,
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(
          icon,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : (isDark ? Colors.white70 : const Color(0xFF334155)),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  void _goToMain(BuildContext context, int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(initialIndex: index),
      ),
      (route) => false,
    );
  }

  void _replace(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
