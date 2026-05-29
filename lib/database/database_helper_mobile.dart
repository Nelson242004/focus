import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'focus_app.db');
    return openDatabase(
      path,
      version: 16,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pomodoros(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            subject TEXT NOT NULL,
            duration INTEGER NOT NULL,
            taskId INTEGER,
            taskTitle TEXT NOT NULL DEFAULT '',
            sessionGoal TEXT NOT NULL DEFAULT '',
            goalAchieved INTEGER,
            note TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE habits(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            identity TEXT NOT NULL DEFAULT 'Soy alguien que cumple incluso cuando no tiene ganas.',
            streak INTEGER DEFAULT 0,
            history TEXT,
            createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await db.execute('''
          CREATE TABLE subjects(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            color TEXT NOT NULL,
            icon TEXT,
            defaultClassroom TEXT,
            professorName TEXT,
            sectionCode TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE exams(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            subject TEXT NOT NULL,
            subjectId INTEGER,
            examType TEXT NOT NULL DEFAULT 'partial',
            examLabel TEXT,
            date TEXT NOT NULL,
            startTime TEXT NOT NULL DEFAULT '08:00',
            classroom TEXT NOT NULL DEFAULT '',
            weight REAL NOT NULL,
            grade REAL,
            minPassingGrade REAL NOT NULL,
            FOREIGN KEY(subjectId) REFERENCES subjects(id) ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE schedules(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subjectId INTEGER NOT NULL,
            dayOfWeek INTEGER NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT NOT NULL,
            classroom TEXT NOT NULL,
            FOREIGN KEY(subjectId) REFERENCES subjects(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE resources(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            url TEXT NOT NULL,
            category TEXT NOT NULL,
            subjectId INTEGER,
            FOREIGN KEY(subjectId) REFERENCES subjects(id) ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE study_tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subjectId INTEGER,
            title TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            dueDate TEXT NOT NULL,
            priority TEXT NOT NULL DEFAULT 'medium',
            status TEXT NOT NULL DEFAULT 'pending',
            createdAt TEXT NOT NULL,
            completedAt TEXT,
            FOREIGN KEY(subjectId) REFERENCES subjects(id) ON DELETE SET NULL
          )
        ''');
        await _insertDefaultData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS schedules(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subjectId INTEGER NOT NULL,
              dayOfWeek INTEGER NOT NULL,
              startTime TEXT NOT NULL,
              endTime TEXT NOT NULL,
              classroom TEXT NOT NULL,
              FOREIGN KEY(subjectId) REFERENCES subjects(id) ON DELETE CASCADE
            )
          ''');
          await _safeAlter(
            db,
            'ALTER TABLE subjects ADD COLUMN defaultClassroom TEXT',
          );
        }
        if (oldVersion < 5) {
          await _safeAlter(
              db, 'ALTER TABLE exams ADD COLUMN subjectId INTEGER');
          await db.rawUpdate('''
            UPDATE exams
            SET subjectId = (
              SELECT subjects.id
              FROM subjects
              WHERE subjects.name = exams.subject
              LIMIT 1
            )
            WHERE subjectId IS NULL
          ''');
        }
        if (oldVersion < 6) {
          await _safeAlter(
            db,
            "ALTER TABLE exams ADD COLUMN examType TEXT NOT NULL DEFAULT 'partial'",
          );
        }
        if (oldVersion < 7) {
          await _safeAlter(
            db,
            "ALTER TABLE exams ADD COLUMN startTime TEXT NOT NULL DEFAULT '08:00'",
          );
          await _safeAlter(
            db,
            "ALTER TABLE exams ADD COLUMN classroom TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS resources(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              url TEXT NOT NULL,
              category TEXT NOT NULL,
              subjectId INTEGER,
              FOREIGN KEY(subjectId) REFERENCES subjects(id) ON DELETE SET NULL
            )
          ''');
        }
        if (oldVersion < 9) {
          await _safeAlter(
            db,
            'ALTER TABLE resources ADD COLUMN subjectId INTEGER',
          );
        }
        if (oldVersion < 10) {
          await _safeAlter(
            db,
            "ALTER TABLE habits ADD COLUMN identity TEXT NOT NULL DEFAULT 'Soy alguien que cumple incluso cuando no tiene ganas.'",
          );
        }
        if (oldVersion < 12) {
          await _safeAlter(
            db,
            'ALTER TABLE subjects ADD COLUMN professorName TEXT',
          );
          await _safeAlter(
            db,
            'ALTER TABLE subjects ADD COLUMN sectionCode TEXT',
          );
        }
        if (oldVersion < 13) {
          await _safeAlter(db, 'ALTER TABLE exams ADD COLUMN examLabel TEXT');
        }
        if (oldVersion < 14) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS study_tasks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subjectId INTEGER,
              title TEXT NOT NULL,
              notes TEXT NOT NULL DEFAULT '',
              dueDate TEXT NOT NULL,
              priority TEXT NOT NULL DEFAULT 'medium',
              status TEXT NOT NULL DEFAULT 'pending',
              createdAt TEXT NOT NULL,
              completedAt TEXT,
              FOREIGN KEY(subjectId) REFERENCES subjects(id) ON DELETE SET NULL
            )
          ''');
        }
        if (oldVersion < 15) {
          await _safeAlter(
            db,
            'ALTER TABLE habits ADD COLUMN createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
          );
        }
        if (oldVersion < 16) {
          await _safeAlter(
              db, 'ALTER TABLE pomodoros ADD COLUMN taskId INTEGER');
          await _safeAlter(
            db,
            "ALTER TABLE pomodoros ADD COLUMN taskTitle TEXT NOT NULL DEFAULT ''",
          );
          await _safeAlter(
            db,
            "ALTER TABLE pomodoros ADD COLUMN sessionGoal TEXT NOT NULL DEFAULT ''",
          );
          await _safeAlter(
            db,
            'ALTER TABLE pomodoros ADD COLUMN goalAchieved INTEGER',
          );
          await _safeAlter(
            db,
            "ALTER TABLE pomodoros ADD COLUMN note TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  Future<void> _safeAlter(Database db, String statement) async {
    try {
      await db.execute(statement);
    } catch (_) {}
  }

  Future<void> _insertDefaultData(Database db) async {
    await db.insert(
      'settings',
      {'key': 'settings', 'value': _serializeSettings(AppSettings())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _serializeSettings(AppSettings s) {
    return jsonEncode(s.toMap());
  }

  AppSettings _deserializeSettings(String str) {
    try {
      final trimmed = str.trim();
      if (trimmed.startsWith('{')) {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return AppSettings.fromMap(Map<String, dynamic>.from(decoded));
        }
      }

      final parts = str.split('|');
      final themeIndex = int.tryParse(parts.elementAtOrNull(0) ?? '0') ?? 0;
      final safeThemeIndex =
          themeIndex.clamp(0, ThemeModeSetting.values.length - 1);
      return AppSettings(
        themeMode: ThemeModeSetting.values[safeThemeIndex],
        language: AppLanguage.system,
        focusTime: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 25,
        shortBreakTime: int.tryParse(parts.elementAtOrNull(2) ?? '') ?? 5,
        longBreakTime: int.tryParse(parts.elementAtOrNull(3) ?? '') ?? 15,
        weeklyGoal: int.tryParse(parts.elementAtOrNull(4) ?? '') ?? 8,
        weeklyFocusMinutesGoal: 300,
        dailyHabitGoal: 3,
        streakGoal: 7,
        sound: (parts.elementAtOrNull(5) ?? '').trim().isNotEmpty
            ? parts[5]
            : 'chime',
        selectedIdentity: (parts.elementAtOrNull(6) ?? '').trim().isNotEmpty
            ? parts[6]
            : 'Soy una persona constante que cumple lo que se propone.',
        startScreen: (parts.elementAtOrNull(7) ?? '').trim().isNotEmpty
            ? parts[7]
            : 'dashboard',
        textScale: double.tryParse(parts.elementAtOrNull(8) ?? '') ?? 1.0,
        animationsEnabled: parts.elementAtOrNull(9) != '0',
        accentColor: (parts.elementAtOrNull(10) ?? '').trim().isNotEmpty
            ? parts[10]
            : '#1D4ED8',
        notificationsEnabled: parts.elementAtOrNull(11) != '0',
        onboardingCompleted: parts.elementAtOrNull(12) == '1',
        breakAfterFocus: (parts.elementAtOrNull(13) ?? '').trim().isNotEmpty
            ? parts[13]
            : 'auto',
        userName: parts.elementAtOrNull(14) ?? '',
      );
    } catch (_) {
      return AppSettings();
    }
  }

  Future<int> insertPomodoro(Pomodoro p) async {
    final db = await database;
    return db.insert('pomodoros', p.toMap());
  }

  Future<List<Pomodoro>> getAllPomodoros() async {
    final db = await database;
    final maps = await db.query('pomodoros', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => Pomodoro.fromMap(maps[i]));
  }

  Future<int> deletePomodoro(int id) async {
    final db = await database;
    return db.delete('pomodoros', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertHabit(Habit h) async {
    final db = await database;
    return db.insert('habits', h.toMap());
  }

  Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final maps = await db.query('habits');
    return List.generate(maps.length, (i) => Habit.fromMap(maps[i]));
  }

  Future<int> updateHabit(Habit h) async {
    final db = await database;
    return db.update('habits', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    return db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertResource(ResourceLink resource) async {
    final db = await database;
    return db.insert('resources', resource.toMap());
  }

  Future<List<ResourceLink>> getAllResources() async {
    final db = await database;
    final maps = await db.query(
      'resources',
      orderBy: 'category, title COLLATE NOCASE ASC',
    );
    return List.generate(maps.length, (i) => ResourceLink.fromMap(maps[i]));
  }

  Future<int> deleteResource(int id) async {
    final db = await database;
    return db.delete('resources', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertStudyTask(StudyTask task) async {
    final db = await database;
    return db.insert('study_tasks', task.toMap());
  }

  Future<List<StudyTask>> getAllStudyTasks() async {
    final db = await database;
    final maps = await db.query(
      'study_tasks',
      orderBy: '''
        CASE priority
          WHEN 'high' THEN 0
          WHEN 'medium' THEN 1
          ELSE 2
        END,
        dueDate ASC
      ''',
    );
    return List.generate(maps.length, (i) => StudyTask.fromMap(maps[i]));
  }

  Future<int> updateStudyTask(StudyTask task) async {
    final db = await database;
    return db.update(
      'study_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteStudyTask(int id) async {
    final db = await database;
    return db.delete('study_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSubject(Subject s) async {
    final db = await database;
    return db.insert('subjects', s.toMap());
  }

  Future<List<Subject>> getAllSubjects() async {
    final db = await database;
    final maps = await db.query('subjects', orderBy: 'name COLLATE NOCASE ASC');
    return List.generate(maps.length, (i) => Subject.fromMap(maps[i]));
  }

  Future<int> updateSubject(Subject s) async {
    final db = await database;
    return db.update('subjects', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteSubject(int id) async {
    final db = await database;
    await db.delete('schedules', where: 'subjectId = ?', whereArgs: [id]);
    await db.rawUpdate(
      'UPDATE exams SET subjectId = NULL WHERE subjectId = ?',
      [id],
    );
    await db.rawUpdate(
      'UPDATE study_tasks SET subjectId = NULL WHERE subjectId = ?',
      [id],
    );
    return db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSchedule(Schedule s) async {
    final db = await database;
    return db.insert('schedules', s.toMap());
  }

  Future<List<Schedule>> getSchedulesBySubject(int subjectId) async {
    final db = await database;
    final maps = await db.query(
      'schedules',
      where: 'subjectId = ?',
      whereArgs: [subjectId],
      orderBy: 'dayOfWeek, startTime',
    );
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final maps = await db.query('schedules', orderBy: 'dayOfWeek, startTime');
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  Future<int> updateSchedule(Schedule s) async {
    final db = await database;
    return db
        .update('schedules', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<AppSettings> getSettings() async {
    final db = await database;
    final result =
        await db.query('settings', where: 'key = ?', whereArgs: ['settings']);
    if (result.isEmpty) return AppSettings();
    return _deserializeSettings(result.first['value'] as String);
  }

  Future<void> updateSettings(AppSettings settings) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'settings', 'value': _serializeSettings(settings)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceAllData({
    required List<Pomodoro> pomodoros,
    required List<Habit> habits,
    required List<Subject> subjects,
    required List<Schedule> schedules,
    required List<Exam> exams,
    required List<StudyTask> studyTasks,
    required List<ResourceLink> resources,
    required AppSettings settings,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('pomodoros');
      await txn.delete('habits');
      await txn.delete('exams');
      await txn.delete('study_tasks');
      await txn.delete('resources');
      await txn.delete('schedules');
      await txn.delete('subjects');
      await txn.delete('settings');

      for (final subject in subjects) {
        await txn.insert(
          'subjects',
          subject.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final schedule in schedules) {
        await txn.insert(
          'schedules',
          schedule.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final exam in exams) {
        await txn.insert(
          'exams',
          exam.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final task in studyTasks) {
        await txn.insert(
          'study_tasks',
          task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final resource in resources) {
        await txn.insert(
          'resources',
          resource.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final pomodoro in pomodoros) {
        await txn.insert(
          'pomodoros',
          pomodoro.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final habit in habits) {
        await txn.insert(
          'habits',
          habit.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'settings',
        {'key': 'settings', 'value': _serializeSettings(settings)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<int> insertExam(Exam e) async {
    final db = await database;
    return db.insert('exams', e.toMap());
  }

  Future<List<Exam>> getAllExams() async {
    final db = await database;
    final maps = await db.query('exams', orderBy: 'date ASC, startTime ASC');
    return List.generate(maps.length, (i) => Exam.fromMap(maps[i]));
  }

  Future<int> updateExam(Exam e) async {
    final db = await database;
    return db.update('exams', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<int> deleteExam(int id) async {
    final db = await database;
    return db.delete('exams', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAcademicData() async {
    final db = await database;
    await db.delete('exams');
    await db.delete('study_tasks');
    await db.delete('schedules');
    await db.delete('subjects');
    await db.delete('resources');
  }

  Future<void> clearAll({bool reseed = true}) async {
    final db = await database;
    await db.delete('pomodoros');
    await db.delete('habits');
    await db.delete('exams');
    await db.delete('study_tasks');
    await db.delete('resources');
    await db.delete('schedules');
    await db.delete('subjects');
    await db.delete('settings');
    if (reseed) {
      await _insertDefaultData(db);
    }
  }
}
