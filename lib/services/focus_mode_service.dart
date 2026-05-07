import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_mode_config.dart';
import '../models/focus_mode_status.dart';
import '../models/focus_shield_app.dart';

class FocusModeService {
  static const MethodChannel _channel = MethodChannel('focus_mode_total');
  static const _enabledKey = 'focus_mode_enabled';
  static const _blockedAppsKey = 'focus_mode_blocked_apps';

  static Future<FocusModeConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final raw = prefs.getString(_blockedAppsKey);
    final blockedApps = <FocusShieldApp>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              blockedApps.add(
                FocusShieldApp.fromMap(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      } catch (_) {}
    }

    return FocusModeConfig(
      enabled: enabled,
      blockedApps: blockedApps,
    );
  }

  static Future<void> saveConfig(FocusModeConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, config.enabled);
    await prefs.setString(
      _blockedAppsKey,
      jsonEncode(config.blockedApps.map((app) => app.toMap()).toList()),
    );
  }

  static Future<List<FocusShieldApp>> getInstalledApps() async {
    if (kIsWeb) return const [];
    final result =
        await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    final apps = (result ?? <dynamic>[])
        .whereType<Map>()
        .map((item) => FocusShieldApp.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    apps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return apps;
  }

  static Future<bool> hasUsageAccessPermission() async {
    if (kIsWeb) return false;
    final granted =
        await _channel.invokeMethod<bool>('hasUsageAccessPermission');
    return granted ?? false;
  }

  static Future<void> openUsageAccessSettings() async {
    if (kIsWeb) return;
    await _channel.invokeMethod('openUsageAccessSettings');
  }

  static Future<void> startFocusSession({
    required String subject,
    required int durationSeconds,
    required List<FocusShieldApp> blockedApps,
  }) async {
    if (kIsWeb || blockedApps.isEmpty) return;
    await _channel.invokeMethod('startFocusSession', {
      'subject': subject,
      'durationSeconds': durationSeconds,
      'blockedApps': blockedApps.map((app) => app.toMap()).toList(),
    });
  }

  static Future<void> stopFocusSession() async {
    if (kIsWeb) return;
    await _channel.invokeMethod('stopFocusSession');
  }

  static Future<FocusModeStatus> getStatus() async {
    if (kIsWeb) return const FocusModeStatus();
    final status = await _channel.invokeMapMethod<String, dynamic>(
          'getFocusSessionStatus',
        ) ??
        <String, dynamic>{};
    return FocusModeStatus.fromMap(status);
  }
}
