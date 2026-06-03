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
import '../models/study_task.dart';
import '../providers/app_provider.dart';
import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../services/pomodoro_task_launch_service.dart';
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
  static const _horizontalDarkModeKey = 'pomodoro_horizontal_dark_mode';
  static const _horizontalAnimationKey = 'pomodoro_horizontal_animation';
  static const _horizontalTickMutedKey = 'pomodoro_horizontal_tick_muted';
  static const _linkedTaskIdKey = 'pomodoro_linked_task_id';
  static const _linkedTaskTitleKey = 'pomodoro_linked_task_title';
  static const _sessionGoalKey = 'pomodoro_session_goal';
  static const _focusSessionMinutesOverrideKey =
      'pomodoro_focus_session_minutes_override';
  static const _maxAutoRecoveryDuration = Duration(hours: 8);
  static const List<_AmbientSoundOption> _ambientSoundOptions = [
    _AmbientSoundOption(
      id: 'none',
      label: 'Sin ambiente',
      vibe: 'Minimal',
      description: 'Pomodoro limpio, sin sonido de fondo.',
      icon: Icons.volume_off_rounded,
      color: Color(0xFF64748B),
    ),
    _AmbientSoundOption(
      id: 'focus_music',
      label: 'Música suave',
      vibe: 'Flow',
      description: 'Base ambiental suave para estudiar.',
      icon: Icons.graphic_eq_rounded,
      color: Color(0xFF10B981),
    ),
    _AmbientSoundOption(
      id: 'focus_jazz',
      label: 'Jazz suave',
      vibe: 'Jazz',
      description: 'Jazz liviano para sesiones tranquilas.',
      icon: Icons.piano_rounded,
      color: Color(0xFFF59E0B),
    ),
    _AmbientSoundOption(
      id: 'focus_rain',
      label: 'Lluvia',
      vibe: 'Calma',
      description: 'Lluvia continua para bajar el ruido externo.',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF38BDF8),
    ),
    _AmbientSoundOption(
      id: 'focus_cafe',
      label: 'Café',
      vibe: 'Ciudad',
      description: 'Ambiente suave de cafetería para estudiar.',
      icon: Icons.local_cafe_rounded,
      color: Color(0xFFB45309),
    ),
    _AmbientSoundOption(
      id: 'focus_forest',
      label: 'Bosque',
      vibe: 'Natural',
      description: 'Ambiente verde y tranquilo para leer.',
      icon: Icons.forest_rounded,
      color: Color(0xFF16A34A),
    ),
    _AmbientSoundOption(
      id: 'focus_water',
      label: 'Agua',
      vibe: 'Fluido',
      description: 'Agua suave para sesiones calmadas.',
      icon: Icons.waves_rounded,
      color: Color(0xFF0891B2),
    ),
    _AmbientSoundOption(
      id: 'focus_white_noise',
      label: 'Ruido blanco',
      vibe: 'Limpio',
      description: 'Sonido estable para tapar distracciones.',
      icon: Icons.blur_on_rounded,
      color: Color(0xFF94A3B8),
    ),
  ];
  static const List<_CompletionSoundOption> _completionSoundOptions = [
    _CompletionSoundOption(
      id: 'focus_clock',
      label: 'Reloj suave',
      icon: Icons.timer_rounded,
      color: Color(0xFFD71923),
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
  bool _horizontalDarkModeEnabled = false;
  int _horizontalAnimationIndex = 1;
  bool _horizontalTickMuted = false;
  final ValueNotifier<int> _horizontalRefresh = ValueNotifier<int>(0);
  late final AnimationController _timerAuraController;
  late final AudioPlayer _audioPlayer;
  late final AudioPlayer _ambientPlayer;
  late final AudioPlayer _ambientPreviewPlayer;
  late final AudioPlayer _horizontalTickPlayer;
  late final TextEditingController _sessionGoalController;
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
  int? _linkedTaskId;
  String _linkedTaskTitle = '';
  String _sessionGoal = '';
  int? _focusSessionMinutesOverride;
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
    int? pomodoroSessionsPerCycle,
    bool? pomodoroAutoStartNext,
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
      pomodoroSessionsPerCycle: pomodoroSessionsPerCycle ??
          provider.settings.pomodoroSessionsPerCycle,
      pomodoroAutoStartNext:
          pomodoroAutoStartNext ?? provider.settings.pomodoroAutoStartNext,
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
    _sessionGoalController = TextEditingController();
    unawaited(
      _horizontalTickPlayer.setAsset('assets/sounds/focus_clock.mp3'),
    );
    unawaited(_horizontalTickPlayer.setVolume(0.24));
    PomodoroTaskLaunchService.request.addListener(_handleTaskLaunchRequest);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _restoreState();
    _handleTaskLaunchRequest();
    if (!mounted) return;
    setState(() => _isLoading = false);
    unawaited(_loadFocusModeConfig());
  }

  void _handleTaskLaunchRequest() {
    final request = PomodoroTaskLaunchService.takePending();
    if (request == null || !mounted) return;
    _applyTaskLaunchRequest(request);
  }

  void _applyTaskLaunchRequest(PomodoroTaskLaunchRequest request) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final subject = provider.getSubjectById(request.subjectId);
    _timer?.cancel();
    _lastPomodoroNotificationSignature = null;
    unawaited(NotificationService.cancelPomodoroTimerNotification());
    setState(() {
      _linkedTaskId = request.taskId;
      _linkedTaskTitle = request.title;
      _mode = 'focus';
      _selectedSubject = subject?.name ?? '';
      _focusSessionMinutesOverride = request.focusMinutes;
      _isRunning = false;
      _setRemainingFromMode();
    });
    _refreshHorizontalMode();
    unawaited(_syncAmbientSound(provider));
    unawaited(_syncPomodoroWidget(provider, force: true));
    unawaited(_persistState());
    showFocusFeedback(
      context,
      message: 'Listo para trabajar en "${request.title}".',
      type: FocusFeedbackType.info,
      icon: Icons.task_alt_rounded,
    );
  }

  Future<void> _linkTaskForPomodoro(StudyTask task) async {
    final taskId = task.id;
    if (taskId == null) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final subject = provider.getSubjectById(task.subjectId);
    if (mounted) {
      setState(() {
        _linkedTaskId = taskId;
        _linkedTaskTitle = task.title;
        if (subject != null) _selectedSubject = subject.name;
        if (!_isRunning) {
          _mode = 'focus';
          _setRemainingFromMode();
        }
      });
    } else {
      _linkedTaskId = taskId;
      _linkedTaskTitle = task.title;
    }
    await _persistState();
    unawaited(_syncPomodoroWidget(provider, force: true));
    if (!mounted) return;
    showFocusFeedback(
      context,
      message: 'Tarea vinculada: "${task.title}".',
      type: FocusFeedbackType.info,
      icon: Icons.task_alt_rounded,
    );
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
        return safeMinutesToSeconds(
          _focusSessionMinutesOverride ?? provider.settings.focusTime,
        );
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
    _horizontalDarkModeEnabled = prefs.getBool(_horizontalDarkModeKey) ?? false;
    _horizontalAnimationIndex = (prefs.getInt(_horizontalAnimationKey) ?? 1)
        .clamp(0, _horizontalAnimations.length - 1)
        .toInt();
    _horizontalTickMuted = prefs.getBool(_horizontalTickMutedKey) ?? false;
    final linkedTaskId = prefs.getInt(_linkedTaskIdKey);
    final linkedTaskTitle = prefs.getString(_linkedTaskTitleKey) ?? '';
    if (linkedTaskId != null && linkedTaskTitle.trim().isNotEmpty) {
      _linkedTaskId = linkedTaskId;
      _linkedTaskTitle = linkedTaskTitle;
    }
    _sessionGoal = prefs.getString(_sessionGoalKey) ?? '';
    _sessionGoalController.text = _sessionGoal;
    _focusSessionMinutesOverride =
        prefs.getInt(_focusSessionMinutesOverrideKey);
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
    await prefs.setBool(_horizontalDarkModeKey, _horizontalDarkModeEnabled);
    await prefs.setInt(_horizontalAnimationKey, _horizontalAnimationIndex);
    await prefs.setBool(_horizontalTickMutedKey, _horizontalTickMuted);
    final linkedTaskId = _linkedTaskId;
    if (linkedTaskId != null && _linkedTaskTitle.trim().isNotEmpty) {
      await prefs.setInt(_linkedTaskIdKey, linkedTaskId);
      await prefs.setString(_linkedTaskTitleKey, _linkedTaskTitle);
    } else {
      await prefs.remove(_linkedTaskIdKey);
      await prefs.remove(_linkedTaskTitleKey);
    }
    await prefs.setString(_sessionGoalKey, _sessionGoal);
    final override = _focusSessionMinutesOverride;
    if (override == null) {
      await prefs.remove(_focusSessionMinutesOverrideKey);
    } else {
      await prefs.setInt(_focusSessionMinutesOverrideKey, override);
    }
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
          message: _mode == 'focus' ? 'Bloque iniciado.' : 'Descanso iniciado.',
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
      taskTitle: _linkedTaskTitle,
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

      final notificationsAllowed =
          await NotificationService.hasNotificationPermission();
      if (!notificationsAllowed) {
        _lastPomodoroNotificationSignature = null;
        return;
      }

      final totalSeconds = _totalSecondsForMode(provider);
      final subject = _activeSubjectName(provider);
      final nextMode = _nextPomodoroMode(provider);
      final nextLabel = _pomodoroModeLabel(nextMode);
      final nextTotalSeconds = _totalSecondsForMode(provider, nextMode);
      final remainingBucket = (_remainingSeconds / 15).ceil();
      final signature =
          '$_mode|$remainingBucket|$totalSeconds|$subject|$nextMode|$nextTotalSeconds';
      if (_lastPomodoroNotificationSignature == signature) return;
      _lastPomodoroNotificationSignature = signature;

      await NotificationService.showPomodoroTimerNotification(
        mode: _mode,
        remainingSeconds: _remainingSeconds,
        totalSeconds: totalSeconds,
        subject: subject,
        nextLabel: nextLabel,
        nextTotalSeconds: nextTotalSeconds,
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

  Future<void> _confirmResetTimer() async {
    if (!_isRunning) {
      _resetTimer();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reiniciar bloque'),
        content: const Text('Se va a pausar y volver al inicio del tiempo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (confirm == true) _resetTimer();
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
        final sessionsPerCycle =
            provider.settings.pomodoroSessionsPerCycle.clamp(1, 8);
        return _completedFocusSessions % sessionsPerCycle == 0
            ? 'longBreak'
            : 'shortBreak';
    }
  }

  String _nextPomodoroMode(AppProvider provider) {
    return _mode == 'focus' ? _nextBreakMode(provider) : 'focus';
  }

  String _horizontalSessionLabel(AppProvider provider) {
    final total = provider.settings.pomodoroSessionsPerCycle.clamp(1, 8);
    final completedInCycle = _completedFocusSessions % total;
    final current = _mode == 'focus'
        ? completedInCycle + 1
        : completedInCycle == 0
            ? total
            : completedInCycle;
    return '$current / $total';
  }

  String _pomodoroModeLabel(String mode) {
    return switch (mode) {
      'shortBreak' => 'Descanso corto',
      'longBreak' => 'Descanso largo',
      _ => 'Enfoque',
    };
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
    final soundId = _completionOptionFor(provider.settings.sound).id;
    if (soundId == 'none') return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setAsset('assets/sounds/$soundId.mp3');
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
    final ambientSound = _ambientOptionFor(settings.ambientSound).id;
    if (!_isRunning || ambientSound == 'none') return false;
    if (_mode == 'focus') return settings.ambientDuringFocus;
    return settings.ambientDuringBreaks;
  }

  Future<void> _syncAmbientSound(AppProvider provider) async {
    try {
      if (!_shouldPlayAmbientSound(provider)) {
        await _ambientPlayer.pause();
        return;
      }

      final selectedSound =
          _ambientOptionFor(provider.settings.ambientSound).id;
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

  Future<void> _previewAmbientSound(String soundId, {double? volume}) async {
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
      await _ambientPreviewPlayer.setVolume((volume ?? 0.55).clamp(0.0, 1.0));
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
      final completedFocusDuration =
          _focusSessionMinutesOverride ?? provider.settings.focusTime;
      final linkedTaskId = _linkedTaskId;
      final linkedTaskTitle = _linkedTaskTitle;
      final completedSessionGoal = _sessionGoal.trim();

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
        if (provider.settings.pomodoroAutoStartNext) {
          _startTimer();
        } else {
          unawaited(NotificationService.cancelPomodoroTimerNotification());
        }
        unawaited(_syncAmbientSound(provider));
        await _persistState();

        unawaited(
          _saveCompletedFocusSession(
            provider: provider,
            completedAt: completedAt,
            subjectName: subjectName,
            durationMinutes: completedFocusDuration,
            distractionFree: blockedAttempts == 0,
            taskId: linkedTaskId,
            taskTitle: linkedTaskTitle,
            sessionGoal: completedSessionGoal,
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
            message: '+20 puntos · 1 Pomodoro guardado.',
            type: FocusFeedbackType.success,
            icon: Icons.emoji_events_rounded,
            celebration: true,
          );
          unawaited(
            _askTaskProgressAfterFocus(
              linkedTaskId,
              linkedTaskTitle,
              completedSessionGoal,
            ),
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
        if (provider.settings.pomodoroAutoStartNext) {
          _startTimer();
        } else {
          unawaited(NotificationService.cancelPomodoroTimerNotification());
        }
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
    required int? taskId,
    required String taskTitle,
    required String sessionGoal,
  }) async {
    try {
      await provider.addPomodoro(
        Pomodoro(
          date: completedAt.toIso8601String(),
          subject: subjectName,
          duration: durationMinutes,
          taskId: taskId,
          taskTitle: taskTitle.trim(),
          sessionGoal: sessionGoal.trim(),
        ),
      );
    } catch (error) {
      debugPrint('[FocusPomodoro] No se pudo guardar la sesión: $error');
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

  Future<void> _askTaskProgressAfterFocus(
    int? taskId,
    String taskTitle,
    String sessionGoal,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final task = taskId == null ? null : _studyTaskById(provider, taskId);
    if (taskId != null && (task == null || task.isDone)) {
      await _clearLinkedTask();
      return;
    }
    final noteController = TextEditingController();
    var goalDone = false;

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
            child: StatefulBuilder(
              builder: (context, refreshSheet) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FocusAssetBadge(
                            kind: FocusAppIconKind.pomodoro,
                            color: FocusPalette.primary,
                            fallback: Icons.emoji_events_rounded,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sesión completada',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Decide por separado qué pasó con tu tarea y con tu objetivo de sesión.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (taskTitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _PostSessionDecisionCard(
                          icon: Icons.task_alt_rounded,
                          title: 'Tarea vinculada',
                          body: taskTitle,
                        ),
                      ],
                      if (sessionGoal.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _PostSessionDecisionCard(
                          icon: Icons.flag_rounded,
                          title: 'Objetivo de sesión',
                          body: sessionGoal,
                          trailing: Checkbox(
                            value: goalDone,
                            onChanged: (value) =>
                                refreshSheet(() => goalDone = value ?? false),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_note_rounded),
                        title: const Text('Agregar nota rapida'),
                        children: [
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Nota opcional',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (task != null)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.pop(sheetContext, 'completed'),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Completar tarea'),
                          ),
                        ),
                      if (task != null) const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (task != null)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, 'inProgress'),
                              icon: const Icon(Icons.trending_up_rounded),
                              label: const Text('Seguir con tarea'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.pop(sheetContext, 'another'),
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Otro bloque'),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, 'later'),
                        child: const Text('Seguir despues'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted || action == null || action == 'later') {
      noteController.dispose();
      return;
    }

    if (task != null) {
      await _appendQuickTaskNoteIfNeeded(task, noteController.text);
    }
    noteController.dispose();
    if (goalDone) await _clearSessionGoal();

    if (action == 'completed' && task != null) {
      await provider.completeStudyTask(task, true);
      await _clearLinkedTask();
      if (!mounted) return;
      showFocusFeedback(
        context,
        message: 'Tarea marcada como completada.',
        type: FocusFeedbackType.success,
        icon: Icons.check_circle_rounded,
      );
      return;
    }

    if (action == 'another') {
      if (task != null && !task.isDone) {
        await provider.updateStudyTask(_taskWithStatus(task, 'inProgress'));
      }
      if (!mounted) return;
      setState(() {
        _mode = 'focus';
        _setRemainingFromMode();
      });
      _startTimer();
      return;
    }

    if (task == null) return;
    await provider.updateStudyTask(_taskWithStatus(task, 'inProgress'));
    if (!mounted) return;
    showFocusFeedback(
      context,
      message: 'Tarea actualizada: en progreso.',
      type: FocusFeedbackType.info,
      icon: Icons.trending_up_rounded,
    );
  }

  Future<void> _showFocusTaskSheet([BuildContext? sheetHostContext]) async {
    final hostContext = sheetHostContext ?? context;
    final titleController = TextEditingController();
    final media = MediaQuery.of(hostContext);
    final isLandscape = media.size.width > media.size.height;
    try {
      if (isLandscape) {
        await showGeneralDialog<void>(
          context: hostContext,
          barrierDismissible: true,
          barrierLabel: 'Cerrar tareas',
          barrierColor: Colors.black.withValues(alpha: 0.34),
          transitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (dialogContext, animation, secondaryAnimation) {
            return SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 84, 12),
                  child: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.min(430.0, media.size.width * 0.48),
                        maxHeight: media.size.height - 24,
                      ),
                      child: _buildFocusTaskPanel(
                        dialogContext,
                        titleController,
                        compact: true,
                        onClose: () => Navigator.of(dialogContext).maybePop(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: hostContext,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
              child: _buildFocusTaskPanel(sheetContext, titleController),
            ),
          );
        },
      );
    } finally {
      titleController.dispose();
    }
  }

  Widget _buildFocusTaskPanel(
    BuildContext panelContext,
    TextEditingController titleController, {
    bool compact = false,
    VoidCallback? onClose,
  }) {
    return StatefulBuilder(
      builder: (context, refreshPanel) {
        return Consumer<AppProvider>(
          builder: (context, provider, _) {
            final tasks =
                provider.activeStudyTasks.take(compact ? 6 : 10).toList();
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(compact ? 24 : 28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 24 : 28),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 18,
                    compact ? 14 : 4,
                    compact ? 14 : 18,
                    compact ? 14 : 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FocusAssetBadge(
                            kind: FocusAppIconKind.tasks,
                            color: FocusPalette.primary,
                            fallback: Icons.task_alt_rounded,
                            size: compact ? 36 : 42,
                            iconSize: compact ? 20 : 23,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tarea de enfoque',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (onClose != null)
                            IconButton(
                              tooltip: 'Cerrar',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: onClose,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Nueva tarea',
                          isDense: true,
                          prefixIcon: const Icon(Icons.add_task_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Crear y vincular',
                            icon: const Icon(Icons.arrow_forward_rounded),
                            onPressed: () async {
                              final created = await _createQuickFocusTask(
                                provider,
                                titleController.text,
                              );
                              if (created == null) return;
                              titleController.clear();
                              await _linkTaskForPomodoro(created);
                              refreshPanel(() {});
                            },
                          ),
                        ),
                        onSubmitted: (value) async {
                          final created =
                              await _createQuickFocusTask(provider, value);
                          if (created == null) return;
                          titleController.clear();
                          await _linkTaskForPomodoro(created);
                          refreshPanel(() {});
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_linkedTaskId != null &&
                          _linkedTaskTitle.trim().isNotEmpty) ...[
                        _CurrentFocusTaskTile(
                          title: _linkedTaskTitle,
                          onClear: () async {
                            await _clearLinkedTask();
                            refreshPanel(() {});
                          },
                          onComplete: () async {
                            final task =
                                _studyTaskById(provider, _linkedTaskId!);
                            if (task == null) {
                              await _clearLinkedTask();
                            } else {
                              await provider.completeStudyTask(task, true);
                              await _clearLinkedTask();
                            }
                            refreshPanel(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Pendientes',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      if (tasks.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: FocusInsets.card,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(FocusRadii.card),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.38),
                          ),
                          child: const Text('Sin tareas pendientes.'),
                        )
                      else
                        ...tasks.map(
                          (task) => _FocusTaskSheetTile(
                            task: task,
                            selected: task.id == _linkedTaskId,
                            subjectName:
                                provider.getSubjectById(task.subjectId)?.name,
                            stats: _taskPomodoroHistoryLabel(provider, task),
                            onSelect: () async {
                              await _linkTaskForPomodoro(task);
                              refreshPanel(() {});
                            },
                            onComplete: () async {
                              await provider.completeStudyTask(task, true);
                              if (task.id == _linkedTaskId) {
                                await _clearLinkedTask();
                              }
                              refreshPanel(() {});
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
      },
    );
  }

  Future<StudyTask?> _createQuickFocusTask(
    AppProvider provider,
    String rawTitle,
  ) async {
    final title = rawTitle.trim();
    if (title.isEmpty) return null;
    final task = StudyTask(
      subjectId: _subjectIdForCurrentPomodoro(provider),
      title: title,
      dueDate: DateTime.now(),
      priority: 'medium',
      status: 'inProgress',
    );
    return provider.addStudyTask(task);
  }

  int? _subjectIdForCurrentPomodoro(AppProvider provider) {
    final selected = _selectedSubject.trim().toLowerCase();
    if (selected.isEmpty) return null;
    for (final subject in provider.subjects) {
      if (subject.name.trim().toLowerCase() == selected) return subject.id;
    }
    return null;
  }

  String _taskPomodoroHistoryLabel(AppProvider provider, StudyTask task) {
    final taskId = task.id;
    if (taskId == null) return '0 sesiones';
    final enfoques =
        provider.pomodoros.where((pomodoro) => pomodoro.taskId == taskId);
    final count = enfoques.length;
    final minutes = enfoques.fold<int>(
      0,
      (sum, pomodoro) => sum + pomodoro.duration,
    );
    if (count == 0) return '0 sesiones';
    return '$count ${count == 1 ? 'sesión' : 'sesiones'} · $minutes min';
  }

  StudyTask? _studyTaskById(AppProvider provider, int taskId) {
    for (final task in provider.studyTasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  StudyTask _taskWithStatus(StudyTask task, String status) {
    return StudyTask(
      id: task.id,
      subjectId: task.subjectId,
      title: task.title,
      notes: task.notes,
      dueDate: task.dueDate,
      priority: task.priority,
      status: status,
      createdAt: task.createdAt,
      completedAt:
          status == 'done' ? (task.completedAt ?? DateTime.now()) : null,
    );
  }

  Future<void> _appendQuickTaskNoteIfNeeded(
    StudyTask task,
    String rawNote,
  ) async {
    final note = rawNote.trim();
    if (note.isEmpty) return;
    final timestamp = formatDateTime(DateTime.now());
    final nextNotes = [
      if (task.notes.trim().isNotEmpty) task.notes.trim(),
      'Pomodoro $timestamp: $note',
    ].join('\n');
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.updateStudyTask(
      StudyTask(
        id: task.id,
        subjectId: task.subjectId,
        title: task.title,
        notes: nextNotes,
        dueDate: task.dueDate,
        priority: task.priority,
        status: task.status,
        createdAt: task.createdAt,
        completedAt: task.completedAt,
      ),
    );
  }

  Future<void> _clearLinkedTask() async {
    final hadTask = _linkedTaskTitle.trim().isNotEmpty;
    if (mounted) {
      setState(() {
        _linkedTaskId = null;
        _linkedTaskTitle = '';
      });
    } else {
      _linkedTaskId = null;
      _linkedTaskTitle = '';
    }
    await _persistState();
    if (hadTask && mounted) {
      showFocusFeedback(
        context,
        message: 'Tarea quitada del bloque.',
        type: FocusFeedbackType.info,
      );
    }
  }

  Future<void> _clearSessionGoal() async {
    final hadGoal = _sessionGoal.trim().isNotEmpty;
    _sessionGoalController.clear();
    if (mounted) {
      setState(() => _sessionGoal = '');
    } else {
      _sessionGoal = '';
    }
    await _persistState();
    if (hadGoal && mounted) {
      showFocusFeedback(
        context,
        message: 'Objetivo quitado.',
        type: FocusFeedbackType.info,
      );
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
                    'Modo Focus Total no pudo iniciarse. El Pomodoro sigue normal.',
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
                  'Activar permisos',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Para proteger sesión necesitás activar estos permisos.',
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
              return _buildCinematicHorizontalTimer(
                routeContext,
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

  bool get _isHorizontalDarkMode => _horizontalDarkModeEnabled;

  void _toggleHorizontalDarkMode(bool enabled) {
    setState(() => _horizontalDarkModeEnabled = enabled);
    _horizontalRefresh.value++;
    _persistState();
  }

  void _toggleHorizontalTickSound() {
    setState(() => _horizontalTickMuted = !_horizontalTickMuted);
    if (_horizontalTickMuted) {
      unawaited(_horizontalTickPlayer.stop());
    }
    _horizontalRefresh.value++;
    _persistState();
  }

  void _setHorizontalAnimation(int index) {
    setState(() => _horizontalAnimationIndex =
        index.clamp(0, _horizontalAnimations.length - 1).toInt());
    _horizontalRefresh.value++;
    _persistState();
  }

  Future<void> _showHorizontalSettings(BuildContext context) async {
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (settingsContext, _, __) {
          return StatefulBuilder(
            builder: (context, refreshSettings) {
              return Consumer<AppProvider>(
                builder: (context, provider, _) {
                  final style =
                      _horizontalTimerStyle(_mode, _isHorizontalDarkMode);
                  return Scaffold(
                    backgroundColor: style.settingsBackground,
                    body: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  iconSize: 36,
                                  color: style.primaryText,
                                  onPressed: () =>
                                      Navigator.of(settingsContext).maybePop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Ajustes',
                                  style: TextStyle(
                                    color: style.primaryText,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _HorizontalTimerSettingCard(
                                            title: 'Enfoque',
                                            value:
                                                '${provider.settings.focusTime} min',
                                            min: 5,
                                            max: 90,
                                            current:
                                                provider.settings.focusTime,
                                            accent: style.accent,
                                            dark: _isHorizontalDarkMode,
                                            onChanged: (value) {
                                              unawaited(
                                                _updatePomodoroSettings(
                                                  focusTime: value.round(),
                                                ),
                                              );
                                              refreshSettings(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _HorizontalTimerSettingCard(
                                            title: 'Descanso corto',
                                            value:
                                                '${provider.settings.shortBreakTime} min',
                                            min: 1,
                                            max: 30,
                                            current: provider
                                                .settings.shortBreakTime,
                                            accent: style.accent,
                                            dark: _isHorizontalDarkMode,
                                            onChanged: (value) {
                                              unawaited(
                                                _updatePomodoroSettings(
                                                  shortBreakTime: value.round(),
                                                ),
                                              );
                                              refreshSettings(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _HorizontalTimerSettingCard(
                                            title: 'Descanso largo',
                                            value:
                                                '${provider.settings.longBreakTime} min',
                                            min: 5,
                                            max: 60,
                                            current:
                                                provider.settings.longBreakTime,
                                            accent: style.accent,
                                            dark: _isHorizontalDarkMode,
                                            onChanged: (value) {
                                              unawaited(
                                                _updatePomodoroSettings(
                                                  longBreakTime: value.round(),
                                                ),
                                              );
                                              refreshSettings(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _HorizontalTimerSettingCard(
                                            title: 'Ciclos',
                                            value:
                                                '${provider.settings.pomodoroSessionsPerCycle} enfoques',
                                            min: 1,
                                            max: 8,
                                            current: provider.settings
                                                .pomodoroSessionsPerCycle,
                                            accent: style.accent,
                                            dark: _isHorizontalDarkMode,
                                            onChanged: (value) {
                                              unawaited(
                                                _updatePomodoroSettings(
                                                  pomodoroSessionsPerCycle:
                                                      value.round(),
                                                ),
                                              );
                                              refreshSettings(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _HorizontalTimerSettingCard(
                                            title: 'Sonido final',
                                            value: _completionOptionFor(
                                              provider.settings.sound,
                                            ).label,
                                            min: 0,
                                            max: (_completionSoundOptions
                                                        .length -
                                                    1)
                                                .toDouble(),
                                            current: _completionSoundOptions
                                                .indexWhere(
                                                  (option) =>
                                                      option.id ==
                                                      provider.settings.sound,
                                                )
                                                .clamp(
                                                  0,
                                                  _completionSoundOptions
                                                          .length -
                                                      1,
                                                ),
                                            accent: style.accent,
                                            dark: _isHorizontalDarkMode,
                                            divisions:
                                                _completionSoundOptions.length -
                                                    1,
                                            onChanged: (value) {
                                              final index = value.round().clamp(
                                                    0,
                                                    _completionSoundOptions
                                                            .length -
                                                        1,
                                                  );
                                              final option =
                                                  _completionSoundOptions[
                                                      index];
                                              unawaited(
                                                _updatePomodoroSettings(
                                                  sound: option.id,
                                                ),
                                              );
                                              unawaited(
                                                _previewCompletionSound(
                                                  option.id,
                                                ),
                                              );
                                              refreshSettings(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _HorizontalTimerSwitchCard(
                                            title: 'Auto iniciar',
                                            value: provider
                                                .settings.pomodoroAutoStartNext,
                                            accent: style.accent,
                                            dark: _isHorizontalDarkMode,
                                            onChanged: (value) {
                                              unawaited(
                                                _updatePomodoroSettings(
                                                  pomodoroAutoStartNext: value,
                                                ),
                                              );
                                              refreshSettings(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    _HorizontalTimerSwitchCard(
                                      title: 'Reloj sonoro',
                                      value: !_horizontalTickMuted,
                                      accent: style.accent,
                                      dark: _isHorizontalDarkMode,
                                      onChanged: (_) {
                                        _toggleHorizontalTickSound();
                                        refreshSettings(() {});
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _HorizontalTimerSwitchCard(
                                            title: 'Modo oscuro',
                                            value: _isHorizontalDarkMode,
                                            accent: style.accent,
                                            dark: _isHorizontalDarkMode,
                                            onChanged: (value) {
                                              _toggleHorizontalDarkMode(value);
                                              refreshSettings(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _HorizontalTimerSettingCard(
                                            title: 'Animación',
                                            value: _horizontalAnimations[
                                                    _horizontalAnimationIndex]
                                                .label,
                                            min: 0,
                                            max: (_horizontalAnimations.length -
                                                    1)
                                                .toDouble(),
                                            current: _horizontalAnimationIndex,
                                            divisions:
                                                _horizontalAnimations.length -
                                                    1,
                                            accent: style.accent,
                                            dark: _isHorizontalDarkMode,
                                            onChanged: (value) {
                                              _setHorizontalAnimation(
                                                value.round(),
                                              );
                                              refreshSettings(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showHorizontalPresetSheet(AppProvider provider) async {
    final presets = [
      const _PomodoroPreset('Pomodoro', 25, 5, 15),
      const _PomodoroPreset('Enfoque rápido', 15, 3, 10),
      const _PomodoroPreset('Trabajo profundo', 45, 10, 20),
      const _PomodoroPreset('Sesión de estudio', 30, 5, 15),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Presets',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca un bloque y cambia el ritmo completo.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                for (final preset in presets)
                  _PomodoroPresetTile(
                    preset: preset,
                    selected: provider.settings.focusTime == preset.focus &&
                        provider.settings.shortBreakTime == preset.shortBreak &&
                        provider.settings.longBreakTime == preset.longBreak,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      if (_isRunning) _pauseTimer();
                      await _updatePomodoroSettings(
                        focusTime: preset.focus,
                        shortBreakTime: preset.shortBreak,
                        longBreakTime: preset.longBreak,
                      );
                      if (!mounted) return;
                      setState(() {
                        _mode = 'focus';
                        _remainingSeconds = preset.focus * 60;
                      });
                      _refreshHorizontalMode();
                      await _persistState();
                    },
                  ),
              ],
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
    BuildContext routeContext, {
    required VoidCallback onExit,
  }) {
    final provider = Provider.of<AppProvider>(routeContext, listen: false);
    final modeStyle = _horizontalTimerStyle(_mode, _isHorizontalDarkMode);
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final taskLabel = _linkedTaskTitle.trim();
    final goalLabel = _sessionGoal.trim();
    final subject =
        _selectedSubject.trim().isEmpty ? 'General' : _selectedSubject.trim();

    return Scaffold(
      backgroundColor: modeStyle.background,
      body: Stack(
        children: [
          Positioned.fill(
              child: DecoratedBox(decoration: modeStyle.decoration)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 380;
                  final numberSize = math
                      .min(
                        constraints.maxWidth * 0.16,
                        (constraints.maxHeight - 170).clamp(150.0, 320.0) /
                            1.95,
                      )
                      .clamp(70.0, 134.0);
                  return Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _HorizontalTimerIconButton(
                          icon: provider.settings.ambientSound == 'none'
                              ? Icons.music_note_rounded
                              : Icons.graphic_eq_rounded,
                          color: modeStyle.accent,
                          selected: provider.settings.ambientSound != 'none',
                          onTap: () => _showAmbientSoundSheet(provider),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _HorizontalTimerIconButton(
                          icon: Icons.settings_rounded,
                          color: modeStyle.accent,
                          onTap: () => _showHorizontalSettings(routeContext),
                        ),
                      ),
                      Positioned(
                        top: compact ? 46 : 52,
                        right: 0,
                        child: _HorizontalTimerIconButton(
                          icon: _horizontalTickMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: modeStyle.accent,
                          selected: !_horizontalTickMuted,
                          onTap: _toggleHorizontalTickSound,
                        ),
                      ),
                      Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => _showHorizontalPresetSheet(
                                  provider,
                                ),
                                child: _HorizontalTimerModeBadge(
                                  label: modeStyle.label,
                                  icon: modeStyle.icon,
                                  accent: modeStyle.accent,
                                  foreground: modeStyle.badgeForeground,
                                ),
                              ),
                              SizedBox(height: compact ? 0 : 4),
                              AnimatedBuilder(
                                animation: _timerAuraController,
                                builder: (context, child) {
                                  final pulse = _horizontalAnimationIndex ==
                                              0 ||
                                          !_isRunning ||
                                          !provider.settings.animationsEnabled
                                      ? 0.0
                                      : math.sin(
                                          _timerAuraController.value *
                                              math.pi *
                                              2,
                                        );
                                  return Transform.translate(
                                    offset: Offset(0, pulse * 1.8),
                                    child: child,
                                  );
                                },
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _HorizontalTimerTimeText(
                                            value: minutes[0],
                                            color: modeStyle.timerText,
                                            size: numberSize,
                                          ),
                                          _HorizontalTimerTimeText(
                                            value: minutes[1],
                                            color: modeStyle.timerText,
                                            size: numberSize,
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _HorizontalTimerTimeText(
                                            value: seconds[0],
                                            color: modeStyle.timerText,
                                            size: numberSize,
                                          ),
                                          _HorizontalTimerTimeText(
                                            value: seconds[1],
                                            color: modeStyle.timerText,
                                            size: numberSize,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (taskLabel.isNotEmpty ||
                                  goalLabel.isNotEmpty ||
                                  subject != 'General') ...[
                                SizedBox(height: compact ? 0 : 4),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.62,
                                  ),
                                  child: Text(
                                    [
                                      if (taskLabel.isNotEmpty) taskLabel,
                                      if (goalLabel.isNotEmpty) goalLabel,
                                      if (subject != 'General') subject,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: modeStyle.secondaryText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: compact ? 11 : 13,
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: compact ? 8 : 14),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _HorizontalTimerSideControl(
                                    icon: Icons.refresh_rounded,
                                    color: modeStyle.accent,
                                    visible: _isRunning,
                                    onTap: () =>
                                        unawaited(_confirmResetTimer()),
                                  ),
                                  const SizedBox(width: 16),
                                  _HorizontalTimerPlayCard(
                                    running: _isRunning,
                                    accent: modeStyle.medium,
                                    iconColor: modeStyle.accent,
                                    onTap: _isRunning
                                        ? _pauseTimer
                                        : () => _startTimer(),
                                  ),
                                  const SizedBox(width: 16),
                                  _HorizontalTimerSideControl(
                                    icon: Icons.skip_next_rounded,
                                    color: modeStyle.accent,
                                    visible: _isRunning,
                                    onTap: () => unawaited(_completeSession()),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: Row(
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: modeStyle.accent,
                              ),
                              onPressed: onExit,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Volver'),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Tareas',
                              color: modeStyle.accent,
                              onPressed: _showFocusTaskSheet,
                              icon: const Icon(Icons.task_alt_rounded),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 4,
                        child: Text(
                          _horizontalSessionLabel(provider),
                          style: TextStyle(
                            color: modeStyle.primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
    _sessionGoalController.dispose();
    PomodoroTaskLaunchService.request.removeListener(_handleTaskLaunchRequest);
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
    final idleSubtitle = _mode == 'focus'
        ? 'Un bloque tranquilo y claro.'
        : _mode == 'shortBreak'
            ? 'Una pausa breve para respirar.'
            : 'Descansa un poco más.';

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isRunning ? modeTitle : _idleModeTitle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isRunning ? 'Sigue con calma.' : idleSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
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
                      IconButton(
                        tooltip: 'Más',
                        onPressed: () => _showPomodoroMoreSheet(provider),
                        icon: const Icon(Icons.more_horiz_rounded),
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
                                taskTitle: _linkedTaskTitle.trim(),
                                goal: _sessionGoal.trim(),
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
                                label: 'Breve',
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
                  if (!_isRunning && _mode == 'focus') ...[
                    FocusGap.md,
                    _PreStartActionBar(
                      taskTitle: _linkedTaskTitle,
                      subject: _selectedSubject.trim().isEmpty
                          ? 'General'
                          : _selectedSubject.trim(),
                      goal: _sessionGoal,
                      ambientEnabled: ambientEnabled,
                      protectEnabled: _focusModeConfig.enabled,
                      accent: themePalette.accent,
                      onTasks: _showFocusTaskSheet,
                      onGoal: _showSessionGoalSheet,
                      onSubject: () => _showSubjectQuickPicker(provider),
                      onAmbient: () => _showAmbientSoundSheet(provider),
                      onProtect: () =>
                          _toggleFocusModeEnabled(!_focusModeConfig.enabled),
                    ),
                  ],
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
                                          ? 'En curso'
                                          : 'Pausa activa',
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
                  if (_linkedTaskTitle.trim().isNotEmpty ||
                      _sessionGoal.trim().isNotEmpty) ...[
                    FocusMicroPop(
                      trigger:
                          'session-context-${_linkedTaskTitle.trim()}-${_sessionGoal.trim()}',
                      fromScale: 0.985,
                      child: _SessionContextCard(
                        accent: themePalette.accent,
                        taskTitle: _linkedTaskTitle.trim(),
                        goal: _sessionGoal.trim(),
                        onEditGoal: _showSessionGoalSheet,
                        onCompleteTask: _linkedTaskId == null
                            ? null
                            : () async {
                                final task =
                                    _studyTaskById(provider, _linkedTaskId!);
                                if (task == null) {
                                  await _clearLinkedTask();
                                } else {
                                  await provider.completeStudyTask(task, true);
                                  await _clearLinkedTask();
                                }
                              },
                        onClearGoal: (_isRunning || _sessionGoal.trim().isEmpty)
                            ? null
                            : _clearSessionGoal,
                        onClearTask: (_isRunning || _linkedTaskId == null)
                            ? null
                            : _clearLinkedTask,
                      ),
                    ),
                    FocusGap.sm,
                  ],
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
                          elevation: 0,
                          shadowColor:
                              themePalette.accent.withValues(alpha: 0.22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
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
                              ? 'Pausar'
                              : _mode == 'focus'
                                  ? 'Empezar bloque'
                                  : 'Empezar pausa',
                        ),
                      ),
                    ),
                  ),
                  FocusGap.sm,
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () =>
                                    unawaited(_confirmResetTimer()),
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
                child: FocusMicroPop(
                  trigger: 'today-sessions-${provider.pomodoros.length}',
                  fromScale: 0.99,
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
                      SizedBox(
                          height: 250, child: _buildTodaySessions(provider)),
                    ],
                  ),
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
                  final ambientSelected =
                      _ambientOptionFor(sheetProvider.settings.ambientSound);
                  final completionSelected =
                      _completionOptionFor(sheetProvider.settings.sound);

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
                          _PomodoroSettingsHeader(
                            isRunning: _isRunning,
                            modeTitle: _currentModeTitle(),
                          ),
                          FocusGap.lg,
                          _PomodoroSettingsSection(
                            icon: Icons.timer_rounded,
                            title: 'Tiempo',
                            subtitle:
                                '${sheetProvider.settings.focusTime}/${sheetProvider.settings.shortBreakTime}/${sheetProvider.settings.longBreakTime} min',
                            accent: FocusPalette.primary,
                            shape: BorderRadius.circular(FocusRadii.panel),
                            child: Column(
                              children: [
                                _PomodoroTimeStepperGrid(
                                  focusTime: sheetProvider.settings.focusTime,
                                  shortBreakTime:
                                      sheetProvider.settings.shortBreakTime,
                                  longBreakTime:
                                      sheetProvider.settings.longBreakTime,
                                  onFocusChanged: (value) =>
                                      _updatePomodoroSettings(
                                    focusTime: value,
                                  ),
                                  onShortBreakChanged: (value) =>
                                      _updatePomodoroSettings(
                                    shortBreakTime: value,
                                  ),
                                  onLongBreakChanged: (value) =>
                                      _updatePomodoroSettings(
                                    longBreakTime: value,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _MinuteStepper(
                                  label: 'Descanso largo cada',
                                  value: sheetProvider
                                      .settings.pomodoroSessionsPerCycle,
                                  min: 1,
                                  max: 8,
                                  unit: 'enfoques',
                                  color: FocusPalette.primary,
                                  onChanged: (value) => _updatePomodoroSettings(
                                    pomodoroSessionsPerCycle: value,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FocusGap.sm,
                          _PomodoroSettingsSection(
                            icon: Icons.music_note_rounded,
                            title: 'Sonidos',
                            subtitle:
                                '${ambientSelected.label} · ${completionSelected.label}',
                            accent: ambientSelected.color,
                            shape: BorderRadius.circular(FocusRadii.panel),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SimpleAmbientSoundControls(
                                  selected: ambientSelected,
                                  options: _ambientSoundOptions,
                                  volume: sheetProvider.settings.ambientVolume,
                                  isPreviewing: _previewingAmbientSound ==
                                          ambientSelected.id &&
                                      _ambientPreviewPlayer.playing,
                                  onSelected: (option) async {
                                    await _updatePomodoroSettings(
                                      ambientSound: option.id,
                                    );
                                    if (option.id == 'none') {
                                      await _stopAmbientPreview();
                                    } else {
                                      await _previewAmbientSound(
                                        option.id,
                                        volume: sheetProvider
                                            .settings.ambientVolume,
                                      );
                                    }
                                    refreshSheet(() {});
                                  },
                                  onVolumeChanged: ambientSelected.id == 'none'
                                      ? null
                                      : (value) {
                                          unawaited(
                                            _ambientPlayer.setVolume(value),
                                          );
                                          unawaited(
                                            _ambientPreviewPlayer
                                                .setVolume(value),
                                          );
                                          unawaited(
                                            _updatePomodoroSettings(
                                              ambientVolume: value,
                                            ),
                                          );
                                          refreshSheet(() {});
                                        },
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value:
                                      sheetProvider.settings.ambientDuringFocus,
                                  activeColor: ambientSelected.color,
                                  title: const Text('Reproducir en enfoque'),
                                  onChanged: ambientSelected.id == 'none'
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
                                  value: sheetProvider
                                      .settings.ambientDuringBreaks,
                                  activeColor: ambientSelected.color,
                                  title: const Text('Reproducir en descansos'),
                                  onChanged: ambientSelected.id == 'none'
                                      ? null
                                      : (value) async {
                                          await _updatePomodoroSettings(
                                            ambientDuringBreaks: value,
                                          );
                                          refreshSheet(() {});
                                        },
                                ),
                                const SizedBox(height: 8),
                                _CompactCompletionSoundPicker(
                                  selected: completionSelected,
                                  options: _completionSoundOptions,
                                  onSelected: (option) async {
                                    await _updatePomodoroSettings(
                                      sound: option.id,
                                    );
                                    await _previewCompletionSound(option.id);
                                    refreshSheet(() {});
                                  },
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Sonido del reloj'),
                                  subtitle: const Text(
                                    'Solo en modo horizontal.',
                                  ),
                                  value: !_horizontalTickMuted,
                                  onChanged: (_) {
                                    _toggleHorizontalTickSound();
                                    refreshSheet(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                          FocusGap.sm,
                          _PomodoroSettingsSection(
                            icon: Icons.tune_rounded,
                            title: 'Avanzado',
                            subtitle: 'Ciclo, auto inicio y modo horizontal',
                            accent: FocusPalette.teal,
                            shape: BorderRadius.circular(FocusRadii.panel),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      sheetProvider.settings.breakAfterFocus,
                                  decoration: const InputDecoration(
                                    labelText: 'Después del enfoque',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'auto',
                                      child: Text('Según ciclos'),
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
                                const SizedBox(height: 8),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Iniciar siguiente bloque'),
                                  subtitle: const Text(
                                    'Pasa de enfoque a descanso sin tocar iniciar.',
                                  ),
                                  value: sheetProvider
                                      .settings.pomodoroAutoStartNext,
                                  onChanged: (value) => _updatePomodoroSettings(
                                    pomodoroAutoStartNext: value,
                                  ),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.palette_rounded),
                                  title: const Text('Apariencia horizontal'),
                                  subtitle: const Text(
                                    'Tema y animación del reloj.',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () => _showHorizontalSettings(context),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.open_in_full_rounded,
                                  ),
                                  title: const Text('Abrir modo horizontal'),
                                  subtitle: const Text(
                                    'Vista inmersiva del temporizador.',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: _toggleHorizontalFocusMode,
                                ),
                              ],
                            ),
                          ),
                          FocusGap.sm,
                          _PomodoroSettingsSection(
                            icon: Icons.shield_rounded,
                            title: 'Bloqueo',
                            subtitle: _focusModeConfig.enabled
                                ? 'Protección activada'
                                : 'Proteger sesión es opcional',
                            accent: FocusPalette.primaryDeep,
                            shape: BorderRadius.circular(FocusRadii.panel),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildFocusModeTotalCard(sheetProvider),
                                const SizedBox(height: 12),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title:
                                      const Text('Activar bloqueo al estudiar'),
                                  subtitle: const Text(
                                    'Protege la sesión de apps que distraen.',
                                  ),
                                  value: _focusModeConfig.enabled,
                                  onChanged: _isTogglingFocusMode
                                      ? null
                                      : (value) =>
                                          _toggleFocusModeEnabled(value),
                                ),
                              ],
                            ),
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
      _refreshPomodoroSettingsSheet = null;
    }
  }

  Future<void> _showPomodoroMoreSheet(AppProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Más opciones',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Todo para preparar o ajustar este bloque.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                _PomodoroMoreAction(
                  icon: Icons.task_alt_rounded,
                  title: 'Tareas',
                  subtitle: _linkedTaskTitle.trim().isEmpty
                      ? 'Elegí o creá una tarea para este bloque.'
                      : _linkedTaskTitle.trim(),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showFocusTaskSheet();
                  },
                ),
                _PomodoroMoreAction(
                  icon: Icons.flag_rounded,
                  title: 'Objetivo',
                  subtitle: _sessionGoal.trim().isEmpty
                      ? 'Definí qué querés lograr.'
                      : _sessionGoal.trim(),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showSessionGoalSheet();
                  },
                ),
                _PomodoroMoreAction(
                  icon: Icons.menu_book_rounded,
                  title: 'Materia',
                  subtitle: _selectedSubject.trim().isEmpty
                      ? 'General'
                      : _selectedSubject.trim(),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showSubjectQuickPicker(provider);
                  },
                ),
                _PomodoroMoreAction(
                  icon: _focusModeConfig.enabled
                      ? Icons.shield_rounded
                      : Icons.shield_outlined,
                  title: 'Proteger sesión',
                  subtitle: _focusModeConfig.enabled
                      ? 'Bloqueo listo para estudiar.'
                      : 'Evitá distracciones mientras estudiás.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _toggleFocusModeEnabled(!_focusModeConfig.enabled);
                  },
                ),
                _PomodoroMoreAction(
                  icon: Icons.open_in_full_rounded,
                  title: 'Abrir horizontal',
                  subtitle: 'Vista inmersiva del reloj actual.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _toggleHorizontalFocusMode();
                  },
                ),
                _PomodoroMoreAction(
                  icon: Icons.palette_rounded,
                  title: 'Tema horizontal',
                  subtitle: 'Tema y movimiento del reloj.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showHorizontalSettings(context);
                  },
                ),
                _PomodoroMoreAction(
                  icon: Icons.tune_rounded,
                  title: 'Ajustes',
                  subtitle: 'Tiempo, ambiente y ritmo.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showPomodoroSettingsSheet(provider);
                  },
                ),
                if (!_isRunning &&
                    (_linkedTaskTitle.trim().isNotEmpty ||
                        _sessionGoal.trim().isNotEmpty))
                  _PomodoroMoreAction(
                    icon: Icons.layers_clear_rounded,
                    title: 'Limpiar contexto',
                    subtitle: 'Quita tarea y objetivo de esta sesión.',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _clearLinkedTask();
                      await _clearSessionGoal();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
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
                          Text(
                            'Ambiente',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Elige una vibra suave para acompañarte.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 14),
                          _SimpleAmbientSoundControls(
                            selected: selected,
                            options: _ambientSoundOptions,
                            volume: sheetProvider.settings.ambientVolume,
                            isPreviewing: isPreviewing,
                            onSelected: (option) async {
                              await _updatePomodoroSettings(
                                ambientSound: option.id,
                              );
                              if (option.id == 'none') {
                                await _stopAmbientPreview();
                              } else {
                                await _previewAmbientSound(
                                  option.id,
                                  volume: sheetProvider.settings.ambientVolume,
                                );
                              }
                              refreshSheet(() {});
                            },
                            onVolumeChanged: selected.id == 'none'
                                ? null
                                : (value) {
                                    unawaited(_ambientPlayer.setVolume(value));
                                    unawaited(
                                      _ambientPreviewPlayer.setVolume(value),
                                    );
                                    unawaited(
                                      _updatePomodoroSettings(
                                        ambientVolume: value,
                                      ),
                                    );
                                    refreshSheet(() {});
                                  },
                          ),
                          const SizedBox(height: 8),
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

  Future<void> _showSubjectQuickPicker(AppProvider provider) async {
    final subjects = provider.subjects;
    if (subjects.isEmpty) {
      setState(() => _selectedSubject = '');
      await _persistState();
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'Materia',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.layers_clear_rounded),
                title: const Text('General'),
                onTap: () => Navigator.pop(sheetContext, ''),
              ),
              for (final subject in subjects)
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: Text(subject.name),
                  selected: subject.name == _selectedSubject,
                  onTap: () => Navigator.pop(sheetContext, subject.name),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedSubject = selected);
    await _persistState();
    if (!mounted) return;
    showFocusFeedback(
      context,
      message: selected.trim().isEmpty
          ? 'Bloque general listo.'
          : 'Materia actualizada.',
      type: FocusFeedbackType.info,
    );
    unawaited(_syncPomodoroWidget(provider, force: true));
  }

  // ignore: unused_element
  Future<void> _showSessionGoalSheet() async {
    final controller = TextEditingController(text: _sessionGoal);
    try {
      final value = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Objetivo',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Qué quieres lograr',
                      hintText: 'Resolver 5 ejercicios',
                      prefixIcon: Icon(Icons.flag_rounded),
                    ),
                    onSubmitted: (_) =>
                        Navigator.pop(sheetContext, controller.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Es algo corto para esta sesión. No crea una tarea nueva.',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(sheetContext)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, ''),
                        child: const Text('Limpiar'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, controller.text),
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (value == null || !mounted) return;
      final previousGoal = _sessionGoal.trim();
      setState(() {
        _sessionGoal = value.trim();
        _sessionGoalController.text = _sessionGoal;
      });
      await _persistState();
      if (!mounted) return;
      final nextGoal = _sessionGoal.trim();
      if (nextGoal.isEmpty && previousGoal.isNotEmpty) {
        showFocusFeedback(
          context,
          message: 'Objetivo limpio.',
          type: FocusFeedbackType.info,
        );
      } else if (nextGoal.isNotEmpty) {
        showFocusFeedback(
          context,
          message: previousGoal.isEmpty
              ? 'Objetivo guardado.'
              : 'Objetivo actualizado.',
          type: FocusFeedbackType.success,
        );
      }
    } finally {
      controller.dispose();
    }
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
                  'Proteger sesión',
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
            isEnabled
                ? 'Evita distracciones mientras estudias. $appsLabel'
                : 'Evita distracciones mientras estudias.',
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
          backgroundStart: Color(0xFFF7FCF9),
          backgroundMiddle: Color(0xFFEEF9F3),
          backgroundEnd: Color(0xFFE3F4EA),
          surfaceTint: Color(0xFFF4FDF8),
        );
      case 'longBreak':
        return const _PomodoroPalette(
          accent: FocusPalette.amber,
          accentSecondary: FocusPalette.amber,
          backgroundStart: Color(0xFFFFFBF4),
          backgroundMiddle: Color(0xFFFFF5E6),
          backgroundEnd: Color(0xFFFFECCE),
          surfaceTint: Color(0xFFFFFAF2),
        );
      default:
        return const _PomodoroPalette(
          accent: FocusPalette.primary,
          accentSecondary: FocusPalette.cyan,
          backgroundStart: Color(0xFFF7FAFF),
          backgroundMiddle: Color(0xFFEEF4FF),
          backgroundEnd: Color(0xFFE5EEFF),
          surfaceTint: Color(0xFFFBFCFF),
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
  final String taskTitle;
  final String goal;
  final int blockedApps;
  final bool shieldActive;
  final Color accent;

  const _ActiveSessionStrip({
    required this.subject,
    required this.taskTitle,
    required this.goal,
    required this.blockedApps,
    required this.shieldActive,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final primaryText = taskTitle.isNotEmpty
            ? 'Trabajando en: $taskTitle'
            : goal.isNotEmpty
                ? 'Objetivo: $goal'
                : 'Materia: $subject';
        final secondaryText = [
          if (taskTitle.isNotEmpty && goal.isNotEmpty) goal,
          if (subject != 'General') subject,
        ].join(' · ');
        return Container(
          key: const ValueKey('active-session'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FocusRadii.card),
            color: accent.withValues(alpha: 0.07),
            border: Border.all(color: accent.withValues(alpha: 0.12)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            primaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (secondaryText.isNotEmpty) ...[
                      Text(
                        secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FocusPill(
                      icon: shieldActive
                          ? Icons.shield_rounded
                          : Icons.shield_outlined,
                      label: blockedApps == 0
                          ? 'Sin bloqueo'
                          : '$blockedApps apps',
                      color:
                          shieldActive ? FocusPalette.teal : FocusPalette.muted,
                      selected: shieldActive,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        primaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (secondaryText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    FocusPill(
                      icon: shieldActive
                          ? Icons.shield_rounded
                          : Icons.shield_outlined,
                      label: blockedApps == 0
                          ? 'Sin bloqueo'
                          : '$blockedApps apps',
                      color:
                          shieldActive ? FocusPalette.teal : FocusPalette.muted,
                      selected: shieldActive,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _PreStartActionBar extends StatelessWidget {
  final String taskTitle;
  final String subject;
  final String goal;
  final bool ambientEnabled;
  final bool protectEnabled;
  final Color accent;
  final VoidCallback onTasks;
  final VoidCallback onGoal;
  final VoidCallback onSubject;
  final VoidCallback onAmbient;
  final VoidCallback onProtect;

  const _PreStartActionBar({
    required this.taskTitle,
    required this.subject,
    required this.goal,
    required this.ambientEnabled,
    required this.protectEnabled,
    required this.accent,
    required this.onTasks,
    required this.onGoal,
    required this.onSubject,
    required this.onAmbient,
    required this.onProtect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTask = taskTitle.trim().isNotEmpty;
    final hasGoal = goal.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasTask ? Icons.task_alt_rounded : Icons.flag_rounded,
                  color: accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTask
                          ? taskTitle.trim()
                          : hasGoal
                              ? goal.trim()
                              : 'Prepará tu bloque',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: hasTask || hasGoal ? null : accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasTask && hasGoal
                          ? goal.trim()
                          : hasTask
                              ? 'Tarea elegida'
                              : hasGoal
                                  ? 'Objetivo definido'
                                  : 'Elegí una tarea u objetivo antes de empezar.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: hasTask ? onGoal : onTasks,
                icon: Icon(
                  hasTask ? Icons.flag_rounded : Icons.add_task_rounded,
                  size: 18,
                ),
                label: Text(hasTask ? 'Objetivo' : 'Elegir tarea'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SessionMiniAction(
                icon: Icons.flag_rounded,
                label: 'Objetivo',
                active: hasGoal,
                onTap: onGoal,
              ),
              _SessionMiniAction(
                icon: Icons.menu_book_rounded,
                label: 'Materia',
                active: subject != 'General',
                onTap: onSubject,
              ),
              _SessionMiniAction(
                icon: ambientEnabled
                    ? Icons.music_note_rounded
                    : Icons.music_off_rounded,
                label: 'Ambiente',
                active: ambientEnabled,
                onTap: onAmbient,
              ),
              _SessionMiniAction(
                icon: protectEnabled
                    ? Icons.shield_rounded
                    : Icons.shield_outlined,
                label: 'Proteger',
                active: protectEnabled,
                onTap: onProtect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionMiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SessionMiniAction({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? colorScheme.primary.withValues(alpha: 0.10)
              : colorScheme.surface.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? colorScheme.primary.withValues(alpha: 0.18)
                : colorScheme.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: active
                    ? colorScheme.primary.withValues(alpha: 0.14)
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PomodoroMoreAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PomodoroMoreAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FocusRadii.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface.withValues(alpha: 0.96),
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.42,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(FocusRadii.card),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rápido',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostSessionDecisionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;

  const _PostSessionDecisionCard({
    required this.icon,
    required this.title,
    required this.body,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _SessionContextCard extends StatelessWidget {
  final Color accent;
  final String taskTitle;
  final String goal;
  final Future<void> Function()? onEditGoal;
  final Future<void> Function()? onClearGoal;
  final Future<void> Function()? onCompleteTask;
  final Future<void> Function()? onClearTask;

  const _SessionContextCard({
    required this.accent,
    required this.taskTitle,
    required this.goal,
    this.onEditGoal,
    this.onClearGoal,
    this.onCompleteTask,
    this.onClearTask,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (taskTitle.isNotEmpty)
        _SessionContextPill(
          icon: Icons.task_alt_rounded,
          label: taskTitle,
          accent: accent,
        ),
      if (goal.isNotEmpty)
        _SessionContextPill(
          icon: Icons.flag_rounded,
          label: goal,
          accent: accent,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sesión actual',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tu contexto para este bloque.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          if (onEditGoal != null ||
              onClearGoal != null ||
              onCompleteTask != null ||
              onClearTask != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onEditGoal != null)
                  TextButton.icon(
                    onPressed: () => unawaited(onEditGoal!()),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Editar objetivo'),
                  ),
                if (onClearGoal != null)
                  TextButton.icon(
                    onPressed: () => unawaited(onClearGoal!()),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Quitar objetivo'),
                  ),
                if (onCompleteTask != null)
                  TextButton.icon(
                    onPressed: () => unawaited(onCompleteTask!()),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Completar'),
                  ),
                if (onClearTask != null)
                  TextButton.icon(
                    onPressed: () => unawaited(onClearTask!()),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Quitar'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionContextPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _SessionContextPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 17),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentFocusTaskTile extends StatelessWidget {
  final String title;
  final Future<void> Function() onClear;
  final Future<void> Function() onComplete;

  const _CurrentFocusTaskTile({
    required this.title,
    required this.onClear,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        color: FocusPalette.primary.withValues(alpha: 0.10),
        border: Border.all(color: FocusPalette.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_checked_rounded,
              color: FocusPalette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Completar',
            icon: const Icon(Icons.check_circle_rounded),
            color: FocusPalette.mint,
            onPressed: () => unawaited(onComplete()),
          ),
          IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => unawaited(onClear()),
          ),
        ],
      ),
    );
  }
}

class _FocusTaskSheetTile extends StatelessWidget {
  final StudyTask task;
  final bool selected;
  final String? subjectName;
  final String stats;
  final Future<void> Function() onSelect;
  final Future<void> Function() onComplete;

  const _FocusTaskSheetTile({
    required this.task,
    required this.selected,
    required this.subjectName,
    required this.stats,
    required this.onSelect,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final subject = subjectName?.trim();
    final detail = [
      if (subject != null && subject.isNotEmpty) subject,
      formatDate(task.dueDate),
      task.priorityLabel,
      stats,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        onTap: () => unawaited(onSelect()),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FocusRadii.card),
            color: selected
                ? FocusPalette.primary.withValues(alpha: 0.10)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.28),
            border: Border.all(
              color: selected
                  ? FocusPalette.primary.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? FocusPalette.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Completar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.check_rounded),
                color: FocusPalette.mint,
                onPressed: () => unawaited(onComplete()),
              ),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? color.withValues(alpha: 0.14)
              : theme.colorScheme.surface.withValues(alpha: 0.42),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.30)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? color : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PomodoroSettingsHeader extends StatelessWidget {
  final bool isRunning;
  final String modeTitle;

  const _PomodoroSettingsHeader({
    required this.isRunning,
    required this.modeTitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: FocusInsets.cardRelaxed,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(FocusRadii.panel),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: FocusPalette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(FocusRadii.control),
            ),
            child: const Icon(
              Icons.timer_rounded,
              color: FocusPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pomodoro',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  isRunning
                      ? '$modeTitle en curso. Algunos cambios se aplican al siguiente bloque.'
                      : 'Tiempo, sonidos, bloqueo y comportamiento del ciclo.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
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

class _PomodoroSettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;
  final BorderRadius shape;

  const _PomodoroSettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: shape,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _PomodoroTimeStepperGrid extends StatelessWidget {
  final int focusTime;
  final int shortBreakTime;
  final int longBreakTime;
  final ValueChanged<int> onFocusChanged;
  final ValueChanged<int> onShortBreakChanged;
  final ValueChanged<int> onLongBreakChanged;

  const _PomodoroTimeStepperGrid({
    required this.focusTime,
    required this.shortBreakTime,
    required this.longBreakTime,
    required this.onFocusChanged,
    required this.onShortBreakChanged,
    required this.onLongBreakChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final children = [
          _MinuteStepper(
            label: 'Enfoque',
            value: focusTime,
            min: 5,
            max: 90,
            color: FocusPalette.primary,
            onChanged: onFocusChanged,
          ),
          _MinuteStepper(
            label: 'Descanso corto',
            value: shortBreakTime,
            min: 1,
            max: 30,
            color: FocusPalette.mint,
            onChanged: onShortBreakChanged,
          ),
          _MinuteStepper(
            label: 'Descanso largo',
            value: longBreakTime,
            min: 5,
            max: 60,
            color: FocusPalette.amber,
            onChanged: onLongBreakChanged,
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _MinuteStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final Color color;
  final ValueChanged<int> onChanged;

  const _MinuteStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.unit = 'min',
    required this.color,
    required this.onChanged,
  });

  void _changeBy(int delta) {
    onChanged((value + delta).clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FocusRadii.control),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$value $unit',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          _TinyStepperButton(
            icon: Icons.remove_rounded,
            enabled: value > min,
            color: color,
            onTap: () => _changeBy(-1),
          ),
          const SizedBox(width: 6),
          _TinyStepperButton(
            icon: Icons.add_rounded,
            enabled: value < max,
            color: color,
            onTap: () => _changeBy(1),
          ),
        ],
      ),
    );
  }
}

class _TinyStepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _TinyStepperButton({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 19),
        ),
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

class _HorizontalTimerStyle {
  final String label;
  final IconData icon;
  final Color background;
  final Color backgroundAccent;
  final Color settingsBackground;
  final Color accent;
  final Color medium;
  final Color timerText;
  final Color primaryText;
  final Color secondaryText;
  final Color badgeForeground;

  const _HorizontalTimerStyle({
    required this.label,
    required this.icon,
    required this.background,
    required this.backgroundAccent,
    required this.settingsBackground,
    required this.accent,
    required this.medium,
    required this.timerText,
    required this.primaryText,
    required this.secondaryText,
    required this.badgeForeground,
  });

  BoxDecoration get decoration {
    return BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -0.12),
        radius: 1.05,
        colors: [
          backgroundAccent.withValues(alpha: 0.36),
          background,
          background,
        ],
      ),
    );
  }
}

_HorizontalTimerStyle _horizontalTimerStyle(String mode, bool dark) {
  if (mode == 'shortBreak') {
    return _HorizontalTimerStyle(
      label: 'Descanso corto',
      icon: Icons.coffee_rounded,
      background: dark ? const Color(0xFF07120E) : const Color(0xFFF7FFF9),
      backgroundAccent:
          dark ? const Color(0xFF134E3A) : const Color(0xFFDDF8E8),
      settingsBackground:
          dark ? const Color(0xFF000000) : const Color(0xFFEFFFF5),
      accent: dark ? const Color(0xFF52D99C) : const Color(0xFF178A58),
      medium: dark ? const Color(0xFF163B2D) : const Color(0xFFDFF5E9),
      timerText: dark ? const Color(0xFFF1FFF6) : const Color(0xFF104D25),
      primaryText: dark ? const Color(0xFFE9FFF5) : const Color(0xFF10281C),
      secondaryText: dark ? const Color(0xFF9DDDBE) : const Color(0xFF527765),
      badgeForeground: Colors.white,
    );
  }
  if (mode == 'longBreak') {
    return _HorizontalTimerStyle(
      label: 'Descanso largo',
      icon: Icons.local_cafe_rounded,
      background: dark ? const Color(0xFF08111C) : const Color(0xFFF6FAFF),
      backgroundAccent:
          dark ? const Color(0xFF173B68) : const Color(0xFFDDEBFF),
      settingsBackground:
          dark ? const Color(0xFF000000) : const Color(0xFFEAF5FF),
      accent: dark ? const Color(0xFF78B7FF) : const Color(0xFF2563EB),
      medium: dark ? const Color(0xFF142F52) : const Color(0xFFE4EEFF),
      timerText: dark ? const Color(0xFFE8F4FF) : const Color(0xFF173A5A),
      primaryText: dark ? const Color(0xFFEAF3FF) : const Color(0xFF0F1F37),
      secondaryText: dark ? const Color(0xFFA9CCF9) : const Color(0xFF5C7192),
      badgeForeground: Colors.white,
    );
  }
  return _HorizontalTimerStyle(
    label: 'Enfoque',
    icon: Icons.psychology_alt_rounded,
    background: dark ? const Color(0xFF190C0E) : const Color(0xFFFFF8F7),
    backgroundAccent: dark ? const Color(0xFF6B1B22) : const Color(0xFFFFE1DD),
    settingsBackground:
        dark ? const Color(0xFF000000) : const Color(0xFFF8EFEC),
    accent: dark ? const Color(0xFFFF6D6D) : const Color(0xFFD71923),
    medium: dark ? const Color(0xFF4A171C) : const Color(0xFFFFE6E4),
    timerText: dark ? const Color(0xFFFFF1F1) : const Color(0xFF591114),
    primaryText: dark ? const Color(0xFFFFEEEE) : const Color(0xFF211112),
    secondaryText: dark ? const Color(0xFFFFB5B5) : const Color(0xFF8B5C5D),
    badgeForeground: Colors.white,
  );
}

class _HorizontalTimerIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _HorizontalTimerIconButton({
    required this.icon,
    required this.color,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: selected ? 'Activo' : null,
      onPressed: onTap,
      icon: Icon(icon),
      color: color,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        backgroundColor: selected
            ? color.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.46),
      ),
    );
  }
}

class _HorizontalTimerModeBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final Color foreground;

  const _HorizontalTimerModeBadge({
    required this.label,
    required this.icon,
    required this.accent,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalTimerTimeText extends StatelessWidget {
  final String value;
  final Color color;
  final double size;

  const _HorizontalTimerTimeText({
    required this.value,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontSize: size,
        height: 0.9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _HorizontalTimerPlayCard extends StatelessWidget {
  final bool running;
  final Color accent;
  final Color iconColor;
  final VoidCallback onTap;

  const _HorizontalTimerPlayCard({
    required this.running,
    required this.accent,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 104,
          height: 78,
          child: Icon(
            running ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: iconColor,
            size: 48,
          ),
        ),
      ),
    );
  }
}

class _HorizontalTimerSideControl extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool visible;
  final VoidCallback onTap;

  const _HorizontalTimerSideControl({
    required this.icon,
    required this.color,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon),
          color: color,
          iconSize: 30,
        ),
      ),
    );
  }
}

class _PomodoroPreset {
  final String name;
  final int focus;
  final int shortBreak;
  final int longBreak;

  const _PomodoroPreset(
    this.name,
    this.focus,
    this.shortBreak,
    this.longBreak,
  );
}

class _PomodoroPresetTile extends StatelessWidget {
  final _PomodoroPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PomodoroPresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected
                ? FocusPalette.primary.withValues(alpha: 0.10)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? FocusPalette.primary.withValues(alpha: 0.28)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${preset.focus} min enfoque · ${preset.shortBreak} min breve · ${preset.longBreak} min largo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: FocusPalette.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalTimerSettingCard extends StatelessWidget {
  final String title;
  final String value;
  final double min;
  final double max;
  final num current;
  final int? divisions;
  final Color accent;
  final bool dark;
  final ValueChanged<double> onChanged;

  const _HorizontalTimerSettingCard({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.current,
    this.divisions,
    required this.accent,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = dark ? const Color(0xFF404040) : Colors.white;
    final textColor = dark ? Colors.white : Colors.black;
    final muted = dark ? const Color(0xFFECECEC) : const Color(0xFF151515);
    return Container(
      height: 132,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 14,
              activeTrackColor: accent,
              inactiveTrackColor: accent.withValues(alpha: dark ? 0.32 : 0.26),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.16),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: current.toDouble().clamp(min, max),
              min: min,
              max: max,
              divisions: divisions ?? (max - min).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalTimerSwitchCard extends StatelessWidget {
  final String title;
  final bool value;
  final Color accent;
  final bool dark;
  final ValueChanged<bool> onChanged;

  const _HorizontalTimerSwitchCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = dark ? const Color(0xFF404040) : Colors.white;
    final textColor = dark ? Colors.white : Colors.black;
    return Container(
      height: 96,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: accent.withValues(alpha: 0.28),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AmbientSoundOption {
  final String id;
  final String label;
  final String vibe;
  final String description;
  final IconData icon;
  final Color color;

  const _AmbientSoundOption({
    required this.id,
    required this.label,
    required this.vibe,
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

  const _CompactCompletionSoundPicker({
    required this.selected,
    required this.options,
    required this.onSelected,
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
              color: colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: colorScheme.primary,
              size: 21,
            ),
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
                      Expanded(child: Text(option.label)),
                      if (option.id == selected.id)
                        Icon(
                          Icons.check_rounded,
                          color: colorScheme.primary,
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

class _SimpleAmbientSoundControls extends StatelessWidget {
  final _AmbientSoundOption selected;
  final List<_AmbientSoundOption> options;
  final double volume;
  final bool isPreviewing;
  final ValueChanged<_AmbientSoundOption> onSelected;
  final ValueChanged<double>? onVolumeChanged;

  const _SimpleAmbientSoundControls({
    required this.selected,
    required this.options,
    required this.volume,
    required this.isPreviewing,
    required this.onSelected,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSound = selected.id != 'none';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(FocusRadii.card),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sonido de fondo',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Elegí una vibra para acompañar tu sesión.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final option in options)
                _AmbientCuteOptionChip(
                  option: option,
                  selected: option.id == selected.id,
                  onTap: () => onSelected(option),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected.color.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: selected.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        selected.icon,
                        color: selected.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: selected.color,
                            ),
                          ),
                          Text(
                            selected.vibe,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasSound)
                      FocusPill(
                        icon: isPreviewing
                            ? Icons.graphic_eq_rounded
                            : Icons.touch_app_rounded,
                        label: isPreviewing ? 'Probando' : 'Toca',
                        color: selected.color,
                        selected: isPreviewing,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selected.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
                if (hasSound) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Volumen',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Slider(
                          value: volume.clamp(0.0, 1.0),
                          min: 0,
                          max: 1,
                          divisions: 10,
                          activeColor: selected.color,
                          label: '${(volume * 100).round()}%',
                          onChanged: onVolumeChanged,
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${(volume * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientCuteOptionChip extends StatelessWidget {
  final _AmbientSoundOption option;
  final bool selected;
  final VoidCallback onTap;

  const _AmbientCuteOptionChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = option.id == 'none' ? 132.0 : 146.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? option.color.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? option.color.withValues(alpha: 0.32)
                : option.color.withValues(alpha: 0.12),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: option.color.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        option.color.withValues(alpha: selected ? 0.18 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(option.icon, size: 18, color: option.color),
                ),
                const Spacer(),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: option.color,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              option.label,
              style: TextStyle(
                color: option.color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.vibe,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: option.color.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
                fontSize: 12,
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
    label: 'Focus rojo',
    description: 'Chip compacto, reloj grande y rojo profundo.',
    icon: Icons.psychology_rounded,
    layout: _HorizontalTimerLayout.immersive,
    backgroundStart: Color(0xFFFFF2F2),
    backgroundEnd: Color(0xFFF2EAE4),
    vignetteColor: Color(0xFFFFF7F4),
    glow: Color(0xFFFF7C7C),
    accent: Color(0xFF471515),
    textColor: Color(0xFF471515),
    chipTextColor: Color(0xFFFFFFFF),
    panelColor: Color(0xFFFFBBBB),
    panelBorder: Color(0x33D71923),
    panelRadius: 50,
    shadowAlpha: 0.10,
  ),
  _HorizontalTheme(
    label: 'Break verde',
    description: 'Verde descanso, suave y limpio.',
    icon: Icons.local_cafe_rounded,
    layout: _HorizontalTimerLayout.immersive,
    backgroundStart: Color(0xFFF2FFF5),
    backgroundEnd: Color(0xFFEFF8EF),
    vignetteColor: Color(0xFFF8FFF9),
    glow: Color(0xFF8CE8A1),
    accent: Color(0xFF14401D),
    textColor: Color(0xFF14401D),
    chipTextColor: Color(0xFFFFFFFF),
    panelColor: Color(0xFF8CE8A1),
    panelBorder: Color(0x3327C300),
    panelRadius: 50,
    shadowAlpha: 0.10,
  ),
  _HorizontalTheme(
    label: 'Azul largo',
    description: 'Azul profundo para descanso largo, claro y respirable.',
    icon: Icons.nightlight_round,
    layout: _HorizontalTimerLayout.immersive,
    backgroundStart: Color(0xFFD9EEFF),
    backgroundEnd: Color(0xFFEAF6FF),
    vignetteColor: Color(0xFFF6FBFF),
    glow: Color(0xFF8BCAFF),
    accent: Color(0xFF153047),
    textColor: Color(0xFF153047),
    chipTextColor: Color(0xFFFFFFFF),
    panelColor: Color(0xFF8BCAFF),
    panelBorder: Color(0x332DA8F8),
    panelRadius: 50,
    shadowAlpha: 0.10,
  ),
  _HorizontalTheme(
    label: 'Dark',
    description: 'Oscuro, limpio y elegante para enfocarte sin ruido.',
    icon: Icons.dark_mode_rounded,
    layout: _HorizontalTimerLayout.immersive,
    isDark: true,
    backgroundStart: Color(0xFF171A20),
    backgroundEnd: Color(0xFF090B10),
    vignetteColor: Color(0xFF05070B),
    glow: Color(0xFF78C6FF),
    accent: Color(0xFF8ED0FF),
    textColor: Color(0xFFF5F8FF),
    chipTextColor: Color(0xFF0F1720),
    panelColor: Color(0xFF262C36),
    panelBorder: Color(0x3D9FC7E8),
    panelRadius: 50,
    shadowAlpha: 0.20,
  ),
];

const List<_HorizontalAnimation> _horizontalAnimations = [
  _HorizontalAnimation(
    id: 'none',
    label: 'Sin animación',
    icon: Icons.motion_photos_off_rounded,
    durationMs: 1,
    curve: Curves.linear,
  ),
  _HorizontalAnimation(
    id: 'slide',
    label: 'Suave',
    icon: Icons.keyboard_double_arrow_up_rounded,
    durationMs: 360,
    curve: Curves.easeOutCubic,
  ),
  _HorizontalAnimation(
    id: 'bounce',
    label: 'Dinámica',
    icon: Icons.auto_awesome_motion_rounded,
    durationMs: 390,
    curve: Curves.easeOutBack,
  ),
];

enum _HorizontalTimerLayout { immersive }

class _HorizontalTheme {
  final String label;
  final String description;
  final IconData icon;
  final _HorizontalTimerLayout layout;
  final bool isDark;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color vignetteColor;
  final Color glow;
  final Color accent;
  final Color textColor;
  final Color chipTextColor;
  final Color panelColor;
  final Color panelBorder;
  final double panelRadius;
  final double shadowAlpha;

  const _HorizontalTheme({
    required this.label,
    required this.description,
    required this.icon,
    required this.layout,
    this.isDark = false,
    required this.backgroundStart,
    required this.backgroundEnd,
    this.vignetteColor = Colors.black,
    required this.glow,
    required this.accent,
    required this.textColor,
    this.chipTextColor = Colors.black,
    required this.panelColor,
    required this.panelBorder,
    required this.panelRadius,
    required this.shadowAlpha,
  });
}

class _HorizontalAnimation {
  final String id;
  final String label;
  final IconData icon;
  final int durationMs;
  final Curve curve;

  const _HorizontalAnimation({
    required this.id,
    required this.label,
    required this.icon,
    required this.durationMs,
    required this.curve,
  });
}
