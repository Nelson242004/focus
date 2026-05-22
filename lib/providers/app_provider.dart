import 'dart:async';

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/app_settings.dart';
import '../models/exam.dart';
import '../models/habit.dart';
import '../models/pomodoro.dart';
import '../models/resource_link.dart';
import '../models/schedule.dart';
import '../models/study_task.dart';
import '../models/subject.dart';
import '../services/notification_service.dart';
import '../services/firebase_user_data_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/app_utils.dart';
import '../utils/resource_catalog.dart';

class UpcomingScheduleEntry {
  final Schedule schedule;
  final Subject subject;
  final DateTime startsAt;

  UpcomingScheduleEntry({
    required this.schedule,
    required this.subject,
    required this.startsAt,
  });
}

class AppProvider extends ChangeNotifier {
  List<Pomodoro> pomodoros = [];
  List<Habit> habits = [];
  List<Subject> subjects = [];
  List<Exam> exams = [];
  List<StudyTask> studyTasks = [];
  List<Schedule> schedules = [];
  List<ResourceLink> resources = [];
  AppSettings settings = AppSettings();
  bool isLoaded = false;
  Object? lastLoadError;

  static const List<ResourceLink> _defaultResources = [
    ResourceLink(
      title: 'Spotify - Playlists para estudiar',
      url:
          'https://open.spotify.com/playlist/3qfeW1jkJty0kQLwGouhBS?si=6t1Wi9isQIuH0gpzm0b3bw',
      category: 'playlist',
      isDefault: true,
    ),
    ResourceLink(
      title: 'YouTube - LoFi Girl',
      url: 'https://youtu.be/n2w3VdXRJjw?si=_xgYeoR6cVGo8lIE',
      category: 'playlist',
      isDefault: true,
    ),
    ResourceLink(
      title: 'Brain.fm',
      url: 'https://www.brain.fm/',
      category: 'playlist',
      isDefault: false,
    ),
    ResourceLink(
      title: 'Khan Academy',
      url: 'https://www.khanacademy.org/',
      category: 'course',
      isDefault: false,
    ),
    ResourceLink(
      title: 'Coursera',
      url: 'https://www.coursera.org/',
      category: 'course',
      isDefault: false,
    ),
    ResourceLink(
      title: 'edX',
      url: 'https://www.edx.org/',
      category: 'course',
      isDefault: false,
    ),
    ResourceLink(
      title: 'MIT OpenCourseWare',
      url: 'https://ocw.mit.edu/',
      category: 'course',
      isDefault: false,
    ),
    ResourceLink(
      title: 'TikTok-PoliCode',
      url: 'https://www.tiktok.com/@policode01',
      category: 'social',
      isDefault: true,
    ),
    ResourceLink(
      title: 'Instagram',
      url: 'https://www.instagram.com/nelson_spy?igsh=ZjhyMWJuY2poeGNv',
      category: 'social',
      isDefault: true,
    ),
    ResourceLink(
      title: 'Politécnica-Drive',
      url: 'https://drive.google.com/',
      category: 'tool',
      isDefault: true,
    ),
    ResourceLink(
      title: 'Notion',
      url: 'https://www.notion.so/',
      category: 'tool',
      isDefault: false,
    ),
    ResourceLink(
      title: 'Anki',
      url: 'https://apps.ankiweb.net/',
      category: 'tool',
      isDefault: false,
    ),
  ];

  final db = DatabaseHelper.instance;

  List<ResourceLink> get _catalogResources {
    final configured = ResourceCatalog.buildVisibleResources(subjects);
    return configured.isEmpty ? _defaultResources : configured;
  }

  Future<void> loadAllData() async {
    try {
      await Future.wait([
        _loadPomodoros(),
        _loadHabits(),
        _loadSubjects(),
        _loadSettings(),
        _loadExams(),
        _loadStudyTasks(),
        _loadSchedules(),
        _loadResources(),
      ]);
      _syncExamSubjectNames();
      await _syncExamNotifications();
    } catch (error, stackTrace) {
      lastLoadError = error;
      debugPrint('Focus loadAllData error: $error');
      debugPrintStack(stackTrace: stackTrace);
      // La app igual debe abrir para permitir backup o reparación.
    } finally {
      isLoaded = true;
      notifyListeners();
      await WidgetSyncService.syncFromProvider(this);
      await _syncRemoteProgressData();
    }
  }

  Future<void> _syncRemoteProgressData() async {
    try {
      await FirebaseUserDataService.syncProgressData(
        pomodoros: pomodoros,
        habits: habits,
      );
    } catch (error) {
      debugPrint('Focus remote progress sync skipped: $error');
    }
  }

  Future<void> _notifyAndSyncWidget() {
    notifyListeners();
    unawaited(WidgetSyncService.syncFromProvider(this));
    return Future.value();
  }

  Future<void> _loadPomodoros() async {
    pomodoros = await db.getAllPomodoros();
  }

  Future<void> _loadHabits() async {
    habits = await db.getAllHabits();
  }

  Future<void> _loadSubjects() async {
    subjects = await db.getAllSubjects();
  }

  Future<void> _loadSettings() async {
    settings = await db.getSettings();
  }

  Future<void> _loadExams() async {
    exams = await db.getAllExams();
  }

  Future<void> _loadStudyTasks() async {
    studyTasks = await db.getAllStudyTasks();
  }

  Future<void> _loadSchedules() async {
    schedules = await db.getAllSchedules();
  }

  Future<void> _loadResources() async {
    resources = await db.getAllResources();
  }

  Future<void> syncExamNotifications() async {
    if (!settings.notificationsEnabled) {
      for (final exam in exams) {
        if (exam.id != null) {
          try {
            await NotificationService.cancelExamNotifications(exam.id!);
          } catch (error) {
            debugPrint('Focus exam notification cancel skipped: $error');
          }
        }
      }
      return;
    }
    for (final exam in exams) {
      try {
        if (combineDateAndTime(exam.date, exam.startTime)
            .isAfter(DateTime.now())) {
          await _scheduleExamNotifications(exam);
        } else if (exam.id != null) {
          await NotificationService.cancelExamNotifications(exam.id!);
        }
      } catch (error) {
        debugPrint('Focus exam notification sync skipped: $error');
      }
    }
  }

  Future<void> _syncExamNotifications() => syncExamNotifications();

  Future<void> _scheduleExamNotifications(Exam exam) {
    return NotificationService.scheduleExamNotifications(
      exam,
      dayBefore: settings.examReminderDayBefore,
      twoHoursBefore: settings.examReminderTwoHoursBefore,
      thirtyMinutesBefore: settings.examReminderThirtyMinutesBefore,
    );
  }

  void _syncExamSubjectNames() {
    final subjectMap = {
      for (final subject in subjects)
        if (subject.id != null) subject.id!: subject.name
    };
    exams = exams.map((exam) {
      if (exam.subjectId != null && subjectMap.containsKey(exam.subjectId)) {
        exam.subject = subjectMap[exam.subjectId]!;
      }
      return exam;
    }).toList();
  }

  Subject? getSubjectById(int? id) {
    if (id == null) return null;
    for (final subject in subjects) {
      if (subject.id == id) return subject;
    }
    return null;
  }

  Subject? getSubjectByName(String name) {
    for (final subject in subjects) {
      if (subject.name.toLowerCase() == name.toLowerCase()) return subject;
    }
    return null;
  }

  String subjectNameForExam(Exam exam) {
    return getSubjectById(exam.subjectId)?.name ?? exam.subject;
  }

  Future<void> addPomodoro(Pomodoro p) async {
    final id = await db.insertPomodoro(p);
    p.id = id;
    await _loadPomodoros();
    await _runOptionalCloudSync(
      () => FirebaseUserDataService.savePomodoro(p),
      'save pomodoro',
    );
    await _notifyAndSyncWidget();
  }

  Future<void> deletePomodoro(int id) async {
    await db.deletePomodoro(id);
    await _loadPomodoros();
    await _runOptionalCloudSync(
      () => FirebaseUserDataService.deletePomodoro(id),
      'delete pomodoro',
    );
    await _notifyAndSyncWidget();
  }

  Future<void> addHabit(Habit h) async {
    final id = await db.insertHabit(h);
    h.id = id;
    await _loadHabits();
    await _runOptionalCloudSync(
      () => FirebaseUserDataService.saveHabit(h),
      'save habit',
    );
    await _notifyAndSyncWidget();
  }

  Future<void> updateHabit(Habit h) async {
    await db.updateHabit(h);
    await _loadHabits();
    await _runOptionalCloudSync(
      () => FirebaseUserDataService.saveHabit(h),
      'update habit',
    );
    await _notifyAndSyncWidget();
  }

  Future<void> deleteHabit(int id) async {
    await db.deleteHabit(id);
    await _loadHabits();
    await _runOptionalCloudSync(
      () => FirebaseUserDataService.deleteHabit(id),
      'delete habit',
    );
    await _notifyAndSyncWidget();
  }

  Future<void> _runOptionalCloudSync(
    Future<void> Function() action,
    String label,
  ) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Focus optional cloud sync skipped ($label): $error');
    }
  }

  List<ResourceLink> resourcesByCategory(String category, {int? subjectId}) {
    bool matches(ResourceLink resource) {
      if (resource.category != category) return false;
      return subjectId == null || resource.subjectId == subjectId;
    }

    final defaults = _catalogResources.where(matches);
    final userResources = resources.where(matches);
    return [...defaults, ...userResources];
  }

  List<ResourceLink> resourcesForSubject(int subjectId) {
    return [..._catalogResources, ...resources]
        .where((resource) => resource.subjectId == subjectId)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  Future<void> addResource(ResourceLink resource) async {
    await db.insertResource(resource);
    await _loadResources();
    await _notifyAndSyncWidget();
  }

  Future<void> deleteResource(int id) async {
    await db.deleteResource(id);
    await _loadResources();
    await _notifyAndSyncWidget();
  }

  Future<void> addStudyTask(StudyTask task) async {
    final normalized = _normalizeStudyTask(task);
    final id = await db.insertStudyTask(normalized);
    normalized.id = id;
    await _loadStudyTasks();
    await _notifyAndSyncWidget();
  }

  Future<void> updateStudyTask(StudyTask task) async {
    await db.updateStudyTask(_normalizeStudyTask(task));
    await _loadStudyTasks();
    await _notifyAndSyncWidget();
  }

  Future<void> completeStudyTask(StudyTask task, bool done) async {
    await updateStudyTask(
      StudyTask(
        id: task.id,
        subjectId: task.subjectId,
        title: task.title,
        notes: task.notes,
        dueDate: task.dueDate,
        priority: task.priority,
        status: done ? 'done' : 'pending',
        createdAt: task.createdAt,
        completedAt: done ? DateTime.now() : null,
      ),
    );
  }

  Future<void> deleteStudyTask(int id) async {
    await db.deleteStudyTask(id);
    await _loadStudyTasks();
    await _notifyAndSyncWidget();
  }

  StudyTask _normalizeStudyTask(StudyTask task) {
    final title = task.title.trim();
    if (title.isEmpty) {
      throw StateError('La tarea necesita un título.');
    }
    final subject = getSubjectById(task.subjectId);
    return StudyTask(
      id: task.id,
      subjectId: subject?.id,
      title: title,
      notes: task.notes.trim(),
      dueDate:
          DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day),
      priority: ['low', 'medium', 'high'].contains(task.priority)
          ? task.priority
          : 'medium',
      status: ['pending', 'inProgress', 'done'].contains(task.status)
          ? task.status
          : 'pending',
      createdAt: task.createdAt,
      completedAt: task.completedAt,
    );
  }

  void _ensureSubjectNameAvailable(String name, {int? ignoreId}) {
    final normalized = name.trim().toLowerCase();
    final exists = subjects.any((subject) {
      if (ignoreId != null && subject.id == ignoreId) return false;
      return subject.name.trim().toLowerCase() == normalized;
    });
    if (exists) {
      throw StateError('Ya existe una materia con ese nombre.');
    }
  }

  Future<Subject> addSubjectWithInitialSchedule(
    Subject subject,
    Schedule initialSchedule, {
    bool validateConflict = true,
  }) async {
    _ensureSubjectNameAvailable(subject.name);
    if (validateConflict && hasScheduleConflict(initialSchedule)) {
      throw StateError('Ese horario se cruza con otro bloque.');
    }
    try {
      final subjectId = await db.insertSubject(subject);
      final savedSubject = Subject(
        id: subjectId,
        name: subject.name,
        color: subject.color,
        icon: subject.icon,
        defaultClassroom: subject.defaultClassroom,
        professorName: subject.professorName,
        sectionCode: subject.sectionCode,
      );
      final scheduleToSave = Schedule(
        subjectId: subjectId,
        dayOfWeek: initialSchedule.dayOfWeek,
        startTime: initialSchedule.startTime,
        endTime: initialSchedule.endTime,
        classroom: initialSchedule.classroom,
      );
      await _loadSubjects();
      await db.insertSchedule(scheduleToSave);
      await _loadSubjects();
      await _loadSchedules();
      await _notifyAndSyncWidget();
      return savedSubject;
    } catch (_) {
      throw StateError('No se pudo guardar la materia.');
    }
  }

  Future<void> addSubject(Subject s) async {
    _ensureSubjectNameAvailable(s.name);
    try {
      final id = await db.insertSubject(s);
      s.id = id;
    } catch (_) {
      throw StateError('No se pudo guardar la materia.');
    }
    await _loadSubjects();
    await _notifyAndSyncWidget();
  }

  Future<void> updateSubject(Subject s) async {
    _ensureSubjectNameAvailable(s.name, ignoreId: s.id);
    await db.updateSubject(s);
    for (final exam in exams.where((exam) => exam.subjectId == s.id)) {
      exam.subject = s.name;
      await db.updateExam(exam);
      if (settings.notificationsEnabled) {
        try {
          await _scheduleExamNotifications(exam);
        } catch (error) {
          debugPrint('Focus exam notification reschedule skipped: $error');
        }
      }
    }
    await _loadSubjects();
    await _loadExams();
    await _loadStudyTasks();
    await _notifyAndSyncWidget();
  }

  Future<void> deleteSubject(int id) async {
    await db.deleteSubject(id);
    await _loadSubjects();
    await _loadSchedules();
    await _loadExams();
    await _loadStudyTasks();
    await _notifyAndSyncWidget();
  }

  bool hasScheduleConflict(Schedule candidate, {int? ignoreId}) {
    final start = timeToMinutes(candidate.startTime);
    final end = timeToMinutes(candidate.endTime);
    if (start < 0 || end < 0 || end <= start) return true;
    return schedules.any((schedule) {
      if (ignoreId != null && schedule.id == ignoreId) return false;
      if (schedule.dayOfWeek != candidate.dayOfWeek) return false;
      final existingStart = timeToMinutes(schedule.startTime);
      final existingEnd = timeToMinutes(schedule.endTime);
      return start < existingEnd && end > existingStart;
    });
  }

  Future<void> addSchedule(
    Schedule s, {
    bool validateConflict = true,
  }) async {
    if (s.dayOfWeek < 0 || s.dayOfWeek > 5) {
      throw StateError('Solo se permiten horarios de lunes a sábado.');
    }
    if (validateConflict && hasScheduleConflict(s)) {
      throw StateError('Ese horario se cruza con otro bloque.');
    }
    final id = await db.insertSchedule(s);
    s.id = id;
    await _loadSchedules();
    await _notifyAndSyncWidget();
  }

  Future<void> updateSchedule(
    Schedule s, {
    bool validateConflict = true,
  }) async {
    if (s.dayOfWeek < 0 || s.dayOfWeek > 5) {
      throw StateError('Solo se permiten horarios de lunes a sábado.');
    }
    if (validateConflict && hasScheduleConflict(s, ignoreId: s.id)) {
      throw StateError('Ese horario se cruza con otro bloque.');
    }
    await db.updateSchedule(s);
    await _loadSchedules();
    await _notifyAndSyncWidget();
  }

  Future<void> deleteSchedule(int id) async {
    await db.deleteSchedule(id);
    await _loadSchedules();
    await _notifyAndSyncWidget();
  }

  Future<List<Schedule>> getSchedulesForSubject(int subjectId) async {
    return schedules
        .where((schedule) => schedule.subjectId == subjectId)
        .toList();
  }

  List<Schedule> get weeklySchedulesMonToSat {
    return schedules
        .where((schedule) => schedule.dayOfWeek >= 0 && schedule.dayOfWeek <= 5)
        .toList()
      ..sort((a, b) {
        final dayComparison = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayComparison != 0) return dayComparison;
        return a.startTime.compareTo(b.startTime);
      });
  }

  Future<void> addExam(Exam e) async {
    final savedExam = _normalizeExam(e);
    final id = await db.insertExam(savedExam);
    savedExam.id = id;
    if (settings.notificationsEnabled) {
      try {
        await _scheduleExamNotifications(savedExam);
      } catch (error) {
        debugPrint('Focus exam notification schedule skipped: $error');
      }
    }
    await _loadExams();
    _syncExamSubjectNames();
    await _notifyAndSyncWidget();
  }

  Future<void> updateExam(Exam e) async {
    final normalized = _normalizeExam(e);
    await db.updateExam(normalized);
    if (normalized.id != null) {
      if (settings.notificationsEnabled) {
        try {
          await _scheduleExamNotifications(normalized);
        } catch (error) {
          debugPrint('Focus exam notification update skipped: $error');
        }
      } else {
        try {
          await NotificationService.cancelExamNotifications(normalized.id!);
        } catch (error) {
          debugPrint('Focus exam notification cancel skipped: $error');
        }
      }
    }
    await _loadExams();
    _syncExamSubjectNames();
    await _notifyAndSyncWidget();
  }

  Exam _normalizeExam(Exam exam) {
    final subject =
        getSubjectById(exam.subjectId) ?? getSubjectByName(exam.subject);
    return Exam(
      id: exam.id,
      subject: subject?.name ?? exam.subject.trim(),
      subjectId: subject?.id,
      examType: exam.examType,
      examLabel: exam.examLabel,
      date: exam.date,
      startTime: exam.startTime,
      classroom: exam.classroom.trim(),
    );
  }

  Future<void> deleteExam(int id) async {
    await db.deleteExam(id);
    try {
      await NotificationService.cancelExamNotifications(id);
    } catch (error) {
      debugPrint('Focus exam notification delete skipped: $error');
    }
    await _loadExams();
    await _notifyAndSyncWidget();
  }

  Future<void> clearAcademicData() async {
    for (final exam in exams) {
      if (exam.id != null) {
        await NotificationService.cancelExamNotifications(exam.id!);
      }
    }
    await db.clearAcademicData();
    await _loadSubjects();
    await _loadSchedules();
    await _loadExams();
    await _loadStudyTasks();
    await _loadResources();
    await _notifyAndSyncWidget();
  }

  Future<void> updateSettings(
    AppSettings newSettings, {
    bool syncNotifications = true,
  }) async {
    settings = newSettings;
    await db.updateSettings(settings);
    if (syncNotifications) {
      await _syncExamNotifications();
    }
    await _notifyAndSyncWidget();
  }

  AppSettings _settingsCopy({
    ThemeModeSetting? themeMode,
    AppLanguage? language,
    int? focusTime,
    int? shortBreakTime,
    int? longBreakTime,
    int? weeklyGoal,
    int? weeklyFocusMinutesGoal,
    int? dailyHabitGoal,
    int? streakGoal,
    String? sound,
    String? selectedIdentity,
    String? startScreen,
    double? textScale,
    bool? animationsEnabled,
    String? accentColor,
    bool? notificationsEnabled,
    bool? examReminderDayBefore,
    bool? examReminderTwoHoursBefore,
    bool? examReminderThirtyMinutesBefore,
    bool? onboardingCompleted,
    String? breakAfterFocus,
    String? userName,
  }) {
    return AppSettings(
      themeMode: themeMode ?? settings.themeMode,
      language: language ?? settings.language,
      focusTime: focusTime ?? settings.focusTime,
      shortBreakTime: shortBreakTime ?? settings.shortBreakTime,
      longBreakTime: longBreakTime ?? settings.longBreakTime,
      weeklyGoal: weeklyGoal ?? settings.weeklyGoal,
      weeklyFocusMinutesGoal:
          weeklyFocusMinutesGoal ?? settings.weeklyFocusMinutesGoal,
      dailyHabitGoal: dailyHabitGoal ?? settings.dailyHabitGoal,
      streakGoal: streakGoal ?? settings.streakGoal,
      sound: sound ?? settings.sound,
      selectedIdentity: selectedIdentity ?? settings.selectedIdentity,
      startScreen: startScreen ?? settings.startScreen,
      textScale: textScale ?? settings.textScale,
      animationsEnabled: animationsEnabled ?? settings.animationsEnabled,
      accentColor: accentColor ?? settings.accentColor,
      notificationsEnabled:
          notificationsEnabled ?? settings.notificationsEnabled,
      examReminderDayBefore:
          examReminderDayBefore ?? settings.examReminderDayBefore,
      examReminderTwoHoursBefore:
          examReminderTwoHoursBefore ?? settings.examReminderTwoHoursBefore,
      examReminderThirtyMinutesBefore: examReminderThirtyMinutesBefore ??
          settings.examReminderThirtyMinutesBefore,
      onboardingCompleted: onboardingCompleted ?? settings.onboardingCompleted,
      breakAfterFocus: breakAfterFocus ?? settings.breakAfterFocus,
      userName: userName ?? settings.userName,
    );
  }

  void toggleTheme() {
    final newTheme = settings.themeMode == ThemeModeSetting.light
        ? ThemeModeSetting.dark
        : ThemeModeSetting.light;
    settings = _settingsCopy(themeMode: newTheme);
    notifyListeners();
    unawaited(
      db.updateSettings(settings).catchError((Object error) {
        debugPrint('Focus theme save skipped: $error');
      }),
    );
  }

  Future<void> updateSelectedIdentity(String identity) async {
    await updateSettings(_settingsCopy(selectedIdentity: identity));
  }

  Future<void> updateUserName(String userName) async {
    await updateSettings(_settingsCopy(userName: userName.trim()));
  }

  Future<void> updateLanguage(AppLanguage language) async {
    await updateSettings(_settingsCopy(language: language));
  }

  Future<void> updateStartScreen(String startScreen) async {
    await updateSettings(_settingsCopy(startScreen: startScreen));
  }

  Future<void> updateTextScale(double textScale) async {
    await updateSettings(_settingsCopy(textScale: textScale));
  }

  Future<void> updateAnimationsEnabled(bool enabled) async {
    await updateSettings(_settingsCopy(animationsEnabled: enabled));
  }

  Future<void> updateAccentColor(String color) async {
    await updateSettings(_settingsCopy(accentColor: color));
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    await updateSettings(
      _settingsCopy(notificationsEnabled: enabled),
      syncNotifications: true,
    );
  }

  Future<void> completeOnboarding() async {
    await updateSettings(
      _settingsCopy(onboardingCompleted: true),
      syncNotifications: false,
    );
  }

  Future<void> clearAllData({bool reseed = true}) async {
    for (final exam in exams) {
      if (exam.id != null) {
        await NotificationService.cancelExamNotifications(exam.id!);
      }
    }
    await db.clearAll(reseed: reseed);
    try {
      await FirebaseUserDataService.clearProgressData();
    } catch (error) {
      debugPrint('Focus remote progress clear skipped: $error');
    }
    await loadAllData();
    if (reseed) {
      await updateSettings(
        _settingsCopy(onboardingCompleted: true),
        syncNotifications: false,
      );
    }
  }

  int get totalPoints => pomodoros.length * 20;
  int get totalHabitCompletions =>
      habits.fold<int>(0, (sum, habit) => sum + habit.history.length);
  int get rewardPoints => totalHabitCompletions * 12;
  int get achievementBonusPoints {
    var points = 0;
    if (pomodoros.isNotEmpty) points += 50;
    if (totalHabitCompletions >= 1) points += 25;
    if (pomodoros.length >= 5) points += 40;
    if (totalHabitCompletions >= 5) points += 40;
    if (currentStreak >= 3) points += 35;
    if (currentStreak >= 7) points += 100;
    if (currentStreak >= 14) points += 180;
    if (currentStreak >= 30) points += 400;
    if (pomodoros.length >= 25) points += 150;
    if (pomodoros.length >= 100) points += 600;
    if (weeklyMissionCompleted) points += 120;
    if (totalHabitCompletions >= 30) points += 180;
    if (totalHabitCompletions >= 75) points += 420;
    return points;
  }

  int get gamifiedPoints => totalPoints + rewardPoints + achievementBonusPoints;
  int get weeklyMissionTarget => 10;
  int get weeklyMissionProgressCount =>
      weeklyPomodoros.clamp(0, weeklyMissionTarget);
  bool get weeklyMissionCompleted => weeklyPomodoros >= weeklyMissionTarget;
  double get weeklyMissionProgress =>
      weeklyMissionProgressCount / weeklyMissionTarget;
  String get streakRewardTitle {
    if (currentStreak >= 30) return 'Racha legendaria';
    if (currentStreak >= 14) return 'Racha imparable';
    if (currentStreak >= 7) return 'Racha encendida';
    if (currentStreak >= 3) return 'Racha en marcha';
    return 'Primeros pasos';
  }

  int get unlockedAchievementCount => [
        pomodoros.isNotEmpty,
        totalHabitCompletions >= 1,
        pomodoros.length >= 5,
        totalHabitCompletions >= 5,
        currentStreak >= 3,
        currentStreak >= 7,
        currentStreak >= 14,
        currentStreak >= 30,
        pomodoros.length >= 25,
        pomodoros.length >= 100,
        weeklyMissionCompleted,
        totalHabitCompletions >= 30,
        totalHabitCompletions >= 75,
        level >= maxLevel,
      ].where((item) => item).length;

  int get currentStreak {
    final dates = <String>{
      ...pomodoros.map((p) => p.date.split('T')[0]),
      ...habits.expand((habit) => habit.history),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    if (dates.isEmpty) return 0;
    int streak = 0;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];
    if (!dates.contains(today) && !dates.contains(yesterday)) return 0;
    for (int i = 0; i < dates.length; i++) {
      if (i == 0 && (dates[i] == today || dates[i] == yesterday)) {
        streak = 1;
      } else {
        final prev = DateTime.parse(dates[i - 1]);
        final curr = DateTime.parse(dates[i]);
        if (prev.difference(curr).inDays == 1) {
          streak++;
        } else {
          break;
        }
      }
    }
    return streak;
  }

  static const int maxLevel = 5;
  static const int pointsPerLevel = 200;

  int get level =>
      ((gamifiedPoints / pointsPerLevel).floor() + 1).clamp(1, maxLevel);
  int get maxLevelPoints => (maxLevel - 1) * pointsPerLevel;
  int get nextLevelTarget =>
      level >= maxLevel ? maxLevelPoints : level * pointsPerLevel;
  int get previousLevelTarget => (level - 1) * 200;
  double get levelProgress {
    if (level >= maxLevel) return 1.0;
    final span = nextLevelTarget - previousLevelTarget;
    if (span <= 0) return 0;
    return ((gamifiedPoints - previousLevelTarget) / span).clamp(0.0, 1.0);
  }

  int get weeklyPomodoros {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return pomodoros
        .where((p) => !DateTime.parse(p.date).isBefore(startOfWeek))
        .length;
  }

  int get todayFocusMinutes {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return pomodoros
        .where((p) => p.date.startsWith(today))
        .fold(0, (sum, pomodoro) => sum + pomodoro.duration);
  }

  double get totalFocusHours =>
      pomodoros.fold<double>(0, (sum, pomodoro) => sum + pomodoro.duration) /
      60;
  double get weeklyFocusHours {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final minutes = pomodoros
        .where((p) => !DateTime.parse(p.date).isBefore(startOfWeek))
        .fold<int>(0, (sum, p) => sum + p.duration);
    return minutes / 60;
  }

  double get weeklyProgress =>
      settings.weeklyGoal > 0 ? weeklyPomodoros / settings.weeklyGoal : 0.0;

  List<StudyTask> get activeStudyTasks =>
      studyTasks.where((task) => !task.isDone).toList()
        ..sort(_compareStudyTasks);

  List<StudyTask> get overdueStudyTasks =>
      activeStudyTasks.where((task) => task.isOverdue).toList();

  List<StudyTask> get dueTodayStudyTasks {
    final now = DateTime.now();
    return activeStudyTasks
        .where((task) => DateUtils.isSameDay(task.dueDate, now))
        .toList();
  }

  List<StudyTask> upcomingStudyTasks({int limit = 5, int? subjectId}) {
    final items = activeStudyTasks
        .where((task) => subjectId == null || task.subjectId == subjectId)
        .toList()
      ..sort(_compareStudyTasks);
    return items.take(limit).toList();
  }

  int _compareStudyTasks(StudyTask a, StudyTask b) {
    if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
    final byDate = a.dueDate.compareTo(b.dueDate);
    if (byDate != 0) return byDate;
    return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
  }

  int _priorityRank(String priority) => switch (priority) {
        'high' => 0,
        'medium' => 1,
        _ => 2,
      };

  int focusMinutesForSubject(String subjectName) {
    final normalized = subjectName.trim().toLowerCase();
    return pomodoros
        .where(
            (pomodoro) => pomodoro.subject.trim().toLowerCase() == normalized)
        .fold(0, (sum, pomodoro) => sum + pomodoro.duration);
  }

  Subject? get mostStudiedSubject {
    Subject? best;
    var bestMinutes = -1;
    for (final subject in subjects) {
      final minutes = focusMinutesForSubject(subject.name);
      if (minutes > bestMinutes) {
        best = subject;
        bestMinutes = minutes;
      }
    }
    return best;
  }

  Exam? get nextUpcomingExam {
    final now = DateTime.now();
    final upcoming = exams
        .where((exam) =>
            !combineDateAndTime(exam.date, exam.startTime).isBefore(now))
        .toList()
      ..sort(
        (a, b) => combineDateAndTime(a.date, a.startTime)
            .compareTo(combineDateAndTime(b.date, b.startTime)),
      );
    return upcoming.isEmpty ? null : upcoming.first;
  }

  UpcomingScheduleEntry? get nextScheduleEntry {
    UpcomingScheduleEntry? best;
    for (final schedule in weeklySchedulesMonToSat) {
      final subject = getSubjectById(schedule.subjectId);
      if (subject == null) continue;
      final startsAt = _nextOccurrence(schedule);
      if (best == null || startsAt.isBefore(best.startsAt)) {
        best = UpcomingScheduleEntry(
            schedule: schedule, subject: subject, startsAt: startsAt);
      }
    }
    return best;
  }

  DateTime _nextOccurrence(Schedule schedule) {
    final now = DateTime.now();
    final minutes = timeToMinutes(schedule.startTime);
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    for (int offset = 0; offset < 7; offset++) {
      final candidate =
          DateTime(now.year, now.month, now.day + offset, hour, minute);
      final candidateDay = candidate.weekday - 1;
      if (candidateDay != schedule.dayOfWeek) continue;
      if (!candidate.isBefore(now)) return candidate;
    }
    return DateTime(now.year, now.month, now.day + 7, hour, minute);
  }
}
