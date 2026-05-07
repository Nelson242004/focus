import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'polytechnic_import_service.dart';

class PolytechnicCacheService {
  static const _cacheVersion = 'v3';

  Future<String> hashBytes(Uint8List bytes) async {
    final digestInput = Uint8List.fromList([
      ...utf8.encode(_cacheVersion),
      ...bytes,
    ]);
    return sha1.convert(digestInput).toString();
  }

  Future<PolytechnicWorkbook?> load(String hash) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey(hash));
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    return PolytechnicWorkbook.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  Future<void> save(String hash, PolytechnicWorkbook workbook) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(hash), jsonEncode(workbook.toJson()));
  }

  String _cacheKey(String hash) => 'polytechnic_cache_$hash';
}
