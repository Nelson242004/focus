import '../models/exam.dart';

class NotificationService {
  NotificationService._();

  static Future<void> initialize() async {}

  static Future<bool> ensurePermissions() async => true;
  static Future<bool> hasPermissions() async => true;

  static Future<void> showTestNotification() async {}

  static Future<int> pendingNotificationsCount() async => 0;

  static Future<void> showPomodoroTimerNotification({
    required String mode,
    required int remainingSeconds,
    required int totalSeconds,
    required String subject,
  }) async {}

  static Future<void> cancelPomodoroTimerNotification() async {}

  static Future<void> scheduleExamNotifications(
    Exam exam, {
    bool dayBefore = true,
    bool twoHoursBefore = true,
    bool thirtyMinutesBefore = false,
  }) async {}

  static Future<void> cancelExamNotifications(int examId) async {}
}
