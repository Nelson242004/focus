import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/app_links.dart';

class AppUpdateInfo {
  final String version;
  final int versionCode;
  final String apkUrl;
  final String notes;
  final bool available;

  const AppUpdateInfo({
    required this.version,
    required this.versionCode,
    required this.apkUrl,
    required this.notes,
    required this.available,
  });
}

class UpdateService {
  const UpdateService._();

  static Future<AppUpdateInfo> checkForUpdates() async {
    final response = await http
        .get(Uri.parse(AppLinks.updateManifest))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException(
        'No se pudo leer el archivo de actualización.',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'El manifiesto de actualización no tiene un formato válido.',
      );
    }

    final versionCode = int.tryParse('${data['versionCode'] ?? 0}') ?? 0;
    final version = '${data['version'] ?? 'Sin versión'}';
    final apkUrl = '${data['apkUrl'] ?? AppLinks.appDownload}';
    final notes = '${data['notes'] ?? 'Nueva versión disponible.'}';
    final apkUri = Uri.tryParse(apkUrl);
    final hasUsableApkUrl = apkUri != null &&
        apkUri.hasScheme &&
        (apkUri.scheme == 'https' || apkUri.scheme == 'http') &&
        !apkUrl.contains('tu-link-del-apk');
    if (versionCode > AppLinks.currentVersionCode && !hasUsableApkUrl) {
      throw const FormatException(
        'El manifiesto beta no tiene un enlace de descarga válido.',
      );
    }

    return AppUpdateInfo(
      version: version,
      versionCode: versionCode,
      apkUrl: apkUrl,
      notes: notes,
      available: versionCode > AppLinks.currentVersionCode,
    );
  }
}
