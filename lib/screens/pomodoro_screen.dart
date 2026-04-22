import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/pomodoro.dart';
import '../providers/app_provider.dart';
import '../services/notification_service.dart';
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
  static const _cycleCountKey = 'pomodoro_cycle_count';
  static const _horizontalThemeKey = 'pomodoro_horizontal_theme';

  Timer? _timer;
  int _remainingSeconds = 25 * 60;
  String _mode = 'focus';
  bool _isRunning = false;
  bool _isLoading = true;
  bool _isHorizontalFocusMode = false;
  String _selectedSubject = '';
  int _completedFocusSessions = 0;
  int _horizontalThemeIndex = 0;
  late final AudioPlayer _audioPlayer;

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
      unawaited(
        NotificationService.showPomodoroTimerNotification(
          mode: _mode,
          remainingSeconds: _remainingSeconds,
          subject: _selectedSubject,
        ),
      );
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
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.subjects.isNotEmpty && _selectedSubject.isEmpty) {
      _selectedSubject = provider.subjects.first.name;
    }
    await _restoreState();
    if (_selectedSubject.isEmpty && provider.subjects.isNotEmpty) {
      _selectedSubject = provider.subjects.first.name;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  int _totalSecondsForMode(AppProvider provider, [String? mode]) {
    switch (mode ?? _mode) {
      case 'shortBreak':
        return provider.settings.shortBreakTime * 60;
      case 'longBreak':
        return provider.settings.longBreakTime * 60;
      default:
        return provider.settings.focusTime * 60;
    }
  }

  void _setRemainingFromMode() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _remainingSeconds = _totalSecondsForMode(provider);
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    _mode = prefs.getString(_modeKey) ?? 'focus';
    _selectedSubject = prefs.getString(_subjectKey) ?? _selectedSubject;
    _completedFocusSessions = prefs.getInt(_cycleCountKey) ?? 0;
    _horizontalThemeIndex = prefs.getInt(_horizontalThemeKey) ?? 0;
    _remainingSeconds =
        prefs.getInt(_remainingKey) ?? _totalSecondsForMode(provider);
    final wasRunning = prefs.getBool(_runningKey) ?? false;
    final savedAt = prefs.getInt(_savedAtKey);
    if (wasRunning && savedAt != null) {
      final elapsed = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(savedAt))
          .inSeconds;
      _remainingSeconds = (_remainingSeconds - elapsed)
          .clamp(0, _totalSecondsForMode(provider));
      if (_remainingSeconds > 0) {
        _startTimer(restored: true);
      } else {
        _setRemainingFromMode();
      }
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_remainingKey, _remainingSeconds);
    await prefs.setString(_modeKey, _mode);
    await prefs.setString(_subjectKey, _selectedSubject);
    await prefs.setBool(_runningKey, _isRunning);
    await prefs.setInt(_savedAtKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_cycleCountKey, _completedFocusSessions);
    await prefs.setInt(_horizontalThemeKey, _horizontalThemeIndex);
  }

  void _startTimer({bool restored = false}) {
    _timer?.cancel();
    if (mounted) {
      setState(() => _isRunning = true);
    } else {
      _isRunning = true;
    }
    if (!restored) {
      _persistState();
    }
    unawaited(
      NotificationService.showPomodoroTimerNotification(
        mode: _mode,
        remainingSeconds: _remainingSeconds,
        subject: _selectedSubject,
      ),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        _persistState();
      } else {
        _completeSession();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    unawaited(NotificationService.cancelPomodoroTimerNotification());
    if (mounted) {
      setState(() => _isRunning = false);
    } else {
      _isRunning = false;
    }
    _persistState();
  }

  void _resetTimer() {
    _pauseTimer();
    setState(_setRemainingFromMode);
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
    _timer?.cancel();
    if (mounted) {
      setState(() => _isRunning = false);
    } else {
      _isRunning = false;
    }
    final provider = Provider.of<AppProvider>(context, listen: false);
    await _playBell();

    if (_mode == 'focus') {
      if (_selectedSubject.isEmpty) {
        _selectedSubject = provider.subjects.isNotEmpty
            ? provider.subjects.first.name
            : 'General';
      }
      await provider.addPomodoro(
        Pomodoro(
          date: DateTime.now().toIso8601String(),
          subject: _selectedSubject,
          duration: provider.settings.focusTime,
        ),
      );
      _completedFocusSessions++;
      final nextMode = _nextBreakMode(provider);
      setState(() {
        _mode = nextMode;
        _setRemainingFromMode();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enfoque completado. Empieza ${nextMode == 'longBreak' ? 'el descanso largo' : 'el descanso corto'}.',
            ),
          ),
        );
      }
    } else {
      setState(() {
        _mode = 'focus';
        _setRemainingFromMode();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Descanso completado. Volvemos al enfoque.'),
          ),
        );
      }
    }

    _startTimer();
    await _persistState();
  }

  Future<void> _toggleHorizontalFocusMode() async {
    final next = !_isHorizontalFocusMode;
    setState(() => _isHorizontalFocusMode = next);
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
    }
  }

  void _setHorizontalTheme(int index) {
    setState(() => _horizontalThemeIndex = index);
    _persistState();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistState();
    }
  }

  @override
  void dispose() {
    _persistState();
    if (!_isRunning) {
      unawaited(NotificationService.cancelPomodoroTimerNotification());
    }
    _timer?.cancel();
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

    if (_isHorizontalFocusMode) {
      final horizontalTheme = _horizontalThemes[_horizontalThemeIndex];
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => _setHorizontalTheme(
            (_horizontalThemeIndex + 1) % _horizontalThemes.length,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        horizontalTheme.backgroundStart,
                        horizontalTheme.glow.withValues(alpha: 0.18),
                        horizontalTheme.backgroundEnd,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        horizontalTheme.glow.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                      radius: 0.9,
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _mode == 'focus'
                          ? 'Enfoque'
                          : _mode == 'shortBreak'
                              ? 'Descanso corto'
                              : 'Descanso largo',
                      style: TextStyle(
                        color: horizontalTheme.textColor.withValues(alpha: 0.7),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        _formatTime(_remainingSeconds),
                        key: ValueKey(_remainingSeconds),
                        style: TextStyle(
                          color: horizontalTheme.textColor,
                          fontSize: 150,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color:
                                  horizontalTheme.glow.withValues(alpha: 0.46),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: IconButton(
                  tooltip: 'Salir',
                  onPressed: _toggleHorizontalFocusMode,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final themePalette = _themePalette();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                              ? Icons.flash_on_rounded
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
                                  ? 'Bloque de enfoque'
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
                                  ? 'Tu ciclo sigue solo: enfoque, timbre, descanso y vuelta al estudio.'
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
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).cardColor,
                                themePalette.surfaceTint,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    themePalette.accent.withValues(alpha: 0.12),
                                blurRadius: 24,
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
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _mode == 'focus'
                                    ? 'Tiempo restante'
                                    : 'Cuenta regresiva',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: themePalette.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        onPressed:
                            _isRunning ? _pauseTimer : () => _startTimer(),
                        icon: Icon(
                          _isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(_isRunning ? 'Pausar' : 'Empezar'),
                      ),
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
            _glassCard(
              context,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurar Pomodoro',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ajusta tiempos, sonido y materia sin salir del temporizador.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
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
                      DropdownMenuItem(
                          value: 'none', child: Text('Sin sonido')),
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
                  if (subjects.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: subjects.any(
                        (subject) => subject.name == _selectedSubject,
                      )
                          ? _selectedSubject
                          : subjects.first.name,
                      decoration: const InputDecoration(
                        labelText: 'Materia asociada',
                      ),
                      items: subjects
                          .map(
                            (subject) => DropdownMenuItem(
                              value: subject.name,
                              child: Text(subject.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedSubject = value ?? '');
                        if (_isRunning) {
                          unawaited(
                            NotificationService.showPomodoroTimerNotification(
                              mode: _mode,
                              remainingSeconds: _remainingSeconds,
                              subject: _selectedSubject,
                            ),
                          );
                        }
                        _persistState();
                      },
                    ),
                  ],
                ],
              ),
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

  _PomodoroPalette _themePalette() {
    switch (_mode) {
      case 'shortBreak':
        return const _PomodoroPalette(
          accent: Color(0xFF10B981),
          accentSecondary: Color(0xFF34D399),
          backgroundStart: Color(0xFFF0FDF4),
          backgroundMiddle: Color(0xFFE6FCF3),
          backgroundEnd: Color(0xFFD1FAE5),
          surfaceTint: Color(0xFFF3FFFB),
        );
      case 'longBreak':
        return const _PomodoroPalette(
          accent: Color(0xFFF59E0B),
          accentSecondary: Color(0xFFFB923C),
          backgroundStart: Color(0xFFFFFBEB),
          backgroundMiddle: Color(0xFFFFF1D6),
          backgroundEnd: Color(0xFFFDE68A),
          surfaceTint: Color(0xFFFFF8EB),
        );
      default:
        return const _PomodoroPalette(
          accent: Color(0xFF2563EB),
          accentSecondary: Color(0xFF7C3AED),
          backgroundStart: Color(0xFFF8FAFC),
          backgroundMiddle: Color(0xFFEFF6FF),
          backgroundEnd: Color(0xFFE0EAFF),
          surfaceTint: Color(0xFFF8FBFF),
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
