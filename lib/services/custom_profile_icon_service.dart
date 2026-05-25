import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomProfileIconService {
  CustomProfileIconService._();

  static const int maxBytes = 2 * 1024 * 1024;
  static const String _pngBase64Key = 'focus_custom_profile_icon_png_base64';

  static Future<Uint8List?> pickAndSavePng() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final name = file.name.trim().toLowerCase();
    final bytes = file.bytes;
    if (!name.endsWith('.png')) {
      throw StateError('Elige una imagen PNG sin fondo.');
    }
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No se pudo leer la imagen seleccionada.');
    }
    if (bytes.lengthInBytes > maxBytes) {
      throw StateError('La imagen PNG debe pesar menos de 2 MB.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pngBase64Key, base64Encode(bytes));
    return bytes;
  }

  static Future<Uint8List?> loadBytes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pngBase64Key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}
