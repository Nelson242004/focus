import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ranking_profile.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';
import '../utils/profile_icon_access.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_drawer.dart';
import '../widgets/focus_help_button.dart';
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
        actions: [
          switch (_selectedIndex) {
            1 => const _PomodoroHelpAction(),
            2 => const _SubjectsHelpAction(),
            3 => const _HabitsHelpAction(),
            4 => const _SettingsHelpAction(),
            _ => const _ProfileAppBarButton(),
          },
        ],
      ),
      drawer: FocusDrawer(selectedMainIndex: _selectedIndex),
      body: SafeArea(
        top: false,
        bottom: true,
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
      bottomNavigationBar: _FocusDockNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedIndex = index;
        }),
      ),
    );
  }
}

class _FocusDockNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _FocusDockNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark
        ? Color.lerp(FocusPalette.darkCard, FocusPalette.darkSurface, 0.32)!
        : theme.colorScheme.surface.withValues(alpha: 0.96);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : FocusPalette.border.withValues(alpha: 0.75);
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
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _DockButton(
                  item: items[index],
                  selected: selectedIndex == index,
                  onTap: () => onDestinationSelected(index),
                ),
              ),
          ],
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

class _SubjectsHelpAction extends StatelessWidget {
  const _SubjectsHelpAction();

  @override
  Widget build(BuildContext context) {
    return const FocusHelpAction(
      title: 'Ayuda de materias',
      message:
          'Aquí organizas tus clases y dejas lista la base para horarios, exámenes y tareas.',
      sections: [
        FocusHelpSection(
          title: 'Qué guardar',
          items: [
            'Con el nombre ya puedes crear una materia.',
            'Aula, profesor, sección y color son opcionales y sirven para ordenar mejor.',
            'Puedes agregar el horario al crearla o hacerlo después.',
          ],
        ),
        FocusHelpSection(
          title: 'Consejos',
          items: [
            'Mantener pocas materias bien cargadas hace que el dashboard y el calendario se vean más claros.',
            'Si eliminas una materia, sus horarios se borran y exámenes, tareas y recursos quedan sin vínculo.',
          ],
        ),
      ],
    );
  }
}

class _HabitsHelpAction extends StatelessWidget {
  const _HabitsHelpAction();

  @override
  Widget build(BuildContext context) {
    return const FocusHelpAction(
      title: 'Ayuda de hábitos',
      message:
          'La idea aquí es repetir pocas acciones claras para construir constancia sin sobrecargarte.',
      sections: [
        FocusHelpSection(
          title: 'Cómo usarlo',
          items: [
            'Puedes tener hasta 8 hábitos activos.',
            'Cada hábito se marca una vez por día para proteger rachas y puntos.',
            'La identidad asociada sirve para que el hábito tenga una razón más clara.',
          ],
        ),
        FocusHelpSection(
          title: 'Ranking',
          items: [
            'Los hábitos también pueden sumar puntos al ranking global con límites diarios y reglas anti abuso.',
            'Crea hábitos desde el bloque de la propia pantalla para no cargar la barra superior.',
          ],
        ),
      ],
    );
  }
}

class _PomodoroHelpAction extends StatelessWidget {
  const _PomodoroHelpAction();

  @override
  Widget build(BuildContext context) {
    return const FocusHelpAction(
      title: 'Ayuda de Pomodoro',
      message:
          'Usa Pomodoro para trabajar en bloques cortos, registrar puntos y proteger tu enfoque.',
      sections: [
        FocusHelpSection(
          title: 'Cómo usarlo',
          items: [
            'Elige una materia si quieres asociar la sesión a una clase.',
            'Pulsa iniciar para comenzar el bloque y pausa solo si necesitas cortar el ritmo.',
            'Los descansos sirven para recuperar energía antes del siguiente bloque.',
          ],
        ),
        FocusHelpSection(
          title: 'Puntos y ranking',
          items: [
            'Los puntos se otorgan al completar bloques de enfoque válidos.',
            'Hay límites diarios para evitar puntos inflados.',
            'Si no iniciaste sesión, el temporizador funciona igual, pero el ranking no se sincroniza.',
          ],
        ),
        FocusHelpSection(
          title: 'Configuración',
          items: [
            'Puedes ajustar duración, sonido y descanso automático desde la tarjeta de configuración.',
            'El bloqueo de apps ayuda a reducir distracciones durante el enfoque.',
            'El modo horizontal deja una vista más limpia para usar el celular como temporizador.',
          ],
        ),
      ],
    );
  }
}

class _SettingsHelpAction extends StatelessWidget {
  const _SettingsHelpAction();

  @override
  Widget build(BuildContext context) {
    return const FocusHelpAction(
      title: 'Ayuda de configuración',
      message:
          'Aquí ajustas la app, tu cuenta y tus copias de seguridad. La ayuda concentra lo secundario para que la pantalla siga limpia.',
      sections: [
        FocusHelpSection(
          title: 'Lo principal',
          items: [
            'Apariencia cambia tema, color, texto y animaciones.',
            'Notificaciones controla recordatorios y pruebas.',
            'Backup exporta o restaura tus datos del dispositivo.',
          ],
        ),
        FocusHelpSection(
          title: 'Importante',
          items: [
            'Guardar aplica los cambios manuales de esta pantalla.',
            'Borrar datos elimina la informacion local y no se puede deshacer.',
          ],
        ),
      ],
    );
  }
}

class _ProfileAppBarButton extends StatelessWidget {
  const _ProfileAppBarButton();

  @override
  Widget build(BuildContext context) {
    if (RankingService.currentUser == null) {
      return _ProfileIconButton(
          asset: defaultProfileIconAsset, onTap: () => _openProfile(context));
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
    return profileIconAssetFromIndex(
      profile?.stats['socialMascotIndex'],
      email: RankingService.currentUser?.email,
      enforceAccess: true,
    );
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
