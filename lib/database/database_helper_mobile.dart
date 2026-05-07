import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import '../models/exam.dart';
import '../models/habit.dart';
import '../models/pomodoro.dart';
import '../models/resource_link.dart';
import '../models/schedule.dart';
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
      version: 13,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pomodoros(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            subject TEXT NOT NULL,
            duration INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE habits(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            identity TEXT NOT NULL DEFAULT 'Soy alguien que cumple incluso cuando no tiene ganas.',
            streak INTEGER DEFAULT 0,
            history TEXT
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
      'subjects',
      {'name': 'Matemáticas', 'color': '#3b82f6', 'icon': 'calculate'},
    );
    await db.insert(
      'subjects',
      {'name': 'Programación', 'color': '#22c55e', 'icon': 'code'},
    );
    await db.insert(
      'subjects',
      {'name': 'Física', 'color': '#f59e0b', 'icon': 'science'},
    );
    await db.insert(
      'settings',
      {'key': 'settings', 'value': _serializeSettings(AppSettings())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _serializeSettings(AppSettings s) {
    return [
      s.themeMode.index,
      s.focusTime,
      s.shortBreakTime,
      s.longBreakTime,
      s.weeklyGoal,
      s.sound,
      s.selectedIdentity,
      s.startScreen,
      s.textScale,
      s.animationsEnabled ? 1 : 0,
      s.accentColor,
      s.notificationsEnabled ? 1 : 0,
      s.onboardingCompleted ? 1 : 0,
      s.breakAfterFocus,
    ].join('|');
  }

  AppSettings _deserializeSettings(String str) {
    try {
      final parts = str.split('|');
      final themeIndex = int.tryParse(parts.elementAtOrNull(0) ?? '0') ?? 0;
      final safeThemeIndex =
          themeIndex.clamp(0, ThemeModeSetting.values.length - 1);
      return AppSettings(
        themeMode: ThemeModeSetting.values[safeThemeIndex],
        focusTime: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 25,
        shortBreakTime: int.tryParse(parts.elementAtOrNull(2) ?? '') ?? 5,
        longBreakTime: int.tryParse(parts.elementAtOrNull(3) ?? '') ?? 15,
        weeklyGoal: int.tryParse(parts.elementAtOrNull(4) ?? '') ?? 8,
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
    await db.delete('schedules');
    await db.delete('subjects');
  }

  Future<void> clearAll({bool reseed = true}) async {
    final db = await database;
    await db.delete('pomodoros');
    await db.delete('habits');
    await db.delete('exams');
    await db.delete('resources');
    await db.delete('schedules');
    await db.delete('subjects');
    await db.delete('settings');
    if (reseed) {
      await _insertDefaultData(db);
    }
  }
}
