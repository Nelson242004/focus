import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_help_button.dart';
import '../widgets/focus_main_navigation_scope.dart';
import 'achievements_screen.dart';
import 'dashboard_screen.dart';
import 'exams_screen.dart';
import 'friends_screen.dart';
import 'global_ranking_screen.dart';
import 'habits_screen.dart';
import 'pomodoro_screen.dart';
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
          'polytechnic' => 0,
          'resources' => 6,
          'ranking' => 7,
          'friends' => 8,
          'achievements' => 9,
          'settings' => 10,
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
          _MainAppBarAction(
            index: _selectedIndex,
            openSettings: () => _selectTab(10),
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

class _MainAppBarAction extends StatelessWidget {
  final int index;
  final VoidCallback openSettings;

  const _MainAppBarAction({
    required this.index,
    required this.openSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (index == 0) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: 'Configuración',
          child: IconButton(
            icon: const FocusAppIcon(
              kind: FocusAppIconKind.settings,
              size: 30,
              fallback: Icons.settings_rounded,
            ),
            onPressed: openSettings,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _helpForIndex(index),
    );
  }

  Widget _helpForIndex(int index) {
    return switch (index) {
      1 => const FocusHelpAction(
          title: 'Ayuda de Pomodoro',
          message: 'Lo esencial para usar Pomodoro y sumar puntos sin dudas.',
          sections: [
            FocusHelpSection(
              title: 'Sesiones',
              items: [
                'Elige una materia si quieres asociar la sesión a tu progreso.',
                'Enfoque usa el temporizador principal; descanso corto y largo no suman puntos.',
                'Al terminar una sesión de enfoque, Focus guarda el Pomodoro en tu historial.',
              ],
            ),
            FocusHelpSection(
              title: 'Puntos',
              items: [
                'Cada bloque válido de 25 minutos suma 20 puntos.',
                'Una sesión de 50 minutos cuenta como 2 bloques válidos.',
                'El extra de Enfoque Total suma 5 puntos si terminaste sin distracciones.',
                'Solo cuentan hasta 6 bloques de Pomodoro por día para el ranking.',
                'Los descansos no restan puntos y los bloques ya ganados tampoco se pierden.',
              ],
            ),
            FocusHelpSection(
              title: 'Enfoque Total',
              items: [
                'Activa el bloqueo antes de empezar si quieres proteger la sesión.',
                'Las apps seleccionadas se bloquean mientras el Pomodoro está activo.',
                'Si algo falla, revisa permisos desde Configuración.',
              ],
            ),
          ],
        ),
      2 => const FocusHelpAction(
          title: 'Ayuda de Materias',
          message: 'Aquí organizas materias, aulas, profesores y horario.',
          sections: [
            FocusHelpSection(
              title: 'Qué se guarda',
              items: [
                'Cada materia puede tener color, aula, profesor, sección y bloques de horario.',
                'El horario semanal se arma con los bloques cargados de lunes a sábado.',
                'El dashboard usa tus materias para mostrar la próxima clase.',
              ],
            ),
            FocusHelpSection(
              title: 'Uso rápido',
              items: [
                'El botón inferior derecho es la acción principal para agregar.',
                'PDF y PNG exportan el horario para compartirlo o guardarlo.',
                'El desplegable de detalles deja la lista limpia cuando tienes muchas materias.',
              ],
            ),
          ],
        ),
      3 => const FocusHelpAction(
          title: 'Ayuda de Hábitos',
          message:
              'Hábitos sirve para crear repeticiones pequeñas y sostenibles.',
          sections: [
            FocusHelpSection(
              title: 'Cómo cuentan',
              items: [
                'Marcar un hábito completa el día actual y actualiza tu racha.',
                'Cada hábito válido puede sumar 12 puntos al ranking.',
                'Solo cuentan hasta 3 hábitos por día para evitar abuso.',
                'Un hábito recién creado debe tener 24 horas para sumar puntos de ranking.',
                'Si ya marcaste el mismo hábito hoy, no vuelve a sumar puntos.',
              ],
            ),
            FocusHelpSection(
              title: 'Recomendación',
              items: [
                'Usa pocos hábitos claros, tipo leer 10 minutos o repasar apuntes.',
                'La pantalla prioriza constancia, racha y hábitos de hoy.',
              ],
            ),
          ],
        ),
      4 => const FocusHelpAction(
          title: 'Ayuda de Exámenes',
          message:
              'Carga evaluaciones para que Focus te avise y priorice lo próximo.',
          sections: [
            FocusHelpSection(
              title: 'Datos',
              items: [
                'Materia y fecha son lo principal; hora y aula pueden completarse después.',
                'Focus evita duplicados del mismo tipo para una materia en la misma fecha.',
                'Los exámenes próximos aparecen en Dashboard, Calendario y Widget.',
              ],
            ),
            FocusHelpSection(
              title: 'Recordatorios',
              items: [
                'Las notificaciones dependen de lo que tengas activado en Configuración.',
                'Un examen de mañana debe mostrarse como Mañana, no como Hoy.',
                'Edita o elimina el examen si cambia la planificación.',
              ],
            ),
          ],
        ),
      5 => const FocusHelpAction(
          title: 'Ayuda de Tareas',
          message: 'Tareas es para pendientes concretos de estudio.',
          sections: [
            FocusHelpSection(
              title: 'Cómo organizar',
              items: [
                'Activas muestra lo pendiente; Hoy prioriza vencimientos del día.',
                'Vencidas te muestra lo que necesita atención inmediata.',
                'Puedes vincular una tarea a una materia, pero no es obligatorio.',
                'La prioridad sirve para ordenar sin llenar la pantalla de texto.',
              ],
            ),
          ],
        ),
      6 => const FocusHelpAction(
          title: 'Ayuda de Recursos',
          message:
              'Recursos guarda enlaces útiles sin competir con tus herramientas principales.',
          sections: [
            FocusHelpSection(
              title: 'Qué guardar',
              items: [
                'Guarda cursos, playlists, documentos, herramientas o enlaces por materia.',
                'Usa filtros y búsqueda para llegar rápido sin una lista interminable.',
                'Mantén solo recursos útiles para que la sección siga simple.',
              ],
            ),
          ],
        ),
      7 => const FocusHelpAction(
          title: 'Ayuda de Ranking',
          message: 'El ranking muestra el top 20 semanal con puntos válidos.',
          sections: [
            FocusHelpSection(
              title: 'Qué aparece',
              items: [
                'Se muestran hasta 20 usuarios para que cargue rápido y gaste menos lecturas.',
                'Tu fila se destaca si estás dentro del top visible.',
                'El ranking se refresca al entrar y luego cada hora mientras estás en la pantalla.',
                'El reinicio semanal ocurre el domingo.',
              ],
            ),
            FocusHelpSection(
              title: 'Puntos y ligas',
              items: [
                'Pomodoros válidos, hábitos válidos y logros pueden sumar puntos.',
                'Cada bloque Pomodoro de 25 minutos suma 20 puntos; máximo 6 bloques por día.',
                'Cada hábito válido suma 12 puntos; máximo 3 hábitos por día.',
                'Oro es el top 10%, Plata llega hasta el top 35% y Bronce es el resto.',
                'Focus limita acciones repetidas para mantener el ranking justo.',
              ],
            ),
          ],
        ),
      8 => const FocusHelpAction(
          title: 'Ayuda de Perfil y Amigos',
          message: 'Tu perfil social controla cómo apareces en Focus.',
          sections: [
            FocusHelpSection(
              title: 'Perfil público',
              items: [
                'Otros usuarios pueden ver tu nombre, carrera, personaje, liga y puntos públicos.',
                'El personaje elegido se usa en perfil, ranking, amigos y estados vacíos compatibles.',
                'Las imágenes PNG propias son locales; para que otros las vean hace falta subirlas a la nube.',
              ],
            ),
            FocusHelpSection(
              title: 'Solicitudes',
              items: [
                'Busca por código, nombre, correo o carrera.',
                'Enviar solicitud no agrega al usuario hasta que acepte.',
                'Mis amigos reemplaza Mi círculo y concentra amigos, enviados y recibidos.',
              ],
            ),
          ],
        ),
      9 => const FocusHelpAction(
          title: 'Ayuda de Logros',
          message: 'Logros resume insignias, nivel y progreso conseguido.',
          sections: [
            FocusHelpSection(
              title: 'Cómo se desbloquean',
              items: [
                'Hay insignias por primer Pomodoro, primer hábito, rachas y metas semanales.',
                'Los logros suman puntos una sola vez cuando se desbloquean.',
                'Los niveles van del 1 al 5 y suben con tus puntos totales.',
                'La misión semanal se basa en Pomodoros completados durante la semana.',
              ],
            ),
          ],
        ),
      10 => const FocusHelpAction(
          title: 'Ayuda de Configuración',
          message:
              'Configuración concentra cuenta, apariencia, Pomodoro, permisos y backup.',
          sections: [
            FocusHelpSection(
              title: 'Secciones',
              items: [
                'Cuenta maneja sesión, nombre y datos sociales.',
                'Apariencia cambia tema, color, animaciones y escala de texto.',
                'Pomodoro ajusta tiempos, sonido y bloqueo.',
                'Notificaciones y Permisos se activan cuando realmente los necesitas.',
                'Backup y Avanzado quedan separados para no saturar el uso diario.',
              ],
            ),
          ],
        ),
      _ => const FocusHelpAction(
          title: 'Ayuda de Focus',
          message: 'Aquí encontrarás información de esta pantalla.',
          sections: [
            FocusHelpSection(
              title: 'Uso',
              items: [
                'Revisa las acciones principales y mantén la app simple.'
              ],
            ),
          ],
        ),
    };
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
    if (widget.selectedIndex >= _dockItems.length) return;
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
              for (var index = 0; index < _dockItems.length; index++) ...[
                SizedBox(
                  width: _itemWidth,
                  child: _DockButton(
                    item: _dockItems[index],
                    selected: widget.selectedIndex == index,
                    onTap: () => widget.onDestinationSelected(index),
                  ),
                ),
                if (index != _dockItems.length - 1)
                  const SizedBox(width: _itemGap),
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

const _dockItems = [
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
];

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
