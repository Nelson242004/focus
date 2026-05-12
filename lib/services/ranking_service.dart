import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/ranking_profile.dart';

class RankingService {
  RankingService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _googleReady = false;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<void> initializeGoogleSignIn() async {
    if (_googleReady) return;
    debugPrint('[FocusRanking] Inicializando Google Sign-In');
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  static Future<UserCredential> signInWithGoogle() async {
    await initializeGoogleSignIn();
    debugPrint('[FocusRanking] Abriendo flujo de Google Sign-In');
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    debugPrint(
      '[FocusRanking] Google OK email=${googleUser.email} '
      'hasIdToken=${googleAuth.idToken != null}',
    );
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    debugPrint('[FocusRanking] Firebase Auth OK uid=${result.user?.uid}');
    return result;
  }

  static Future<void> signOut() async {
    await initializeGoogleSignIn();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  static Stream<RankingProfile?> profileStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return RankingProfile.fromMap(uid, data);
    });
  }

  static Future<void> saveProfile({
    required String name,
    required String career,
    String? university,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final cleanedName = name.trim().isEmpty ? 'Estudiante Focus' : name.trim();
    final cleanedCareer = career.trim().isEmpty ? 'Sin carrera' : career.trim();
    final currentPoints = await currentWeekPoints(user.uid);
    final rank = rankForPoints(currentPoints);
    await _firestore.collection('users').doc(user.uid).set({
      'name': cleanedName,
      'career': cleanedCareer,
      'rank': rank,
      'photoUrl': user.photoURL ?? '',
      'email': user.email ?? '',
      'university': university,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _currentScoresCollection().doc(user.uid).set({
      'uid': user.uid,
      'weekId': currentWeekId(),
      'name': cleanedName,
      'career': cleanedCareer,
      'university': university,
      'rank': rank,
      'photoUrl': user.photoURL ?? '',
      'points': currentPoints,
      'pomodoros': FieldValue.increment(0),
      'focusMinutes': FieldValue.increment(0),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('[FocusRanking] Perfil guardado uid=${user.uid}');
  }

  static Future<int> currentWeekPoints(String uid) async {
    final doc = await _currentScoresCollection().doc(uid).get();
    return int.tryParse('${doc.data()?['points'] ?? 0}') ?? 0;
  }

  static Future<void> submitPomodoro({
    required int durationMinutes,
    required bool distractionFree,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final profileDoc = await _firestore.collection('users').doc(user.uid).get();
    final profile = profileDoc.data() ?? {};
    final basePoints = (durationMinutes / 25).ceil().clamp(1, 8) * 10;
    final bonus = distractionFree ? 5 : 0;
    final points = basePoints + bonus;
    final weekId = currentWeekId();
    final hourBucket = currentHourBucket();

    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(_currentScoresCollection().doc(user.uid));
      final currentPoints =
          int.tryParse('${current.data()?['points'] ?? 0}') ?? 0;
      final nextPoints = currentPoints + points;
      transaction.set(
        _currentScoresCollection().doc(user.uid),
        {
          'uid': user.uid,
          'weekId': weekId,
          'name': profile['name'] ?? user.displayName ?? 'Estudiante Focus',
          'career': profile['career'] ?? 'Sin carrera',
          'university': profile['university'],
          'rank': rankForPoints(nextPoints),
          'photoUrl': profile['photoUrl'] ?? user.photoURL ?? '',
          'points': FieldValue.increment(points),
          'pomodoros': FieldValue.increment(1),
          'focusMinutes': FieldValue.increment(durationMinutes),
          'lastHourBucket': hourBucket,
          'lastActive': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        _firestore.collection('users').doc(user.uid),
        {
          'rank': rankForPoints(nextPoints),
          'weeklyPoints': FieldValue.increment(points),
          'totalPoints': FieldValue.increment(points),
          'pomodoros': FieldValue.increment(1),
          'focusMinutes': FieldValue.increment(durationMinutes),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
    debugPrint(
      '[FocusRanking] Pomodoro enviado uid=${user.uid} points=$points',
    );
  }

  static Stream<List<RankingEntry>> globalLeaderboardStream({int limit = 50}) {
    return _currentScoresCollection()
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      int position = 0;
      return snapshot.docs.map((doc) {
        position++;
        return RankingEntry.fromMap(
          '${doc.data()['uid'] ?? doc.id}',
          doc.data(),
          position: position,
        );
      }).toList();
    });
  }

  static Future<List<RankingEntry>> fetchGlobalLeaderboard({int limit = 50}) async {
    final snapshot = await _currentScoresCollection()
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    int position = 0;
    return snapshot.docs.map((doc) {
      position++;
      return RankingEntry.fromMap(
        '${doc.data()['uid'] ?? doc.id}',
        doc.data(),
        position: position,
      );
    }).toList();
  }

  static Stream<List<RankingEntry>> leagueLeaderboardStream({
    required String league,
    int limit = 50,
  }) {
    return _currentScoresCollection()
        .where('rank', isEqualTo: league)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      int position = 0;
      return snapshot.docs.map((doc) {
        position++;
        return RankingEntry.fromMap(
          '${doc.data()['uid'] ?? doc.id}',
          doc.data(),
          position: position,
        );
      }).toList();
    });
  }

  static Future<List<RankingEntry>> fetchLeagueLeaderboard({
    required String league,
    int limit = 50,
  }) async {
    final snapshot = await _currentScoresCollection()
        .where('rank', isEqualTo: league)
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    int position = 0;
    return snapshot.docs.map((doc) {
      position++;
      return RankingEntry.fromMap(
        '${doc.data()['uid'] ?? doc.id}',
        doc.data(),
        position: position,
      );
    }).toList();
  }

  static Stream<List<RankingEntry>> careerLeaderboardStream({
    required String career,
    int limit = 50,
  }) {
    return _currentScoresCollection()
        .where('career', isEqualTo: career)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      int position = 0;
      return snapshot.docs.map((doc) {
        position++;
        return RankingEntry.fromMap(
          '${doc.data()['uid'] ?? doc.id}',
          doc.data(),
          position: position,
        );
      }).toList();
    });
  }

  static Future<List<RankingEntry>> fetchCareerLeaderboard({
    required String career,
    int limit = 50,
  }) async {
    final snapshot = await _currentScoresCollection()
        .where('career', isEqualTo: career)
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    int position = 0;
    return snapshot.docs.map((doc) {
      position++;
      return RankingEntry.fromMap(
        '${doc.data()['uid'] ?? doc.id}',
        doc.data(),
        position: position,
      );
    }).toList();
  }

  static Stream<List<RankingEntry>> friendsLeaderboardStream({
    required List<String> friendUids,
    int limit = 50,
  }) {
    if (friendUids.isEmpty) return Stream.value([]);
    return _currentScoresCollection()
        .where(FieldPath.documentId, whereIn: friendUids)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      int position = 0;
      return snapshot.docs.map((doc) {
        position++;
        return RankingEntry.fromMap(
          '${doc.data()['uid'] ?? doc.id}',
          doc.data(),
          position: position,
        );
      }).toList();
    });
  }

  static Future<List<RankingEntry>> fetchFriendsLeaderboard({
    required List<String> friendUids,
    int limit = 50,
  }) async {
    if (friendUids.isEmpty) return [];
    final snapshot = await _currentScoresCollection()
        .where(FieldPath.documentId, whereIn: friendUids)
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    int position = 0;
    return snapshot.docs.map((doc) {
      position++;
      return RankingEntry.fromMap(
        '${doc.data()['uid'] ?? doc.id}',
        doc.data(),
        position: position,
      );
    }).toList();
  }

  static Future<RankingEntry?> getUserEntry(String uid) async {
    final doc = await _currentScoresCollection().doc(uid).get();
    if (!doc.exists) return null;
    return RankingEntry.fromMap(uid, doc.data()!);
  }

  static Future<int> getUserPosition(String uid) async {
    final userEntry = await getUserEntry(uid);
    if (userEntry == null) return -1;
    
    final snapshot = await _currentScoresCollection()
        .where('points', isGreaterThan: userEntry.points)
        .count()
        .get();
    
    return (snapshot.count ?? 0) + 1;
  }

  static Stream<RankingSeason?> currentSeasonStream() {
    return _firestore
        .collection('seasons')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return RankingSeason.fromMap(doc.id, doc.data());
    });
  }

  static Future<List<RankingSeason>> getPastSeasons({int limit = 10}) async {
    final snapshot = await _firestore
        .collection('seasons')
        .where('isActive', isEqualTo: false)
        .orderBy('endDate', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs
        .map((doc) => RankingSeason.fromMap(doc.id, doc.data()))
        .toList();
  }

  static Future<void> awardBadge(String uid, String badgeId) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final badges = List<String>.from(userDoc.data()?['badges'] ?? []);
      if (!badges.contains(badgeId)) {
        badges.add(badgeId);
        transaction.update(userRef, {'badges': badges});
      }
    });
  }

  static Future<List<String>> getUserBadges(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return List<String>.from(doc.data()?['badges'] ?? []);
  }

  static String currentWeekId() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  static String currentHourBucket() {
    final now = DateTime.now();
    return '${currentWeekId()}-${now.hour.toString().padLeft(2, '0')}';
  }

  static CollectionReference<Map<String, dynamic>> _currentScoresCollection() {
    return _firestore
        .collection('leaderboards')
        .doc(currentWeekId())
        .collection('scores');
  }

  static String rankForPoints(int points) {
    if (points >= 700) return 'Diamante';
    if (points >= 450) return 'Platino';
    if (points >= 250) return 'Oro';
    if (points >= 100) return 'Plata';
    return 'Bronce';
  }

  static DateTime nextHourlyUpdate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  static String friendlyRankingError(Object? error) {
    if (error == null) return 'Error desconocido';
    final message = error.toString();
    if (message.contains('network-request-failed')) {
      return 'Verifica tu conexión a internet e intenta nuevamente.';
    }
    if (message.contains('permission-denied')) {
      return 'No tienes permisos para realizar esta acción.';
    }
    if (message.contains('unavailable')) {
      return 'El servicio no está disponible temporalmente.';
    }
    if (message.contains('cancelled')) {
      return 'La operación fue cancelada.';
    }
    return 'Ocurrió un error. Intenta nuevamente.';
  }
}
