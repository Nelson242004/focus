import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'database/database_helper.dart';
import 'models/app_settings.dart';
import 'providers/app_provider.dart';
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
                        requireAccount: true,
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
  bool _finishing = false;
  final String _selectedStartScreen = 'dashboard';
  late final PageController _controller;

  static const _pages = [
    (
      title: 'Organiza tu día',
      text: 'Clases, exámenes y tareas en un solo lugar.',
      label: 'Dashboard',
      asset: 'assets/profile_icons/focus_champion_female.png',
      colors: [Color(0xFF2563EB), Color(0xFF14B8A6), Color(0xFFF59E0B)],
    ),
    (
      title: 'Entra en enfoque',
      text: 'Pomodoro y descansos para estudiar sin ruido.',
      label: '25:00',
      asset: 'assets/profile_icons/focus_champion_female.png',
      colors: [Color(0xFF2563EB), Color(0xFF0EA5E9), Color(0xFF10B981)],
    ),
    (
      title: 'Mira tu progreso',
      text: 'Puntos, rachas, logros y ranking semanal.',
      label: 'Top 20',
      asset: 'assets/profile_icons/focus_champion_female.png',
      colors: [Color(0xFF2563EB), Color(0xFF14B8A6), Color(0xFFF59E0B)],
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

  Future<void> _finishOnboarding() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final provider = Provider.of<AppProvider>(context, listen: false);
    unawaited(provider.updateStartScreen(_selectedStartScreen));
    unawaited(widget.onComplete());
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) {
      setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : FocusPalette.ink;
    final mutedColor = isDark ? const Color(0xFFB6C2D2) : FocusPalette.muted;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC),
              Color.lerp(
                isDark ? const Color(0xFF030712) : const Color(0xFFFFFFFF),
                page.colors[1],
                isDark ? 0.16 : 0.10,
              )!,
              Color.lerp(
                isDark ? const Color(0xFF020617) : const Color(0xFFF6F8FC),
                page.colors[2],
                isDark ? 0.14 : 0.08,
              )!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset('assets/icon.png', width: 32, height: 32),
                    const SizedBox(width: 10),
                    Text(
                      'Focus',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _finishing ? null : _finishOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: mutedColor,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Saltar'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      return _SimpleOnboardingSlide(
                        title: item.title,
                        text: item.text,
                        label: item.label,
                        asset: item.asset,
                        accent: item.colors.first,
                        textColor: textColor,
                        mutedColor: mutedColor,
                        key: ValueKey(index),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ...List.generate(_pages.length, (index) {
                      final selected = index == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 8),
                        width: selected ? 34 : 9,
                        height: 9,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: selected
                              ? page.colors.first
                              : mutedColor.withValues(alpha: 0.28),
                        ),
                      );
                    }),
                    const Spacer(),
                    Text(
                      '${_page + 1}/${_pages.length}',
                      style: TextStyle(
                        color: mutedColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _finishing
                        ? null
                        : () async {
                            if (_page == _pages.length - 1) {
                              await _finishOnboarding();
                            } else {
                              await _controller.nextPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: page.colors.first,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _finishing
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              key: ValueKey(_page),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _page == _pages.length - 1
                                      ? 'Ir al inicio de sesión'
                                      : 'Continuar',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                    ),
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

class _SimpleOnboardingSlide extends StatelessWidget {
  final String title;
  final String text;
  final String label;
  final String asset;
  final Color accent;
  final Color textColor;
  final Color mutedColor;

  const _SimpleOnboardingSlide({
    super.key,
    required this.title,
    required this.text,
    required this.label,
    required this.asset,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.white.withValues(alpha: 0.78),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : FocusPalette.border.withValues(alpha: 0.72),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accent.withValues(alpha: 0.10),
                    border: Border.all(color: accent.withValues(alpha: 0.20)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 210,
                  child: Image.asset(asset, fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
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

// ignore: unused_element
class _OnboardingPremiumHero extends StatelessWidget {
  final String asset;
  final List<Color> colors;
  final List<String> rows;
  final String stat;
  final String statValue;
  final bool compact;
  final Animation<double> animation;
  final int page;

  const _OnboardingPremiumHero({
    required this.asset,
    required this.colors,
    required this.rows,
    required this.stat,
    required this.statValue,
    required this.compact,
    required this.animation,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final heroSize = (height * 0.62).clamp(168.0, compact ? 230.0 : 290.0);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value * math.pi * 2;
            final drift = math.sin(t);
            final slowDrift = math.cos(t * 0.72);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: compact ? 6 : 10,
                  bottom: compact ? 4 : 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Color.lerp(const Color(0xFF07111F),
                                    colors.first, 0.28)!,
                                Color.lerp(
                                    const Color(0xFF0B1726), colors[1], 0.26)!,
                                Color.lerp(
                                    const Color(0xFF101827), colors[2], 0.16)!,
                              ]
                            : [
                                Color.lerp(Colors.white, colors.first, 0.22)!,
                                Color.lerp(Colors.white, colors[1], 0.28)!,
                                Color.lerp(
                                    const Color(0xFFF8FAFC), colors[2], 0.18)!,
                              ],
                        begin: Alignment(-0.85 + drift * 0.08, -1),
                        end: Alignment(0.9 + slowDrift * 0.06, 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first
                              .withValues(alpha: isDark ? 0.22 : 0.14),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: isDark ? 0.08 : 0.72),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  top: compact ? 6 : 10,
                  bottom: compact ? 4 : 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: CustomPaint(
                      painter: _OnboardingImmersivePatternPainter(
                        color: Colors.white.withValues(alpha: 0.18),
                        progress: animation.value,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18 + slowDrift * 4,
                  top: (compact ? 24 : 32) + drift * 3,
                  child: _OnboardingGlassStat(
                    label: stat,
                    value: statValue,
                  ),
                ),
                Positioned(
                  left: (compact ? 10 : 22) + drift * 5,
                  bottom: (compact ? 4 : 10) + slowDrift * 7,
                  child: Image.asset(
                    asset,
                    width: heroSize * 1.03,
                    height: heroSize * 1.03,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  right: (compact ? 12 : 20) + slowDrift * 5,
                  bottom: (compact ? 18 : 28) - drift * 5,
                  child: _OnboardingMiniMockup(
                    rows: rows,
                    color: colors.first,
                    page: page,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ignore: unused_element
class _OnboardingChoicePanel extends StatelessWidget {
  final String selectedStartScreen;
  final String selectedGoal;
  final ValueChanged<String> onStartScreenChanged;
  final ValueChanged<String> onGoalChanged;

  const _OnboardingChoicePanel({
    required this.selectedStartScreen,
    required this.selectedGoal,
    required this.onStartScreenChanged,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white.withValues(alpha: 0.72),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : FocusPalette.border.withValues(alpha: 0.70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Empieza por',
            style: TextStyle(
              color: isDark ? Colors.white : FocusPalette.ink,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OnboardingChoiceChip(
                label: 'Dashboard',
                selected: selectedStartScreen == 'dashboard',
                onTap: () => onStartScreenChanged('dashboard'),
              ),
              _OnboardingChoiceChip(
                label: 'Pomodoro',
                selected: selectedStartScreen == 'pomodoro',
                onTap: () => onStartScreenChanged('pomodoro'),
              ),
              _OnboardingChoiceChip(
                label: 'Materias',
                selected: selectedStartScreen == 'subjects',
                onTap: () => onStartScreenChanged('subjects'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OnboardingChoiceChip(
                label: 'Meta semanal',
                selected: selectedGoal == 'weekly',
                onTap: () => onGoalChanged('weekly'),
              ),
              _OnboardingChoiceChip(
                label: 'Racha',
                selected: selectedGoal == 'streak',
                onTap: () => onGoalChanged('streak'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OnboardingChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? FocusPalette.primary : FocusPalette.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? FocusPalette.primary.withValues(alpha: 0.12)
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.48),
          border: Border.all(
            color: selected
                ? FocusPalette.primary.withValues(alpha: 0.36)
                : Theme.of(context).dividerColor.withValues(alpha: 0.36),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _OnboardingTextPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String text;
  final Color accent;
  final Color textColor;
  final Color mutedColor;
  final bool compact;

  const _OnboardingTextPanel({
    required this.eyebrow,
    required this.title,
    required this.text,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(18, compact ? 16 : 18, 18, compact ? 16 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white.withValues(alpha: 0.76),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : FocusPalette.border.withValues(alpha: 0.70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.left,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  fontSize: compact ? 28 : 34,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: mutedColor,
                  fontSize: compact ? 14 : 15,
                  height: 1.42,
                ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingGlassStat extends StatelessWidget {
  final String label;
  final String value;

  const _OnboardingGlassStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark ? Colors.white : FocusPalette.ink;
    final labelColor = isDark ? Colors.white70 : FocusPalette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.82),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingMiniMockup extends StatelessWidget {
  final List<String> rows;
  final Color color;
  final int page;

  const _OnboardingMiniMockup({
    required this.rows,
    required this.color,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.94),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 6,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const Spacer(),
              Icon(
                page == 1
                    ? Icons.timer_rounded
                    : page == 2
                        ? Icons.emoji_events_rounded
                        : Icons.dashboard_rounded,
                color: color,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                      bottom: entry.key == rows.length - 1 ? 0 : 8),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          entry.key == 0
                              ? Icons.school_rounded
                              : entry.key == 1
                                  ? Icons.timer_rounded
                                  : Icons.check_rounded,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: FocusPalette.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _OnboardingImmersivePatternPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _OnboardingImmersivePatternPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final phase = progress * math.pi * 2;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.16 + i * 0.12);
      final wave = math.sin(phase + i * 0.6) * size.width * 0.025;
      canvas.drawLine(
        Offset(size.width * 0.08 + wave, y),
        Offset(size.width * 0.92 + wave, y + size.height * 0.075),
        paint,
      );
    }
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < 22; i++) {
      final column = i % 7;
      final row = i ~/ 7;
      final x =
          size.width * (0.07 + column * 0.145 + math.sin(phase + i) * 0.006);
      final y =
          size.height * (0.10 + row * 0.25 + math.cos(phase * 0.8 + i) * 0.008);
      canvas.drawCircle(Offset(x, y), 1.9 + (i % 3) * 0.35, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingImmersivePatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
