import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'database/database_helper.dart';
import 'models/app_settings.dart';
import 'providers/app_provider.dart';
import 'screens/app_tutorial_screen.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/required_permissions_screen.dart';
import 'screens/web_focus_screen.dart';
import 'services/notification_service.dart';
import 'services/ranking_service.dart';
import 'utils/app_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  await Firebase.initializeApp();
  if (!kIsWeb) {
    await RankingService.initializeGoogleSignIn();
  }
  await DatabaseHelper.instance.database;
  await NotificationService.initialize();
  runApp(const MyApp());
}

ThemeMode _convertThemeMode(ThemeModeSetting setting) {
  switch (setting) {
    case ThemeModeSetting.dark:
      return ThemeMode.dark;
    case ThemeModeSetting.light:
      return ThemeMode.light;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..loadAllData(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final resolvedThemeMode =
              _convertThemeMode(provider.settings.themeMode);
          final accent = colorFromHex(
            provider.settings.accentColor,
            fallback: const Color(0xFF1D4ED8),
          );
          final animationDuration = provider.settings.animationsEnabled
              ? const Duration(milliseconds: 280)
              : Duration.zero;

          final lightTheme = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accent,
              brightness: Brightness.light,
              primary: accent,
              secondary: const Color(0xFF0F766E),
              tertiary: const Color(0xFFF97316),
              surface: const Color(0xFFF8FAFC),
            ),
            scaffoldBackgroundColor: const Color(0xFFF6F8FC),
            canvasColor: const Color(0xFFF6F8FC),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFF0F172A),
              titleTextStyle: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            drawerTheme:
                const DrawerThemeData(backgroundColor: Colors.transparent),
            cardTheme: CardThemeData(
              elevation: 2,
              shadowColor: const Color(0x120F172A),
              surfaceTintColor: Colors.transparent,
              color: Colors.white,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFFCFDFF),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD6E0EC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: accent, width: 1.4),
              ),
              labelStyle: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFD6E0EC)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFFE8EEF6),
              selectedColor: accent.withValues(alpha: 0.16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: BorderSide.none,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              contentTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            dividerColor: const Color(0xFFD6E0EC),
            iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
            listTileTheme: const ListTileThemeData(
              iconColor: Color(0xFF334155),
              textColor: Color(0xFF0F172A),
            ),
            segmentedButtonTheme: SegmentedButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : const Color(0xFF334155),
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? accent
                      : Colors.white,
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: Color(0xFFD6E0EC)),
                ),
              ),
            ),
            textTheme: ThemeData.light(useMaterial3: true)
                .textTheme
                .copyWith(
                  bodyLarge:
                      const TextStyle(color: Color(0xFF0F172A), height: 1.35),
                  bodyMedium:
                      const TextStyle(color: Color(0xFF1E293B), height: 1.35),
                  bodySmall:
                      const TextStyle(color: Color(0xFF64748B), height: 1.3),
                  titleLarge: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                  titleMedium: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                  labelLarge: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                )
                .apply(
                  bodyColor: const Color(0xFF0F172A),
                  displayColor: const Color(0xFF0F172A),
                ),
          );

          final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: accent,
              brightness: Brightness.dark,
              primary: accent,
              secondary: const Color(0xFF22C55E),
              tertiary: const Color(0xFFF59E0B),
              surface: Colors.black,
            ),
            scaffoldBackgroundColor: Colors.black,
            canvasColor: Colors.black,
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            drawerTheme:
                const DrawerThemeData(backgroundColor: Colors.transparent),
            cardTheme: CardThemeData(
              color: const Color(0xFF050505),
              elevation: 0,
              margin: EdgeInsets.zero,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF050505),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF090909),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF1F1F1F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: accent, width: 1.4),
              ),
              labelStyle: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w600,
              ),
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF222222)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFF0B0B0B),
              selectedColor: accent.withValues(alpha: 0.18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: Color(0xFF181818)),
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.white),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF111111),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              contentTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            dividerColor: const Color(0xFF1A1A1A),
            iconTheme: const IconThemeData(color: Colors.white),
            listTileTheme: const ListTileThemeData(
              iconColor: Color(0xFFE2E8F0),
              textColor: Colors.white,
            ),
            segmentedButtonTheme: SegmentedButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : const Color(0xFFE2E8F0),
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? accent
                      : const Color(0xFF050505),
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
            textTheme: ThemeData.dark(useMaterial3: true)
                .textTheme
                .copyWith(
                  bodyLarge: const TextStyle(color: Colors.white, height: 1.35),
                  bodyMedium:
                      const TextStyle(color: Color(0xFFE2E8F0), height: 1.35),
                  bodySmall:
                      const TextStyle(color: Color(0xFF94A3B8), height: 1.3),
                  titleLarge: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  titleMedium: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  labelLarge: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w700,
                  ),
                )
                .apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
          );

          return MaterialApp(
            title: 'Focus',
            debugShowCheckedModeBanner: false,
            themeMode: resolvedThemeMode,
            theme: lightTheme,
            darkTheme: darkTheme,
            builder: (context, child) {
              final scaledChild = MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(provider.settings.textScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
              if (!provider.settings.animationsEnabled) return scaledChild;
              return AnimatedSwitcher(
                duration: animationDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: scaledChild,
              );
            },
            home: !provider.isLoaded
                ? const _BootSplash()
                : provider.settings.onboardingCompleted
                    ? AuthGateScreen(
                        child: kIsWeb
                            ? const WebFocusScreen()
                            : const RequiredPermissionsGate(),
                      )
                    : OnboardingScreen(
                        onComplete: () => provider.completeOnboarding(),
                      ),
          );
        },
      ),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  late final PageController _controller;

  static const _pages = [
    (
      icon: Icons.auto_awesome_rounded,
      title: 'Tu semestre en piloto automático',
      text:
          'Focus junta horario, exámenes, hábitos, pomodoro y recursos para que estudies con menos caos y más claridad.',
      highlights: ['Horario', 'Exámenes', 'Pomodoro'],
      colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
    ),
    (
      icon: Icons.calendar_month_rounded,
      title: 'Mira qué viene antes de que te alcance',
      text:
          'Ten clases, parciales, finales y recordatorios en un mismo lugar. Ideal para no depender de capturas sueltas.',
      highlights: ['Calendario', 'Recordatorios', 'Agenda'],
      colors: [Color(0xFF0F766E), Color(0xFF10B981)],
    ),
    (
      icon: Icons.school_rounded,
      title: 'Si eres de Politécnica, empieza más rápido',
      text:
          'Carga el Excel oficial, elige carrera, materias y secciones. Focus arma horarios, aulas, profesores y exámenes cuando estén disponibles.',
      highlights: ['Excel', 'Calculadora', 'Secciones'],
      colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    ),
    (
      icon: Icons.ios_share_rounded,
      title: 'Comparte tu horario como imagen',
      text:
          'Exporta PDF para imprimir o comparte una imagen bonita de tu horario por WhatsApp e Instagram.',
      highlights: ['Imagen', 'PDF', 'Backup'],
      colors: [Color(0xFFF97316), Color(0xFFFACC15)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 760 || size.width < 380;
    final pageMinHeight = isCompact ? size.height * 0.34 : size.height * 0.45;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              page.colors.first.withValues(alpha: 0.12),
              Theme.of(context).scaffoldBackgroundColor,
              page.colors.last.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 18 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: page.colors.first.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        'Focus beta',
                        style: TextStyle(
                          color: page.colors.first,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async => widget.onComplete(),
                      child: const Text('Saltar'),
                    ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: pageMinHeight,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: isCompact ? 18 : 30),
                                Container(
                                  width: isCompact ? 76 : 92,
                                  height: isCompact ? 76 : 92,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        isCompact ? 24 : 28),
                                    gradient:
                                        LinearGradient(colors: item.colors),
                                    boxShadow: [
                                      BoxShadow(
                                        color: item.colors.first
                                            .withValues(alpha: 0.28),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: Colors.white,
                                    size: isCompact ? 34 : 42,
                                  ),
                                ),
                                SizedBox(height: isCompact ? 20 : 28),
                                Text(
                                  item.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontSize: isCompact ? 25 : null,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.text,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                          fontSize: isCompact ? 15 : null),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: item.highlights
                                      .map(
                                        (highlight) => _OnboardingPill(
                                          label: highlight,
                                          color: item.colors.first,
                                        ),
                                      )
                                      .toList(),
                                ),
                                SizedBox(height: isCompact ? 16 : 30),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: List.generate(_pages.length, (index) {
                    final selected = index == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      width: selected ? 30 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                if (_page == _pages.length - 1) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AppTutorialScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_lesson_rounded),
                      label: const Text('Ver tutorial'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: isCompact ? VisualDensity.compact : null,
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (_page == _pages.length - 1) {
                        await widget.onComplete();
                      } else {
                        await _controller.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      visualDensity: isCompact ? VisualDensity.compact : null,
                    ),
                    child: Text(
                        _page == _pages.length - 1 ? 'Empezar' : 'Continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPill extends StatelessWidget {
  final String label;
  final Color color;

  const _OnboardingPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
