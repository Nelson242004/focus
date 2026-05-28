import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/ranking_profile.dart';
import '../utils/profile_icon_access.dart';

enum HabitRankingStatus {
  awarded,
  signedOut,
  missingHabit,
  tooNew,
  alreadyAwardedToday,
  dailyLimitReached,
}

class HabitRankingResult {
  final HabitRankingStatus status;
  final int points;

  const HabitRankingResult(this.status, {this.points = 0});

  bool get awarded => status == HabitRankingStatus.awarded;
}

class RankingService {
  RankingService._();

  static const int defaultLeaderboardLimit = 20;

  static const int pointsPerPomodoro = 20;
  static const int distractionFreeBonus = 5;
  static const int pointsPerHabitCompletion = 12;
  static const int minimumRankingPomodoroMinutes = 25;
  static const int maxRankingPomodoroBlocksPerDay = 6;
  static const int maxRankingHabitsPerDay = 3;
  static const Duration minimumHabitAgeForRanking = Duration(hours: 24);
  static const Map<String, int> achievementPoints = {
    'first_pomodoro': 50,
    'first_habit': 25,
    'pomodoros_5': 40,
    'habits_5': 40,
    'streak_3': 35,
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
  static const String _googleServerClientId =
      '1059624966381-9obri2ta3d8brscndpucbiu5mlvpa06l.apps.googleusercontent.com';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, _CachedProfile> _profileCache = {};
  static const Duration _profileCacheTtl = Duration(minutes: 3);
  static bool _googleReady = false;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static bool isGoogleSignInCanceled(Object error) {
    return error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled;
  }

  static bool isUserDataActive(Map<String, dynamic>? data) {
    if (data == null) return false;
    final status =
        '${data['accountStatus'] ?? data['status'] ?? ''}'.trim().toLowerCase();
    return data['isActive'] != false &&
        data['deletedAt'] == null &&
        data['disabledAt'] == null &&
        status != 'disabled' &&
        status != 'deleted' &&
        status != 'inactive';
  }

  static Future<void> initializeGoogleSignIn() async {
    if (_googleReady) return;
    debugPrint('[FocusRanking] Inicializando Google Sign-In');
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
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
    if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
      throw StateError(
        'Google no devolvió un token válido. Revisa la configuración OAuth de Firebase.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    debugPrint('[FocusRanking] Firebase Auth OK uid=${result.user?.uid}');
    await _tryEnsureProfile('google sign in');
    return result;
  }

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _tryEnsureProfile('email sign in');
    return result;
  }

  static Future<UserCredential> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _tryEnsureProfile('email sign up');
    return result;
  }

  static Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() async {
    try {
      await initializeGoogleSignIn();
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('[FocusRanking] Google signOut omitido: $error');
    }
    await _auth.signOut();
    _profileCache.clear();
  }

  static Stream<RankingProfile?> profileStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!isUserDataActive(data)) return null;
      return RankingProfile.fromMap(uid, data!);
    });
  }

  static Future<RankingProfile?> fetchProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    return isUserDataActive(data) ? RankingProfile.fromMap(uid, data!) : null;
  }

  static Future<RankingProfile?> fetchProfileByUid(String uid) async {
    final cleanedUid = uid.trim();
    if (cleanedUid.isEmpty) return null;
    final cached = _profileCache[cleanedUid];
    if (cached != null && !cached.isExpired) return cached.profile;
    final snapshot = await _firestore.collection('users').doc(cleanedUid).get();
    final data = snapshot.data();
    final profile = isUserDataActive(data)
        ? RankingProfile.fromMap(cleanedUid, data!)
        : null;
    if (profile != null) {
      _profileCache[cleanedUid] = _CachedProfile(profile, data!);
    } else {
      _profileCache.remove(cleanedUid);
    }
    return profile;
  }

  static Future<RankingProfile?> ensureProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      await signOut();
      throw StateError(
        error.code == 'user-disabled'
            ? 'Esta cuenta fue desactivada.'
            : 'Esta cuenta ya no está disponible.',
      );
    }
    final refreshedUser = currentUser;
    if (refreshedUser == null) return null;

    final snapshot =
        await _firestore.collection('users').doc(refreshedUser.uid).get();
    final data = snapshot.data();
    if (snapshot.exists && !isUserDataActive(data)) {
      await signOut();
      throw StateError('Esta cuenta fue desactivada.');
    }
    if (data != null) return RankingProfile.fromMap(refreshedUser.uid, data);
    await saveProfile(
      name: refreshedUser.displayName ?? _nameFromEmail(refreshedUser.email),
      career: 'Sin carrera',
    );
    return fetchProfile();
  }

  static Future<void> _tryEnsureProfile(String label) async {
    try {
      await ensureProfile();
    } catch (error) {
      debugPrint('[FocusRanking] Perfil automático omitido ($label): $error');
    }
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
    final currentSnapshot = await userRef.get();
    final exists = currentSnapshot.exists;
    if (exists && !isUserDataActive(currentSnapshot.data())) {
      await signOut();
      throw StateError('Esta cuenta fue desactivada.');
    }
    final friendCode = friendCodeForUid(user.uid);
    await _firestore.collection('users').doc(user.uid).set({
      'name': cleanedName,
      'nameLower': cleanedName.toLowerCase(),
      'career': cleanedCareer,
      'careerLower': cleanedCareer.toLowerCase(),
      'rank': rank,
      'photoUrl': user.photoURL ?? '',
      'email': user.email ?? '',
      'emailLower': (user.email ?? '').toLowerCase(),
      'friendCode': friendCode,
      'friendCodeNormalized': friendCode.replaceAll('-', '').toLowerCase(),
      'friendCodeSearchKey': friendCode
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .replaceFirst(RegExp('^FOC', caseSensitive: false), '')
          .toLowerCase(),
      'university': university,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!exists) 'isActive': true,
      if (!exists) 'accountStatus': 'active',
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!exists) 'joinedAt': FieldValue.serverTimestamp(),
      'weeklyWeekId': currentWeekId(),
      'weeklyPoints': currentPoints,
    }, SetOptions(merge: true));
    await ensureCurrentWeekScore();
    debugPrint('[FocusRanking] Perfil guardado uid=${user.uid}');
  }

  static Future<void> updateSocialStyle({
    int? themeIndex,
    int? mascotIndex,
    String? profileIconAsset,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final payload = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (themeIndex != null) {
      payload['stats.socialThemeIndex'] = themeIndex;
    }
    if (mascotIndex != null) {
      payload['stats.socialMascotIndex'] = mascotIndex;
    }
    if (profileIconAsset != null) {
      final asset = normalizeProfileIconAsset(
        profileIconAsset,
        email: user.email,
        enforceAccess: true,
      );
      payload['profileIconAsset'] = asset;
      payload['stats.profileIconAsset'] = asset;
    } else if (mascotIndex != null) {
      final asset = profileIconAssetFromIndex(
        mascotIndex,
        email: user.email,
        enforceAccess: true,
      );
      payload['profileIconAsset'] = asset;
      payload['stats.profileIconAsset'] = asset;
    }
    await _firestore.collection('users').doc(user.uid).update(payload);
    if (mascotIndex != null || profileIconAsset != null) {
      try {
        await ensureCurrentWeekScore();
      } catch (error) {
        debugPrint('[FocusRanking] Sync de icono en ranking omitido: $error');
      }
    }
  }

  static Future<void> updateSocialAvatar(Map<String, dynamic> avatar) async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'stats.socialAvatar': avatar,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await ensureCurrentWeekScore();
    } catch (error) {
      debugPrint('[FocusRanking] Sync de avatar en ranking omitido: $error');
    }
  }

  static Future<void> updateFavoriteBadge(String badgeId) async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'favoriteBadge': badgeId,
      'stats.favoriteBadge': badgeId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await ensureCurrentWeekScore();
  }

  static Future<void> updateFeaturedBadges(List<String> badgeIds) async {
    final user = currentUser;
    if (user == null) return;
    final cleaned = badgeIds
        .where((id) => id.trim().isNotEmpty)
        .map((id) => id.trim())
        .toSet()
        .take(3)
        .toList();
    await _firestore.collection('users').doc(user.uid).update({
      'featuredBadges': cleaned,
      'favoriteBadge': cleaned.isEmpty ? '' : cleaned.first,
      'stats.featuredBadges': cleaned,
      'stats.favoriteBadge': cleaned.isEmpty ? '' : cleaned.first,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await ensureCurrentWeekScore();
  }

  static Future<void> syncSocialStats({
    required int currentStreak,
    required int totalPomodoros,
    required int totalFocusMinutes,
    required int totalHabitCompletions,
    required bool weeklyMissionCompleted,
    required int level,
    int? bestStreak,
    int? focusPoints,
    int? weeklyPomodoros,
    int? weeklyFocusMinutes,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final userRef = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final stats = Map<String, dynamic>.from(data['stats'] ?? const {});
      final previousBest =
          int.tryParse('${stats['bestStreak'] ?? data['bestStreak'] ?? 0}') ??
              0;
      final nextBest = [
        previousBest,
        bestStreak ?? 0,
        currentStreak,
      ].reduce((a, b) => a > b ? a : b);

      transaction.set(
        userRef,
        {
          if (focusPoints != null) 'focusPoints': focusPoints,
          if (focusPoints != null) 'stats.focusPoints': focusPoints,
          if (focusPoints != null) 'totalPoints': focusPoints,
          'stats.currentStreak': currentStreak,
          'stats.bestStreak': nextBest,
          'stats.totalPomodoros': totalPomodoros,
          'stats.totalFocusMinutes': totalFocusMinutes,
          'stats.totalHabitCompletions': totalHabitCompletions,
          'stats.weeklyMissionCompleted': weeklyMissionCompleted,
          if (weeklyPomodoros != null) 'stats.weeklyPomodoros': weeklyPomodoros,
          if (weeklyFocusMinutes != null)
            'stats.weeklyFocusMinutes': weeklyFocusMinutes,
          if (weeklyPomodoros != null) 'weeklyPomodoros': weeklyPomodoros,
          if (weeklyFocusMinutes != null)
            'weeklyFocusMinutes': weeklyFocusMinutes,
          'stats.level': level,
          'currentStreak': currentStreak,
          'bestStreak': nextBest,
          'pomodoros': totalPomodoros,
          'focusMinutes': totalFocusMinutes,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
    await ensureCurrentWeekScore();
  }

  static Future<void> updatePresence({
    required String status,
    String subject = '',
  }) async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set(
      {
        'stats.socialStatus': status,
        'stats.statusSubject': subject.trim(),
        'stats.statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await ensureCurrentWeekScore();
  }

  static Future<void> ensureCurrentWeekScore() async {
    final user = currentUser;
    if (user == null) return;
    final profileDoc = await _firestore.collection('users').doc(user.uid).get();
    final profile = profileDoc.data();
    if (profile == null) return;
    if (!isUserDataActive(profile)) {
      await _currentScoresCollection().doc(user.uid).delete();
      return;
    }
    final normalized = _normalizedWeeklyState(profile);
    final currentPoints = normalized.points;
    final currentRank = rankForPoints(currentPoints);
    await _currentScoresCollection().doc(user.uid).set({
      'uid': user.uid,
      'weekId': currentWeekId(),
      'isActive': true,
      'accountStatus': 'active',
      'name': profile['name'] ?? user.displayName ?? 'Estudiante Focus',
      'career': profile['career'] ?? 'Sin carrera',
      'university': profile['university'],
      'rank': currentRank,
      'photoUrl': profile['photoUrl'] ?? user.photoURL ?? '',
      'socialMascotIndex': profile['stats']?['socialMascotIndex'] ?? 0,
      'profileIconAsset': _profileIconAssetFromProfile(profile),
      'stats': {
        'socialMascotIndex': profile['stats']?['socialMascotIndex'] ?? 0,
        'profileIconAsset': _profileIconAssetFromProfile(profile),
        'socialAvatar': profile['stats']?['socialAvatar'],
        'currentStreak':
            profile['stats']?['currentStreak'] ?? profile['currentStreak'] ?? 0,
        'bestStreak':
            profile['stats']?['bestStreak'] ?? profile['bestStreak'] ?? 0,
        'totalHabitCompletions': profile['stats']?['totalHabitCompletions'] ??
            profile['habitCompletions'] ??
            0,
        'weeklyMissionCompleted':
            profile['stats']?['weeklyMissionCompleted'] ?? false,
        'level': profile['stats']?['level'] ?? 1,
      },
      'points': currentPoints,
      'pomodoros': normalized.pomodoros,
      'focusMinutes': normalized.focusMinutes,
      'badges': List<String>.from(profile['badges'] ?? []),
      'favoriteBadge':
          profile['favoriteBadge'] ?? profile['stats']?['favoriteBadge'] ?? '',
      'featuredBadges': List<String>.from(
        profile['featuredBadges'] ??
            profile['stats']?['featuredBadges'] ??
            const [],
      ),
      'lastPointEvent': profile['lastPointEvent'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if ('${profile['weeklyWeekId'] ?? ''}' != currentWeekId()) {
      await _firestore.collection('users').doc(user.uid).set({
        'weeklyWeekId': currentWeekId(),
        'weeklyPoints': 0,
        'weeklyPomodoros': 0,
        'weeklyFocusMinutes': 0,
        'weeklyHabitCompletions': 0,
        'rank': currentRank,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static String friendCodeForUid(String uid) {
    final compact = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (compact.isEmpty) return 'FOC-FOCUS';
    return 'FOC-${compact.substring(0, compact.length < 8 ? compact.length : 8)}';
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
    final earnedBlocks = durationMinutes ~/ minimumRankingPomodoroMinutes;
    if (earnedBlocks <= 0) {
      debugPrint(
        '[FocusRanking] Pomodoro sin puntos: duration=$durationMinutes',
      );
      return;
    }

    final dayId = currentDayId();
    final hourBucket = currentHourBucket();
    final userRef = _firestore.collection('users').doc(user.uid);
    final scoreRef = _currentScoresCollection().doc(user.uid);
    var awardedPoints = 0;

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final data = userDoc.data() ?? {};
      final dailyDayId = '${data['rankingDailyDayId'] ?? ''}';
      final dailyBlocks = dailyDayId == dayId
          ? int.tryParse('${data['rankingDailyPomodoroBlocks'] ?? 0}') ?? 0
          : 0;
      final remainingBlocks =
          maxRankingPomodoroBlocksPerDay - dailyBlocks.clamp(0, 9999);
      if (remainingBlocks <= 0) return;

      final countedBlocks =
          earnedBlocks < remainingBlocks ? earnedBlocks : remainingBlocks;
      final bonus = distractionFree ? distractionFreeBonus : 0;
      awardedPoints = countedBlocks * pointsPerPomodoro + bonus;
      final normalized = _normalizedWeeklyState(data);
      final nextPoints = normalized.points + awardedPoints;

      transaction.set(
        scoreRef,
        _scorePayload(
          uid: user.uid,
          profile: data,
          points: nextPoints,
          rank: rankForPoints(nextPoints),
          pomodoros: normalized.pomodoros + 1,
          focusMinutes: normalized.focusMinutes + durationMinutes,
          habitCompletions: normalized.habitCompletions,
          lastHourBucket: hourBucket,
          lastPointEvent: 'pomodoro',
        ),
        SetOptions(merge: true),
      );
      transaction.set(
        userRef,
        {
          'weeklyWeekId': currentWeekId(),
          'weeklyPoints': nextPoints,
          'weeklyPomodoros': normalized.pomodoros + 1,
          'weeklyFocusMinutes': normalized.focusMinutes + durationMinutes,
          'weeklyHabitCompletions': normalized.habitCompletions,
          'rankingDailyDayId': dayId,
          'rankingDailyPomodoroBlocks': dailyBlocks + countedBlocks,
          'lastPointEvent': 'pomodoro',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
    debugPrint(
      '[FocusRanking] Pomodoro enviado uid=${user.uid} points=$awardedPoints',
    );
  }

  static Future<HabitRankingResult> submitHabitCompletion({
    required int? habitId,
    required DateTime habitCreatedAt,
  }) async {
    final user = currentUser;
    if (user == null) {
      return const HabitRankingResult(HabitRankingStatus.signedOut);
    }
    if (habitId == null) {
      return const HabitRankingResult(HabitRankingStatus.missingHabit);
    }
    if (DateTime.now().difference(habitCreatedAt) < minimumHabitAgeForRanking) {
      debugPrint('[FocusRanking] Hábito sin puntos: creado hace menos de 24h');
      return const HabitRankingResult(HabitRankingStatus.tooNew);
    }

    final dayId = currentDayId();
    final hourBucket = currentHourBucket();
    final habitKey = '$habitId';
    final userRef = _firestore.collection('users').doc(user.uid);
    final scoreRef = _currentScoresCollection().doc(user.uid);
    var awardedPoints = 0;
    var status = HabitRankingStatus.awarded;

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final data = userDoc.data() ?? {};
      final dailyDayId = '${data['rankingDailyDayId'] ?? ''}';
      final dailyHabitIds = dailyDayId == dayId
          ? List<String>.from(data['rankingDailyHabitIds'] ?? const [])
          : <String>[];
      if (dailyHabitIds.contains(habitKey)) {
        status = HabitRankingStatus.alreadyAwardedToday;
        return;
      }
      if (dailyHabitIds.length >= maxRankingHabitsPerDay) {
        status = HabitRankingStatus.dailyLimitReached;
        return;
      }

      awardedPoints = pointsPerHabitCompletion;
      final normalized = _normalizedWeeklyState(data);
      final nextPoints = normalized.points + awardedPoints;
      final nextDailyHabitIds = [...dailyHabitIds, habitKey];

      transaction.set(
        scoreRef,
        _scorePayload(
          uid: user.uid,
          profile: data,
          points: nextPoints,
          rank: rankForPoints(nextPoints),
          pomodoros: normalized.pomodoros,
          focusMinutes: normalized.focusMinutes,
          habitCompletions: normalized.habitCompletions + 1,
          lastHourBucket: hourBucket,
          lastPointEvent: 'habit',
        ),
        SetOptions(merge: true),
      );
      transaction.set(
        userRef,
        {
          'weeklyWeekId': currentWeekId(),
          'weeklyPoints': nextPoints,
          'weeklyPomodoros': normalized.pomodoros,
          'weeklyFocusMinutes': normalized.focusMinutes,
          'weeklyHabitCompletions': normalized.habitCompletions + 1,
          'rankingDailyDayId': dayId,
          'rankingDailyHabitIds': nextDailyHabitIds,
          'lastPointEvent': 'habit',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
    debugPrint(
      '[FocusRanking] Hábito enviado uid=${user.uid} points=$awardedPoints',
    );
    return HabitRankingResult(status, points: awardedPoints);
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
      if (totalHabitCompletions >= 1) 'first_habit',
      if (pomodoros >= 5) 'pomodoros_5',
      if (totalHabitCompletions >= 5) 'habits_5',
      if (currentStreak >= 3) 'streak_3',
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
          lastPointEvent: 'achievement',
        ),
        SetOptions(merge: true),
      );
    });
  }

  static Stream<List<RankingEntry>> globalLeaderboardStream({
    int limit = defaultLeaderboardLimit,
  }) {
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

  static Future<List<RankingEntry>> fetchGlobalLeaderboard(
      {int limit = defaultLeaderboardLimit}) async {
    try {
      await ensureCurrentWeekScore();
    } catch (error) {
      debugPrint('[FocusRanking] No se pudo asegurar score actual: $error');
    }

    try {
      final query = _currentScoresCollection().orderBy(
        'points',
        descending: true,
      );
      final snapshot =
          limit > 0 ? await query.limit(limit).get() : await query.get();
      int position = 0;
      final entries =
          snapshot.docs.where((doc) => isUserDataActive(doc.data())).map((doc) {
        position++;
        return RankingEntry.fromMap(
          '${doc.data()['uid'] ?? doc.id}',
          doc.data(),
          position: position,
        );
      }).toList();
      final hydrated = await _hydrateEntriesWithCurrentProfileIcons(entries);
      final distributed = _withDistributedRanks(hydrated);
      await _syncCurrentUserDistributedRank(distributed);
      return distributed;
    } catch (error) {
      debugPrint('[FocusRanking] Fallback ranking desde users: $error');
    }

    final query = _firestore.collection('users');
    final snapshot =
        limit > 0 ? await query.limit(limit).get() : await query.get();
    int position = 0;
    final entries = snapshot.docs
        .where((doc) => isUserDataActive(doc.data()))
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
    final positioned = entries.map((entry) {
      position++;
      return RankingEntry(
        uid: entry.uid,
        name: entry.name,
        career: entry.career,
        rank: entry.rank,
        points: entry.points,
        pomodoros: entry.pomodoros,
        focusMinutes: entry.focusMinutes,
        socialMascotIndex: entry.socialMascotIndex,
        profileIconAsset: entry.profileIconAsset,
        position: position,
        trend: entry.trend,
        photoUrl: entry.photoUrl,
        university: entry.university,
        badges: entry.badges,
        favoriteBadge: entry.favoriteBadge,
        featuredBadges: entry.featuredBadges,
        lastActive: entry.lastActive,
        lastPointEvent: entry.lastPointEvent,
      );
    }).toList();
    final distributed = _withDistributedRanks(positioned);
    await _syncCurrentUserDistributedRank(distributed);
    return distributed;
  }

  static Stream<List<RankingEntry>> leagueLeaderboardStream({
    required String league,
    int limit = defaultLeaderboardLimit,
  }) {
    return _currentScoresCollection()
        .where('rank', isEqualTo: league)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      int position = 0;
      return snapshot.docs
          .where((doc) => isUserDataActive(doc.data()))
          .map((doc) {
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
    int limit = defaultLeaderboardLimit,
  }) async {
    final snapshot = await _currentScoresCollection()
        .where('rank', isEqualTo: league)
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    int position = 0;
    return snapshot.docs
        .where((doc) => isUserDataActive(doc.data()))
        .map((doc) {
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
    int limit = defaultLeaderboardLimit,
  }) {
    return _currentScoresCollection()
        .where('career', isEqualTo: career)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      int position = 0;
      return snapshot.docs
          .where((doc) => isUserDataActive(doc.data()))
          .map((doc) {
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
    int limit = defaultLeaderboardLimit,
  }) async {
    final snapshot = await _currentScoresCollection()
        .where('career', isEqualTo: career)
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    int position = 0;
    return snapshot.docs
        .where((doc) => isUserDataActive(doc.data()))
        .map((doc) {
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
    int limit = defaultLeaderboardLimit,
  }) {
    if (friendUids.isEmpty) return Stream.value([]);
    return _currentScoresCollection()
        .where(FieldPath.documentId, whereIn: friendUids)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      int position = 0;
      return snapshot.docs
          .where((doc) => isUserDataActive(doc.data()))
          .map((doc) {
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
    int limit = defaultLeaderboardLimit,
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
      entries.addAll(
          snapshot.docs.where((doc) => isUserDataActive(doc.data())).map((doc) {
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
        socialMascotIndex: entry.socialMascotIndex,
        profileIconAsset: entry.profileIconAsset,
        position: position,
        trend: entry.trend,
        photoUrl: entry.photoUrl,
        university: entry.university,
        badges: entry.badges,
        favoriteBadge: entry.favoriteBadge,
        featuredBadges: entry.featuredBadges,
        lastActive: entry.lastActive,
        lastPointEvent: entry.lastPointEvent,
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

  static String currentDayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static CollectionReference<Map<String, dynamic>> _currentScoresCollection() {
    return _firestore
        .collection('leaderboards')
        .doc(currentWeekId())
        .collection('scores');
  }

  static String rankForPoints(int points) {
    if (points >= 250) return 'Oro';
    if (points >= 100) return 'Plata';
    return 'Bronce';
  }

  static String distributedRankForPosition(int position, int total) {
    if (position <= 0 || total <= 0) return 'Bronce';
    final limits = distributedRankLimits(total);
    if (position <= limits.goldLimit) return 'Oro';
    if (position <= limits.silverLimit) return 'Plata';
    return 'Bronce';
  }

  static ({int total, int goldLimit, int silverLimit}) distributedRankLimits(
    int total,
  ) {
    if (total <= 0) return (total: 0, goldLimit: 0, silverLimit: 0);
    final goldLimit = (total * 0.10).ceil().clamp(1, total);
    final silverLimit = (total * 0.35).ceil().clamp(goldLimit, total);
    return (total: total, goldLimit: goldLimit, silverLimit: silverLimit);
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
      'socialMascotIndex': map['stats']?['socialMascotIndex'] ?? 0,
      'profileIconAsset': _profileIconAssetFromProfile(map),
      'stats': {
        'socialMascotIndex': map['stats']?['socialMascotIndex'] ?? 0,
        'profileIconAsset': _profileIconAssetFromProfile(map),
        'socialAvatar': map['stats']?['socialAvatar'],
        'currentStreak':
            map['stats']?['currentStreak'] ?? map['currentStreak'] ?? 0,
        'bestStreak': map['stats']?['bestStreak'] ?? map['bestStreak'] ?? 0,
        'totalHabitCompletions': map['stats']?['totalHabitCompletions'] ??
            map['habitCompletions'] ??
            0,
        'weeklyMissionCompleted':
            map['stats']?['weeklyMissionCompleted'] ?? false,
        'level': map['stats']?['level'] ?? 1,
      },
      'points': normalized.points,
      'pomodoros':
          _intFrom(map['weeklyPomodoros'] ?? map['stats']?['weeklyPomodoros']),
      'focusMinutes': _intFrom(
        map['weeklyFocusMinutes'] ?? map['stats']?['weeklyFocusMinutes'],
      ),
      'badges': List<String>.from(map['badges'] ?? []),
      'favoriteBadge':
          map['favoriteBadge'] ?? map['stats']?['favoriteBadge'] ?? '',
      'featuredBadges': List<String>.from(
        map['featuredBadges'] ?? map['stats']?['featuredBadges'] ?? const [],
      ),
      'lastActive': map['updatedAt'],
      'lastPointEvent': map['lastPointEvent'] ?? '',
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
    String? lastPointEvent,
  }) {
    return {
      'uid': uid,
      'weekId': currentWeekId(),
      'isActive': true,
      'accountStatus': 'active',
      'name': profile['name'] ?? 'Estudiante Focus',
      'career': profile['career'] ?? 'Sin carrera',
      'university': profile['university'],
      'rank': rank,
      'photoUrl': profile['photoUrl'] ?? '',
      'socialMascotIndex': profile['stats']?['socialMascotIndex'] ?? 0,
      'profileIconAsset': _profileIconAssetFromProfile(profile),
      'stats': {
        'socialMascotIndex': profile['stats']?['socialMascotIndex'] ?? 0,
        'profileIconAsset': _profileIconAssetFromProfile(profile),
        'socialAvatar': profile['stats']?['socialAvatar'],
        'currentStreak':
            profile['stats']?['currentStreak'] ?? profile['currentStreak'] ?? 0,
        'bestStreak':
            profile['stats']?['bestStreak'] ?? profile['bestStreak'] ?? 0,
        'totalHabitCompletions': profile['stats']?['totalHabitCompletions'] ??
            profile['habitCompletions'] ??
            habitCompletions ??
            0,
        'weeklyMissionCompleted':
            profile['stats']?['weeklyMissionCompleted'] ?? false,
        'level': profile['stats']?['level'] ?? 1,
      },
      'points': points,
      if (pomodoros != null) 'pomodoros': pomodoros,
      if (focusMinutes != null) 'focusMinutes': focusMinutes,
      if (habitCompletions != null) 'habitCompletions': habitCompletions,
      if (badges != null) 'badges': badges,
      'favoriteBadge':
          profile['favoriteBadge'] ?? profile['stats']?['favoriteBadge'] ?? '',
      'featuredBadges': List<String>.from(
        profile['featuredBadges'] ??
            profile['stats']?['featuredBadges'] ??
            const [],
      ),
      if (lastHourBucket != null) 'lastHourBucket': lastHourBucket,
      'lastActive': FieldValue.serverTimestamp(),
      'lastPointEvent': lastPointEvent ?? profile['lastPointEvent'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<List<RankingEntry>> _hydrateEntriesWithCurrentProfileIcons(
    List<RankingEntry> entries,
  ) async {
    if (entries.isEmpty) return entries;
    try {
      final profileDataByUid = await _fetchActiveProfileDataByUid(
        entries.map((entry) => entry.uid).toSet().toList(),
      );
      final hydrated = entries.map((entry) {
        final activeData = profileDataByUid[entry.uid];
        if (activeData == null) return null;
        final stats = activeData['stats'];
        final rawIndex = stats is Map
            ? activeData['socialMascotIndex'] ?? stats['socialMascotIndex']
            : activeData['socialMascotIndex'];
        return RankingEntry(
          uid: entry.uid,
          name: entry.name,
          career: entry.career,
          rank: entry.rank,
          points: entry.points,
          pomodoros: entry.pomodoros,
          focusMinutes: entry.focusMinutes,
          socialMascotIndex:
              int.tryParse('${rawIndex ?? entry.socialMascotIndex}') ??
                  entry.socialMascotIndex,
          profileIconAsset: _profileIconAssetFromProfile(activeData),
          position: entry.position,
          trend: entry.trend,
          photoUrl: entry.photoUrl,
          university: entry.university,
          badges: entry.badges,
          favoriteBadge: entry.favoriteBadge,
          featuredBadges: entry.featuredBadges,
          lastActive: entry.lastActive,
          lastPointEvent: entry.lastPointEvent,
        );
      });
      return hydrated.whereType<RankingEntry>().toList();
    } catch (error) {
      debugPrint('[FocusRanking] No se pudieron refrescar iconos: $error');
      return entries;
    }
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchActiveProfileDataByUid(
    List<String> uids,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    final pending = <String>[];
    final now = DateTime.now();
    for (final uid in uids.where((uid) => uid.trim().isNotEmpty)) {
      final cached = _profileCache[uid];
      if (cached != null &&
          now.difference(cached.cachedAt) < _profileCacheTtl) {
        result[uid] = cached.data;
      } else {
        pending.add(uid);
      }
    }

    for (var index = 0; index < pending.length; index += 10) {
      final chunk = pending.sublist(
        index,
        (index + 10).clamp(0, pending.length).toInt(),
      );
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (!isUserDataActive(data)) {
          _profileCache.remove(doc.id);
          continue;
        }
        result[doc.id] = data;
        _profileCache[doc.id] = _CachedProfile(
          RankingProfile.fromMap(doc.id, data),
          data,
        );
      }
    }
    return result;
  }

  static List<RankingEntry> _withDistributedRanks(List<RankingEntry> entries) {
    final total = entries.length;
    return entries.map((entry) {
      return RankingEntry(
        uid: entry.uid,
        name: entry.name,
        career: entry.career,
        rank: distributedRankForPosition(entry.position, total),
        points: entry.points,
        pomodoros: entry.pomodoros,
        focusMinutes: entry.focusMinutes,
        socialMascotIndex: entry.socialMascotIndex,
        profileIconAsset: entry.profileIconAsset,
        position: entry.position,
        trend: entry.trend,
        photoUrl: entry.photoUrl,
        university: entry.university,
        badges: entry.badges,
        favoriteBadge: entry.favoriteBadge,
        featuredBadges: entry.featuredBadges,
        lastActive: entry.lastActive,
        lastPointEvent: entry.lastPointEvent,
      );
    }).toList();
  }

  static Future<void> _syncCurrentUserDistributedRank(
    List<RankingEntry> entries,
  ) async {
    final user = currentUser;
    if (user == null || entries.isEmpty) return;
    final matches = entries.where((entry) => entry.uid == user.uid);
    if (matches.isEmpty) return;
    final entry = matches.first;
    try {
      await Future.wait([
        _firestore.collection('users').doc(user.uid).set({
          'rank': entry.rank,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        _currentScoresCollection().doc(user.uid).set({
          'rank': entry.rank,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);
    } catch (error) {
      debugPrint('[FocusRanking] Rank distribuido no sincronizado: $error');
    }
  }

  static int _intFrom(Object? value) => int.tryParse('$value') ?? 0;

  static String _profileIconAssetFromProfile(Map<String, dynamic> profile) {
    final stats = profile['stats'];
    final rawAsset = stats is Map
        ? '${profile['profileIconAsset'] ?? stats['profileIconAsset'] ?? ''}'
        : '${profile['profileIconAsset'] ?? ''}';
    if (rawAsset.trim().isNotEmpty) {
      return normalizeProfileIconAsset(rawAsset);
    }
    final rawIndex = stats is Map
        ? profile['socialMascotIndex'] ?? stats['socialMascotIndex']
        : profile['socialMascotIndex'];
    return profileIconAssetFromIndex(rawIndex);
  }

  static String friendlyRankingError(Object? error) {
    if (error == null) return 'Error desconocido';
    final message = error.toString();
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'El correo no tiene un formato válido.',
        'user-disabled' => 'Esta cuenta fue deshabilitada.',
        'user-not-found' => 'No existe una cuenta con ese correo.',
        'wrong-password' ||
        'invalid-credential' =>
          'Correo o contraseña incorrectos.',
        'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
        'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
        'network-request-failed' =>
          'Verifica tu conexión a internet e intenta nuevamente.',
        'too-many-requests' =>
          'Demasiados intentos. Espera un momento y vuelve a probar.',
        'operation-not-allowed' =>
          'Este método de inicio de sesión no está habilitado en Firebase.',
        _ => error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'No se pudo iniciar sesión. Intenta nuevamente.',
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'No tienes permisos para guardar o leer estos datos.',
        'unavailable' => 'El servicio no está disponible temporalmente.',
        'not-found' => 'No se encontraron los datos solicitados.',
        'already-exists' => 'Ese dato ya existe.',
        _ => error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'No se pudo completar la operación.',
      };
    }
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Inicio de sesión cancelado.',
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google Sign-In no está bien configurado. Revisa el SHA-1/SHA-256 de Firebase.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'No se pudo abrir la ventana de Google. Intenta nuevamente.',
        _ => error.description?.trim().isNotEmpty == true
            ? error.description!
            : 'No se pudo iniciar sesión con Google.',
      };
    }
    if (error is StateError) {
      return message.replaceFirst('Bad state: ', '');
    }
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

  static String _nameFromEmail(String? email) {
    final name = email?.split('@').first.trim();
    if (name == null || name.isEmpty) return 'Estudiante Focus';
    return name
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _CachedProfile {
  final RankingProfile profile;
  final Map<String, dynamic> data;
  final DateTime cachedAt;

  _CachedProfile(this.profile, this.data) : cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cachedAt) >= RankingService._profileCacheTtl;
}
