import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam.dart';
import '../models/ranking_profile.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/app_utils.dart';
import '../utils/profile_icon_access.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('focus_home_widget');
  static const String _profileIconAssetKey = 'focus_widget_profile_icon_asset';
  static const String _profileIconImageBase64Key =
      'focus_widget_profile_icon_image_base64';

  static Future<void> syncFromProvider(AppProvider provider) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final nextClass = provider.nextScheduleEntry;
    final nextExam = provider.nextUpcomingExam;
    final nextExamAt = nextExam == null
        ? null
        : combineDateAndTime(nextExam.date, nextExam.startTime);
    final profileIconAsset = await _currentProfileIconAsset();
    final profileIconBase64 = await _currentProfileIconBase64(
      profileIconAsset,
    );
    final today = DateTime.now().toIso8601String().split('T')[0];
    final studiedToday = provider.pomodoros.any(
          (pomodoro) => pomodoro.date.startsWith(today),
        ) ||
        provider.habits.any((habit) => habit.history.contains(today));
    final streakAtRisk = provider.currentStreak > 0 && !studiedToday;

    final payload = <String, dynamic>{
      'widgetMode': streakAtRisk ? 'streak_risk' : _academicMode(nextExamAt),
      'classTitle': streakAtRisk
          ? 'Racha en riesgo'
          : nextClass?.subject.name ?? 'Día libre por ahora',
      'classDetail': streakAtRisk
          ? 'Completa una sesión o hábito hoy.'
          : nextClass != null
              ? '${weekdayLabel(nextClass.schedule.dayOfWeek)} · ${nextClass.schedule.startTime} a ${nextClass.schedule.endTime}'
              : 'Abre Focus y organiza tu semana.',
      'examTitle':
          nextExam == null ? '' : provider.subjectNameForExam(nextExam),
      'examDetail': nextExam == null ? '' : _examDetail(nextExam),
      'examNote': nextExam == null ? '' : _examNote(nextExam),
      'examAtMillis': nextExamAt?.millisecondsSinceEpoch ?? 0,
      'meta': _streakLabel(provider.currentStreak),
      'profileIconAsset': profileIconAsset,
      'profileIconBase64': profileIconBase64,
    };

    try {
      await _channel.invokeMethod<void>('updateWidget', payload);
    } catch (error) {
      debugPrint('Widget sync skipped: $error');
    }
  }

  static Future<void> syncPomodoroState({
    required String mode,
    required bool isRunning,
    required int remainingSeconds,
    required int totalSeconds,
    required String subject,
    String taskTitle = '',
    required int currentStreak,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final safeTotal = totalSeconds <= 0 ? 1 : totalSeconds;
    final ratio = (remainingSeconds / safeTotal).clamp(0.0, 1.0);
    final widgetMode = !isRunning
        ? 'idle'
        : mode == 'focus' && ratio <= 0.18
            ? 'almost_done'
            : mode == 'focus'
                ? 'pomodoro'
                : 'break';
    final label = mode == 'focus'
        ? 'Pomodoro activo'
        : mode == 'longBreak'
            ? 'Descanso largo'
            : 'Descanso corto';
    final cleanTaskTitle = taskTitle.trim();
    final title = mode == 'focus'
        ? (cleanTaskTitle.isNotEmpty
            ? 'Enfoque: $cleanTaskTitle'
            : subject.trim().isEmpty
                ? 'General'
                : subject.trim())
        : 'Recarga energía';
    final profileIconAsset = await _storedProfileIconAsset();
    final profileIconBase64 = await _currentProfileIconBase64(
      profileIconAsset,
    );

    final payload = <String, dynamic>{
      'widgetMode': widgetMode,
      'classTitle': title,
      'classDetail': '${_formatDuration(remainingSeconds)} restantes',
      'examTitle': '',
      'examDetail': '',
      'examNote': label,
      'examAtMillis': 0,
      'meta': _streakLabel(currentStreak),
      'profileIconAsset': profileIconAsset,
      'profileIconBase64': profileIconBase64,
    };

    try {
      await _channel.invokeMethod<void>('updateWidget', payload);
    } catch (error) {
      debugPrint('Widget pomodoro sync skipped: $error');
    }
  }

  static Future<void> syncProfileIconAsset(String asset) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final normalized = _normalizeProfileIconAsset(
      asset,
      RankingService.currentUser?.email,
    );
    await _saveProfileIconAsset(normalized);
    final imageBase64 = await _imageBase64ForAsset(normalized);
    await _saveProfileIconBase64(imageBase64);
    try {
      await _channel.invokeMethod<void>('updateWidgetProfileIcon', {
        'profileIconAsset': normalized,
        'profileIconBase64': imageBase64,
      });
    } catch (error) {
      debugPrint('Widget profile icon sync skipped: $error');
    }
  }

  static String _examDetail(Exam exam) {
    final classroom = exam.classroom.trim();
    return classroom.isEmpty ? 'Aula por confirmar' : 'Aula $classroom';
  }

  static String _examNote(Exam exam) {
    return <String>[
      exam.displayType,
      if (exam.startTime.trim().isNotEmpty) exam.startTime,
    ].join(' · ');
  }

  static String _streakLabel(int streak) {
    if (streak == 1) return '1 día';
    return '$streak días';
  }

  static String _academicMode(DateTime? nextExamAt) {
    if (nextExamAt == null) return 'class';
    final remaining = nextExamAt.difference(DateTime.now());
    if (!remaining.isNegative && remaining <= const Duration(days: 1)) {
      return 'exam';
    }
    return 'class';
  }

  static String _formatDuration(int seconds) {
    final safeSeconds = seconds.clamp(0, 24 * 60 * 60);
    final minutes = safeSeconds ~/ 60;
    final remaining = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  static Future<String> _currentProfileIconAsset() async {
    final profile =
        RankingService.currentUser == null ? null : await _fetchProfileSafely();
    final asset = profile == null
        ? await _storedProfileIconAsset()
        : _assetFromProfile(profile);
    await _saveProfileIconAsset(asset);
    return asset;
  }

  static Future<RankingProfile?> _fetchProfileSafely() async {
    try {
      return RankingService.fetchProfile();
    } catch (error) {
      debugPrint('Widget profile fetch skipped: $error');
      return null;
    }
  }

  static String _assetFromProfile(RankingProfile profile) {
    final rawAsset = '${profile.stats['profileIconAsset'] ?? ''}'.trim();
    if (rawAsset.isNotEmpty) {
      return _normalizeProfileIconAsset(
        rawAsset,
        RankingService.currentUser?.email,
      );
    }

    final rawIndex = profile.stats['socialMascotIndex'];
    final index = rawIndex is int ? rawIndex : int.tryParse('$rawIndex') ?? 0;
    if (index < 0 || index >= profileIconAssets.length) {
      return defaultProfileIconAsset;
    }
    return allowedProfileIconAssetOrDefault(
      profileIconAssets[index],
      RankingService.currentUser?.email,
      defaultAsset: defaultProfileIconAsset,
    );
  }

  static Future<String> _storedProfileIconAsset() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeProfileIconAsset(
      prefs.getString(_profileIconAssetKey) ?? defaultProfileIconAsset,
      RankingService.currentUser?.email,
    );
  }

  static Future<void> _saveProfileIconAsset(String asset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profileIconAssetKey,
      _normalizeProfileIconAsset(asset, RankingService.currentUser?.email),
    );
  }

  static Future<String> _currentProfileIconBase64(String asset) async {
    if (!isGiphyProfileIconAsset(asset)) {
      await _saveProfileIconBase64('');
      return '';
    }
    final imageBase64 = await _imageBase64ForAsset(asset);
    if (imageBase64.isNotEmpty) {
      await _saveProfileIconBase64(imageBase64);
      return imageBase64;
    }
    return _storedProfileIconBase64();
  }

  static Future<String> _storedProfileIconBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileIconImageBase64Key) ?? '';
  }

  static Future<void> _saveProfileIconBase64(String imageBase64) async {
    final prefs = await SharedPreferences.getInstance();
    if (imageBase64.isEmpty) {
      await prefs.remove(_profileIconImageBase64Key);
      return;
    }
    await prefs.setString(_profileIconImageBase64Key, imageBase64);
  }

  static Future<String> _imageBase64ForAsset(String asset) async {
    if (!isGiphyProfileIconAsset(asset)) return '';
    final bytes = await _downloadProfileIconBytes(_giphyStillUrl(asset));
    if (bytes == null || bytes.isEmpty) return '';
    return base64Encode(bytes);
  }

  static String _giphyStillUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path;
    if (!path.toLowerCase().endsWith('.gif')) return url;
    final stillPath =
        path.replaceFirst(RegExp(r'\.gif$', caseSensitive: false), '_s.gif');
    return uri.replace(path: stillPath).toString();
  }

  static Future<Uint8List?> _downloadProfileIconBytes(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (response.bodyBytes.lengthInBytes > 700 * 1024) return null;
      return response.bodyBytes;
    } catch (error) {
      debugPrint('Widget profile icon download skipped: $error');
      return null;
    }
  }

  static String _normalizeProfileIconAsset(String asset, String? email) {
    if (isGiphyProfileIconAsset(asset)) return asset;
    if (!profileIconAssets.contains(asset)) return defaultProfileIconAsset;
    return allowedProfileIconAssetOrDefault(
      asset,
      email,
      defaultAsset: defaultProfileIconAsset,
    );
  }
}
