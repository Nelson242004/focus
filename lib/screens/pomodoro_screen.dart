import 'dart:async';
import 'dart:math' as math;
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
import '../services/ranking_service.dart';
import '../services/widget_sync_service.dart';
import 'focus_mode_setup_screen.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_feedback.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _remainingKey = 'pomodoro_remaining';
  static const _modeKey = 'pomodoro_mode';
  static const _subjectKey = 'pomodoro_subject';
  static const _runningKey = 'pomodoro_running';
  static const _savedAtKey = 'pomodoro_saved_at';
  static const _endAtKey = 'pomodoro_end_at';
  static const _cycleCountKey = 'pomodoro_cycle_count';
  static const _horizontalThemeKey = 'pomodoro_horizontal_theme';
  static const _horizontalTickMutedKey = 'pomodoro_horizontal_tick_muted';
  static const _maxAutoRecoveryDuration = Duration(hours: 8);
  static const List<_AmbientSoundOption> _ambientSoundOptions = [
    _AmbientSoundOption(
      id: 'none',
      label: 'Sin ambiente',
      description: 'Pomodoro limpio, sin sonido de fondo.',
      icon: Icons.volume_off_rounded,
      color: Color(0xFF64748B),
    ),
    _AmbientSoundOption(
      id: 'rain',
      label: 'Lluvia',
      description:
          'Un fondo fresco y constante para estudiar sin ruido visual.',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF2563EB),
    ),
    _AmbientSoundOption(
      id: 'forest',
      label: 'Bosque',
      description: 'Ambiente natural y suave para sesiones largas.',
      icon: Icons.forest_rounded,
      color: Color(0xFF16A34A),
    ),
    _AmbientSoundOption(
      id: 'cafe',
      label: 'Café',
      description: 'Murmullo cálido para sentir compañía mientras trabajas.',
      icon: Icons.local_cafe_rounded,
      color: Color(0xFFD97706),
    ),
    _AmbientSoundOption(
      id: 'water',
      label: 'Agua',
      description: 'Movimiento tranquilo para bajar tensión y seguir enfocado.',
      icon: Icons.waves_rounded,
      color: Color(0xFF0891B2),
    ),
    _AmbientSoundOption(
      id: 'white_noise',
      label: 'Ruido blanco',
      description: 'Sonido neutro para tapar distracciones del entorno.',
      icon: Icons.graphic_eq_rounded,
      color: Color(0xFF7C3AED),
    ),
  ];
  static const List<_CompletionSoundOption> _completionSoundOptions = [
    _CompletionSoundOption(
      id: 'chime',
      label: 'Campana',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF2563EB),
    ),
    _CompletionSoundOption(
      id: 'bell',
      label: 'Timbre',
      icon: Icons.campaign_rounded,
      color: Color(0xFFF59E0B),
    ),
    _CompletionSoundOption(
      id: 'success',
      label: 'Logro',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFF16A34A),
    ),
    _CompletionSoundOption(
      id: 'soft_bell',
      label: 'Suave',
      icon: Icons.self_improvement_rounded,
      color: Color(0xFF0891B2),
    ),
    _CompletionSoundOption(
      id: 'digital',
      label: 'Digital',
      icon: Icons.memory_rounded,
      color: Color(0xFF7C3AED),
    ),
    _CompletionSoundOption(
      id: 'magic',
      label: 'Mágico',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFDB2777),
    ),
    _CompletionSoundOption(
      id: 'confirm',
      label: 'Confirmar',
      icon: Icons.check_circle_rounded,
      color: Color(0xFF0F766E),
    ),
    _CompletionSoundOption(
      id: 'none',
      label: 'Silencio',
      icon: Icons.volume_off_rounded,
      color: Color(0xFF64748B),
    ),
  ];

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
  bool _horizontalTickMuted = false;
  final ValueNotifier<int> _horizontalRefresh = ValueNotifier<int>(0);
  late final AnimationController _timerAuraController;
  late final AudioPlayer _audioPlayer;
  late final AudioPlayer _ambientPlayer;
  late final AudioPlayer _ambientPreviewPlayer;
  late final AudioPlayer _horizontalTickPlayer;
  String? _loadedAmbientSound;
  String? _previewingAmbientSound;
  Timer? _ambientPreviewTimer;
  FocusModeConfig _focusModeConfig = const FocusModeConfig();
  FocusModeStatus _focusModeStatus = const FocusModeStatus();
  bool _focusModePermissionGranted = false;
  bool _loadingFocusMode = true;
  Timer? _focusModeStatusTimer;
  int _lastHandledBlockedAtMillis = 0;
  int? _lastWidgetSyncBucket;
  String? _lastPomodoroNotificationSignature;
  bool _showingDistractionPrompt = false;
  bool _focusPermissionWarningShown = false;
  bool _isTogglingFocusMode = false;
  VoidCallback? _refreshPomodoroSettingsSheet;

  Future<void> _updatePomodoroSettings({
    int? focusTime,
    int? shortBreakTime,
    int? longBreakTime,
    String? sound,
    String? ambientSound,
    double? ambientVolume,
    bool? ambientDuringFocus,
    bool? ambientDuringBreaks,
    String? breakAfterFocus,
  }) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final previousTotal = _totalSecondsForMode(provider);
    final newSettings = AppSettings(
      themeMode: provider.settings.themeMode,
      language: provider.settings.language,
      focusTime: focusTime ?? provider.settings.focusTime,
      shortBreakTime: shortBreakTime ?? provider.settings.shortBreakTime,
      longBreakTime: longBreakTime ?? provider.settings.longBreakTime,
      weeklyGoal: provider.settings.weeklyGoal,
      weeklyFocusMinutesGoal: provider.settings.weeklyFocusMinutesGoal,
      dailyHabitGoal: provider.settings.dailyHabitGoal,
      streakGoal: provider.settings.streakGoal,
      sound: sound ?? provider.settings.sound,
      ambientSound: ambientSound ?? provider.settings.ambientSound,
      ambientVolume: ambientVolume ?? provider.settings.ambientVolume,
      ambientDuringFocus:
          ambientDuringFocus ?? provider.settings.ambientDuringFocus,
      ambientDuringBreaks:
          ambientDuringBreaks ?? provider.settings.ambientDuringBreaks,
      selectedIdentity: provider.settings.selectedIdentity,
      startScreen: provider.settings.startScreen,
      textScale: provider.settings.textScale,
      animationsEnabled: provider.settings.animationsEnabled,
      accentColor: provider.settings.accentColor,
      notificationsEnabled: provider.settings.notificationsEnabled,
      examReminderDayBefore: provider.settings.examReminderDayBefore,
      examReminderTwoHoursBefore: provider.settings.examReminderTwoHoursBefore,
      examReminderThirtyMinutesBefore:
          provider.settings.examReminderThirtyMinutesBefore,
      onboardingCompleted: provider.settings.onboardingCompleted,
      breakAfterFocus: breakAfterFocus ?? provider.settings.breakAfterFocus,
      userName: provider.settings.userName,
      showPolytechnicTools: provider.settings.showPolytechnicTools,
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
    unawaited(_syncAmbientSound(provider));
    await _persistState();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerAuraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _audioPlayer = AudioPlayer();
    _ambientPlayer = AudioPlayer();
    _ambientPreviewPlayer = AudioPlayer();
    _horizontalTickPlayer = AudioPlayer();
    unawaited(_horizontalTickPlayer.setAsset('assets/sounds/clock_tick.mp3'));
    unawaited(_horizontalTickPlayer.setVolume(0.24));
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
    if (granted) {
      _focusPermissionWarningShown = false;
    }
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
    _horizontalTickMuted = prefs.getBool(_horizontalTickMutedKey) ?? false;
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
    await prefs.setBool(_horizontalTickMutedKey, _horizontalTickMuted);
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
    unawaited(_syncAmbientSound(provider));
    if (!restored) {
      _persistState();
      if (mounted) {
        showFocusFeedback(
          context,
          message: _mode == 'focus'
              ? 'Sesión de enfoque iniciada.'
              : 'Descanso iniciado.',
          type: FocusFeedbackType.info,
          icon: _mode == 'focus'
              ? Icons.play_circle_fill_rounded
              : Icons.spa_rounded,
        );
      }
    }
    unawaited(_showPomodoroNotification(provider));
    unawaited(_syncPomodoroWidget(provider, force: true));
    if (_mode == 'focus') {
      unawaited(
        RankingService.updatePresence(
          status: 'pomodoro',
          subject: _activeSubjectName(provider),
        ),
      );
    }
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
      unawaited(_playHorizontalTick());
      _refreshHorizontalMode();
      unawaited(_showPomodoroNotification(provider));
      unawaited(_syncPomodoroWidget(provider));
      _persistState();
    });
  }

  Future<void> _syncPomodoroWidget(
    AppProvider provider, {
    bool force = false,
  }) {
    final syncBucket = _isRunning ? _remainingSeconds ~/ 30 : -1;
    if (!force && _lastWidgetSyncBucket == syncBucket) {
      return Future.value();
    }
    _lastWidgetSyncBucket = syncBucket;
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
    try {
      if (!_isRunning || !provider.settings.notificationsEnabled) {
        _lastPomodoroNotificationSignature = null;
        await NotificationService.cancelPomodoroTimerNotification();
        return;
      }

      final nativeShieldOwnsNotification = _mode == 'focus' &&
          _focusModeConfig.enabled &&
          _focusModePermissionGranted &&
          _focusModeConfig.blockedApps.isNotEmpty;
      if (nativeShieldOwnsNotification) {
        _lastPomodoroNotificationSignature = null;
        await NotificationService.cancelPomodoroTimerNotification();
        return;
      }

      final notificationsAllowed = await NotificationService.hasPermissions();
      if (!notificationsAllowed) {
        _lastPomodoroNotificationSignature = null;
        return;
      }

      final totalSeconds = _totalSecondsForMode(provider);
      final subject = _activeSubjectName(provider);
      final notificationBucket = _remainingSeconds ~/ 30;
      final signature = '$_mode|$totalSeconds|$subject|$notificationBucket';
      if (_lastPomodoroNotificationSignature == signature) return;
      _lastPomodoroNotificationSignature = signature;

      await NotificationService.showPomodoroTimerNotification(
        mode: _mode,
        remainingSeconds: _remainingSeconds,
        totalSeconds: totalSeconds,
        subject: subject,
      );
    } catch (error) {
      _lastPomodoroNotificationSignature = null;
      debugPrint('[FocusPomodoro] Notificación omitida: $error');
    }
  }

  void _refreshHorizontalMode() {
    if (!_isDisposed && _isHorizontalFocusMode) {
      _horizontalRefresh.value++;
    }
  }

  Future<void> _playHorizontalTick() async {
    if (!_isHorizontalFocusMode || _horizontalTickMuted || !_isRunning) return;
    try {
      await _horizontalTickPlayer.stop();
      await _horizontalTickPlayer.seek(Duration.zero);
      await _horizontalTickPlayer.play();
    } catch (_) {}
  }

  void _pauseTimer() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _timer?.cancel();
    _lastPomodoroNotificationSignature = null;
    unawaited(NotificationService.cancelPomodoroTimerNotification());
    if (mounted) {
      setState(() => _isRunning = false);
    } else {
      _isRunning = false;
    }
    _lastWidgetSyncBucket = null;
    _refreshHorizontalMode();
    unawaited(_stopFocusModeShield());
    unawaited(_stopAmbientSound());
    unawaited(RankingService.updatePresence(status: 'idle'));
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
    _lastPomodoroNotificationSignature = null;
    unawaited(NotificationService.cancelPomodoroTimerNotification());
    _lastWidgetSyncBucket = null;
    setState(() {
      _mode = newMode;
      _isRunning = false;
      _setRemainingFromMode();
    });
    _refreshHorizontalMode();
    unawaited(_stopFocusModeShield());
    unawaited(_stopAmbientSound());
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
      showFocusFeedback(
        context,
        message: 'Restauramos tu Pomodoro según el tiempo real pasado.',
        type: FocusFeedbackType.info,
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
      unawaited(RankingService.submitPomodoro(
        durationMinutes: provider.settings.focusTime,
        distractionFree: true,
      ));
      unawaited(
        RankingService.syncSocialStats(
          currentStreak: provider.currentStreak,
          totalPomodoros: provider.pomodoros.length,
          totalFocusMinutes: provider.totalFocusMinutes,
          totalHabitCompletions: provider.totalHabitCompletions,
          weeklyMissionCompleted: provider.weeklyMissionCompleted,
          level: provider.level,
          bestStreak: provider.bestStreak,
          focusPoints: provider.gamifiedPoints,
          weeklyPomodoros: provider.weeklyPomodoros,
          weeklyFocusMinutes: provider.weeklyFocusMinutes,
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

  Future<void> _previewCompletionSound(String soundId) async {
    if (soundId == 'none') {
      await _audioPlayer.stop();
      return;
    }
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setAsset('assets/sounds/$soundId.mp3');
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (error) {
      debugPrint('[FocusPomodoro] Preview finalización omitido: $error');
    }
  }

  _AmbientSoundOption _ambientOptionFor(String id) {
    return _ambientSoundOptions.firstWhere(
      (option) => option.id == id,
      orElse: () => _ambientSoundOptions.first,
    );
  }

  _CompletionSoundOption _completionOptionFor(String id) {
    return _completionSoundOptions.firstWhere(
      (option) => option.id == id,
      orElse: () => _completionSoundOptions.first,
    );
  }

  bool _shouldPlayAmbientSound(AppProvider provider) {
    final settings = provider.settings;
    if (!_isRunning || settings.ambientSound == 'none') return false;
    if (_mode == 'focus') return settings.ambientDuringFocus;
    return settings.ambientDuringBreaks;
  }

  Future<void> _syncAmbientSound(AppProvider provider) async {
    try {
      if (!_shouldPlayAmbientSound(provider)) {
        await _ambientPlayer.pause();
        return;
      }

      final selectedSound = provider.settings.ambientSound;
      if (_loadedAmbientSound != selectedSound) {
        await _ambientPlayer.stop();
        await _ambientPlayer.setLoopMode(LoopMode.one);
        await _ambientPlayer
            .setAsset('assets/sounds/ambient/$selectedSound.mp3');
        _loadedAmbientSound = selectedSound;
      }
      await _ambientPlayer.setVolume(provider.settings.ambientVolume);
      if (!_ambientPlayer.playing) {
        await _ambientPlayer.play();
      }
    } catch (error) {
      _loadedAmbientSound = null;
      debugPrint('[FocusPomodoro] Ambiente omitido: $error');
    }
  }

  Future<void> _stopAmbientSound() async {
    try {
      await _ambientPlayer.pause();
    } catch (_) {}
  }

  Future<void> _previewAmbientSound(String soundId) async {
    if (soundId == 'none') {
      await _stopAmbientPreview();
      return;
    }
    try {
      if (_previewingAmbientSound == soundId && _ambientPreviewPlayer.playing) {
        await _stopAmbientPreview();
        return;
      }
      _ambientPreviewTimer?.cancel();
      await _ambientPreviewPlayer.stop();
      await _ambientPreviewPlayer.setLoopMode(LoopMode.one);
      await _ambientPreviewPlayer
          .setAsset('assets/sounds/ambient/$soundId.mp3');
      await _ambientPreviewPlayer.setVolume(0.55);
      _previewingAmbientSound = soundId;
      await _ambientPreviewPlayer.play();
      _ambientPreviewTimer = Timer(
        const Duration(seconds: 8),
        () => unawaited(_stopAmbientPreview()),
      );
    } catch (error) {
      _previewingAmbientSound = null;
      debugPrint('[FocusPomodoro] Preview ambiente omitido: $error');
    }
    if (mounted) setState(() {});
  }

  Future<void> _stopAmbientPreview() async {
    _ambientPreviewTimer?.cancel();
    _ambientPreviewTimer = null;
    _previewingAmbientSound = null;
    try {
      await _ambientPreviewPlayer.stop();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _completeSession() async {
    if (_isCompletingSession) return;
    _isCompletingSession = true;
    try {
      _timer?.cancel();
      final provider = Provider.of<AppProvider>(context, listen: false);
      final completedMode = _mode;
      final completedAt = DateTime.now();
      final blockedAttempts = _focusModeStatus.blockedAttempts;
      final subjectName = _activeSubjectName(provider);
      final completedFocusDuration = provider.settings.focusTime;

      unawaited(_playBell());

      if (completedMode == 'focus') {
        unawaited(_stopFocusModeShield());
        _completedFocusSessions++;
        final nextMode = _nextBreakMode(provider);
        if (mounted) {
          setState(() {
            _isRunning = false;
            _mode = nextMode;
            _setRemainingFromMode();
          });
        } else {
          _isRunning = false;
          _mode = nextMode;
          _setRemainingFromMode();
        }
        _refreshHorizontalMode();
        _startTimer();
        unawaited(_syncAmbientSound(provider));
        await _persistState();

        unawaited(
          _saveCompletedFocusSession(
            provider: provider,
            completedAt: completedAt,
            subjectName: subjectName,
            durationMinutes: completedFocusDuration,
            distractionFree: blockedAttempts == 0,
          ),
        );
        unawaited(
          RankingService.updatePresence(
            status: 'studied_today',
            subject: subjectName,
          ),
        );

        if (mounted) {
          showFocusFeedback(
            context,
            message:
                'Enfoque completado. Empieza ${nextMode == 'longBreak' ? 'el descanso largo' : 'el descanso corto'}.',
            type: FocusFeedbackType.success,
            icon: Icons.emoji_events_rounded,
            celebration: true,
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isRunning = false;
            _mode = 'focus';
            _setRemainingFromMode();
          });
        } else {
          _isRunning = false;
          _mode = 'focus';
          _setRemainingFromMode();
        }
        _refreshHorizontalMode();
        _startTimer();
        unawaited(_syncAmbientSound(provider));
        await _persistState();

        if (mounted) {
          showFocusFeedback(
            context,
            message: 'Descanso completado. Volvemos al enfoque.',
            type: FocusFeedbackType.info,
            icon: Icons.self_improvement_rounded,
          );
        }
      }
    } finally {
      _isCompletingSession = false;
    }
  }

  Future<void> _saveCompletedFocusSession({
    required AppProvider provider,
    required DateTime completedAt,
    required String subjectName,
    required int durationMinutes,
    required bool distractionFree,
  }) async {
    try {
      await provider.addPomodoro(
        Pomodoro(
          date: completedAt.toIso8601String(),
          subject: subjectName,
          duration: durationMinutes,
        ),
      );
    } catch (error) {
      debugPrint('[FocusPomodoro] No se pudo guardar la sesión: $error');
      return;
    }

    unawaited(
      RankingService.submitPomodoro(
        durationMinutes: durationMinutes,
        distractionFree: distractionFree,
      ).catchError((Object error) {
        debugPrint('[FocusRanking] No se pudo enviar el Pomodoro: $error');
      }),
    );
    unawaited(
      RankingService.syncSocialStats(
        currentStreak: provider.currentStreak,
        totalPomodoros: provider.pomodoros.length,
        totalFocusMinutes: provider.totalFocusMinutes,
        totalHabitCompletions: provider.totalHabitCompletions,
        weeklyMissionCompleted: provider.weeklyMissionCompleted,
        level: provider.level,
        bestStreak: provider.bestStreak,
        focusPoints: provider.gamifiedPoints,
        weeklyPomodoros: provider.weeklyPomodoros,
        weeklyFocusMinutes: provider.weeklyFocusMinutes,
      ).catchError((Object error) {
        debugPrint('[FocusRanking] No se pudo sincronizar stats: $error');
      }),
    );
    unawaited(
      RankingService.syncAchievementAwards(
        pomodoros: provider.pomodoros.length,
        currentStreak: provider.currentStreak,
        totalHabitCompletions: provider.totalHabitCompletions,
        weeklyMissionCompleted: provider.weeklyMissionCompleted,
        level: provider.level,
        maxLevel: AppProvider.maxLevel,
      ).catchError((Object error) {
        debugPrint('[FocusRanking] No se pudo sincronizar logros: $error');
      }),
    );
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
      if (mounted && !_focusPermissionWarningShown) {
        _focusPermissionWarningShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: FocusActionSnackContent(
              icon: Icons.lock_open_rounded,
              message:
                  'El Pomodoro sigue. Activa permisos solo si quieres bloquear apps.',
              color: FocusPalette.amber,
            ),
            behavior: SnackBarBehavior.floating,
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
              content: FocusActionSnackContent(
                icon: Icons.shield_outlined,
                message:
                    'Modo Enfoque Total no pudo iniciarse. El Pomodoro sigue normal.',
                color: FocusPalette.amber,
              ),
              behavior: SnackBarBehavior.floating,
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
            content: FocusActionSnackContent(
              icon: Icons.warning_amber_rounded,
              message:
                  'El bloqueo falló al arrancar. La sesión de Pomodoro sigue activa.',
              color: FocusPalette.amber,
            ),
            behavior: SnackBarBehavior.floating,
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
    if (_isTogglingFocusMode) return;
    setState(() => _isTogglingFocusMode = true);
    _refreshPomodoroSettingsSheet?.call();
    try {
      var nextBlockedApps = _focusModeConfig.blockedApps;
      if (value && nextBlockedApps.isEmpty) {
        final selectedApps =
            await _openFocusModeSetupForResult(initialApps: nextBlockedApps);
        if (selectedApps == null || selectedApps.isEmpty) {
          if (mounted) {
            showFocusFeedback(
              context,
              message: 'Elegí al menos una app para activar el bloqueo.',
              type: FocusFeedbackType.info,
              icon: Icons.apps_rounded,
            );
          }
          return;
        }
        nextBlockedApps = selectedApps;
      }

      if (value) {
        var permissionGranted = await _refreshFocusModePermissionState();
        if (!permissionGranted) {
          final opened = await _showFocusModePermissionSheet();
          if (!opened) return;
          permissionGranted = await _refreshFocusModePermissionState();
          if (!permissionGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: FocusActionSnackContent(
                  icon: Icons.info_rounded,
                  message:
                      'Focus no detecta todos los permisos todavía. Puedes seguir usando Pomodoro normal.',
                  color: FocusPalette.amber,
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
        }
      }
      final newConfig = _focusModeConfig.copyWith(
        enabled: value,
        blockedApps: nextBlockedApps,
        protectionLevel: 'strict',
      );
      await FocusModeService.saveConfig(newConfig);
      if (!mounted) return;
      setState(() => _focusModeConfig = newConfig);
      _refreshPomodoroSettingsSheet?.call();
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (!value) {
        await _stopFocusModeShield();
        await NotificationService.cancelPomodoroTimerNotification();
        if (_isRunning) {
          unawaited(_showPomodoroNotification(provider));
        }
        return;
      }
      if (_isRunning && _mode == 'focus') {
        await _syncFocusModeShield(provider);
        unawaited(_showPomodoroNotification(provider));
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingFocusMode = false);
        _refreshPomodoroSettingsSheet?.call();
      } else {
        _isTogglingFocusMode = false;
      }
    }
  }

  Future<bool> _showFocusModePermissionSheet() async {
    if (!mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activar bloqueo de apps',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Solo necesitas estos permisos si quieres que Focus bloquee distracciones durante el Pomodoro.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                FocusGap.lg,
                _FocusModePermissionAction(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Accesibilidad',
                  subtitle: 'Detecta apps distractoras.',
                  onTap: FocusModeService.openAccessibilitySettings,
                ),
                const SizedBox(height: 10),
                _FocusModePermissionAction(
                  icon: Icons.layers_rounded,
                  title: 'Superposición',
                  subtitle: 'Muestra la pantalla de bloqueo.',
                  onTap: FocusModeService.openOverlaySettings,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Ya los activé'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Ahora no'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
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
            content: FocusActionSnackContent(
              icon: Icons.shield_rounded,
              message: 'Bloqueo activo: $appName',
              color: FocusPalette.amber,
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      _showingDistractionPrompt = false;
    }
  }

  Future<void> _openFocusModeSetup() async {
    final selectedApps = await _openFocusModeSetupForResult(
      initialApps: _focusModeConfig.blockedApps,
    );
    if (selectedApps == null) return;
    final newConfig = _focusModeConfig.copyWith(blockedApps: selectedApps);
    await FocusModeService.saveConfig(newConfig);
    if (!mounted) return;
    setState(() => _focusModeConfig = newConfig);
    _refreshPomodoroSettingsSheet?.call();
    if (_isRunning && _mode == 'focus' && newConfig.enabled) {
      unawaited(_syncFocusModeShield(
        Provider.of<AppProvider>(context, listen: false),
      ));
    }
  }

  Future<List<FocusShieldApp>?> _openFocusModeSetupForResult({
    required List<FocusShieldApp> initialApps,
  }) async {
    if (!mounted) return null;
    return Navigator.of(context).push<List<FocusShieldApp>>(
      MaterialPageRoute(
        builder: (_) => FocusModeSetupScreen(
          initiallySelected: initialApps,
        ),
      ),
    );
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
                routeContext,
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
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _setHorizontalTheme(int index) {
    setState(() => _horizontalThemeIndex =
        index.clamp(0, _horizontalThemes.length - 1).toInt());
    _horizontalRefresh.value++;
    _persistState();
  }

  void _toggleHorizontalTickSound() {
    setState(() => _horizontalTickMuted = !_horizontalTickMuted);
    _horizontalRefresh.value++;
    _persistState();
  }

  Future<void> _showHorizontalThemePicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < _horizontalThemes.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        right: index == _horizontalThemes.length - 1 ? 0 : 10,
                      ),
                      child: _HorizontalThemeOption(
                        theme: _horizontalThemes[index],
                        selected: index == _horizontalThemeIndex,
                        onTap: () {
                          _setHorizontalTheme(index);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildCinematicHorizontalTimer(
    BuildContext routeContext,
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
                    horizontalTheme.glow.withValues(alpha: 0.22),
                    horizontalTheme.backgroundStart,
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
                                    pulseKey: minutes,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _TimePanel(
                                    value: seconds.toString().padLeft(2, '0'),
                                    topLabel: '',
                                    numberSize: numberSize,
                                    theme: horizontalTheme,
                                    pulseKey: seconds,
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
              tickMuted: _horizontalTickMuted,
              onTheme: () => _showHorizontalThemePicker(routeContext),
              onTickSound: _toggleHorizontalTickSound,
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
    _ambientPreviewTimer?.cancel();
    _horizontalRefresh.dispose();
    _timerAuraController.dispose();
    _audioPlayer.dispose();
    _ambientPlayer.dispose();
    _ambientPreviewPlayer.dispose();
    _horizontalTickPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
    );
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final subjects = provider.subjects;

    if (_isLoading) {
      return const FocusSkeletonList(
        heights: [420, 180],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePalette = _themePalette();
    final compact = MediaQuery.of(context).size.width < 390;
    final modeTitle = _currentModeTitle();
    final ambientEnabled = provider.settings.ambientSound != 'none';
    final ambientOption = _ambientOptionFor(provider.settings.ambientSound);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _screenGradientColors(isDark, themePalette),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: FocusInsets.pageCompact,
          children: [
            _glassCard(
              context,
              padding: FocusInsets.panel,
              immersive: _isRunning,
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: FocusAssetBadge(
                          kind: FocusAppIconKind.pomodoro,
                          key: ValueKey(
                              'pomodoro-title-icon-$_isRunning-$_mode'),
                          color: themePalette.accent,
                          size: 36,
                          iconSize: 22,
                          fallback: _mode == 'focus'
                              ? Icons.psychology_alt_rounded
                              : Icons.spa_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isRunning ? modeTitle : _idleModeTitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ambiente',
                        onPressed: () => _showAmbientSoundSheet(provider),
                        icon: Icon(
                          ambientEnabled
                              ? ambientOption.icon
                              : Icons.music_note_rounded,
                        ),
                        color: ambientEnabled ? ambientOption.color : null,
                      ),
                      if (_isRunning)
                        IconButton.filledTonal(
                          tooltip: 'Voltear pantalla',
                          onPressed: _toggleHorizontalFocusMode,
                          icon: const Icon(Icons.screen_rotation_alt_rounded),
                        )
                      else
                        IconButton(
                          tooltip: 'Ajustes de Pomodoro',
                          onPressed: () => _showPomodoroSettingsSheet(provider),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _isRunning
                        ? Column(
                            key: const ValueKey('active-session-mode'),
                            children: [
                              _ActiveSessionStrip(
                                subject: _selectedSubject.trim().isEmpty
                                    ? 'General'
                                    : _selectedSubject.trim(),
                                blockedApps: _focusModeConfig.enabled
                                    ? _focusModeConfig.blockedApps.length
                                    : 0,
                                shieldActive: _focusModeStatus.active,
                                accent: themePalette.accent,
                              ),
                            ],
                          )
                        : Wrap(
                            key: const ValueKey('mode-picker'),
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              _ModePill(
                                label: 'Enfoque',
                                selected: _mode == 'focus',
                                color: FocusPalette.primary,
                                onTap: () => _changeMode('focus'),
                              ),
                              _ModePill(
                                label: 'Descanso',
                                selected: _mode == 'shortBreak',
                                color: FocusPalette.mint,
                                onTap: () => _changeMode('shortBreak'),
                              ),
                              _ModePill(
                                label: 'Largo',
                                selected: _mode == 'longBreak',
                                color: FocusPalette.amber,
                                onTap: () => _changeMode('longBreak'),
                              ),
                            ],
                          ),
                  ),
                  FocusGap.lg,
                  FocusMicroPop(
                    trigger: 'pomodoro-timer-$_mode-$_isRunning',
                    fromScale: _isRunning ? 0.97 : 0.99,
                    child: SizedBox(
                      width: _isRunning
                          ? (compact ? 258 : 308)
                          : compact
                              ? 230
                              : 268,
                      height: _isRunning
                          ? (compact ? 258 : 308)
                          : compact
                              ? 230
                              : 268,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: AnimatedBuilder(
                              animation: _timerAuraController,
                              builder: (context, child) {
                                final value = _timerAuraController.value;
                                return CustomPaint(
                                  painter: _ImmersiveTimerAuraPainter(
                                    animation: value,
                                    active: _isRunning,
                                    isDark: isDark,
                                    accent: themePalette.accent,
                                    secondary: themePalette.accentSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            width: _isRunning
                                ? (compact ? 204 : 244)
                                : compact
                                    ? 178
                                    : 214,
                            height: _isRunning
                                ? (compact ? 204 : 244)
                                : compact
                                    ? 178
                                    : 214,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? FocusPalette.darkCard
                                  : Theme.of(context).cardColor,
                              border: Border.all(
                                color: themePalette.accent.withValues(
                                  alpha: _isRunning
                                      ? (isDark ? 0.26 : 0.20)
                                      : (isDark ? 0.08 : 0.16),
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: themePalette.accent.withValues(
                                    alpha: _isRunning
                                        ? (isDark ? 0.24 : 0.13)
                                        : (isDark ? 0.18 : 0.08),
                                  ),
                                  blurRadius: _isRunning
                                      ? (isDark ? 38 : 28)
                                      : (isDark ? 30 : 20),
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: Text(
                                    _formatTime(_remainingSeconds),
                                    key: ValueKey(_remainingSeconds),
                                    style: TextStyle(
                                      fontSize: compact ? 42 : 52,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      color: isDark
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isRunning
                                      ? 'Sesión activa'
                                      : _mode == 'focus'
                                          ? 'Tiempo restante'
                                          : 'Cuenta regresiva',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.66)
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FocusGap.lg,
                  FocusMicroPop(
                    trigger: 'pomodoro-button-$_isRunning-$_mode',
                    fromScale: 0.97,
                    child: SizedBox(
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
                        onPressed:
                            _isRunning ? _pauseTimer : () => _startTimer(),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            _isRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(_isRunning),
                          ),
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
                  ),
                  FocusGap.sm,
                  if (!_isRunning && _mode == 'focus') ...[
                    _subjectSelector(provider, subjects),
                    FocusGap.sm,
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _isRunning
                        ? FocusPill(
                            key: const ValueKey('active-focus-pill'),
                            icon: _focusModeStatus.active
                                ? Icons.shield_rounded
                                : Icons.timer_rounded,
                            label: _focusModeStatus.active
                                ? 'Bloqueo activo'
                                : 'Sesión en curso',
                            color: themePalette.accent,
                          )
                        : Wrap(
                            key: const ValueKey('idle-actions'),
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
                            ],
                          ),
                  ),
                ],
              ),
            ),
            if (!_isRunning) ...[
              FocusGap.md,
              _glassCard(
                context,
                padding: FocusInsets.cardRelaxed,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FocusSectionHeader(
                      icon: Icons.today_rounded,
                      iconKind: FocusAppIconKind.pomodoro,
                      title: 'Sesiones de hoy',
                      subtitle:
                          'Se guardan automáticamente al completar el enfoque.',
                      accent: themePalette.accent,
                    ),
                    FocusGap.md,
                    SizedBox(height: 250, child: _buildTodaySessions(provider)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Color> _screenGradientColors(
    bool isDark,
    _PomodoroPalette themePalette,
  ) {
    return isDark
        ? [
            FocusPalette.darkSurfaceTop,
            FocusPalette.darkSurfaceMid,
            FocusPalette.darkSurfaceTint,
          ]
        : [
            themePalette.backgroundStart,
            themePalette.backgroundMiddle,
            themePalette.backgroundEnd,
          ];
  }

  String _idleModeTitle() {
    return switch (_mode) {
      'focus' => 'Concentrarse ahora',
      'shortBreak' => 'Descanso breve',
      'longBreak' => 'Descanso largo',
      _ => 'Pomodoro',
    };
  }

  String _currentModeTitle() {
    return switch (_mode) {
      'focus' => 'Enfoque',
      'shortBreak' => 'Descanso corto',
      'longBreak' => 'Descanso largo',
      _ => 'Pomodoro',
    };
  }

  Future<void> _showPomodoroSettingsSheet(AppProvider provider) async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, refreshSheet) {
              _refreshPomodoroSettingsSheet = () => refreshSheet(() {});
              return Consumer<AppProvider>(
                builder: (context, sheetProvider, _) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      0,
                      18,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ajustes de Pomodoro',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tiempos, sonido, descanso automático y bloqueo de apps.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          FocusGap.lg,
                          _TimerSlider(
                            label: 'Enfoque',
                            value: sheetProvider.settings.focusTime,
                            min: 5,
                            max: 90,
                            color: FocusPalette.primary,
                            onChanged: (value) =>
                                _updatePomodoroSettings(focusTime: value),
                          ),
                          _TimerSlider(
                            label: 'Descanso corto',
                            value: sheetProvider.settings.shortBreakTime,
                            min: 1,
                            max: 30,
                            color: FocusPalette.mint,
                            onChanged: (value) =>
                                _updatePomodoroSettings(shortBreakTime: value),
                          ),
                          _TimerSlider(
                            label: 'Descanso largo',
                            value: sheetProvider.settings.longBreakTime,
                            min: 5,
                            max: 60,
                            color: FocusPalette.amber,
                            onChanged: (value) =>
                                _updatePomodoroSettings(longBreakTime: value),
                          ),
                          const SizedBox(height: 10),
                          _CompactCompletionSoundPicker(
                            selected: _completionOptionFor(
                                sheetProvider.settings.sound),
                            options: _completionSoundOptions,
                            onSelected: (option) async {
                              await _updatePomodoroSettings(sound: option.id);
                              await _previewCompletionSound(option.id);
                              refreshSheet(() {});
                            },
                            onPreview: (option) =>
                                _previewCompletionSound(option.id),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue:
                                sheetProvider.settings.breakAfterFocus,
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
                          FocusGap.lg,
                          _buildFocusModeTotalCard(sheetProvider),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } finally {
      _refreshPomodoroSettingsSheet = null;
    }
  }

  Future<void> _showAmbientSoundSheet(AppProvider provider) async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, refreshSheet) {
              return Consumer<AppProvider>(
                builder: (context, sheetProvider, _) {
                  final selected =
                      _ambientOptionFor(sheetProvider.settings.ambientSound);
                  final isPreviewing = _previewingAmbientSound == selected.id &&
                      _ambientPreviewPlayer.playing;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      0,
                      18,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: selected.color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    Icon(selected.icon, color: selected.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ambiente',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    Text(
                                      'Sonidos suaves para acompañar el Pomodoro.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          FocusGap.lg,
                          _CompactAmbientPreviewCard(
                            option: selected,
                            enabled: selected.id != 'none',
                            isPreviewing: isPreviewing,
                            options: _ambientSoundOptions,
                            onSelected: (option) async {
                              await _updatePomodoroSettings(
                                ambientSound: option.id,
                              );
                              await _stopAmbientPreview();
                              refreshSheet(() {});
                            },
                            onPreview: selected.id == 'none'
                                ? null
                                : () async {
                                    await _previewAmbientSound(selected.id);
                                    refreshSheet(() {});
                                  },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Volumen',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          Slider(
                            value: sheetProvider.settings.ambientVolume,
                            min: 0,
                            max: 1,
                            divisions: 10,
                            activeColor: selected.color,
                            label:
                                '${(sheetProvider.settings.ambientVolume * 100).round()}%',
                            onChanged:
                                sheetProvider.settings.ambientSound == 'none'
                                    ? null
                                    : (value) {
                                        _updatePomodoroSettings(
                                          ambientVolume: value,
                                        );
                                        refreshSheet(() {});
                                      },
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: sheetProvider.settings.ambientDuringFocus,
                            activeColor: selected.color,
                            title: const Text('Reproducir en enfoque'),
                            onChanged:
                                sheetProvider.settings.ambientSound == 'none'
                                    ? null
                                    : (value) async {
                                        await _updatePomodoroSettings(
                                          ambientDuringFocus: value,
                                        );
                                        refreshSheet(() {});
                                      },
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: sheetProvider.settings.ambientDuringBreaks,
                            activeColor: selected.color,
                            title: const Text('Reproducir en descansos'),
                            onChanged:
                                sheetProvider.settings.ambientSound == 'none'
                                    ? null
                                    : (value) async {
                                        await _updatePomodoroSettings(
                                          ambientDuringBreaks: value,
                                        );
                                        refreshSheet(() {});
                                      },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } finally {
      await _stopAmbientPreview();
    }
  }

  Widget _glassCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = FocusInsets.card,
    bool immersive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themePalette = _themePalette();
    return Container(
      decoration: BoxDecoration(
        color: immersive ? null : theme.cardColor,
        gradient: immersive
            ? LinearGradient(
                colors: _immersiveCardColors(isDark, themePalette),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(FocusRadii.panel),
        border: Border.all(
          color: immersive
              ? Colors.white.withValues(alpha: 0.18)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: immersive
                ? (isDark ? FocusPalette.cyan : FocusPalette.primaryDeep)
                    .withValues(alpha: isDark ? 0.16 : 0.24)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: immersive ? 34 : 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  List<Color> _immersiveCardColors(
    bool isDark,
    _PomodoroPalette themePalette,
  ) {
    if (_mode == 'shortBreak') {
      return isDark
          ? [
              Color.lerp(FocusPalette.darkCard, FocusPalette.mint, 0.08)!,
              FocusPalette.darkCard,
              Color.lerp(FocusPalette.darkCard2, FocusPalette.mint, 0.10)!,
            ]
          : [
              Color.lerp(Colors.white, FocusPalette.mint, 0.18)!,
              Color.lerp(Colors.white, FocusPalette.cyan, 0.10)!,
              Colors.white,
            ];
    }
    if (_mode == 'longBreak') {
      return isDark
          ? [
              Color.lerp(FocusPalette.darkCard, FocusPalette.amber, 0.10)!,
              FocusPalette.darkCard,
              Color.lerp(FocusPalette.darkCard2, FocusPalette.amber, 0.12)!,
            ]
          : [
              Color.lerp(Colors.white, FocusPalette.amber, 0.18)!,
              Color.lerp(Colors.white, FocusPalette.mint, 0.10)!,
              Colors.white,
            ];
    }
    return isDark
        ? [
            Color.lerp(FocusPalette.darkCard, FocusPalette.teal, 0.12)!,
            FocusPalette.darkCard,
            Color.lerp(FocusPalette.darkCard2, FocusPalette.cyan, 0.10)!,
          ]
        : [
            Color.lerp(Colors.white, FocusPalette.teal, 0.16)!,
            Color.lerp(Colors.white, FocusPalette.cyan, 0.12)!,
            Colors.white,
          ];
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
          unawaited(_syncPomodoroWidget(provider, force: true));
          if (_mode == 'focus') {
            unawaited(_syncFocusModeShield(provider));
            unawaited(
              RankingService.updatePresence(
                status: 'pomodoro',
                subject: _activeSubjectName(provider),
              ),
            );
          }
        }
        _persistState();
      },
    );
  }

  Widget _buildFocusModeTotalCard(AppProvider provider) {
    final blockedApps = _focusModeConfig.blockedApps;
    final isEnabled = _focusModeConfig.enabled;
    final accent = FocusPalette.teal;
    final appsLabel = blockedApps.isEmpty
        ? 'Sin apps elegidas'
        : '${blockedApps.length} app${blockedApps.length == 1 ? '' : 's'}';

    return Container(
      width: double.infinity,
      padding: FocusInsets.cardRelaxed,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FocusRadii.card),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
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
                  borderRadius: BorderRadius.circular(FocusRadii.control),
                  color: accent.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.shield_moon_rounded,
                  color: FocusPalette.teal,
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
                onChanged:
                    _isTogglingFocusMode ? null : _toggleFocusModeEnabled,
              ),
            ],
          ),
          FocusGap.sm,
          Text(
            appsLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          FocusGap.sm,
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
          accent: FocusPalette.mint,
          accentSecondary: FocusPalette.mint,
          backgroundStart: Color(0xFFF3FBF7),
          backgroundMiddle: Color(0xFFE7F8EF),
          backgroundEnd: Color(0xFFD9F3E6),
          surfaceTint: Color(0xFFECFDF5),
        );
      case 'longBreak':
        return const _PomodoroPalette(
          accent: FocusPalette.amber,
          accentSecondary: FocusPalette.amber,
          backgroundStart: Color(0xFFFFF8EE),
          backgroundMiddle: Color(0xFFFFF1D6),
          backgroundEnd: Color(0xFFFFE5BF),
          surfaceTint: Color(0xFFFFF7ED),
        );
      default:
        return const _PomodoroPalette(
          accent: FocusPalette.primary,
          accentSecondary: FocusPalette.cyan,
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
        padding: FocusInsets.cardRelaxed,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FocusRadii.card),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.34),
        ),
        child: const Center(
          child: Text('Sin sesiones hoy.'),
        ),
      );
    }
    return ListView.separated(
      itemCount: todaySessions.length,
      separatorBuilder: (_, __) => FocusGap.sm,
      itemBuilder: (context, index) {
        final session = todaySessions[index];
        final date = DateTime.parse(session.date);
        return Container(
          padding: FocusInsets.card,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FocusRadii.card),
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
                  borderRadius: BorderRadius.circular(FocusRadii.control),
                  color: FocusPalette.mint.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: FocusPalette.mint,
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

class _ImmersiveTimerAuraPainter extends CustomPainter {
  final double animation;
  final bool active;
  final bool isDark;
  final Color accent;
  final Color secondary;

  const _ImmersiveTimerAuraPainter({
    required this.animation,
    required this.active,
    required this.isDark,
    required this.accent,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    final outerRadius = shortest / 2 - 4;
    final pulse =
        active ? (0.5 + math.sin(animation * math.pi * 2) * 0.5) : 0.0;

    final glowRect = Rect.fromCircle(center: center, radius: outerRadius);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: active ? 0.30 : 0.12),
          secondary.withValues(alpha: active ? 0.18 : 0.07),
          Colors.transparent,
        ],
        stops: const [0.28, 0.62, 1],
      ).createShader(glowRect);
    canvas.drawCircle(center, outerRadius, glowPaint);

    final baseRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.8 : 1.2
      ..color = accent.withValues(alpha: active ? 0.24 : 0.10);
    canvas.drawCircle(center, outerRadius - 10, baseRingPaint);
    canvas.drawCircle(center, outerRadius - 34, baseRingPaint);

    final auraRect = Rect.fromCircle(center: center, radius: outerRadius - 18);
    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = active ? 11.0 : 6.0
      ..shader = SweepGradient(
        colors: [
          accent.withValues(alpha: active ? 0.10 : 0.05),
          secondary.withValues(alpha: active ? 0.82 : 0.26),
          FocusPalette.amber.withValues(alpha: active ? 0.66 : 0.18),
          accent.withValues(alpha: active ? 0.96 : 0.34),
          accent.withValues(alpha: active ? 0.10 : 0.05),
        ],
        stops: const [0.0, 0.34, 0.54, 0.78, 1.0],
        transform: GradientRotation(animation * math.pi * 2),
      ).createShader(auraRect)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        active ? 1.6 + pulse * 0.9 : 1.0,
      );
    canvas.drawCircle(center, outerRadius - 18, auraPaint);

    if (!active) return;

    final orbitRect = Rect.fromCircle(center: center, radius: outerRadius - 4);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9 + pulse * 1.6
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.16),
          secondary.withValues(alpha: 0.92),
          FocusPalette.amber.withValues(alpha: 0.72),
          Colors.transparent,
        ],
        stops: const [0.0, 0.34, 0.50, 0.62, 1.0],
        transform: GradientRotation(animation * math.pi * 2),
      ).createShader(orbitRect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.8 + pulse * 1.2);
    canvas.drawCircle(center, outerRadius - 4, orbitPaint);

    final innerOrbitRect =
        Rect.fromCircle(center: center, radius: outerRadius - 42);
    final innerOrbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: isDark ? 0.48 : 0.34),
          accent.withValues(alpha: 0.62),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.58, 1.0],
        transform: GradientRotation(-animation * math.pi * 2),
      ).createShader(innerOrbitRect);
    canvas.drawCircle(center, outerRadius - 42, innerOrbitPaint);
  }

  @override
  bool shouldRepaint(covariant _ImmersiveTimerAuraPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.active != active ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary;
  }
}

class _ActiveSessionStrip extends StatelessWidget {
  final String subject;
  final int blockedApps;
  final bool shieldActive;
  final Color accent;

  const _ActiveSessionStrip({
    required this.subject,
    required this.blockedApps,
    required this.shieldActive,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('active-session'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          FocusPill(
            icon: shieldActive ? Icons.shield_rounded : Icons.shield_outlined,
            label: blockedApps == 0 ? 'Sin bloqueo' : '$blockedApps apps',
            color: shieldActive ? FocusPalette.teal : FocusPalette.muted,
            selected: shieldActive,
          ),
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
  final int pulseKey;

  const _TimePanel({
    required this.value,
    required this.topLabel,
    required this.numberSize,
    required this.theme,
    required this.pulseKey,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('horizontal-panel-$pulseKey-$value'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, animation, child) {
        final lift = (1 - animation) * 10;
        final scale = 0.982 + animation * 0.018;
        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(42),
          color: Colors.white.withValues(alpha: 0.055),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: theme.glow.withValues(alpha: 0.10),
              blurRadius: 36,
              offset: const Offset(0, 20),
            ),
          ],
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
                    color: theme.textColor.withValues(alpha: 0.86),
                    fontSize: numberSize,
                    height: 0.86,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -8,
                    shadows: [
                      Shadow(
                        color: theme.glow.withValues(alpha: 0.32),
                        blurRadius: 36,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizontalToolRail extends StatelessWidget {
  final _HorizontalTheme theme;
  final bool isRunning;
  final bool tickMuted;
  final VoidCallback onTheme;
  final VoidCallback onTickSound;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  const _HorizontalToolRail({
    required this.theme,
    required this.isRunning,
    required this.tickMuted,
    required this.onTheme,
    required this.onTickSound,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RailButton(icon: Icons.palette_rounded, onTap: onTheme, theme: theme),
        const SizedBox(height: 12),
        _RailButton(
          icon: tickMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          onTap: onTickSound,
          theme: theme,
          selected: !tickMuted,
        ),
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
  final bool selected;

  const _RailButton({
    required this.icon,
    required this.onTap,
    required this.theme,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? theme.glow.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.075),
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

class _FocusModePermissionAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;

  const _FocusModePermissionAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FocusSurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: FocusRadii.card,
      elevated: false,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: const Text('Abrir'),
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

class _AmbientSoundOption {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _AmbientSoundOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _CompletionSoundOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _CompletionSoundOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _CompactCompletionSoundPicker extends StatelessWidget {
  final _CompletionSoundOption selected;
  final List<_CompletionSoundOption> options;
  final ValueChanged<_CompletionSoundOption> onSelected;
  final ValueChanged<_CompletionSoundOption> onPreview;

  const _CompactCompletionSoundPicker({
    required this.selected,
    required this.options,
    required this.onSelected,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(FocusRadii.card),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(selected.icon, color: selected.color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sonido al terminar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  selected.id == 'none' ? 'Silencio' : selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Escuchar',
            onPressed: selected.id == 'none' ? null : () => onPreview(selected),
            color: selected.color,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Cambiar sonido',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onSelected: (id) {
              final option = options.firstWhere(
                (item) => item.id == id,
                orElse: () => selected,
              );
              onSelected(option);
            },
            itemBuilder: (context) => [
              for (final option in options)
                PopupMenuItem<String>(
                  value: option.id,
                  child: Row(
                    children: [
                      Icon(option.icon, color: option.color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(option.label)),
                      if (option.id == selected.id)
                        Icon(
                          Icons.check_rounded,
                          color: option.color,
                          size: 18,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactAmbientPreviewCard extends StatelessWidget {
  final _AmbientSoundOption option;
  final bool enabled;
  final bool isPreviewing;
  final List<_AmbientSoundOption> options;
  final ValueChanged<_AmbientSoundOption> onSelected;
  final VoidCallback? onPreview;

  const _CompactAmbientPreviewCard({
    required this.option,
    required this.enabled,
    required this.isPreviewing,
    required this.options,
    required this.onSelected,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subtle = foreground.withValues(alpha: isDark ? 0.72 : 0.62);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        gradient: LinearGradient(
          colors: [
            option.color.withValues(alpha: isDark ? 0.34 : 0.16),
            option.color.withValues(alpha: isDark ? 0.12 : 0.06),
            theme.colorScheme.surface.withValues(alpha: isDark ? 0.55 : 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: option.color.withValues(alpha: isDark ? 0.32 : 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: option.color.withValues(alpha: isDark ? 0.22 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(option.icon, color: option.color, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: foreground,
                  ),
                ),
                Text(
                  option.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: subtle),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isPreviewing ? 'Detener preview' : 'Probar sonido',
            onPressed: enabled ? onPreview : null,
            color: option.color,
            icon: Icon(
              isPreviewing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Cambiar ambiente',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onSelected: (id) {
              final selected = options.firstWhere(
                (item) => item.id == id,
                orElse: () => option,
              );
              onSelected(selected);
            },
            itemBuilder: (context) => [
              for (final item in options)
                PopupMenuItem<String>(
                  value: item.id,
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.label)),
                      if (item.id == option.id)
                        Icon(
                          Icons.check_rounded,
                          color: item.color,
                          size: 18,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HorizontalThemeOption extends StatelessWidget {
  final _HorizontalTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _HorizontalThemeOption({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 128,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              theme.glow.withValues(alpha: 0.38),
              theme.backgroundStart,
              theme.backgroundEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: selected
                ? theme.glow.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(theme.icon, color: theme.textColor, size: 20),
                const Spacer(),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.glow,
                    size: 19,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              theme.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<_HorizontalTheme> _horizontalThemes = [
  _HorizontalTheme(
    label: 'Noche',
    icon: Icons.dark_mode_rounded,
    backgroundStart: Color(0xFF070B18),
    backgroundEnd: Color(0xFF010207),
    glow: Color(0xFF38BDF8),
    textColor: Colors.white,
  ),
  _HorizontalTheme(
    label: 'Algodón',
    icon: Icons.favorite_rounded,
    backgroundStart: Color(0xFF2B123B),
    backgroundEnd: Color(0xFF090214),
    glow: Color(0xFFF9A8D4),
    textColor: Color(0xFFFFF1F7),
  ),
  _HorizontalTheme(
    label: 'Menta',
    icon: Icons.eco_rounded,
    backgroundStart: Color(0xFF062D25),
    backgroundEnd: Color(0xFF01110E),
    glow: Color(0xFF34D399),
    textColor: Color(0xFFE7FFF7),
  ),
  _HorizontalTheme(
    label: 'Atardecer',
    icon: Icons.wb_twilight_rounded,
    backgroundStart: Color(0xFF301306),
    backgroundEnd: Color(0xFF130617),
    glow: Color(0xFFFBBF24),
    textColor: Color(0xFFFFF7ED),
  ),
  _HorizontalTheme(
    label: 'Lila',
    icon: Icons.auto_awesome_rounded,
    backgroundStart: Color(0xFF1E1B4B),
    backgroundEnd: Color(0xFF080616),
    glow: Color(0xFFC4B5FD),
    textColor: Color(0xFFF5F3FF),
  ),
];

class _HorizontalTheme {
  final String label;
  final IconData icon;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color glow;
  final Color textColor;

  const _HorizontalTheme({
    required this.label,
    required this.icon,
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.glow,
    required this.textColor,
  });
}
