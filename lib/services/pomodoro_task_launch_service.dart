import 'package:flutter/foundation.dart';

import '../models/study_task.dart';

class PomodoroTaskLaunchRequest {
  final int taskId;
  final int? subjectId;
  final String title;
  final DateTime requestedAt;

  PomodoroTaskLaunchRequest({
    required this.taskId,
    required this.subjectId,
    required this.title,
    required this.requestedAt,
  });
}

class PomodoroTaskLaunchService {
  static final ValueNotifier<PomodoroTaskLaunchRequest?> request =
      ValueNotifier<PomodoroTaskLaunchRequest?>(null);

  static void startFromTask(StudyTask task) {
    final id = task.id;
    if (id == null) return;
    request.value = PomodoroTaskLaunchRequest(
      taskId: id,
      subjectId: task.subjectId,
      title: task.title,
      requestedAt: DateTime.now(),
    );
  }

  static PomodoroTaskLaunchRequest? takePending() {
    final pending = request.value;
    request.value = null;
    return pending;
  }
}
