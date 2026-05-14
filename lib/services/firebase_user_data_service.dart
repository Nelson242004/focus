import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/habit.dart';
import '../models/pomodoro.dart';
import 'ranking_service.dart';

class FirebaseUserDataService {
  FirebaseUserDataService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  static Future<void> savePomodoro(Pomodoro item) async {
    final doc = _doc('pomodoros', item.id ?? item.date.hashCode);
    if (doc == null) return;
    await doc.set({
      ...item.toMap(),
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deletePomodoro(int id) => _delete('pomodoros', id);

  static Future<void> saveHabit(Habit item) async {
    final doc = _doc('habits', item.id);
    if (doc == null) return;
    await doc.set({
      ...item.toMap(),
      'historyList': item.history,
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteHabit(int id) => _delete('habits', id);

  static Future<void> replaceCollection(
    String collection,
    Iterable<Map<String, dynamic>> items,
  ) async {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return;
    final ref = _firestore.collection('users').doc(uid).collection(collection);
    final existing = await ref.get();
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final item in items) {
      final id = item['id'] ?? item['date']?.hashCode ?? item.hashCode;
      batch.set(ref.doc('$id'), {
        ...item,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
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
            }));
  }

  static Future<void> clearProgressData() async {
    await replaceCollection('pomodoros', const []);
    await replaceCollection('habits', const []);
  }

  static Future<void> _delete(String collection, int id) async {
    final doc = _doc(collection, id);
    if (doc == null) return;
    await doc.delete();
  }
}
