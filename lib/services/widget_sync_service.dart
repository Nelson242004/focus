import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/exam.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('focus_home_widget');

  static Future<void> syncFromProvider(AppProvider provider) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final nextClass = provider.nextScheduleEntry;
    final nextExam = provider.nextUpcomingExam;
    final nextExamAt = nextExam == null
        ? null
        : combineDateAndTime(nextExam.date, nextExam.startTime);

    final payload = <String, dynamic>{
      'widgetMode': _academicMode(nextExamAt),
      'classTitle': nextClass?.subject.name ?? 'Día libre por ahora',
      'classDetail': nextClass != null
          ? '${weekdayLabel(nextClass.schedule.dayOfWeek)} · ${nextClass.schedule.startTime} a ${nextClass.schedule.endTime}'
          : 'Abre Focus y organiza tu semana.',
      'examTitle':
          nextExam == null ? '' : provider.subjectNameForExam(nextExam),
      'examDetail': nextExam == null ? '' : _examDetail(nextExam),
      'examNote': nextExam == null ? '' : _examNote(nextExam),
      'examAtMillis': nextExamAt?.millisecondsSinceEpoch ?? 0,
      'meta': _streakLabel(provider.currentStreak),
    };

    try {
      await _channel.invokeMethod<void>('updateWidget', payload);
    } catch (error) {
      debugPrint('Widget sync skipped: $error');
    }
  }

  static Future<void> syncPomodoroState({
    required String mode,
    required bool isRunning,
    required int remainingSeconds,
    required int totalSeconds,
    required String subject,
    required int currentStreak,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final safeTotal = totalSeconds <= 0 ? 1 : totalSeconds;
    final ratio = (remainingSeconds / safeTotal).clamp(0.0, 1.0);
    final widgetMode = !isRunning
        ? 'idle'
        : mode == 'focus' && ratio <= 0.18
            ? 'almost_done'
            : mode == 'focus'
                ? 'pomodoro'
                : 'break';
    final label = mode == 'focus'
        ? 'Pomodoro activo'
        : mode == 'longBreak'
            ? 'Descanso largo'
            : 'Descanso corto';
    final title = mode == 'focus'
        ? (subject.trim().isEmpty ? 'General' : subject.trim())
        : 'Recarga energía';

    final payload = <String, dynamic>{
      'widgetMode': widgetMode,
      'classTitle': title,
      'classDetail': '${_formatDuration(remainingSeconds)} restantes',
      'examTitle': '',
      'examDetail': '',
      'examNote': label,
      'examAtMillis': 0,
      'meta': _streakLabel(currentStreak),
    };

    try {
      await _channel.invokeMethod<void>('updateWidget', payload);
    } catch (error) {
      debugPrint('Widget pomodoro sync skipped: $error');
    }
  }

  static String _examDetail(Exam exam) {
    final classroom = exam.classroom.trim();
    return classroom.isEmpty ? 'Aula por confirmar' : 'Aula $classroom';
  }

  static String _examNote(Exam exam) {
    return <String>[
      exam.displayType,
      if (exam.startTime.trim().isNotEmpty) exam.startTime,
    ].join(' · ');
  }

  static String _streakLabel(int streak) {
    if (streak == 1) return '1 día';
    return '$streak días';
  }

  static String _academicMode(DateTime? nextExamAt) {
    if (nextExamAt == null) return 'class';
    final remaining = nextExamAt.difference(DateTime.now());
    if (!remaining.isNegative && remaining <= const Duration(days: 1)) {
      return 'exam';
    }
    return 'class';
  }

  static String _formatDuration(int seconds) {
    final safeSeconds = seconds.clamp(0, 24 * 60 * 60);
    final minutes = safeSeconds ~/ 60;
    final remaining = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }
}
