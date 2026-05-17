import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/ranking_profile.dart';
import 'ranking_service.dart';

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String toName;
  final String status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.toName,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromMap(String id, Map<String, dynamic> map) {
    return FriendRequest(
      id: id,
      fromUid: '${map['fromUid'] ?? ''}',
      toUid: '${map['toUid'] ?? ''}',
      fromName: '${map['fromName'] ?? 'Estudiante'}',
      toName: '${map['toName'] ?? 'Estudiante'}',
      status: '${map['status'] ?? 'pending'}',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FriendStreakRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String toName;
  final DateTime createdAt;

  const FriendStreakRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.toName,
    required this.createdAt,
  });

  factory FriendStreakRequest.fromMap(String id, Map<String, dynamic> map) {
    return FriendStreakRequest(
      id: id,
      fromUid: '${map['fromUid'] ?? ''}',
      toUid: '${map['toUid'] ?? ''}',
      fromName: '${map['fromName'] ?? 'Estudiante'}',
      toName: '${map['toName'] ?? 'Estudiante'}',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FriendStreak {
  final String id;
  final List<String> members;
  final RankingProfile friend;
  final DateTime startedAt;

  const FriendStreak({
    required this.id,
    required this.members,
    required this.friend,
    required this.startedAt,
  });
}

class FriendsService {
  FriendsService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<List<RankingProfile>> friendsStream() {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('friendships')
        .where('members', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final friendIds = snapshot.docs
          .map((doc) => List<String>.from(doc.data()['members'] ?? const []))
          .expand((members) => members)
          .where((memberUid) => memberUid != uid)
          .toSet()
          .toList();
      if (friendIds.isEmpty) return const <RankingProfile>[];
      final chunks = <List<String>>[];
      for (var index = 0; index < friendIds.length; index += 10) {
        chunks.add(friendIds.sublist(
          index,
          (index + 10).clamp(0, friendIds.length).toInt(),
        ));
      }
      final profiles = <RankingProfile>[];
      for (final chunk in chunks) {
        final users = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        profiles.addAll(
          users.docs.map((doc) => RankingProfile.fromMap(doc.id, doc.data())),
        );
      }
      profiles.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return profiles;
    });
  }

  static Stream<List<FriendRequest>> incomingRequestsStream() {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('friendRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => '${doc.data()['type'] ?? 'friend'}' != 'streak')
            .map((doc) => FriendRequest.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  static Stream<List<FriendStreakRequest>> incomingStreakRequestsStream() {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('friendRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()['type'] == 'streak')
            .map((doc) => FriendStreakRequest.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  static Stream<List<FriendStreak>> friendStreaksStream() {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('friendships')
        .where('members', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final streaks = <FriendStreak>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['streakActive'] != true) continue;
        final members = List<String>.from(data['members'] ?? const []);
        final friendUid = members.firstWhere(
          (member) => member != uid,
          orElse: () => '',
        );
        if (friendUid.isEmpty) continue;
        final friendDoc =
            await _firestore.collection('users').doc(friendUid).get();
        final friendData = friendDoc.data();
        if (friendData == null) continue;
        streaks.add(
          FriendStreak(
            id: doc.id,
            members: members,
            friend: RankingProfile.fromMap(friendUid, friendData),
            startedAt:
                (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ),
        );
      }
      streaks.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      return streaks.take(5).toList();
    });
  }

  static Future<List<RankingProfile>> searchUsers(String query) async {
    final currentUid = RankingService.currentUser?.uid;
    final normalized = query.trim().toLowerCase();
    if (currentUid == null || normalized.length < 2) return const [];
    final codeQuery = normalized
        .replaceAll('focus', '')
        .replaceAll('foc', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');
    final snapshot = await _firestore.collection('users').limit(50).get();
    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          final friendCode = '${data['friendCode'] ?? ''}'.toLowerCase();
          return doc.id != currentUid &&
              ('${data['name'] ?? ''}'.toLowerCase().contains(normalized) ||
                  '${data['career'] ?? ''}'
                      .toLowerCase()
                      .contains(normalized) ||
                  '${data['email'] ?? ''}'.toLowerCase().contains(normalized) ||
                  friendCode.contains(normalized) ||
                  (codeQuery.length >= 3 &&
                      friendCode.replaceAll('-', '').contains(codeQuery)) ||
                  (codeQuery.length >= 3 &&
                      doc.id.toLowerCase().startsWith(codeQuery)) ||
                  doc.id.toLowerCase().contains(normalized));
        })
        .map((doc) => RankingProfile.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static String friendCodeForUid(String uid) {
    if (uid.isEmpty) return 'FOCUS';
    final compact = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final suffix = compact.length <= 8 ? compact : compact.substring(0, 8);
    return 'FOC-$suffix';
  }

  static Future<void> sendRequest(RankingProfile target) async {
    final user = RankingService.currentUser;
    final me = await RankingService.fetchProfile();
    if (user == null) {
      throw StateError('Inicia sesión para agregar amigos.');
    }
    if (me == null) {
      throw StateError('Completa tu perfil antes de agregar amigos.');
    }
    if (target.uid == user.uid) {
      throw StateError('No puedes enviarte una solicitud a ti mismo.');
    }

    final friendshipId = _friendshipId(user.uid, target.uid);
    final friendshipRef =
        _firestore.collection('friendships').doc(friendshipId);
    final existingFriendship = await _safeGet(friendshipRef);
    if (existingFriendship?.exists == true) {
      throw StateError('Este usuario ya forma parte de tus amigos.');
    }

    final requestId = _friendshipId(user.uid, target.uid);
    final requestRef = _firestore.collection('friendRequests').doc(requestId);
    final existingRequest = await _safeGet(requestRef);
    final existingData = existingRequest?.data();
    if (existingData != null && existingData['status'] == 'pending') {
      if (existingData['fromUid'] == target.uid &&
          existingData['toUid'] == user.uid) {
        throw StateError(
          'Esta persona ya te envió una solicitud. Revísala en pendientes.',
        );
      }
      throw StateError('Ya existe una solicitud pendiente con este usuario.');
    }
    if (existingData != null && existingData['status'] == 'accepted') {
      throw StateError('Este usuario ya forma parte de tus amigos.');
    }

    await requestRef.set({
      'fromUid': user.uid,
      'toUid': target.uid,
      'fromName': me.name,
      'toName': target.name,
      'type': 'friend',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendStreakRequest(RankingProfile target) async {
    final user = RankingService.currentUser;
    final me = await RankingService.fetchProfile();
    if (user == null) throw StateError('Inicia sesión para usar rachas.');
    if (me == null) throw StateError('Completa tu perfil primero.');
    if (target.uid == user.uid) {
      throw StateError('No puedes iniciar una racha contigo mismo.');
    }

    final active = await _firestore
        .collection('friendships')
        .where('members', arrayContains: user.uid)
        .get();
    final activeCount =
        active.docs.where((doc) => doc.data()['streakActive'] == true).length;
    if (activeCount >= 5) {
      throw StateError('Solo puedes tener 5 rachas entre amigos.');
    }

    final id = _friendshipId(user.uid, target.uid);
    final existing =
        await _safeGet(_firestore.collection('friendships').doc(id));
    if (existing?.exists != true) {
      throw StateError('Primero agrega a esta persona como amigo.');
    }
    if (existing?.data()?['streakActive'] == true) {
      throw StateError('Ya tienes una racha activa con este amigo.');
    }

    await _firestore.collection('friendRequests').doc('streak_$id').set({
      'fromUid': user.uid,
      'toUid': target.uid,
      'fromName': me.name,
      'toName': target.name,
      'type': 'streak',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> _safeGet(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint(
          '[FocusFriends] Lectura previa omitida para ${ref.path}: $error',
        );
        return null;
      }
      rethrow;
    }
  }

  static Future<void> acceptRequest(FriendRequest request) async {
    final uid = RankingService.currentUser?.uid;
    if (uid == null || request.toUid != uid) return;
    final friendshipId = _friendshipId(request.fromUid, request.toUid);
    final batch = _firestore.batch();
    batch.set(
        _firestore.collection('friendships').doc(friendshipId),
        {
          'members': [request.fromUid, request.toUid]..sort(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.update(_firestore.collection('friendRequests').doc(request.id), {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> acceptStreakRequest(FriendStreakRequest request) async {
    final uid = RankingService.currentUser?.uid;
    if (uid == null || request.toUid != uid) return;
    final id = _friendshipId(request.fromUid, request.toUid);
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('friendships').doc(id),
      {
        'members': [request.fromUid, request.toUid]..sort(),
        'streakActive': true,
        'streakStartedBy': request.fromUid,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.update(_firestore.collection('friendRequests').doc(request.id), {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> rejectRequest(FriendRequest request) {
    return _firestore.collection('friendRequests').doc(request.id).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> rejectStreakRequest(FriendStreakRequest request) {
    return _firestore.collection('friendRequests').doc(request.id).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> removeStreak(String streakId) {
    return _firestore.collection('friendships').doc(streakId).update({
      'streakActive': false,
      'streakRemovedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> removeFriend(String friendUid) {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return Future.value();
    return _firestore
        .collection('friendships')
        .doc(_friendshipId(uid, friendUid))
        .delete();
  }

  static String _friendshipId(String a, String b) {
    final members = [a, b]..sort();
    return '${members[0]}_${members[1]}';
  }
}
