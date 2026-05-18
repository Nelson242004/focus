import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/exam.dart';
import '../models/habit.dart';
import '../models/pomodoro.dart';
import '../models/resource_link.dart';
import '../models/schedule.dart';
import '../models/study_task.dart';
import '../models/subject.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  DatabaseHelper._privateConstructor();

  static const _subjectsKey = 'web_subjects';
  static const _schedulesKey = 'web_schedules';
  static const _examsKey = 'web_exams';
  static const _pomodorosKey = 'web_pomodoros';
  static const _habitsKey = 'web_habits';
  static const _resourcesKey = 'web_resources';
  static const _studyTasksKey = 'web_study_tasks';
  static const _settingsKey = 'web_settings';
  static const _seededKey = 'web_seeded';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!(_prefs!.getBool(_seededKey) ?? false)) {
      await _seedDefaults(_prefs!);
    }
    return _prefs!;
  }

  Future<Object?> get database async => _preferences;

  Future<void> _seedDefaults(SharedPreferences prefs) async {
    await _writeCollection(
        _subjectsKey,
        [
          Subject(name: 'Matemáticas', color: '#3b82f6', icon: 'calculate')
              .toMap(),
          Subject(name: 'Programación', color: '#22c55e', icon: 'code').toMap(),
          Subject(name: 'Física', color: '#f59e0b', icon: 'science').toMap(),
        ],
        prefsOverride: prefs);
    await prefs.setInt(_sequenceKey(_subjectsKey), 3);
    await prefs.setString(_settingsKey, jsonEncode(AppSettings().toMap()));
    await prefs.setBool(_seededKey, true);
  }

  String _sequenceKey(String collectionKey) => '${collectionKey}_seq';

  Future<List<Map<String, dynamic>>> _readCollection(String key) async {
    final prefs = await _preferences;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _writeCollection(
    String key,
    List<Map<String, dynamic>> values, {
    SharedPreferences? prefsOverride,
  }) async {
    final prefs = prefsOverride ?? await _preferences;
    await prefs.setString(key, jsonEncode(values));
  }

  Future<int> _nextId(String key) async {
    final prefs = await _preferences;
    final seqKey = _sequenceKey(key);
    final next = (prefs.getInt(seqKey) ?? 0) + 1;
    await prefs.setInt(seqKey, next);
    return next;
  }

  int _compareText(dynamic a, dynamic b) =>
      '${a ?? ''}'.toLowerCase().compareTo('${b ?? ''}'.toLowerCase());

  Future<int> insertPomodoro(Pomodoro p) async {
    final items = await _readCollection(_pomodorosKey);
    final id = await _nextId(_pomodorosKey);
    items.add({...p.toMap(), 'id': id});
    await _writeCollection(_pomodorosKey, items);
    return id;
  }

  Future<List<Pomodoro>> getAllPomodoros() async {
    final items = await _readCollection(_pomodorosKey);
    items.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    return items.map(Pomodoro.fromMap).toList();
  }

  Future<int> deletePomodoro(int id) async {
    final items = await _readCollection(_pomodorosKey);
    final originalLength = items.length;
    items.removeWhere((item) => item['id'] == id);
    await _writeCollection(_pomodorosKey, items);
    return originalLength - items.length;
  }

  Future<int> insertHabit(Habit h) async {
    final items = await _readCollection(_habitsKey);
    final id = await _nextId(_habitsKey);
    items.add({...h.toMap(), 'id': id});
    await _writeCollection(_habitsKey, items);
    return id;
  }

  Future<List<Habit>> getAllHabits() async {
    final items = await _readCollection(_habitsKey);
    return items.map(Habit.fromMap).toList();
  }

  Future<int> updateHabit(Habit h) async {
    final items = await _readCollection(_habitsKey);
    final index = items.indexWhere((item) => item['id'] == h.id);
    if (index == -1) return 0;
    items[index] = h.toMap();
    await _writeCollection(_habitsKey, items);
    return 1;
  }

  Future<int> deleteHabit(int id) async {
    final items = await _readCollection(_habitsKey);
    final originalLength = items.length;
    items.removeWhere((item) => item['id'] == id);
    await _writeCollection(_habitsKey, items);
    return originalLength - items.length;
  }

  Future<int> insertResource(ResourceLink resource) async {
    final items = await _readCollection(_resourcesKey);
    final id = await _nextId(_resourcesKey);
    items.add({...resource.toMap(), 'id': id});
    await _writeCollection(_resourcesKey, items);
    return id;
  }

  Future<List<ResourceLink>> getAllResources() async {
    final items = await _readCollection(_resourcesKey);
    items.sort((a, b) {
      final byCategory = _compareText(a['category'], b['category']);
      if (byCategory != 0) return byCategory;
      return _compareText(a['title'], b['title']);
    });
    return items.map(ResourceLink.fromMap).toList();
  }

  Future<int> deleteResource(int id) async {
    final items = await _readCollection(_resourcesKey);
    final originalLength = items.length;
    items.removeWhere((item) => item['id'] == id);
    await _writeCollection(_resourcesKey, items);
    return originalLength - items.length;
  }

  Future<int> insertStudyTask(StudyTask task) async {
    final items = await _readCollection(_studyTasksKey);
    final id = await _nextId(_studyTasksKey);
    items.add({...task.toMap(), 'id': id});
    await _writeCollection(_studyTasksKey, items);
    return id;
  }

  Future<List<StudyTask>> getAllStudyTasks() async {
    final items = await _readCollection(_studyTasksKey);
    int priorityRank(Map<String, dynamic> item) => switch (item['priority']) {
          'high' => 0,
          'medium' => 1,
          _ => 2,
        };
    items.sort((a, b) {
      final byPriority = priorityRank(a).compareTo(priorityRank(b));
      if (byPriority != 0) return byPriority;
      return _compareText(a['dueDate'], b['dueDate']);
    });
    return items.map(StudyTask.fromMap).toList();
  }

  Future<int> updateStudyTask(StudyTask task) async {
    final items = await _readCollection(_studyTasksKey);
    final index = items.indexWhere((item) => item['id'] == task.id);
    if (index == -1) return 0;
    items[index] = task.toMap();
    await _writeCollection(_studyTasksKey, items);
    return 1;
  }

  Future<int> deleteStudyTask(int id) async {
    final items = await _readCollection(_studyTasksKey);
    final originalLength = items.length;
    items.removeWhere((item) => item['id'] == id);
    await _writeCollection(_studyTasksKey, items);
    return originalLength - items.length;
  }

  Future<int> insertSubject(Subject s) async {
    final items = await _readCollection(_subjectsKey);
    final id = await _nextId(_subjectsKey);
    items.add({...s.toMap(), 'id': id});
    await _writeCollection(_subjectsKey, items);
    return id;
  }

  Future<List<Subject>> getAllSubjects() async {
    final items = await _readCollection(_subjectsKey);
    items.sort((a, b) => _compareText(a['name'], b['name']));
    return items.map(Subject.fromMap).toList();
  }

  Future<int> updateSubject(Subject s) async {
    final items = await _readCollection(_subjectsKey);
    final index = items.indexWhere((item) => item['id'] == s.id);
    if (index == -1) return 0;
    items[index] = s.toMap();
    await _writeCollection(_subjectsKey, items);
    return 1;
  }

  Future<int> deleteSubject(int id) async {
    final subjects = await _readCollection(_subjectsKey);
    final schedules = await _readCollection(_schedulesKey);
    final exams = await _readCollection(_examsKey);
    final resources = await _readCollection(_resourcesKey);
    final tasks = await _readCollection(_studyTasksKey);
    final originalLength = subjects.length;
    subjects.removeWhere((item) => item['id'] == id);
    schedules.removeWhere((item) => item['subjectId'] == id);
    for (final exam in exams) {
      if (exam['subjectId'] == id) {
        exam['subjectId'] = null;
      }
    }
    for (final resource in resources) {
      if (resource['subjectId'] == id) {
        resource['subjectId'] = null;
      }
    }
    for (final task in tasks) {
      if (task['subjectId'] == id) {
        task['subjectId'] = null;
      }
    }
    await _writeCollection(_subjectsKey, subjects);
    await _writeCollection(_schedulesKey, schedules);
    await _writeCollection(_examsKey, exams);
    await _writeCollection(_resourcesKey, resources);
    await _writeCollection(_studyTasksKey, tasks);
    return originalLength - subjects.length;
  }

  Future<int> insertSchedule(Schedule s) async {
    final items = await _readCollection(_schedulesKey);
    final id = await _nextId(_schedulesKey);
    items.add({...s.toMap(), 'id': id});
    await _writeCollection(_schedulesKey, items);
    return id;
  }

  Future<List<Schedule>> getSchedulesBySubject(int subjectId) async {
    final items = await _readCollection(_schedulesKey);
    final filtered =
        items.where((item) => item['subjectId'] == subjectId).toList();
    filtered.sort((a, b) {
      final byDay = ('${a['dayOfWeek']}').compareTo('${b['dayOfWeek']}');
      if (byDay != 0) return byDay;
      return _compareText(a['startTime'], b['startTime']);
    });
    return filtered.map(Schedule.fromMap).toList();
  }

  Future<List<Schedule>> getAllSchedules() async {
    final items = await _readCollection(_schedulesKey);
    items.sort((a, b) {
      final dayA = int.tryParse('${a['dayOfWeek']}') ?? 0;
      final dayB = int.tryParse('${b['dayOfWeek']}') ?? 0;
      final byDay = dayA.compareTo(dayB);
      if (byDay != 0) return byDay;
      return _compareText(a['startTime'], b['startTime']);
    });
    return items.map(Schedule.fromMap).toList();
  }

  Future<int> updateSchedule(Schedule s) async {
    final items = await _readCollection(_schedulesKey);
    final index = items.indexWhere((item) => item['id'] == s.id);
    if (index == -1) return 0;
    items[index] = s.toMap();
    await _writeCollection(_schedulesKey, items);
    return 1;
  }

  Future<int> deleteSchedule(int id) async {
    final items = await _readCollection(_schedulesKey);
    final originalLength = items.length;
    items.removeWhere((item) => item['id'] == id);
    await _writeCollection(_schedulesKey, items);
    return originalLength - items.length;
  }

  Future<AppSettings> getSettings() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return AppSettings();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return AppSettings();
    return AppSettings.fromMap(Map<String, dynamic>.from(decoded));
  }

  Future<void> updateSettings(AppSettings settings) async {
    final prefs = await _preferences;
    await prefs.setString(_settingsKey, jsonEncode(settings.toMap()));
  }

  Future<int> insertExam(Exam e) async {
    final items = await _readCollection(_examsKey);
    final id = await _nextId(_examsKey);
    items.add({...e.toMap(), 'id': id});
    await _writeCollection(_examsKey, items);
    return id;
  }

  Future<List<Exam>> getAllExams() async {
    final items = await _readCollection(_examsKey);
    items.sort((a, b) {
      final byDate = _compareText(a['date'], b['date']);
      if (byDate != 0) return byDate;
      return _compareText(a['startTime'], b['startTime']);
    });
    return items.map(Exam.fromMap).toList();
  }

  Future<int> updateExam(Exam e) async {
    final items = await _readCollection(_examsKey);
    final index = items.indexWhere((item) => item['id'] == e.id);
    if (index == -1) return 0;
    items[index] = e.toMap();
    await _writeCollection(_examsKey, items);
    return 1;
  }

  Future<int> deleteExam(int id) async {
    final items = await _readCollection(_examsKey);
    final originalLength = items.length;
    items.removeWhere((item) => item['id'] == id);
    await _writeCollection(_examsKey, items);
    return originalLength - items.length;
  }

  Future<void> clearAcademicData() async {
    final prefs = await _preferences;
    await prefs.remove(_examsKey);
    await prefs.remove(_studyTasksKey);
    await prefs.remove(_schedulesKey);
    await prefs.remove(_subjectsKey);
    await prefs.remove(_resourcesKey);
  }

  Future<void> clearAll({bool reseed = true}) async {
    final prefs = await _preferences;
    await prefs.remove(_pomodorosKey);
    await prefs.remove(_habitsKey);
    await prefs.remove(_examsKey);
    await prefs.remove(_studyTasksKey);
    await prefs.remove(_resourcesKey);
    await prefs.remove(_schedulesKey);
    await prefs.remove(_subjectsKey);
    await prefs.remove(_settingsKey);
    await prefs.remove(_seededKey);
    await prefs.remove(_sequenceKey(_pomodorosKey));
    await prefs.remove(_sequenceKey(_habitsKey));
    await prefs.remove(_sequenceKey(_resourcesKey));
    await prefs.remove(_sequenceKey(_schedulesKey));
    await prefs.remove(_sequenceKey(_subjectsKey));
    await prefs.remove(_sequenceKey(_examsKey));
    await prefs.remove(_sequenceKey(_studyTasksKey));
    if (reseed) {
      await _seedDefaults(prefs);
    }
  }
}

