import 'package:cloud_firestore/cloud_firestore.dart';

import 'polytechnic_import_service.dart';
import 'ranking_service.dart';

class PolytechnicCloudService {
  PolytechnicCloudService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final _catalogRef =
      _firestore.collection('polytechnicCatalog').doc('current');

  static Future<bool> currentUserIsAdmin() async {
    final uid = RankingService.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['isAdmin'] == true;
  }

  static Future<PolytechnicWorkbook?> loadCurrentWorkbook() async {
    final doc = await _catalogRef.get();
    final data = doc.data();
    if (data == null || data['workbook'] is! Map) return null;
    return PolytechnicWorkbook.fromJson(
      Map<String, dynamic>.from(data['workbook'] as Map),
    );
  }

  static Future<void> publishWorkbook(PolytechnicWorkbook workbook) async {
    final user = RankingService.currentUser;
    if (user == null) return;
    await _catalogRef.set({
      'workbook': workbook.toJson(),
      'sourceName': workbook.sourceName,
      'careerCount': workbook.careers.length,
      'subjectCount': workbook.careers
          .expand((career) => career.semesters)
          .fold<int>(0, (sum, semester) => sum + semester.subjects.length),
      'updatedBy': user.uid,
      'updatedByEmail': user.email ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
