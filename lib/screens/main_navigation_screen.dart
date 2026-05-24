import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_main_navigation_scope.dart';
import 'achievements_screen.dart';
import 'dashboard_screen.dart';
import 'exams_screen.dart';
import 'friends_screen.dart';
import 'global_ranking_screen.dart';
import 'habits_screen.dart';
import 'pomodoro_screen.dart';
import 'polytechnic_screen.dart';
import 'resources_screen.dart';
import 'settings_screen.dart';
import 'study_tasks_screen.dart';
import 'subjects_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int? initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _showDock = true;
  bool _startScreenApplied = false;

  final List<Widget> _screens = const [
    DashboardScreen(),
    PomodoroScreen(),
    SubjectsScreen(showAppBar: false),
    HabitsScreen(showAppBar: false),
    ExamsScreen(showAppBar: false),
    StudyTasksScreen(showAppBar: false),
    PolytechnicScreen(showAppBar: false),
    ResourcesScreen(showAppBar: false),
    GlobalRankingScreen(showAppBar: false),
    FriendsScreen(showAppBar: false),
    AchievementsScreen(showAppBar: false),
    SettingsScreen(showAppBar: false),
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
          'exams' => 4,
          'tasks' => 5,
          'polytechnic' => 6,
          'resources' => 7,
          'ranking' => 8,
          'friends' => 9,
          'achievements' => 10,
          'settings' => 11,
          _ => 0,
        };
    if (_selectedIndex >= _screens.length) _selectedIndex = 0;
    _startScreenApplied = true;
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() {
      _selectedIndex = index;
      _showDock = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Configuración',
              child: IconButton(
                icon: FocusAppIcon(
                  kind: FocusAppIconKind.settings,
                  size: 30,
                  fallback: Icons.settings_rounded,
                  fallbackColor: _selectedIndex == 11
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: () => _selectTab(11),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: FocusMainNavigationScope(
          openTab: _selectTab,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              final direction = notification.direction;
              if (notification.metrics.axis != Axis.vertical) return false;
              if (direction == ScrollDirection.reverse && _showDock) {
                setState(() => _showDock = false);
              } else if (direction == ScrollDirection.forward && !_showDock) {
                setState(() => _showDock = true);
              }
              return false;
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0.035, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: _screens[_selectedIndex],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: _showDock
            ? _FocusDockNavigation(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectTab,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _FocusDockNavigation extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _FocusDockNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<_FocusDockNavigation> createState() => _FocusDockNavigationState();
}

class _FocusDockNavigationState extends State<_FocusDockNavigation> {
  final ScrollController _controller = ScrollController();

  static const double _itemWidth = 74;
  static const double _itemGap = 4;

  @override
  void didUpdateWidget(covariant _FocusDockNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _centerSelected() {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    final itemExtent = _itemWidth + _itemGap;
    final target =
        (widget.selectedIndex * itemExtent) - (viewport / 2) + (_itemWidth / 2);
    final max = _controller.position.maxScrollExtent;
    _controller.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? FocusPalette.darkCard : FocusPalette.card;
    final border = isDark
        ? FocusPalette.darkBorder.withValues(alpha: 0.92)
        : FocusPalette.border.withValues(alpha: 0.9);
    final shadow = isDark ? Colors.black : FocusPalette.ink;
    final items = const [
      _DockItem(
        label: 'Inicio',
        kind: FocusAppIconKind.focus,
        fallback: Icons.dashboard_rounded,
      ),
      _DockItem(
        label: 'Focus',
        kind: FocusAppIconKind.pomodoro,
        fallback: Icons.timer_rounded,
      ),
      _DockItem(
        label: 'Materias',
        kind: FocusAppIconKind.subjects,
        fallback: Icons.menu_book_rounded,
      ),
      _DockItem(
        label: 'Hábitos',
        kind: FocusAppIconKind.habits,
        fallback: Icons.check_circle_rounded,
      ),
      _DockItem(
        label: 'Exámenes',
        kind: FocusAppIconKind.exams,
        fallback: Icons.assignment_rounded,
      ),
      _DockItem(
        label: 'Tareas',
        kind: FocusAppIconKind.tasks,
        fallback: Icons.task_alt_rounded,
      ),
      _DockItem(
        label: 'Poli',
        kind: FocusAppIconKind.polytechnic,
        fallback: Icons.school_rounded,
      ),
      _DockItem(
        label: 'Recursos',
        kind: FocusAppIconKind.resources,
        fallback: Icons.folder_rounded,
      ),
      _DockItem(
        label: 'Ranking',
        kind: FocusAppIconKind.ranking,
        fallback: Icons.emoji_events_rounded,
      ),
      _DockItem(
        label: 'Perfil',
        kind: FocusAppIconKind.friends,
        fallback: Icons.people_alt_rounded,
      ),
      _DockItem(
        label: 'Logros',
        kind: FocusAppIconKind.achievements,
        fallback: Icons.military_tech_rounded,
      ),
      _DockItem(
        label: 'Ajustes',
        kind: FocusAppIconKind.settings,
        fallback: Icons.settings_rounded,
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: shadow.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: isDark ? 26 : 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                SizedBox(
                  width: _itemWidth,
                  child: _DockButton(
                    item: items[index],
                    selected: widget.selectedIndex == index,
                    onTap: () => widget.onDestinationSelected(index),
                  ),
                ),
                if (index != items.length - 1) const SizedBox(width: _itemGap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem {
  final String label;
  final FocusAppIconKind? kind;
  final IconData fallback;

  const _DockItem({
    required this.label,
    this.kind,
    required this.fallback,
  });
}

class _DockButton extends StatelessWidget {
  final _DockItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DockButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = selected
        ? theme.colorScheme.primary
        : (isDark ? const Color(0xFF94A3B8) : FocusPalette.muted);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
                  .withValues(alpha: isDark ? 0.18 : 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                    .withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.kind != null)
              FocusAppIcon(
                kind: item.kind!,
                size: selected ? 27 : 23,
                fallback: item.fallback,
                fallbackColor: accent,
              )
            else
              Icon(item.fallback, color: accent, size: selected ? 27 : 23),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _OldNavigationPlaceholder extends StatelessWidget {
  const _OldNavigationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      destinations: const [
        NavigationDestination(
          icon: FocusAppIcon(
            kind: FocusAppIconKind.focus,
            size: 24,
            fallback: Icons.dashboard_outlined,
          ),
          selectedIcon: FocusAppIcon(
            kind: FocusAppIconKind.focus,
            size: 28,
            fallback: Icons.dashboard_rounded,
          ),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: FocusAppIcon(
            kind: FocusAppIconKind.pomodoro,
            size: 24,
            fallback: Icons.timer_outlined,
          ),
          selectedIcon: FocusAppIcon(
            kind: FocusAppIconKind.pomodoro,
            size: 28,
            fallback: Icons.timer_rounded,
          ),
          label: 'Pomodoro',
        ),
        NavigationDestination(
          icon: FocusAppIcon(
            kind: FocusAppIconKind.subjects,
            size: 24,
            fallback: Icons.menu_book_outlined,
          ),
          selectedIcon: FocusAppIcon(
            kind: FocusAppIconKind.subjects,
            size: 28,
            fallback: Icons.menu_book_rounded,
          ),
          label: 'Materias',
        ),
        NavigationDestination(
          icon: FocusAppIcon(
            kind: FocusAppIconKind.habits,
            size: 24,
            fallback: Icons.check_circle_outline_rounded,
          ),
          selectedIcon: FocusAppIcon(
            kind: FocusAppIconKind.habits,
            size: 28,
            fallback: Icons.check_circle_rounded,
          ),
          label: 'Hábitos',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Ajustes',
        ),
      ],
    );
  }
}
