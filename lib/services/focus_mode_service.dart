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
  static const _channelTimeout = Duration(seconds: 20);

  static Future<FocusModeConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final raw = prefs.getString(_blockedAppsKey);
    final protectionLevel = 'strict';
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
      protectionLevel: protectionLevel,
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
    try {
      final result = await _channel
          .invokeMethod<List<dynamic>>('getInstalledApps')
          .timeout(_channelTimeout);
      final apps = (result ?? <dynamic>[])
          .whereType<Map>()
          .map(
              (item) => FocusShieldApp.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      apps.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
      return apps;
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> hasUsageAccessPermission() async {
    if (kIsWeb) return false;
    try {
      final granted = await _channel
          .invokeMethod<bool>('hasUsageAccessPermission')
          .timeout(_channelTimeout);
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasAccessibilityPermission() async {
    if (kIsWeb) return false;
    try {
      final granted = await _channel
          .invokeMethod<bool>('hasAccessibilityPermission')
          .timeout(_channelTimeout);
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    if (kIsWeb) return;
    try {
      await _channel
          .invokeMethod('openAccessibilitySettings')
          .timeout(_channelTimeout);
    } catch (_) {}
  }

  static Future<bool> hasOverlayPermission() async {
    if (kIsWeb) return false;
    try {
      final granted = await _channel
          .invokeMethod<bool>('hasOverlayPermission')
          .timeout(_channelTimeout);
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openOverlaySettings() async {
    if (kIsWeb) return;
    try {
      await _channel
          .invokeMethod('openOverlaySettings')
          .timeout(_channelTimeout);
    } catch (_) {}
  }

  static Future<bool> hasIgnoreBatteryOptimizationPermission() async {
    if (kIsWeb) return false;
    try {
      final granted = await _channel
          .invokeMethod<bool>('hasIgnoreBatteryOptimizationPermission')
          .timeout(_channelTimeout);
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasCorePermissions() async {
    if (kIsWeb) return false;
    final accessibility = await hasAccessibilityPermission();
    final overlay = await hasOverlayPermission();
    return accessibility && overlay;
  }

  static Future<void> openIgnoreBatteryOptimizationSettings() async {
    if (kIsWeb) return;
    try {
      await _channel
          .invokeMethod('openIgnoreBatteryOptimizationSettings')
          .timeout(_channelTimeout);
    } catch (_) {}
  }

  static Future<String> getAppIcon(String packageName) async {
    if (kIsWeb || packageName.trim().isEmpty) return '';
    try {
      final result = await _channel.invokeMethod<String>(
        'getAppIcon',
        {'packageName': packageName},
      ).timeout(_channelTimeout);
      return result ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> openUsageAccessSettings() async {
    if (kIsWeb) return;
    try {
      await _channel
          .invokeMethod('openUsageAccessSettings')
          .timeout(_channelTimeout);
    } catch (_) {}
  }

  static Future<bool> startFocusSession({
    required String subject,
    required int durationSeconds,
    required List<FocusShieldApp> blockedApps,
  }) async {
    if (kIsWeb || blockedApps.isEmpty) return false;
    try {
      await _channel.invokeMethod('startFocusSession', {
        'subject': subject,
        'durationSeconds': durationSeconds,
        'blockedApps': blockedApps
            .map(
              (app) => {
                'packageName': app.packageName,
                'label': app.label,
              },
            )
            .toList(),
      }).timeout(_channelTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopFocusSession() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('stopFocusSession').timeout(_channelTimeout);
    } catch (_) {}
  }

  static Future<FocusModeStatus> getStatus() async {
    if (kIsWeb) return const FocusModeStatus();
    try {
      final status = await _channel
              .invokeMapMethod<String, dynamic>('getFocusSessionStatus')
              .timeout(_channelTimeout) ??
          <String, dynamic>{};
      return FocusModeStatus.fromMap(status);
    } catch (_) {
      return const FocusModeStatus();
    }
  }
}
