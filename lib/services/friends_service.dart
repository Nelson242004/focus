import 'package:cloud_firestore/cloud_firestore.dart';

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
            .map((doc) => FriendRequest.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  static Future<List<RankingProfile>> searchUsers(String query) async {
    final currentUid = RankingService.currentUser?.uid;
    final normalized = query.trim().toLowerCase();
    if (currentUid == null || normalized.length < 2) return const [];
    final snapshot = await _firestore.collection('users').limit(50).get();
    return snapshot.docs.where((doc) {
      final data = doc.data();
      return doc.id != currentUid &&
          ('${data['name'] ?? ''}'.toLowerCase().contains(normalized) ||
              '${data['career'] ?? ''}'.toLowerCase().contains(normalized) ||
              '${data['email'] ?? ''}'.toLowerCase().contains(normalized) ||
              doc.id.toLowerCase().contains(normalized));
    }).map((doc) => RankingProfile.fromMap(doc.id, doc.data())).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static Future<void> sendRequest(RankingProfile target) async {
    final user = RankingService.currentUser;
    final me = await RankingService.fetchProfile();
    if (user == null || me == null || target.uid == user.uid) return;
    final friendshipId = _friendshipId(user.uid, target.uid);
    final existingFriendship =
        await _firestore.collection('friendships').doc(friendshipId).get();
    if (existingFriendship.exists) return;

    final requestId = _friendshipId(user.uid, target.uid);
    await _firestore.collection('friendRequests').doc(requestId).set({
      'fromUid': user.uid,
      'toUid': target.uid,
      'fromName': me.name,
      'toName': target.name,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> acceptRequest(FriendRequest request) async {
    final uid = RankingService.currentUser?.uid;
    if (uid == null || request.toUid != uid) return;
    final friendshipId = _friendshipId(request.fromUid, request.toUid);
    final batch = _firestore.batch();
    batch.set(_firestore.collection('friendships').doc(friendshipId), {
      'members': [request.fromUid, request.toUid]..sort(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
