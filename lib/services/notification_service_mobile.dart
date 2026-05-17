import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/exam.dart';
import '../utils/app_utils.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const String _examChannelId = 'focus_exam_reminders';
  static const String _examChannelName = 'Recordatorios de exámenes';
  static const String _examChannelDescription =
      'Avisos automáticos antes de parciales y finales';
  static const String _pomodoroChannelId = 'focus_pomodoro_timer';
  static const String _pomodoroChannelName = 'Temporizador Pomodoro';
  static const String _pomodoroChannelDescription =
      'Muestra el contador activo del Pomodoro';
  static const int _pomodoroNotificationId = 880001;
  static const MethodChannel _nativeFocusChannel =
      MethodChannel('focus_mode_total');
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {}

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _examChannelId,
        _examChannelName,
        description: _examChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _pomodoroChannelId,
        _pomodoroChannelName,
        description: _pomodoroChannelDescription,
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    _initialized = true;
  }

  static Future<bool> ensurePermissions() async {
    await initialize();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notificationPermission =
        await androidPlugin?.requestNotificationsPermission();
    final exactAlarmPermission =
        await androidPlugin?.requestExactAlarmsPermission();

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosPermissions = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return (notificationPermission ?? true) &&
        (exactAlarmPermission ?? true) &&
        (iosPermissions ?? true);
  }

  static Future<bool> hasPermissions() async {
    await initialize();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notificationsEnabled =
        await androidPlugin?.areNotificationsEnabled() ?? true;
    bool exactAlarmAllowed = true;
    try {
      exactAlarmAllowed =
          await androidPlugin?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      exactAlarmAllowed = true;
    }

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    bool iosAllowed = true;
    try {
      final permissions = await iosPlugin?.checkPermissions();
      iosAllowed = permissions?.isEnabled ?? true;
    } catch (_) {
      iosAllowed = true;
    }

    return notificationsEnabled && exactAlarmAllowed && iosAllowed;
  }

  static Future<void> showTestNotification() async {
    await initialize();
    await _plugin.show(
      id: 999001,
      title: 'Prueba de notificación',
      body:
          'Si ves este aviso, Focus ya puede enviar recordatorios correctamente.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _examChannelId,
          _examChannelName,
          channelDescription: _examChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          ticker: 'Prueba de Focus',
          color: Color(0xFF1D4ED8),
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }

  static Future<int> pendingNotificationsCount() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  static Future<void> showPomodoroTimerNotification({
    required String mode,
    required int remainingSeconds,
    required int totalSeconds,
    required String subject,
  }) async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _nativeFocusChannel.invokeMethod('startPomodoroTimerNotification', {
        'mode': mode,
        'remainingSeconds': remainingSeconds,
        'totalSeconds': totalSeconds,
        'subject': subject.trim().isEmpty ? 'General' : subject.trim(),
      });
      return;
    }

    final isFocus = mode == 'focus';
    final isLongBreak = mode == 'longBreak';
    final modeLabel = isFocus
        ? 'Enfoque'
        : isLongBreak
            ? 'Descanso largo'
            : 'Descanso corto';
    final timeLeft = _formatDuration(remainingSeconds);
    final progress = totalSeconds <= 0
        ? 0
        : ((1 - (remainingSeconds / totalSeconds)) * 100).clamp(0, 100).round();
    final title = '$modeLabel · $timeLeft';
    final body = isFocus
        ? (subject.trim().isEmpty ? 'Materia: General' : subject.trim())
        : 'Descanso activo';

    await _plugin.show(
      id: _pomodoroNotificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _pomodoroChannelId,
          _pomodoroChannelName,
          icon: '@mipmap/ic_launcher',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          channelDescription: _pomodoroChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.progress,
          visibility: NotificationVisibility.public,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          showWhen: false,
          usesChronometer: false,
          chronometerCountDown: false,
          ticker: 'Focus activo',
          subText: body,
          color: isFocus ? const Color(0xFF2563EB) : const Color(0xFF10B981),
          playSound: false,
          enableVibration: false,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: body,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final safeSeconds = seconds.clamp(0, 24 * 60 * 60);
    final minutes = safeSeconds ~/ 60;
    final remaining = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  static Future<void> cancelPomodoroTimerNotification() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _nativeFocusChannel.invokeMethod('stopPomodoroTimerNotification');
    }
    await _plugin.cancel(id: _pomodoroNotificationId);
  }

  static Future<void> scheduleExamNotifications(
    Exam exam, {
    bool dayBefore = true,
    bool twoHoursBefore = true,
    bool thirtyMinutesBefore = false,
  }) async {
    if (exam.id == null) return;

    await initialize();
    await cancelExamNotifications(exam.id!);
    if (!dayBefore && !twoHoursBefore && !thirtyMinutesBefore) return;

    final hasDefinedTime = exam.startTime.trim().isNotEmpty;
    final examDateTime = combineExamDateAndTime(exam);
    final classroom =
        exam.classroom.trim().isEmpty ? 'aula por confirmar' : exam.classroom;
    final dayBeforeMoment = hasDefinedTime
        ? examDateTime.subtract(const Duration(days: 1))
        : DateTime(
            examDateTime.year,
            examDateTime.month,
            examDateTime.day - 1,
            20,
          );
    final reminders =
        <({int suffix, DateTime when, String title, String body})>[
      if (dayBefore)
        (
          suffix: 1,
          when: dayBeforeMoment,
          title: 'Examen mañana',
          body: hasDefinedTime
              ? '${exam.subject} mañana a las ${exam.startTime} en $classroom'
              : '${exam.subject} mañana con hora por confirmar en $classroom',
        ),
      if (hasDefinedTime && twoHoursBefore)
        (
          suffix: 2,
          when: examDateTime.subtract(const Duration(hours: 2)),
          title: 'Examen próximamente',
          body: '${exam.subject} hoy a las ${exam.startTime} en $classroom',
        ),
      if (hasDefinedTime && thirtyMinutesBefore)
        (
          suffix: 3,
          when: examDateTime.subtract(const Duration(minutes: 30)),
          title: 'Examen en 30 minutos',
          body: '${exam.subject} empieza a las ${exam.startTime} en $classroom',
        ),
    ];

    for (final reminder in reminders) {
      if (!reminder.when.isAfter(DateTime.now())) continue;

      await _plugin.zonedSchedule(
        id: exam.id! * 10 + reminder.suffix,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _examChannelId,
            _examChannelName,
            channelDescription: _examChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
            ticker: 'Recordatorio académico',
            color: const Color(0xFF1D4ED8),
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(reminder.body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancelExamNotifications(int examId) async {
    await initialize();
    await _plugin.cancel(id: examId * 10 + 1);
    await _plugin.cancel(id: examId * 10 + 2);
    await _plugin.cancel(id: examId * 10 + 3);
  }
}
