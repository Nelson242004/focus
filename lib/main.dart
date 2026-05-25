import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'database/database_helper.dart';
import 'models/app_settings.dart';
import 'providers/app_provider.dart';
import 'screens/app_tutorial_screen.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/web_focus_screen.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/ranking_service.dart';
import 'utils/app_utils.dart';
import 'utils/focus_palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
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

Locale? _localeForLanguage(AppLanguage language) {
  return switch (language) {
    AppLanguage.system => null,
    AppLanguage.spanish => const Locale('es'),
    AppLanguage.english => const Locale('en'),
    AppLanguage.portuguese => const Locale('pt'),
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
            fallback: FocusPalette.primaryDeep,
          );

          final lightTheme = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accent,
              brightness: Brightness.light,
              primary: accent,
              secondary: FocusPalette.teal,
              tertiary: FocusPalette.amber,
              surface: FocusPalette.surfaceTop,
            ),
            scaffoldBackgroundColor: FocusPalette.surfaceTop,
            canvasColor: FocusPalette.surfaceTop,
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: FocusPalette.surfaceTop,
              foregroundColor: FocusPalette.ink,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(
                color: FocusPalette.ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            drawerTheme:
                const DrawerThemeData(backgroundColor: Colors.transparent),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: FocusPalette.card,
              surfaceTintColor: Colors.transparent,
              showDragHandle: true,
              dragHandleColor: FocusPalette.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shadowColor: Color(0x120F172A),
              surfaceTintColor: Colors.transparent,
              color: Colors.white,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFFCFDFF),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: FocusPalette.border),
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
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: FocusPalette.ink,
                side: BorderSide(color: FocusPalette.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: FocusPalette.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                highlightColor: accent.withValues(alpha: 0.10),
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              elevation: 8,
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : FocusPalette.muted,
              ),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent.withValues(alpha: 0.48)
                    : FocusPalette.border,
              ),
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: accent,
              linearTrackColor: FocusPalette.border.withValues(alpha: 0.55),
              circularTrackColor: FocusPalette.border.withValues(alpha: 0.55),
            ),
            popupMenuTheme: PopupMenuThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                color: FocusPalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            expansionTileTheme: ExpansionTileThemeData(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              iconColor: accent,
              collapsedIconColor: FocusPalette.muted,
              textColor: FocusPalette.ink,
              collapsedTextColor: FocusPalette.ink,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: accent.withValues(alpha: 0.09),
              selectedColor: accent.withValues(alpha: 0.16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              side: BorderSide(color: accent.withValues(alpha: 0.12)),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.1,
                color: accent,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: FocusPalette.ink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              contentTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            dividerColor: FocusPalette.border,
            iconTheme: const IconThemeData(color: FocusPalette.ink),
            listTileTheme: const ListTileThemeData(
              iconColor: Color(0xFF334155),
              textColor: FocusPalette.ink,
            ),
            segmentedButtonTheme: SegmentedButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : FocusPalette.ink2,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? accent
                      : Colors.white,
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: FocusPalette.border),
                ),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              elevation: 0,
              backgroundColor: Colors.white.withValues(alpha: 0.96),
              indicatorColor: accent.withValues(alpha: 0.14),
              labelTextStyle: const WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? accent
                      : FocusPalette.muted,
                ),
              ),
            ),
            textTheme: ThemeData.light(useMaterial3: true)
                .textTheme
                .copyWith(
                  bodyLarge:
                      const TextStyle(color: FocusPalette.ink, height: 1.35),
                  bodyMedium:
                      const TextStyle(color: FocusPalette.ink2, height: 1.35),
                  bodySmall:
                      const TextStyle(color: FocusPalette.muted, height: 1.3),
                  titleLarge: const TextStyle(
                    color: FocusPalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
                  titleMedium: const TextStyle(
                    color: FocusPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  labelLarge: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                )
                .apply(
                  bodyColor: FocusPalette.ink,
                  displayColor: FocusPalette.ink,
                ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _FocusPageTransitionsBuilder(),
                TargetPlatform.iOS: _FocusPageTransitionsBuilder(),
                TargetPlatform.macOS: _FocusPageTransitionsBuilder(),
                TargetPlatform.windows: _FocusPageTransitionsBuilder(),
                TargetPlatform.linux: _FocusPageTransitionsBuilder(),
              },
            ),
          );

          final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: accent,
              brightness: Brightness.dark,
              primary: accent,
              secondary: FocusPalette.mint,
              tertiary: FocusPalette.amber,
              onSurface: const Color(0xFFF8FAFC),
              onSurfaceVariant: const Color(0xFF94A3B8),
              surface: FocusPalette.darkSurfaceTop,
              surfaceContainerLowest: FocusPalette.darkSurface,
              surfaceContainerLow: FocusPalette.darkCard,
              surfaceContainer: FocusPalette.darkCard,
              surfaceContainerHigh: FocusPalette.darkCard2,
              surfaceContainerHighest: FocusPalette.darkCard2,
              outline: FocusPalette.darkBorder,
              outlineVariant: const Color(0xFF151C26),
            ),
            scaffoldBackgroundColor: FocusPalette.darkSurfaceTop,
            canvasColor: FocusPalette.darkSurfaceTop,
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: FocusPalette.darkSurfaceTop,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            drawerTheme:
                const DrawerThemeData(backgroundColor: Colors.transparent),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: FocusPalette.darkCard,
              surfaceTintColor: Colors.transparent,
              showDragHandle: true,
              dragHandleColor: Color(0xFF334155),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
            cardTheme: CardThemeData(
              color: FocusPalette.darkCard,
              elevation: 0,
              margin: EdgeInsets.zero,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: FocusPalette.darkCard,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: FocusPalette.darkCard2.withValues(alpha: 0.72),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: FocusPalette.darkBorder.withValues(alpha: 0.88),
                ),
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
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF8FAFC),
                side: BorderSide(
                  color: FocusPalette.darkBorder.withValues(alpha: 0.95),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                highlightColor: accent.withValues(alpha: 0.16),
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              elevation: 2,
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : const Color(0xFF94A3B8),
              ),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent.withValues(alpha: 0.48)
                    : FocusPalette.darkBorder,
              ),
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: accent,
              linearTrackColor: FocusPalette.darkBorder.withValues(alpha: 0.62),
              circularTrackColor:
                  FocusPalette.darkBorder.withValues(alpha: 0.62),
            ),
            popupMenuTheme: PopupMenuThemeData(
              color: FocusPalette.darkCard,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            expansionTileTheme: ExpansionTileThemeData(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              iconColor: accent,
              collapsedIconColor: const Color(0xFF94A3B8),
              textColor: Colors.white,
              collapsedTextColor: Colors.white,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: accent.withValues(alpha: 0.10),
              selectedColor: accent.withValues(alpha: 0.18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              side: BorderSide(color: accent.withValues(alpha: 0.18)),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.1,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: FocusPalette.darkCard2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              contentTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            dividerColor: FocusPalette.darkBorder,
            iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
            listTileTheme: const ListTileThemeData(
              iconColor: Color(0xFFE2E8F0),
              textColor: Color(0xFFF8FAFC),
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
                      : FocusPalette.darkCard2.withValues(alpha: 0.55),
                ),
                side: WidgetStatePropertyAll(
                  BorderSide(
                    color: FocusPalette.darkBorder.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              elevation: 0,
              backgroundColor: Colors.black,
              indicatorColor: accent.withValues(alpha: 0.22),
              labelTextStyle: const WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? accent
                      : const Color(0xFF94A3B8),
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
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _FocusPageTransitionsBuilder(),
                TargetPlatform.iOS: _FocusPageTransitionsBuilder(),
                TargetPlatform.macOS: _FocusPageTransitionsBuilder(),
                TargetPlatform.windows: _FocusPageTransitionsBuilder(),
                TargetPlatform.linux: _FocusPageTransitionsBuilder(),
              },
            ),
          );

          return MaterialApp(
            navigatorKey: MyApp.navigatorKey,
            title: 'Focus',
            debugShowCheckedModeBanner: false,
            themeMode: resolvedThemeMode,
            locale: _localeForLanguage(provider.settings.language),
            supportedLocales: const [
              Locale('es'),
              Locale('en'),
              Locale('pt'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: lightTheme,
            darkTheme: darkTheme,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final overlayStyle = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: isDark
                    ? FocusPalette.darkSurfaceTop
                    : FocusPalette.surfaceTop,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
              );

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: _DeepLinkListener(
                  navigatorKey: MyApp.navigatorKey,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler:
                          TextScaler.linear(provider.settings.textScale),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
            home: !provider.isLoaded
                ? const _BootSplash()
                : provider.settings.onboardingCompleted
                    ? AuthGateScreen(
                        requireAccount: false,
                        child: kIsWeb
                            ? const WebFocusScreen()
                            : const MainNavigationScreen(),
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

class _DeepLinkListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const _DeepLinkListener({
    required this.navigatorKey,
    required this.child,
  });

  @override
  State<_DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<_DeepLinkListener>
    with WidgetsBindingObserver {
  String? _lastHandledCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleInitialLink());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleLatestLink();
    }
  }

  Future<void> _handleInitialLink() async {
    final link = await DeepLinkService.initialLink();
    _openLink(link);
  }

  Future<void> _handleLatestLink() async {
    final link = await DeepLinkService.consumeLatestLink();
    _openLink(link);
  }

  void _openLink(FocusDeepLink? link) {
    if (!mounted || link == null) return;
    if (_lastHandledCode == link.friendCode) return;
    _lastHandledCode = link.friendCode;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => FriendsScreen(initialFriendCode: link.friendCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _FocusPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FocusPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.035, 0.018),
          end: Offset.zero,
        ).animate(curved),
        child: child,
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
      title: 'Tu semestre más claro',
      text: 'Organiza materias, exámenes y hábitos sin llenar la app de ruido.',
      highlights: ['Materias', 'Exámenes', 'Hábitos'],
      colors: [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
    ),
    (
      icon: Icons.timer_rounded,
      title: 'Entra en modo enfoque',
      text:
          'Usa Pomodoro y Modo Enfoque Total para proteger tus bloques de estudio.',
      highlights: ['Pomodoro', 'Bloqueo', 'Racha'],
      colors: [Color(0xFF0F766E), Color(0xFF10B981)],
    ),
    (
      icon: Icons.emoji_events_rounded,
      title: 'Haz visible tu progreso',
      text: 'Suma puntos, cuida tu racha y compite con amigos cuando quieras.',
      highlights: ['Puntos', 'Ranking', 'Perfil'],
      colors: [FocusPalette.teal, FocusPalette.mint],
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
