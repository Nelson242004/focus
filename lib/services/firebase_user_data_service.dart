import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_settings.dart';
import '../models/exam.dart';
import '../models/habit.dart';
import '../models/pomodoro.dart';
import '../models/resource_link.dart';
import '../models/schedule.dart';
import '../models/study_task.dart';
import '../models/subject.dart';
import 'ranking_service.dart';

class FocusCloudUserData {
  final List<Pomodoro> pomodoros;
  final List<Habit> habits;
  final List<Subject> subjects;
  final List<Schedule> schedules;
  final List<Exam> exams;
  final List<StudyTask> studyTasks;
  final List<ResourceLink> resources;
  final AppSettings? settings;

  const FocusCloudUserData({
    required this.pomodoros,
    required this.habits,
    required this.subjects,
    required this.schedules,
    required this.exams,
    required this.studyTasks,
    required this.resources,
    required this.settings,
  });

  bool get hasAnyData =>
      pomodoros.isNotEmpty ||
      habits.isNotEmpty ||
      subjects.isNotEmpty ||
      schedules.isNotEmpty ||
      exams.isNotEmpty ||
      studyTasks.isNotEmpty ||
      resources.isNotEmpty ||
      settings != null;
}

class FirebaseUserDataService {
  FirebaseUserDataService._();

  static const int _maxBatchWrites = 450;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>? _userDoc() {
    final user = RankingService.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid);
  }

  static DocumentReference<Map<String, dynamic>>? _doc(
    String collection,
    Object? id,
  ) {
    final uid = RankingService.currentUser?.uid;
    if (uid == null || id == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc('$id');
  }

  static Future<void> _touchUserAccount() async {
    final user = RankingService.currentUser;
    final userDoc = _userDoc();
    if (user == null || userDoc == null) return;
    await userDoc.set({
      'email': user.email ?? '',
      'emailLower': (user.email ?? '').toLowerCase(),
      'cloudDataSyncedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> savePomodoro(Pomodoro item) async {
    final doc = _doc('pomodoros', item.id ?? item.date.hashCode);
    if (doc == null) return;
    await _touchUserAccount();
    await doc.set({
      ...item.toMap(),
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deletePomodoro(int id) => _delete('pomodoros', id);

  static Future<void> saveHabit(Habit item) async {
    final doc = _doc('habits', item.id);
    if (doc == null) return;
    await _touchUserAccount();
    await doc.set({
      ...item.toMap(),
      'historyList': item.history,
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteHabit(int id) => _delete('habits', id);

  static Future<void> saveSubject(Subject item) =>
      _saveMap('subjects', item.id, item.toMap());

  static Future<void> deleteSubject(int id) => _delete('subjects', id);

  static Future<void> saveSchedule(Schedule item) =>
      _saveMap('schedules', item.id, item.toMap());

  static Future<void> deleteSchedule(int id) => _delete('schedules', id);

  static Future<void> saveExam(Exam item) =>
      _saveMap('exams', item.id, item.toMap());

  static Future<void> deleteExam(int id) => _delete('exams', id);

  static Future<void> saveStudyTask(StudyTask item) =>
      _saveMap('studyTasks', item.id, item.toMap());

  static Future<void> deleteStudyTask(int id) => _delete('studyTasks', id);

  static Future<void> saveResource(ResourceLink item) =>
      _saveMap('resources', item.id, item.toMap());

  static Future<void> deleteResource(int id) => _delete('resources', id);

  static Future<void> saveSettings(AppSettings settings) async {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return;
    await _touchUserAccount();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('current')
        .set({
      ...settings.toMap(),
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _saveMap(
    String collection,
    Object? id,
    Map<String, dynamic> data,
  ) async {
    final doc = _doc(collection, id);
    if (doc == null) return;
    await _touchUserAccount();
    await doc.set({
      ...data,
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> replaceCollection(
    String collection,
    Iterable<Map<String, dynamic>> items,
  ) async {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return;
    await _touchUserAccount();
    final ref = _firestore.collection('users').doc(uid).collection(collection);
    final existing = await ref.get();

    var batch = _firestore.batch();
    var writes = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (writes == 0) return;
      if (!force && writes < _maxBatchWrites) return;
      await batch.commit();
      batch = _firestore.batch();
      writes = 0;
    }

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
      writes++;
      await commitIfNeeded();
    }
    for (final item in items) {
      final id = item['id'] ?? item['date']?.hashCode ?? item.hashCode;
      batch.set(ref.doc('$id'), {
        ...item,
        'syncedAt': FieldValue.serverTimestamp(),
      });
      writes++;
      await commitIfNeeded();
    }
    await commitIfNeeded(force: true);
  }

  static Future<void> syncAllData({
    required List<Pomodoro> pomodoros,
    required List<Habit> habits,
    required List<Subject> subjects,
    required List<Schedule> schedules,
    required List<Exam> exams,
    required List<StudyTask> studyTasks,
    required List<ResourceLink> resources,
    required AppSettings settings,
  }) async {
    await Future.wait([
      syncProgressData(pomodoros: pomodoros, habits: habits),
      replaceCollection('subjects', subjects.map((item) => item.toMap())),
      replaceCollection('schedules', schedules.map((item) => item.toMap())),
      replaceCollection('exams', exams.map((item) => item.toMap())),
      replaceCollection('studyTasks', studyTasks.map((item) => item.toMap())),
      replaceCollection('resources', resources.map((item) => item.toMap())),
      saveSettings(settings),
    ]);
  }

  static Future<FocusCloudUserData?> fetchAllData() async {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return null;
    final userRef = _firestore.collection('users').doc(uid);

    Future<List<Map<String, dynamic>>> collectionMaps(String name) async {
      final snapshot = await userRef.collection(name).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    }

    final results = await Future.wait<List<Map<String, dynamic>>>([
      collectionMaps('pomodoros'),
      collectionMaps('habits'),
      collectionMaps('subjects'),
      collectionMaps('schedules'),
      collectionMaps('exams'),
      collectionMaps('studyTasks'),
      collectionMaps('resources'),
    ]);
    final settingsDoc =
        await userRef.collection('settings').doc('current').get();
    final settingsData = settingsDoc.data();

    return FocusCloudUserData(
      pomodoros: results[0].map(Pomodoro.fromMap).toList(),
      habits: results[1].map(_habitFromCloudMap).toList(),
      subjects: results[2].map(Subject.fromMap).toList(),
      schedules: results[3].map(Schedule.fromMap).toList(),
      exams: results[4].map(Exam.fromMap).toList(),
      studyTasks: results[5].map(StudyTask.fromMap).toList(),
      resources: results[6].map(ResourceLink.fromMap).toList(),
      settings: settingsData == null ? null : AppSettings.fromMap(settingsData),
    );
  }

  static Habit _habitFromCloudMap(Map<String, dynamic> map) {
    final normalized = Map<String, dynamic>.from(map);
    if ((normalized['history'] == null || '${normalized['history']}'.isEmpty) &&
        normalized['historyList'] is List) {
      normalized['history'] = List.from(normalized['historyList']).join(',');
    }
    return Habit.fromMap(normalized);
  }

  static Future<void> syncProgressData({
    required List<Pomodoro> pomodoros,
    required List<Habit> habits,
  }) async {
    await replaceCollection('pomodoros', pomodoros.map((item) => item.toMap()));
    await replaceCollection(
      'habits',
      habits.map((item) => {
            ...item.toMap(),
            'historyList': item.history,
          }),
    );
  }

  static Future<void> clearProgressData() async {
    await replaceCollection('pomodoros', const []);
    await replaceCollection('habits', const []);
  }

  static Future<void> clearAllUserData() async {
    await Future.wait([
      replaceCollection('pomodoros', const []),
      replaceCollection('habits', const []),
      replaceCollection('subjects', const []),
      replaceCollection('schedules', const []),
      replaceCollection('exams', const []),
      replaceCollection('studyTasks', const []),
      replaceCollection('resources', const []),
    ]);
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('current')
        .delete();
    await _touchUserAccount();
  }

  static Future<void> _delete(String collection, int id) async {
    final doc = _doc(collection, id);
    if (doc == null) return;
    await _touchUserAccount();
    await doc.delete();
  }
}
