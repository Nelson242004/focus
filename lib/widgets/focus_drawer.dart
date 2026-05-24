import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ranking_profile.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../screens/achievements_screen.dart';
import '../screens/exams_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/global_ranking_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/polytechnic_screen.dart';
import '../screens/resources_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/study_tasks_screen.dart';
import '../utils/focus_palette.dart';
import 'focus_app_icon.dart';

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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? FocusPalette.darkBackgroundGradient
                : FocusPalette.lightBackgroundGradient,
          ),
        ),
        child: Column(
          children: [
            _DrawerHeaderCard(isDark: isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _sectionLabel(context, 'Estudio'),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.dashboard,
                    iconKind: FocusAppIconKind.focus,
                    label: 'Dashboard',
                    selected: selectedMainIndex == 0,
                    onTap: () => _goToMain(context, 0),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.timer,
                    iconKind: FocusAppIconKind.pomodoro,
                    label: 'Pomodoro',
                    selected: selectedMainIndex == 1,
                    onTap: () => _goToMain(context, 1),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.book,
                    iconKind: FocusAppIconKind.subjects,
                    label: 'Materias',
                    selected: selectedMainIndex == 2,
                    onTap: () => _goToMain(context, 2),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.check_circle,
                    iconKind: FocusAppIconKind.habits,
                    label: 'Hábitos',
                    selected: selectedMainIndex == 3,
                    onTap: () => _goToMain(context, 3),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.assignment,
                    iconKind: FocusAppIconKind.exams,
                    label: 'Exámenes',
                    selected: selectedRoute == 'exams',
                    onTap: () => _replace(context, const ExamsScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.task_alt_rounded,
                    iconKind: FocusAppIconKind.tasks,
                    label: 'Tareas',
                    selected: selectedRoute == 'tasks',
                    onTap: () => _replace(context, const StudyTasksScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.school_rounded,
                    iconKind: FocusAppIconKind.polytechnic,
                    label: 'Politécnica',
                    selected: selectedRoute == 'polytechnic',
                    onTap: () => _replace(context, const PolytechnicScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.link_rounded,
                    iconKind: FocusAppIconKind.resources,
                    label: 'Recursos',
                    selected: selectedRoute == 'resources',
                    onTap: () => _replace(context, const ResourcesScreen()),
                  ),
                  _sectionLabel(context, 'Comunidad'),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.public_rounded,
                    iconKind: FocusAppIconKind.ranking,
                    label: 'Ranking global',
                    selected: selectedRoute == 'ranking',
                    onTap: () => _replace(context, const GlobalRankingScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.people_alt_rounded,
                    iconKind: FocusAppIconKind.friends,
                    label: 'Perfil',
                    selected: selectedRoute == 'friends',
                    onTap: () => _replace(context, const FriendsScreen()),
                  ),
                  _tile(
                    context,
                    duration: duration,
                    icon: Icons.military_tech_rounded,
                    iconKind: FocusAppIconKind.achievements,
                    label: 'Logros',
                    selected: selectedRoute == 'achievements',
                    onTap: () => _replace(context, const AchievementsScreen()),
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
                      icon: Icons.settings,
                      iconKind: FocusAppIconKind.settings,
                      label: 'Configuración',
                      selected: selectedRoute == 'settings',
                      onTap: () => _replace(context, const SettingsScreen()),
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

  Widget _sectionLabel(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: muted.withValues(alpha: isDark ? 0.70 : 0.85),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required Duration duration,
    required IconData icon,
    FocusAppIconKind? iconKind,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final normalColor = theme.colorScheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: duration,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: selected
            ? selectedColor.withValues(alpha: isDark ? 0.15 : 0.10)
            : Colors.transparent,
        border: selected
            ? Border.all(
                color: selectedColor.withValues(alpha: isDark ? 0.18 : 0.12),
              )
            : null,
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: iconKind == null
            ? Icon(
                icon,
                color: selected ? selectedColor : normalColor,
              )
            : FocusAppIcon(
                kind: iconKind,
                size: selected ? 30 : 27,
                fallback: icon,
                fallbackColor: selected ? selectedColor : normalColor,
              ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? selectedColor : normalColor,
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

class _DrawerHeaderCard extends StatelessWidget {
  final bool isDark;

  const _DrawerHeaderCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (RankingService.currentUser == null) {
            final localName = provider.settings.userName.trim();
            return _DrawerHeaderContent(
              isDark: isDark,
              name: localName.isEmpty ? 'Focus' : localName,
              subtitle: 'Datos académicos locales',
            );
          }

          return FutureBuilder<RankingProfile?>(
            future: RankingService.ensureProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return _DrawerHeaderContent(
                isDark: isDark,
                name: profile?.name ??
                    RankingService.currentUser?.email ??
                    'Focus',
                subtitle: profile?.career ?? 'Cuenta activa',
                photoUrl: profile?.photoUrl,
              );
            },
          );
        },
      ),
    );
  }
}

class _DrawerHeaderContent extends StatelessWidget {
  final bool isDark;
  final String name;
  final String subtitle;
  final String? photoUrl;

  const _DrawerHeaderContent({
    required this.isDark,
    required this.name,
    required this.subtitle,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? surface.withValues(alpha: 0.74)
            : surface.withValues(alpha: 0.92),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : FocusPalette.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
            child: hasPhoto
                ? null
                : const Icon(
                    Icons.center_focus_strong_rounded,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
