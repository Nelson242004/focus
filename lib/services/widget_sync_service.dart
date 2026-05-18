import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam.dart';
import '../models/ranking_profile.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/app_utils.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('focus_home_widget');
  static const String _profileIconAssetKey = 'focus_widget_profile_icon_asset';
  static const String _defaultProfileIconAsset =
      'assets/profile_icons/focus_scholar.png';

  static const List<String> _profileIconAssets = [
    'assets/profile_icons/focus_scholar.png',
    'assets/profile_icons/focus_flame.png',
    'assets/profile_icons/focus_calm.png',
    'assets/profile_icons/focus_champion.png',
    'assets/profile_icons/focus_scholar_female.png',
    'assets/profile_icons/focus_flame_female.png',
    'assets/profile_icons/focus_calm_female.png',
    'assets/profile_icons/focus_champion_female.png',
  ];

  static Future<void> syncFromProvider(AppProvider provider) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final nextClass = provider.nextScheduleEntry;
    final nextExam = provider.nextUpcomingExam;
    final nextExamAt = nextExam == null
        ? null
        : combineDateAndTime(nextExam.date, nextExam.startTime);
    final profileIconAsset = await _currentProfileIconAsset();

    final payload = <String, dynamic>{
      'widgetMode': _academicMode(nextExamAt),
      'classTitle': nextClass?.subject.name ?? 'Día libre por ahora',
      'classDetail': nextClass != null
          ? '${weekdayLabel(nextClass.schedule.dayOfWeek)} · ${nextClass.schedule.startTime} a ${nextClass.schedule.endTime}'
          : 'Abre Focus y organiza tu semana.',
      'examTitle':
          nextExam == null ? '' : provider.subjectNameForExam(nextExam),
      'examDetail': nextExam == null ? '' : _examDetail(nextExam),
      'examNote': nextExam == null ? '' : _examNote(nextExam),
      'examAtMillis': nextExamAt?.millisecondsSinceEpoch ?? 0,
      'meta': _streakLabel(provider.currentStreak),
      'profileIconAsset': profileIconAsset,
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
    final title = mode == 'focus'
        ? (subject.trim().isEmpty ? 'General' : subject.trim())
        : 'Recarga energía';
    final profileIconAsset = await _storedProfileIconAsset();

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
    };

    try {
      await _channel.invokeMethod<void>('updateWidget', payload);
    } catch (error) {
      debugPrint('Widget pomodoro sync skipped: $error');
    }
  }

  static Future<void> syncProfileIconAsset(String asset) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final normalized = _normalizeProfileIconAsset(asset);
    await _saveProfileIconAsset(normalized);
    try {
      await _channel.invokeMethod<void>('updateWidgetProfileIcon', {
        'profileIconAsset': normalized,
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
    final rawIndex = profile.stats['socialMascotIndex'];
    final index = rawIndex is int ? rawIndex : int.tryParse('$rawIndex') ?? 0;
    if (index < 0 || index >= _profileIconAssets.length) {
      return _defaultProfileIconAsset;
    }
    return _profileIconAssets[index];
  }

  static Future<String> _storedProfileIconAsset() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeProfileIconAsset(
      prefs.getString(_profileIconAssetKey) ?? _defaultProfileIconAsset,
    );
  }

  static Future<void> _saveProfileIconAsset(String asset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profileIconAssetKey,
      _normalizeProfileIconAsset(asset),
    );
  }

  static String _normalizeProfileIconAsset(String asset) {
    return _profileIconAssets.contains(asset)
        ? asset
        : _defaultProfileIconAsset;
  }
}

