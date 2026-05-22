import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ranking_profile.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/profile_icon_access.dart';
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
