import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

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
    final file = await _cacheFile(hash);
    if (!await file.exists()) {
      return null;
    }
    final jsonString = await file.readAsString();
    return PolytechnicWorkbook.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  Future<void> save(String hash, PolytechnicWorkbook workbook) async {
    final file = await _cacheFile(hash);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(workbook.toJson()));
  }

  Future<File> _cacheFile(String hash) async {
    final dir = await getApplicationDocumentsDirectory();
    return File(
        '${dir.path}${Platform.pathSeparator}polytechnic_cache${Platform.pathSeparator}$hash.json');
  }
}
