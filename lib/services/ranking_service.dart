import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/ranking_profile.dart';

class RankingService {
  RankingService._();

  static const int pointsPerPomodoro = 20;
  static const int distractionFreeBonus = 5;
  static const int pointsPerHabitCompletion = 12;
  static const Map<String, int> achievementPoints = {
    'first_pomodoro': 50,
    'streak_7': 100,
    'streak_14': 180,
    'streak_30': 400,
    'pomodoros_25': 150,
    'pomodoros_100': 600,
    'weekly_mission': 120,
    'habits_30': 180,
    'habits_75': 420,
    'max_level': 500,
  };

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

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<UserCredential> createUserWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signOut() async {
    try {
      await initializeGoogleSignIn();
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('[FocusRanking] Google signOut omitido: $error');
    }
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

  static Future<RankingProfile?> fetchProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    return data == null ? null : RankingProfile.fromMap(uid, data);
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
    final userRef = _firestore.collection('users').doc(user.uid);
    final exists = (await userRef.get()).exists;
    await _firestore.collection('users').doc(user.uid).set({
      'name': cleanedName,
      'career': cleanedCareer,
      'rank': rank,
      'photoUrl': user.photoURL ?? '',
      'email': user.email ?? '',
      'university': university,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!exists) 'joinedAt': FieldValue.serverTimestamp(),
      'weeklyWeekId': currentWeekId(),
      'weeklyPoints': currentPoints,
    }, SetOptions(merge: true));
    await ensureCurrentWeekScore();
    debugPrint('[FocusRanking] Perfil guardado uid=${user.uid}');
  }

  static Future<void> ensureCurrentWeekScore() async {
    final user = currentUser;
    if (user == null) return;
    final profileDoc = await _firestore.collection('users').doc(user.uid).get();
    final profile = profileDoc.data();
    if (profile == null) return;
    final currentPoints = pointsFromUserMap(profile);
    await _currentScoresCollection().doc(user.uid).set({
      'uid': user.uid,
      'weekId': currentWeekId(),
      'name': profile['name'] ?? user.displayName ?? 'Estudiante Focus',
      'career': profile['career'] ?? 'Sin carrera',
      'university': profile['university'],
      'rank': rankForPoints(currentPoints),
      'photoUrl': profile['photoUrl'] ?? user.photoURL ?? '',
      'points': currentPoints,
      'pomodoros': int.tryParse('${profile['weeklyPomodoros'] ?? 0}') ?? 0,
      'focusMinutes': int.tryParse('${profile['weeklyFocusMinutes'] ?? 0}') ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final basePoints =
        (durationMinutes / 25).ceil().clamp(1, 8) * pointsPerPomodoro;
    final bonus = distractionFree ? distractionFreeBonus : 0;
    final points = basePoints + bonus;
    await _addWeeklyPoints(
      user.uid,
      points: points,
      pomodoros: 1,
      focusMinutes: durationMinutes,
      event: 'pomodoro',
      profile: profile,
    );
    debugPrint(
      '[FocusRanking] Pomodoro enviado uid=${user.uid} points=$points',
    );
  }

  static Future<void> submitHabitCompletion() async {
    final user = currentUser;
    if (user == null) return;
    final profileDoc = await _firestore.collection('users').doc(user.uid).get();
    await _addWeeklyPoints(
      user.uid,
      points: pointsPerHabitCompletion,
      habitCompletions: 1,
      event: 'habit',
      profile: profileDoc.data() ?? {},
    );
  }

  static Future<void> syncAchievementAwards({
    required int pomodoros,
    required int currentStreak,
    required int totalHabitCompletions,
    required bool weeklyMissionCompleted,
    required int level,
    required int maxLevel,
  }) async {
    final candidates = <String>[
      if (pomodoros >= 1) 'first_pomodoro',
      if (currentStreak >= 7) 'streak_7',
      if (currentStreak >= 14) 'streak_14',
      if (currentStreak >= 30) 'streak_30',
      if (pomodoros >= 25) 'pomodoros_25',
      if (pomodoros >= 100) 'pomodoros_100',
      if (weeklyMissionCompleted) 'weekly_mission',
      if (totalHabitCompletions >= 30) 'habits_30',
      if (totalHabitCompletions >= 75) 'habits_75',
      if (level >= maxLevel) 'max_level',
    ];
    for (final badgeId in candidates) {
      await awardAchievementPoints(badgeId);
    }
  }

  static Future<void> awardAchievementPoints(String badgeId) async {
    final user = currentUser;
    final points = achievementPoints[badgeId];
    if (user == null || points == null) return;
    final userRef = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final data = userDoc.data() ?? {};
      final badges = List<String>.from(data['badges'] ?? []);
      if (badges.contains(badgeId)) return;
      badges.add(badgeId);
      final normalized = _normalizedWeeklyState(data);
      final nextPoints = normalized.points + points;
      transaction.set(
        userRef,
        {
          'badges': badges,
          'weeklyWeekId': currentWeekId(),
          'weeklyPoints': nextPoints,
          'totalPoints': FieldValue.increment(points),
          'rank': rankForPoints(nextPoints),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        _currentScoresCollection().doc(user.uid),
        _scorePayload(
          uid: user.uid,
          profile: data,
          points: nextPoints,
          rank: rankForPoints(nextPoints),
          badges: badges,
        ),
        SetOptions(merge: true),
      );
    });
  }

  static Future<void> _addWeeklyPoints(
    String uid, {
    required int points,
    int pomodoros = 0,
    int focusMinutes = 0,
    int habitCompletions = 0,
    required String event,
    required Map<String, dynamic> profile,
  }) async {
    final hourBucket = currentHourBucket();
    final userRef = _firestore.collection('users').doc(uid);
    final scoreRef = _currentScoresCollection().doc(uid);

    await _firestore.runTransaction((transaction) async {
      final currentUserDoc = await transaction.get(userRef);
      final data = currentUserDoc.data() ?? profile;
      final normalized = _normalizedWeeklyState(data);
      final nextPoints = normalized.points + points;
      transaction.set(
        scoreRef,
        _scorePayload(
          uid: uid,
          profile: data,
          points: nextPoints,
          rank: rankForPoints(nextPoints),
          pomodoros: normalized.pomodoros + pomodoros,
          focusMinutes: normalized.focusMinutes + focusMinutes,
          habitCompletions: normalized.habitCompletions + habitCompletions,
          lastHourBucket: hourBucket,
        ),
        SetOptions(merge: true),
      );
      transaction.set(
        userRef,
        {
          'rank': rankForPoints(nextPoints),
          'weeklyWeekId': currentWeekId(),
          'weeklyPoints': nextPoints,
          'totalPoints': FieldValue.increment(points),
          'weeklyPomodoros': normalized.pomodoros + pomodoros,
          'weeklyFocusMinutes': normalized.focusMinutes + focusMinutes,
          'weeklyHabitCompletions':
              normalized.habitCompletions + habitCompletions,
          'pomodoros': FieldValue.increment(pomodoros),
          'focusMinutes': FieldValue.increment(focusMinutes),
          'habitCompletions': FieldValue.increment(habitCompletions),
          'lastPointEvent': event,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
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

  static Future<List<RankingEntry>> fetchGlobalLeaderboard({int limit = 0}) async {
    final query = _firestore.collection('users');
    final snapshot = limit > 0 ? await query.limit(limit).get() : await query.get();
    int position = 0;
    final entries = snapshot.docs
        .map((doc) => RankingEntry.fromMap(
              doc.id,
              _userMapAsWeeklyScore(doc.data(), doc.id),
            ))
        .toList()
      ..sort((a, b) {
        final points = b.points.compareTo(a.points);
        if (points != 0) return points;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return entries.map((entry) {
      position++;
      return RankingEntry(
        uid: entry.uid,
        name: entry.name,
        career: entry.career,
        rank: entry.rank,
        points: entry.points,
        pomodoros: entry.pomodoros,
        focusMinutes: entry.focusMinutes,
        position: position,
        trend: entry.trend,
        photoUrl: entry.photoUrl,
        university: entry.university,
        badges: entry.badges,
        lastActive: entry.lastActive,
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
    final uid = currentUser?.uid;
    final allUids = {
      if (uid != null) uid,
      ...friendUids,
    }.toList();
    if (allUids.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var index = 0; index < allUids.length; index += 10) {
      chunks.add(
        allUids.sublist(
          index,
          (index + 10).clamp(0, allUids.length).toInt(),
        ),
      );
    }
    final entries = <RankingEntry>[];
    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      entries.addAll(snapshot.docs.map((doc) {
        return RankingEntry.fromMap(
          doc.id,
          _userMapAsWeeklyScore(doc.data(), doc.id),
        );
      }));
    }
    entries.sort((a, b) {
      final points = b.points.compareTo(a.points);
      if (points != 0) return points;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    int position = 0;
    return entries.take(limit).map((entry) {
      position++;
      return RankingEntry(
        uid: entry.uid,
        name: entry.name,
        career: entry.career,
        rank: entry.rank,
        points: entry.points,
        pomodoros: entry.pomodoros,
        focusMinutes: entry.focusMinutes,
        position: position,
        trend: entry.trend,
        photoUrl: entry.photoUrl,
        university: entry.university,
        badges: entry.badges,
        lastActive: entry.lastActive,
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
        .subtract(Duration(days: now.weekday % 7));
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

  static DateTime nextWeeklyReset() {
    final now = DateTime.now();
    final daysUntilSunday = 7 - (now.weekday % 7);
    return DateTime(now.year, now.month, now.day + daysUntilSunday);
  }

  static int pointsFromUserMap(Map<String, dynamic> map) {
    if ('${map['weeklyWeekId'] ?? ''}' != currentWeekId()) return 0;
    return int.tryParse('${map['weeklyPoints'] ?? 0}') ?? 0;
  }

  static ({
    int points,
    int pomodoros,
    int focusMinutes,
    int habitCompletions,
  }) _normalizedWeeklyState(Map<String, dynamic> map) {
    if ('${map['weeklyWeekId'] ?? ''}' != currentWeekId()) {
      return (points: 0, pomodoros: 0, focusMinutes: 0, habitCompletions: 0);
    }
    return (
      points: int.tryParse('${map['weeklyPoints'] ?? 0}') ?? 0,
      pomodoros: int.tryParse('${map['weeklyPomodoros'] ?? 0}') ?? 0,
      focusMinutes: int.tryParse('${map['weeklyFocusMinutes'] ?? 0}') ?? 0,
      habitCompletions:
          int.tryParse('${map['weeklyHabitCompletions'] ?? 0}') ?? 0,
    );
  }

  static Map<String, dynamic> _userMapAsWeeklyScore(
    Map<String, dynamic> map,
    String uid,
  ) {
    final normalized = _normalizedWeeklyState(map);
    return {
      'uid': uid,
      'name': map['name'] ?? 'Estudiante Focus',
      'career': map['career'] ?? 'Sin carrera',
      'university': map['university'],
      'rank': rankForPoints(normalized.points),
      'photoUrl': map['photoUrl'] ?? '',
      'points': normalized.points,
      'pomodoros': normalized.pomodoros,
      'focusMinutes': normalized.focusMinutes,
      'badges': List<String>.from(map['badges'] ?? []),
      'lastActive': map['updatedAt'],
    };
  }

  static Map<String, dynamic> _scorePayload({
    required String uid,
    required Map<String, dynamic> profile,
    required int points,
    required String rank,
    int? pomodoros,
    int? focusMinutes,
    int? habitCompletions,
    List<String>? badges,
    String? lastHourBucket,
  }) {
    return {
      'uid': uid,
      'weekId': currentWeekId(),
      'name': profile['name'] ?? 'Estudiante Focus',
      'career': profile['career'] ?? 'Sin carrera',
      'university': profile['university'],
      'rank': rank,
      'photoUrl': profile['photoUrl'] ?? '',
      'points': points,
      if (pomodoros != null) 'pomodoros': pomodoros,
      if (focusMinutes != null) 'focusMinutes': focusMinutes,
      if (habitCompletions != null) 'habitCompletions': habitCompletions,
      if (badges != null) 'badges': badges,
      if (lastHourBucket != null) 'lastHourBucket': lastHourBucket,
      'lastActive': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
