import 'dart:convert';
import 'dart:io';

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
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(AppLinks.updateManifest));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const HttpException(
            'No se pudo leer el archivo de actualización.');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
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
    } finally {
      client.close(force: true);
    }
  }
}
