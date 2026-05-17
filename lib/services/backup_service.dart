import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/exam.dart';
import '../models/habit.dart';
import '../models/pomodoro.dart';
import '../models/resource_link.dart';
import '../models/schedule.dart';
import '../models/study_task.dart';
import '../models/subject.dart';
import '../providers/app_provider.dart';

class BackupExportResult {
  final String fileName;
  final int sizeInBytes;

  const BackupExportResult({
    required this.fileName,
    required this.sizeInBytes,
  });
}

class BackupService {
  BackupService._();

  static const String _appName = 'focus_app';
  static const int _formatVersion = 6;
  static const String _latestBackupStorageKey = 'focus_latest_backup_json';

  static String friendlyBackupError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission')) {
      return 'Focus no pudo acceder al archivo. Vuelve a intentarlo desde el selector.';
    }
    if (text.contains('format') ||
        text.contains('json') ||
        text.contains('unexpected')) {
      return 'Ese archivo no parece ser un backup válido de Focus. Exporta una copia desde Configuración e intenta otra vez.';
    }
    if (text.contains('no se encontró') || text.contains('cannot find')) {
      return 'No encontramos un backup reciente dentro de la app. Exporta una copia nueva o elige un archivo manualmente.';
    }
    return 'No se pudo completar la acción. Intenta otra vez o prueba con otro archivo.';
  }

  static Future<BackupExportResult> exportBackup(AppProvider provider) async {
    final data = <String, dynamic>{
      'app': _appName,
      'formatVersion': _formatVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'settings': _repairJsonText(provider.settings.toMap()),
      'pomodoros': provider.pomodoros
          .map((item) => _repairJsonText(item.toMap()))
          .toList(),
      'habits':
          provider.habits.map((item) => _repairJsonText(item.toMap())).toList(),
      'subjects': provider.subjects
          .map((item) => _repairJsonText(item.toMap()))
          .toList(),
      'schedules': provider.schedules
          .map((item) => _repairJsonText(item.toMap()))
          .toList(),
      'exams':
          provider.exams.map((item) => _repairJsonText(item.toMap())).toList(),
      'studyTasks': provider.studyTasks
          .map((item) => _repairJsonText(item.toMap()))
          .toList(),
      'resources': provider.resources
          .map((item) => _repairJsonText(item.toMap()))
          .toList(),
    };

    final encodedBackup = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = Uint8List.fromList(utf8.encode(encodedBackup));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_latestBackupStorageKey, encodedBackup);

    final date = DateTime.now().toIso8601String().split('T')[0];
    final fileName = 'focus_backup_$date.focusbackup.json';
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'application/json',
          name: fileName,
        ),
      ],
      subject: 'Backup de Focus',
      text:
          'Backup completo de Focus. Guarda este archivo para restaurarlo después.',
    );

    return BackupExportResult(
      fileName: fileName,
      sizeInBytes: bytes.length,
    );
  }

  static Future<Map<String, dynamic>?> latestBackupData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_latestBackupStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return readBackupText(raw);
  }

  static Future<Map<String, dynamic>> readBackupBytes(Uint8List bytes) async {
    final raw = utf8.decode(bytes).replaceFirst('\uFEFF', '');
    return readBackupText(raw);
  }

  static Map<String, dynamic> readBackupText(String raw) {
    final sanitized = raw.replaceFirst('\uFEFF', '');
    final decoded = jsonDecode(sanitized);
    if (decoded is! Map) {
      throw const FormatException('El backup no tiene formato de objeto.');
    }
    final data = Map<String, dynamic>.from(_repairJsonText(decoded) as Map);
    if (data['app'] != _appName) {
      throw Exception('El archivo seleccionado no pertenece a Focus.');
    }
    return data;
  }

  static Future<void> restoreBackupData(
    AppProvider provider,
    Map<String, dynamic> data,
  ) async {
    await provider.clearAllData(reseed: false);

    final importedSubjects = (data['subjects'] as List? ?? [])
        .map((item) => Subject.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedSchedules = (data['schedules'] as List? ?? [])
        .map((item) => Schedule.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedExams = (data['exams'] as List? ?? [])
        .map((item) => Exam.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedPomodoros = (data['pomodoros'] as List? ?? [])
        .map((item) => Pomodoro.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedHabits = (data['habits'] as List? ?? [])
        .map((item) => Habit.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedResources = (data['resources'] as List? ?? [])
        .map((item) =>
            ResourceLink.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedStudyTasks = (data['studyTasks'] as List? ?? [])
        .map(
            (item) => StudyTask.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    final oldToNewSubjectId = <int, int>{};
    final subjectScheduleMap = <int, List<Schedule>>{};
    for (final schedule in importedSchedules) {
      subjectScheduleMap
          .putIfAbsent(schedule.subjectId, () => [])
          .add(schedule);
    }

    for (final subject in importedSubjects) {
      final seedSchedules = subject.id != null
          ? (subjectScheduleMap[subject.id!] ?? [])
          : <Schedule>[];
      if (seedSchedules.isEmpty) {
        await provider.addSubject(
          Subject(
            name: subject.name,
            color: subject.color,
            icon: subject.icon,
            defaultClassroom: subject.defaultClassroom,
            professorName: subject.professorName,
            sectionCode: subject.sectionCode,
          ),
        );
        final created = provider.getSubjectByName(subject.name);
        if (subject.id != null && created?.id != null) {
          oldToNewSubjectId[subject.id!] = created!.id!;
        }
        continue;
      }

      final created = await provider.addSubjectWithInitialSchedule(
        Subject(
          name: subject.name,
          color: subject.color,
          icon: subject.icon,
          defaultClassroom: subject.defaultClassroom,
          professorName: subject.professorName,
          sectionCode: subject.sectionCode,
        ),
        Schedule(
          subjectId: -1,
          dayOfWeek: seedSchedules.first.dayOfWeek,
          startTime: seedSchedules.first.startTime,
          endTime: seedSchedules.first.endTime,
          classroom: seedSchedules.first.classroom,
        ),
        validateConflict: false,
      );
      if (subject.id != null && created.id != null) {
        oldToNewSubjectId[subject.id!] = created.id!;
      }
      for (final extra in seedSchedules.skip(1)) {
        await provider.addSchedule(
          Schedule(
            subjectId: created.id!,
            dayOfWeek: extra.dayOfWeek,
            startTime: extra.startTime,
            endTime: extra.endTime,
            classroom: extra.classroom,
          ),
          validateConflict: false,
        );
      }
    }

    for (final pomodoro in importedPomodoros) {
      await provider.addPomodoro(pomodoro);
    }
    for (final habit in importedHabits) {
      await provider.addHabit(
        Habit(
          name: habit.name,
          identity: habit.identity,
          history: habit.history,
          streak: habit.streak,
          createdAt: habit.createdAt,
        ),
      );
    }
    for (final exam in importedExams) {
      final subjectId = oldToNewSubjectId[exam.subjectId] ??
          provider.getSubjectByName(exam.subject)?.id;
      await provider.addExam(
        Exam(
          subject: exam.subject,
          subjectId: subjectId,
          examType: exam.examType,
          examLabel: exam.examLabel,
          date: exam.date,
          startTime: exam.startTime,
          classroom: exam.classroom,
        ),
      );
    }
    for (final task in importedStudyTasks) {
      await provider.addStudyTask(
        StudyTask(
          subjectId: oldToNewSubjectId[task.subjectId] ?? task.subjectId,
          title: task.title,
          notes: task.notes,
          dueDate: task.dueDate,
          priority: task.priority,
          status: task.status,
          createdAt: task.createdAt,
          completedAt: task.completedAt,
        ),
      );
    }
    for (final resource in importedResources) {
      await provider.addResource(
        ResourceLink(
          title: resource.title,
          url: resource.url,
          category: resource.category,
          subjectId:
              oldToNewSubjectId[resource.subjectId] ?? resource.subjectId,
        ),
      );
    }

    final importedSettings = data['settings'] != null
        ? AppSettings.fromMap(
            Map<String, dynamic>.from(data['settings'] as Map),
          )
        : provider.settings;
    importedSettings.onboardingCompleted = true;
    await provider.updateSettings(importedSettings);
  }

  static dynamic _repairJsonText(dynamic value) {
    if (value is String) return _repairText(value);
    if (value is List) return value.map(_repairJsonText).toList();
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _repairJsonText(entry.value),
      };
    }
    return value;
  }

  static String _repairText(String value) {
    const mojibakeMarker = '\u00C3';
    const latin1Marker = '\u00C2';
    const replacementMarker = '\uFFFD';
    if (!value.contains(mojibakeMarker) &&
        !value.contains(latin1Marker) &&
        !value.contains(replacementMarker)) {
      return value;
    }
    try {
      return utf8.decode(latin1.encode(value), allowMalformed: false);
    } catch (_) {
      return value
          .replaceAll('\u00C3\u00A1', 'á')
          .replaceAll('\u00C3\u00A9', 'é')
          .replaceAll('\u00C3\u00AD', 'í')
          .replaceAll('\u00C3\u00B3', 'ó')
          .replaceAll('\u00C3\u00BA', 'ú')
          .replaceAll('\u00C3\u00B1', 'ñ')
          .replaceAll('\u00C3\u0081', 'Á')
          .replaceAll('\u00C3\u0089', 'É')
          .replaceAll('\u00C3\u008D', 'Í')
          .replaceAll('\u00C3\u0093', 'Ó')
          .replaceAll('\u00C3\u009A', 'Ú')
          .replaceAll('\u00C3\u0091', 'Ñ')
          .replaceAll('\u00C2\u00BF', '¿')
          .replaceAll('\u00C2\u00A1', '¡')
          .replaceAll('\u00C2\u00B7', '·')
          .replaceAll(latin1Marker, '');
    }
  }
}
