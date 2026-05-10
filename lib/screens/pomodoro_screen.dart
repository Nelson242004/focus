import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_mode_config.dart';
import '../models/focus_mode_status.dart';
import '../models/focus_shield_app.dart';
import '../models/app_settings.dart';
import '../models/pomodoro.dart';
import '../models/subject.dart';
import '../providers/app_provider.dart';
import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../services/widget_sync_service.dart';
import 'focus_mode_setup_screen.dart';
import '../utils/app_utils.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with WidgetsBindingObserver {
  static const _remainingKey = 'pomodoro_remaining';
  static const _modeKey = 'pomodoro_mode';
  static const _subjectKey = 'pomodoro_subject';
  static const _runningKey = 'pomodoro_running';
  static const _savedAtKey = 'pomodoro_saved_at';
  static const _endAtKey = 'pomodoro_end_at';
  static const _cycleCountKey = 'pomodoro_cycle_count';
  static const _horizontalThemeKey = 'pomodoro_horizontal_theme';
  static const _maxAutoRecoveryDuration = Duration(hours: 8);

  Timer? _timer;
  int _remainingSeconds = 25 * 60;
  String _mode = 'focus';
  bool _isRunning = false;
  bool _isLoading = true;
  bool _isHorizontalFocusMode = false;
  bool _isCompletingSession = false;
  bool _isDisposed = false;
  String _selectedSubject = '';
  int _completedFocusSessions = 0;
  int _horizontalThemeIndex = 0;
  final ValueNotifier<int> _horizontalRefresh = ValueNotifier<int>(0);
  late final AudioPlayer _audioPlayer;
  FocusModeConfig _focusModeConfig = const FocusModeConfig();
  FocusModeStatus _focusModeStatus = const FocusModeStatus();
  bool _focusModePermissionGranted = false;
  bool _loadingFocusMode = true;
  Timer? _focusModeStatusTimer;
  int _lastHandledBlockedAtMillis = 0;
  bool _showingDistractionPrompt = false;
  _FocusSessionSummary? _lastFocusSummary;

  Future<void> _updatePomodoroSettings({
    int? focusTime,
    int? shortBreakTime,
    int? longBreakTime,
    String? sound,
    String? breakAfterFocus,
  }) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final previousTotal = _totalSecondsForMode(provider);
    final newSettings = AppSettings(
      themeMode: provider.settings.themeMode,
      focusTime: focusTime ?? provider.settings.focusTime,
      shortBreakTime: shortBreakTime ?? provider.settings.shortBreakTime,
      longBreakTime: longBreakTime ?? provider.settings.longBreakTime,
      weeklyGoal: provider.settings.weeklyGoal,
      sound: sound ?? provider.settings.sound,
      selectedIdentity: provider.settings.selectedIdentity,
      startScreen: provider.settings.startScreen,
      textScale: provider.settings.textScale,
      animationsEnabled: provider.settings.animationsEnabled,
      accentColor: provider.settings.accentColor,
      notificationsEnabled: provider.settings.notificationsEnabled,
      onboardingCompleted: provider.settings.onboardingCompleted,
      breakAfterFocus: breakAfterFocus ?? provider.settings.breakAfterFocus,
    );
    await provider.updateSettings(newSettings, syncNotifications: false);
    if (!mounted) return;
    setState(() {
      if (!_isRunning || _remainingSeconds == previousTotal) {
        _setRemainingFromMode();
      } else {
        _remainingSeconds =
            _remainingSeconds.clamp(0, _totalSecondsForMode(provider));
      }
    });
    if (_isRunning) {
      unawaited(_showPomodoroNotification(provider));
    }
    await _persistState();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _restoreState();
    await _loadFocusModeConfig();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadFocusModeConfig() async {
    final config = await FocusModeService.loadConfig();
    final permissionGranted = await _refreshFocusModePermissionState();
    final status = await FocusModeService.getStatus();
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() {
      _focusModeConfig = config.copyWith(protectionLevel: 'strict');
      _focusModePermissionGranted = permissionGranted;
      _focusModeStatus = status;
      _loadingFocusMode = false;
    });
    _lastHandledBlockedAtMillis = status.lastBlockedAtMillis;
    if (_isRunning &&
        _mode == 'focus' &&
        config.enabled &&
        config.blockedApps.isNotEmpty &&
        permissionGranted &&
        !status.active) {
      unawaited(_syncFocusModeShield(provider));
    }
    if (status.active || (_isRunning && _mode == 'focus')) {
      _startFocusModeStatusPolling();
    }
  }

  Future<bool> _refreshFocusModePermissionState() async {
    final granted = await FocusModeService.hasCorePermissions();
    if (!mounted) {
      _focusModePermissionGranted = granted;
      return granted;
    }
    setState(() => _focusModePermissionGranted = granted);
    return granted;
  }

  int _totalSecondsForMode(AppProvider provider, [String? mode]) {
    int safeMinutesToSeconds(int minutes) =>
        (minutes * 60).clamp(1, 24 * 60 * 60).toInt();

    switch (mode ?? _mode) {
      case 'shortBreak':
        return safeMinutesToSeconds(provider.settings.shortBreakTime);
      case 'longBreak':
        return safeMinutesToSeconds(provider.settings.longBreakTime);
      default:
        return safeMinutesToSeconds(provider.settings.focusTime);
    }
  }

  void _setRemainingFromMode() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _remainingSeconds = _totalSecondsForMode(provider);
  }

  String _activeSubjectName(AppProvider provider) {
    final selected = _selectedSubject.trim();
    if (selected.isEmpty) return 'General';

    final exists = provider.subjects.any(
      (subject) => subject.name.trim().toLowerCase() == selected.toLowerCase(),
    );
    return exists ? selected : 'General';
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    _mode = _normalizeMode(prefs.getString(_modeKey));
    _selectedSubject = prefs.getString(_subjectKey) ?? _selectedSubject;
    if (_activeSubjectName(provider) == 'General') {
      _selectedSubject = '';
    }
    _completedFocusSessions = prefs.getInt(_cycleCountKey) ?? 0;
    _horizontalThemeIndex = (prefs.getInt(_horizontalThemeKey) ?? 0)
        .clamp(0, _horizontalThemes.length - 1)
        .toInt();
    _remainingSeconds =
        prefs.getInt(_remainingKey) ?? _totalSecondsForMode(provider);
    final wasRunning = prefs.getBool(_runningKey) ?? false;
    final endAtMillis = prefs.getInt(_endAtKey);
    if (wasRunning && endAtMillis != null) {
      final now = DateTime.now();
      final endAt = DateTime.fromMillisecondsSinceEpoch(endAtMillis);
      final secondsLeft = endAt.difference(now).inSeconds;
      if (secondsLeft > 0) {
        _remainingSeconds =
            secondsLeft.clamp(1, _totalSecondsForMode(provider));
        _startTimer(restored: true);
      } else {
        await _recoverExpiredTimer(provider, now: now, endedAt: endAt);
      }
      return;
    }

    final savedAt = prefs.getInt(_savedAtKey);
    if (wasRunning && savedAt != null) {
      final savedAtDate = DateTime.fromMillisecondsSinceEpoch(savedAt);
      final savedRemaining = _remainingSeconds;
      final elapsed = DateTime.now().difference(savedAtDate).inSeconds;
      _remainingSeconds = (_remainingSeconds - elapsed)
          .clamp(0, _totalSecondsForMode(provider));
      if (_remainingSeconds > 0) {
        _startTimer(restored: true);
      } else {
        await _recoverExpiredTimer(
          provider,
          now: DateTime.now(),
          endedAt: savedAtDate.add(Duration(seconds: savedRemaining)),
        );
      }
    }
  }

  String _normalizeMode(String? mode) {
    switch (mode) {
      case 'focus':
      case 'shortBreak':
      case 'longBreak':
        return mode!;
      default:
        return 'focus';
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_remainingKey, _remainingSeconds);
    await prefs.setString(_modeKey, _mode);
    await prefs.setString(_subjectKey, _selectedSubject);
    await prefs.setBool(_runningKey, _isRunning);
    await prefs.setInt(_savedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (_isRunning) {
      await prefs.setInt(
        _endAtKey,
        DateTime.now()
            .add(Duration(seconds: _remainingSeconds))
            .millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_endAtKey);
    }
    await prefs.setInt(_cycleCountKey, _completedFocusSessions);
    await prefs.setInt(_horizontalThemeKey, _horizontalThemeIndex);
  }

  void _startTimer({bool restored = false}) {
    if (_isDisposed) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    _timer?.cancel();
    if (_remainingSeconds <= 0) {
      _setRemainingFromMode();
    }
    if (mounted) {
      setState(() => _isRunning = true);
    } else {
      _isRunning = true;
    }
    _refreshHorizontalMode();
    unawaited(_syncFocusModeShield(provider));
    if (!restored) {
      _persistState();
    }
    unawaited(_showPomodoroNotification(provider));
    unawaited(_syncPomodoroWidget(provider));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        if (mounted) {
          setState(() => _remainingSeconds = 0);
        } else {
          _remainingSeconds = 0;
        }
        _refreshHorizontalMode();
        _completeSession();
        return;
      }

      if (mounted) {
        setState(() => _remainingSeconds--);
      } else {
        _remainingSeconds--;
      }
      _refreshHorizontalMode();
      unawaited(_showPomodoroNotification(provider));
      unawaited(_syncPomodoroWidget(provider));
      _persistState();
    });
  }

  Future<void> _syncPomodoroWidget(AppProvider provider) {
    return WidgetSyncService.syncPomodoroState(
      mode: _mode,
      isRunning: _isRunning,
      remainingSeconds: _remainingSeconds,
      totalSeconds: _totalSecondsForMode(provider),
      subject: _activeSubjectName(provider),
      currentStreak: provider.currentStreak,
    );
  }

  Future<void> _showPomodoroNotification(AppProvider provider) async {
    if (!_isRunning || !provider.settings.notificationsEnabled) {
      await NotificationService.cancelPomodoroTimerNotification();
      return;
    }

    final nativeShieldOwnsNotification = _mode == 'focus' &&
        _focusModeConfig.enabled &&
        _focusModePermissionGranted &&
        _focusModeConfig.blockedApps.isNotEmpty;
    if (nativeShieldOwnsNotification) {
      await NotificationService.cancelPomodoroTimerNotification();
      return;
    }

    await NotificationService.showPomodoroTimerNotification(
      mode: _mode,
      remainingSeconds: _remainingSeconds,
      totalSeconds: _totalSecondsForMode(provider),
      subject: _activeSubjectName(provider),
    );
  }

  void _refreshHorizontalMode() {
    if (!_isDisposed && _isHorizontalFocusMode) {
      _horizontalRefresh.value++;
    }
  }

  void _pauseTimer() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _timer?.cancel();
    unawaited(NotificationService.cancelPomodoroTimerNotification());
    if (mounted) {
      setState(() => _isRunning = false);
    } else {
      _isRunning = false;
    }
    _refreshHorizontalMode();
    unawaited(_stopFocusModeShield());
    unawaited(WidgetSyncService.syncFromProvider(provider));
    _persistState();
  }

  void _resetTimer() {
    _pauseTimer();
    if (mounted) {
      setState(_setRemainingFromMode);
    } else {
      _setRemainingFromMode();
    }
    _refreshHorizontalMode();
    _persistState();
  }

  void _changeMode(String newMode) {
    _timer?.cancel();
    unawaited(NotificationService.cancelPomodoroTimerNotification());
    setState(() {
      _mode = newMode;
      _isRunning = false;
      _setRemainingFromMode();
    });
    _refreshHorizontalMode();
    unawaited(_stopFocusModeShield());
    unawaited(WidgetSyncService.syncFromProvider(
        Provider.of<AppProvider>(context, listen: false)));
    _persistState();
  }

  String _nextBreakMode(AppProvider provider) {
    switch (provider.settings.breakAfterFocus) {
      case 'shortBreak':
        return 'shortBreak';
      case 'longBreak':
        return 'longBreak';
      default:
        return _completedFocusSessions % 4 == 0 ? 'longBreak' : 'shortBreak';
    }
  }

  Future<void> _recoverExpiredTimer(
    AppProvider provider, {
    required DateTime now,
    required DateTime endedAt,
  }) async {
    final overrun = now.difference(endedAt);
    if (overrun > _maxAutoRecoveryDuration) {
      await _completePhaseSilently(provider, completedAt: endedAt);
      _timer?.cancel();
      _isRunning = false;
      _setRemainingFromMode();
      await NotificationService.cancelPomodoroTimerNotification();
      await _persistState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El Pomodoro quedó abierto mucho tiempo. Guardamos lo seguro y pausamos el ciclo.',
            ),
          ),
        );
      }
      return;
    }

    await _completePhaseSilently(provider, completedAt: endedAt);
    var consumedSeconds = overrun.inSeconds;
    var guard = 0;
    var phaseStart = endedAt;

    while (guard < 24) {
      final currentTotal = _totalSecondsForMode(provider);
      if (consumedSeconds < currentTotal) break;
      phaseStart = phaseStart.add(Duration(seconds: currentTotal));
      consumedSeconds -= currentTotal;
      await _completePhaseSilently(provider, completedAt: phaseStart);
      guard++;
    }

    final currentTotal = _totalSecondsForMode(provider);
    _remainingSeconds = (currentTotal - consumedSeconds).clamp(1, currentTotal);
    _startTimer(restored: true);
    await _persistState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restauramos tu Pomodoro según el tiempo real pasado.'),
        ),
      );
    }
  }

  Future<void> _completePhaseSilently(
    AppProvider provider, {
    required DateTime completedAt,
  }) async {
    if (_mode == 'focus') {
      final subjectName = _activeSubjectName(provider);
      await provider.addPomodoro(
        Pomodoro(
          date: completedAt.toIso8601String(),
          subject: subjectName,
          duration: provider.settings.focusTime,
        ),
      );
      _completedFocusSessions++;
      _mode = _nextBreakMode(provider);
    } else {
      _mode = 'focus';
    }
    _remainingSeconds = _totalSecondsForMode(provider);
  }

  Future<void> _playBell() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.settings.sound == 'none') return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer
          .setAsset('assets/sounds/${provider.settings.sound}.mp3');
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (_) {}
  }

  Future<void> _completeSession() async {
    if (_isCompletingSession) return;
    _isCompletingSession = true;
    try {
      _timer?.cancel();
      if (mounted) {
        setState(() => _isRunning = false);
      } else {
        _isRunning = false;
      }
      _refreshHorizontalMode();
      final provider = Provider.of<AppProvider>(context, listen: false);
      await _playBell();

      if (_mode == 'focus') {
        final summary = _buildFocusSessionSummary(provider);
        await _stopFocusModeShield();
        final subjectName = _activeSubjectName(provider);
        await provider.addPomodoro(
          Pomodoro(
            date: DateTime.now().toIso8601String(),
            subject: subjectName,
            duration: provider.settings.focusTime,
          ),
        );
        _completedFocusSessions++;
        final nextMode = _nextBreakMode(provider);
        if (mounted) {
          setState(() {
            _mode = nextMode;
            _setRemainingFromMode();
          });
        } else {
          _mode = nextMode;
          _setRemainingFromMode();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Enfoque completado. Empieza ${nextMode == 'longBreak' ? 'el descanso largo' : 'el descanso corto'}.',
              ),
            ),
          );
          unawaited(_showFocusSummary(summary));
        }
        _lastFocusSummary = summary;
      } else {
        await _stopFocusModeShield();
        if (mounted) {
          setState(() {
            _mode = 'focus';
            _setRemainingFromMode();
          });
        } else {
          _mode = 'focus';
          _setRemainingFromMode();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Descanso completado. Volvemos al enfoque.'),
            ),
          );
        }
      }

      _refreshHorizontalMode();
      _startTimer();
      await _persistState();
    } finally {
      _isCompletingSession = false;
    }
  }

  Future<void> _syncFocusModeShield(AppProvider provider) async {
    if (!_isRunning || _mode != 'focus') {
      await _stopFocusModeShield();
      return;
    }
    if (!_focusModeConfig.enabled || _focusModeConfig.blockedApps.isEmpty) {
      return;
    }
    final permissionGranted = await _refreshFocusModePermissionState();
    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Activa Accesibilidad, superposición y acceso de uso.',
            ),
          ),
        );
      }
      return;
    }

    try {
      await NotificationService.cancelPomodoroTimerNotification();
      final started = await FocusModeService.startFocusSession(
        subject: _activeSubjectName(provider),
        durationSeconds: _remainingSeconds,
        blockedApps: _focusModeConfig.blockedApps,
      );
      if (!started) {
        _focusModeStatusTimer?.cancel();
        _focusModeStatusTimer = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Modo Enfoque Total no pudo iniciarse. El Pomodoro seguirá funcionando normal.',
              ),
            ),
          );
        }
        return;
      }
      _startFocusModeStatusPolling();
      await _refreshFocusModeStatus();
    } catch (_) {
      _focusModeStatusTimer?.cancel();
      _focusModeStatusTimer = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El bloqueo de distracciones falló al arrancar. La sesión de Pomodoro sigue activa.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopFocusModeShield() async {
    _focusModeStatusTimer?.cancel();
    _focusModeStatusTimer = null;
    await FocusModeService.stopFocusSession();
    if (!mounted) return;
    setState(() {
      _focusModeStatus = const FocusModeStatus();
    });
  }

  void _startFocusModeStatusPolling() {
    _focusModeStatusTimer?.cancel();
    _focusModeStatusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshFocusModeStatus(),
    );
  }

  Future<void> _refreshFocusModeStatus() async {
    final status = await FocusModeService.getStatus();
    if (!mounted) return;
    setState(() => _focusModeStatus = status);
    if (status.lastBlockedAtMillis > _lastHandledBlockedAtMillis) {
      _lastHandledBlockedAtMillis = status.lastBlockedAtMillis;
      unawaited(_handleBlockedAttempt(status));
    }
    if (!status.active) {
      _focusModeStatusTimer?.cancel();
      _focusModeStatusTimer = null;
    }
  }

  Future<void> _toggleFocusModeEnabled(bool value) async {
    final newConfig =
        _focusModeConfig.copyWith(enabled: value, protectionLevel: 'strict');
    await FocusModeService.saveConfig(newConfig);
    if (!mounted) return;
    setState(() => _focusModeConfig = newConfig);
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!value) {
      await _stopFocusModeShield();
      await NotificationService.cancelPomodoroTimerNotification();
      if (_isRunning) {
        unawaited(_showPomodoroNotification(provider));
      }
      return;
    }
    await _refreshFocusModePermissionState();
    if (_isRunning && _mode == 'focus') {
      await _syncFocusModeShield(provider);
      unawaited(_showPomodoroNotification(provider));
    }
  }

  Future<void> _handleBlockedAttempt(FocusModeStatus status) async {
    if (!mounted || !_isRunning || _mode != 'focus') {
      return;
    }

    final appName = status.lastBlockedApp.trim();
    if (appName.isEmpty || _showingDistractionPrompt) return;

    _showingDistractionPrompt = true;
    try {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Bloqueo activo: $appName'),
            duration: const Duration(seconds: 2),
          ),
        );
    } finally {
      _showingDistractionPrompt = false;
    }
  }

  _FocusSessionSummary _buildFocusSessionSummary(AppProvider provider) {
    final distractionFree = _focusModeStatus.blockedAttempts == 0;
    final earnedPoints = 10 + (distractionFree ? 5 : 0);
    return _FocusSessionSummary(
      subject: _activeSubjectName(provider),
      blockedAppsCount: _focusModeConfig.blockedApps.length,
      blockedAttempts: _focusModeStatus.blockedAttempts,
      earnedPoints: earnedPoints,
      distractionFree: distractionFree,
    );
  }

  Future<void> _showFocusSummary(_FocusSessionSummary summary) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: _FocusSummarySheet(summary: summary),
        ),
      ),
    );
  }

  Future<void> _openFocusModeSetup() async {
    if (!mounted) return;
    final selectedApps = await Navigator.of(context).push<List<FocusShieldApp>>(
      MaterialPageRoute(
        builder: (_) => FocusModeSetupScreen(
          initiallySelected: _focusModeConfig.blockedApps,
        ),
      ),
    );
    if (selectedApps == null) return;
    final newConfig = _focusModeConfig.copyWith(blockedApps: selectedApps);
    await FocusModeService.saveConfig(newConfig);
    if (!mounted) return;
    setState(() => _focusModeConfig = newConfig);
  }

  Future<void> _toggleHorizontalFocusMode() async {
    if (_isHorizontalFocusMode) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }

    setState(() => _isHorizontalFocusMode = true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;

    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (routeContext, _, __) {
          return ValueListenableBuilder<int>(
            valueListenable: _horizontalRefresh,
            builder: (_, __, ___) {
              final provider = Provider.of<AppProvider>(context, listen: false);
              final horizontalTheme = _horizontalThemes[_horizontalThemeIndex];
              return _buildCinematicHorizontalTimer(
                horizontalTheme,
                _totalSecondsForMode(provider),
                onExit: () => Navigator.of(routeContext).maybePop(),
              );
            },
          );
        },
      ),
    );

    if (!mounted) return;
    setState(() => _isHorizontalFocusMode = false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _setHorizontalTheme(int index) {
    setState(() => _horizontalThemeIndex = index);
    _horizontalRefresh.value++;
    _persistState();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildCinematicHorizontalTimer(
    _HorizontalTheme horizontalTheme,
    int totalSeconds, {
    required VoidCallback onExit,
  }) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress =
        totalSeconds == 0 ? 0.0 : 1 - (_remainingSeconds / totalSeconds);
    final modeLabel = _mode == 'focus'
        ? 'Enfoque'
        : _mode == 'shortBreak'
            ? 'Descanso'
            : 'Descanso largo';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.15,
                  colors: [
                    horizontalTheme.glow.withValues(alpha: 0.16),
                    horizontalTheme.backgroundEnd,
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 74, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Salir',
                        onPressed: onExit,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          modeLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: horizontalTheme.textColor
                                .withValues(alpha: 0.58),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final numberSize =
                            (constraints.maxHeight * 0.74).clamp(112.0, 265.0);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _TimePanel(
                                    value: minutes.toString().padLeft(2, '0'),
                                    topLabel: '',
                                    numberSize: numberSize,
                                    theme: horizontalTheme,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _TimePanel(
                                    value: seconds.toString().padLeft(2, '0'),
                                    topLabel: '',
                                    numberSize: numberSize,
                                    theme: horizontalTheme,
                                  ),
                                ),
                              ],
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    height: 2,
                                    color: Colors.black.withValues(alpha: 0.42),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: progress.clamp(0, 1),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(horizontalTheme.glow),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 58,
            bottom: 58,
            child: _HorizontalToolRail(
              theme: horizontalTheme,
              isRunning: _isRunning,
              onTheme: () => _setHorizontalTheme(
                (_horizontalThemeIndex + 1) % _horizontalThemes.length,
              ),
              onToggle: _isRunning ? _pauseTimer : () => _startTimer(),
              onReset: _resetTimer,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistState();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_refreshFocusModeStatus());
      unawaited(_loadFocusModeConfig());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _persistState();
    if (!_isRunning) {
      unawaited(NotificationService.cancelPomodoroTimerNotification());
    }
    _timer?.cancel();
    _focusModeStatusTimer?.cancel();
    if (!_isRunning || _mode != 'focus') {
      unawaited(FocusModeService.stopFocusSession());
    }
    _horizontalRefresh.dispose();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final subjects = provider.subjects;
    final totalSeconds = _totalSecondsForMode(provider);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePalette = _themePalette();
    final progress =
        totalSeconds == 0 ? 0.0 : 1 - (_remainingSeconds / totalSeconds);
    final compact = MediaQuery.of(context).size.width < 390;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            if (isDark) ...[
              const Color(0xFF000000),
              const Color(0xFF020617),
              const Color(0xFF000000),
            ] else ...[
              themePalette.backgroundStart,
              themePalette.backgroundMiddle,
              themePalette.backgroundEnd,
            ],
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _glassCard(
              context,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              themePalette.accent,
                              themePalette.accentSecondary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  themePalette.accent.withValues(alpha: 0.28),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _mode == 'focus'
                              ? Icons.school_rounded
                              : Icons.spa_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mode == 'focus'
                                  ? 'Concentrarse ahora'
                                  : _mode == 'shortBreak'
                                      ? 'Descanso breve'
                                      : 'Descanso largo',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _mode == 'focus'
                                  ? 'Activa tu pomodoro y entra en tu bloque de enfoque sin distracciones.'
                                  : 'Recupera energía mientras Focus prepara el siguiente bloque.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ModePill(
                        label: 'Enfoque',
                        selected: _mode == 'focus',
                        color: const Color(0xFF2563EB),
                        onTap: () => _changeMode('focus'),
                      ),
                      _ModePill(
                        label: 'Descanso',
                        selected: _mode == 'shortBreak',
                        color: const Color(0xFF10B981),
                        onTap: () => _changeMode('shortBreak'),
                      ),
                      _ModePill(
                        label: 'Largo',
                        selected: _mode == 'longBreak',
                        color: const Color(0xFFF59E0B),
                        onTap: () => _changeMode('longBreak'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _glassCard(
              context,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: compact ? 238 : 278,
                    height: compact ? 238 : 278,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  themePalette.accent.withValues(alpha: 0.22),
                                  themePalette.accent,
                                  themePalette.accentSecondary,
                                  themePalette.accent.withValues(alpha: 0.22),
                                ],
                                stops: const [0.0, 0.38, 0.78, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 14,
                            strokeCap: StrokeCap.round,
                            backgroundColor:
                                themePalette.accent.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              themePalette.accent,
                            ),
                          ),
                        ),
                        Container(
                          width: compact ? 186 : 220,
                          height: compact ? 186 : 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.35, -0.45),
                              radius: 1.05,
                              colors: isDark
                                  ? [
                                      themePalette.accent
                                          .withValues(alpha: 0.22),
                                      const Color(0xFF111827),
                                      const Color(0xFF020617),
                                    ]
                                  : [
                                      Theme.of(context).cardColor,
                                      themePalette.surfaceTint,
                                    ],
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    themePalette.accent.withValues(alpha: 0.18),
                                blurRadius: 32,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(progress * 100).clamp(0, 100).round()}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: themePalette.accent,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  _formatTime(_remainingSeconds),
                                  key: ValueKey(_remainingSeconds),
                                  style: TextStyle(
                                    fontSize: compact ? 42 : 52,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                    color: isDark ? Colors.white : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _mode == 'focus'
                                    ? 'Tiempo restante'
                                    : 'Cuenta regresiva',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.66)
                                          : null,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_mode == 'focus') ...[
                    if (subjects.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _subjectSelector(provider, subjects),
                    ],
                    if (!_isRunning && _lastFocusSummary != null) ...[
                      const SizedBox(height: 14),
                      _LastFocusSummaryBanner(summary: _lastFocusSummary!),
                    ],
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: themePalette.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                      onPressed: _isRunning ? _pauseTimer : () => _startTimer(),
                      icon: Icon(
                        _isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        _isRunning
                            ? 'Pausar sesión'
                            : _mode == 'focus'
                                ? 'Iniciar sesión de enfoque'
                                : 'Empezar descanso',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        onPressed: _resetTimer,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reiniciar'),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        onPressed: _toggleHorizontalFocusMode,
                        icon: const Icon(Icons.stay_current_landscape_rounded),
                        label: const Text('Modo horizontal'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _expandableGlassCard(
              context,
              title: 'Modo Enfoque Total',
              subtitle: 'Activa el bloqueo y elige tus apps.',
              children: [
                _buildFocusModeTotalCard(provider),
              ],
            ),
            const SizedBox(height: 14),
            _expandableGlassCard(
              context,
              title: 'Configurar Pomodoro',
              subtitle:
                  'Ajusta tiempos, sonido y descanso sin salir del temporizador.',
              children: [
                _TimerSlider(
                  label: 'Enfoque',
                  value: provider.settings.focusTime,
                  min: 5,
                  max: 90,
                  color: const Color(0xFF2563EB),
                  onChanged: (value) =>
                      _updatePomodoroSettings(focusTime: value),
                ),
                _TimerSlider(
                  label: 'Descanso corto',
                  value: provider.settings.shortBreakTime,
                  min: 1,
                  max: 30,
                  color: const Color(0xFF10B981),
                  onChanged: (value) =>
                      _updatePomodoroSettings(shortBreakTime: value),
                ),
                _TimerSlider(
                  label: 'Descanso largo',
                  value: provider.settings.longBreakTime,
                  min: 5,
                  max: 60,
                  color: const Color(0xFFF59E0B),
                  onChanged: (value) =>
                      _updatePomodoroSettings(longBreakTime: value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: provider.settings.sound,
                  decoration: const InputDecoration(
                    labelText: 'Sonido al terminar',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'chime', child: Text('Campana')),
                    DropdownMenuItem(value: 'bell', child: Text('Timbre')),
                    DropdownMenuItem(value: 'none', child: Text('Sin sonido')),
                  ],
                  onChanged: (value) =>
                      _updatePomodoroSettings(sound: value ?? 'none'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: provider.settings.breakAfterFocus,
                  decoration: const InputDecoration(
                    labelText: 'Después del enfoque',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'auto',
                      child: Text('Automático cada 4 ciclos'),
                    ),
                    DropdownMenuItem(
                      value: 'shortBreak',
                      child: Text('Siempre descanso corto'),
                    ),
                    DropdownMenuItem(
                      value: 'longBreak',
                      child: Text('Siempre descanso largo'),
                    ),
                  ],
                  onChanged: (value) => _updatePomodoroSettings(
                    breakAfterFocus: value ?? 'auto',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _glassCard(
              context,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sesiones de hoy',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cada enfoque completado se guarda automáticamente para tus estadísticas.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(height: 250, child: _buildTodaySessions(provider)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor.withValues(alpha: 0.94),
            Theme.of(context).cardColor.withValues(alpha: 0.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  Widget _expandableGlassCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return _glassCard(
      context,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('pomodoro-$title'),
          initiallyExpanded: false,
          maintainState: false,
          tilePadding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _subjectSelector(AppProvider provider, List<Subject> subjects) {
    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedSubject),
      initialValue: subjects.any(
        (subject) => subject.name == _selectedSubject,
      )
          ? _selectedSubject
          : '',
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Materia asociada',
        prefixIcon: Icon(Icons.menu_book_rounded),
        helperText: 'Opcional. Se guarda en tus estadísticas del Pomodoro.',
      ),
      items: [
        const DropdownMenuItem(
          value: '',
          child: Text('General'),
        ),
        ...subjects.map(
          (subject) => DropdownMenuItem<String>(
            value: subject.name,
            child: Text(
              subject.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() => _selectedSubject = value ?? '');
        if (_isRunning) {
          unawaited(_showPomodoroNotification(provider));
        }
        _persistState();
      },
    );
  }

  Widget _buildFocusModeTotalCard(AppProvider provider) {
    final blockedApps = _focusModeConfig.blockedApps;
    final isEnabled = _focusModeConfig.enabled;
    final accent = const Color(0xFF7C3AED);
    final appsLabel = blockedApps.isEmpty
        ? 'Sin apps elegidas'
        : '${blockedApps.length} app${blockedApps.length == 1 ? '' : 's'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: accent.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.shield_moon_rounded,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bloqueo total',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: _toggleFocusModeEnabled,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appsLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadingFocusMode ? null : _openFocusModeSetup,
              icon: _loadingFocusMode
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.apps_rounded),
              label: Text(blockedApps.isEmpty ? 'Elegir apps' : 'Editar apps'),
            ),
          ),
        ],
      ),
    );
  }

  _PomodoroPalette _themePalette() {
    switch (_mode) {
      case 'shortBreak':
        return const _PomodoroPalette(
          accent: Color(0xFF10B981),
          accentSecondary: Color(0xFF34D399),
          backgroundStart: Color(0xFFF3FBF7),
          backgroundMiddle: Color(0xFFE7F8EF),
          backgroundEnd: Color(0xFFD9F3E6),
          surfaceTint: Color(0xFFECFDF5),
        );
      case 'longBreak':
        return const _PomodoroPalette(
          accent: Color(0xFFF59E0B),
          accentSecondary: Color(0xFFFB923C),
          backgroundStart: Color(0xFFFFF8EE),
          backgroundMiddle: Color(0xFFFFF1D6),
          backgroundEnd: Color(0xFFFFE5BF),
          surfaceTint: Color(0xFFFFF7ED),
        );
      default:
        return const _PomodoroPalette(
          accent: Color(0xFF2563EB),
          accentSecondary: Color(0xFF4F46E5),
          backgroundStart: Color(0xFFF4F8FF),
          backgroundMiddle: Color(0xFFEAF1FF),
          backgroundEnd: Color(0xFFDDE8FF),
          surfaceTint: Color(0xFFF8FAFF),
        );
    }
  }

  Widget _buildTodaySessions(AppProvider provider) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todaySessions =
        provider.pomodoros.where((p) => p.date.startsWith(today)).toList();
    if (todaySessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.34),
        ),
        child: const Center(
          child: Text('Todavía no hay sesiones registradas hoy.'),
        ),
      );
    }
    return ListView.separated(
      itemCount: todaySessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = todaySessions[index];
        final date = DateTime.parse(session.date);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.22),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF10B981).withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subject,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(formatDateTime(date)),
                  ],
                ),
              ),
              Text(
                '${session.duration} min',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FocusSessionSummary {
  final String subject;
  final int blockedAppsCount;
  final int blockedAttempts;
  final int earnedPoints;
  final bool distractionFree;

  const _FocusSessionSummary({
    required this.subject,
    required this.blockedAppsCount,
    required this.blockedAttempts,
    required this.earnedPoints,
    required this.distractionFree,
  });
}

class _LastFocusSummaryBanner extends StatelessWidget {
  final _FocusSessionSummary summary;

  const _LastFocusSummaryBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    final accent = summary.distractionFree
        ? const Color(0xFF10B981)
        : const Color(0xFF7C3AED);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(
            summary.distractionFree
                ? Icons.verified_rounded
                : Icons.bolt_rounded,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Último bloque: ${summary.earnedPoints} puntos · ${summary.blockedAttempts} interrupciones',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusSummarySheet extends StatelessWidget {
  final _FocusSessionSummary summary;

  const _FocusSummarySheet({required this.summary});

  @override
  Widget build(BuildContext context) {
    final accent = summary.distractionFree
        ? const Color(0xFF10B981)
        : const Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sesión completada',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            summary.subject,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryChip(
                label: 'Apps bloqueadas',
                value: '${summary.blockedAppsCount}',
              ),
              _SummaryChip(
                label: 'Interrupciones',
                value: '${summary.blockedAttempts}',
              ),
              _SummaryChip(
                label: 'Puntos',
                value: '${summary.earnedPoints}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          border: Border.all(
              color: selected ? color : Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? color : null,
          ),
        ),
      ),
    );
  }
}

class _TimePanel extends StatelessWidget {
  final String value;
  final String topLabel;
  final double numberSize;
  final _HorizontalTheme theme;

  const _TimePanel({
    required this.value,
    required this.topLabel,
    required this.numberSize,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(42),
        color: Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: Colors.white.withValues(alpha: 0.045)),
      ),
      child: Stack(
        children: [
          if (topLabel.isNotEmpty)
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Text(
                topLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.52),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.82),
                  fontSize: numberSize,
                  height: 0.86,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -10,
                  shadows: [
                    Shadow(
                      color: theme.glow.withValues(alpha: 0.26),
                      blurRadius: 34,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalToolRail extends StatelessWidget {
  final _HorizontalTheme theme;
  final bool isRunning;
  final VoidCallback onTheme;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  const _HorizontalToolRail({
    required this.theme,
    required this.isRunning,
    required this.onTheme,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RailButton(icon: Icons.tune_rounded, onTap: onTheme, theme: theme),
        const SizedBox(height: 12),
        _RailButton(
          icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: onToggle,
          theme: theme,
        ),
        const SizedBox(height: 12),
        _RailButton(icon: Icons.refresh_rounded, onTap: onReset, theme: theme),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final _HorizontalTheme theme;

  const _RailButton({
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.075),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(
            icon,
            color: theme.textColor.withValues(alpha: 0.78),
            size: 25,
          ),
        ),
      ),
    );
  }
}

class _TimerSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const _TimerSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: color.withValues(alpha: 0.12),
                ),
                child: Text(
                  '$value min',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            activeColor: color,
            label: '$value min',
            onChanged: (newValue) => onChanged(newValue.round()),
          ),
        ],
      ),
    );
  }
}

class _PomodoroPalette {
  final Color accent;
  final Color accentSecondary;
  final Color backgroundStart;
  final Color backgroundMiddle;
  final Color backgroundEnd;
  final Color surfaceTint;

  const _PomodoroPalette({
    required this.accent,
    required this.accentSecondary,
    required this.backgroundStart,
    required this.backgroundMiddle,
    required this.backgroundEnd,
    required this.surfaceTint,
  });
}

const List<_HorizontalTheme> _horizontalThemes = [
  _HorizontalTheme(
    backgroundStart: Color(0xFF000000),
    backgroundEnd: Color(0xFF000000),
    glow: Color(0xFF111827),
    textColor: Colors.white,
  ),
  _HorizontalTheme(
    backgroundStart: Color(0xFF020617),
    backgroundEnd: Color(0xFF050816),
    glow: Color(0xFF2563EB),
    textColor: Colors.white,
  ),
  _HorizontalTheme(
    backgroundStart: Color(0xFF06140E),
    backgroundEnd: Color(0xFF021510),
    glow: Color(0xFF10B981),
    textColor: Color(0xFFE7FFF7),
  ),
  _HorizontalTheme(
    backgroundStart: Color(0xFF1A0C02),
    backgroundEnd: Color(0xFF180B19),
    glow: Color(0xFFF59E0B),
    textColor: Color(0xFFFFF7ED),
  ),
];

class _HorizontalTheme {
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color glow;
  final Color textColor;

  const _HorizontalTheme({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.glow,
    required this.textColor,
  });
}
