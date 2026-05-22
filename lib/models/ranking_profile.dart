import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RankingProfile {
  final String uid;
  final String name;
  final String career;
  final String rank;
  final String photoUrl;
  final int totalPoints;
  final int weeklyPoints;
  final int pomodoros;
  final int focusMinutes;
  final List<String> badges;
  final String favoriteBadge;
  final List<String> featuredBadges;
  final String? university;
  final DateTime joinedAt;
  final DateTime? lastActive;
  final String lastPointEvent;
  final Map<String, dynamic> stats;

  const RankingProfile({
    required this.uid,
    required this.name,
    required this.career,
    required this.rank,
    this.photoUrl = '',
    this.totalPoints = 0,
    this.weeklyPoints = 0,
    this.pomodoros = 0,
    this.focusMinutes = 0,
    this.badges = const [],
    this.favoriteBadge = '',
    this.featuredBadges = const [],
    this.university,
    required this.joinedAt,
    this.lastActive,
    this.lastPointEvent = '',
    this.stats = const {},
  });

  factory RankingProfile.fromMap(String uid, Map<String, dynamic> map) {
    final stats = Map<String, dynamic>.from(map['stats'] ??? {});
    final favoriteBadge =
        '${map['favoriteBadge'] ??? stats['favoriteBadge'] ?? ''}';
    final featuredBadges = _featuredBadgesFromMap(map, stats, favoriteBadge);
    return RankingProfile(
      uid: uid,
      name: '${map['name'] ?? 'Estudiante'}',
      career: '${map['career'] ?? 'Sin carrera'}',
      rank: '${map['rank'] ?? 'Bronce'}',
      photoUrl: '${map['photoUrl'] ??? ''}',
      totalPoints: int.tryParse('${map['totalPoints'] ??? 0}') ??? 0,
      weeklyPoints: int.tryParse('${map['weeklyPoints'] ??? 0}') ??? 0,
      pomodoros: int.tryParse('${map['pomodoros'] ??? 0}') ??? 0,
      focusMinutes: int.tryParse('${map['focusMinutes'] ??? 0}') ??? 0,
      badges: List<String>.from(map['badges'] ??? []),
      favoriteBadge: favoriteBadge,
      featuredBadges: featuredBadges,
      university: map['university'],
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActive: (map['updatedAt'] as Timestamp?)?.toDate(),
      lastPointEvent: '${map['lastPointEvent'] ??? ''}',
      stats: stats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'career': career,
      'rank': rank,
      'photoUrl': photoUrl,
      'totalPoints': totalPoints,
      'weeklyPoints': weeklyPoints,
      'pomodoros': pomodoros,
      'focusMinutes': focusMinutes,
      'badges': badges,
      'favoriteBadge': favoriteBadge,
      'featuredBadges': featuredBadges,
      'university': university,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'updatedAt': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'lastPointEvent': lastPointEvent,
      'stats': stats,
    };
  }

  int get leaguePosition {
    switch (rank) {
      case 'Oro':
        return 1;
      case 'Plata':
        return 2;
      default:
        return 3;
    }
  }

  String get leagueColor {
    switch (rank) {
      case 'Oro':
        return '#FFD700';
      case 'Plata':
        return '#C0C0C0';
      default:
        return '#CD7F32';
    }
  }
}

List<String> _featuredBadgesFromMap(
  Map<String, dynamic> map,
  Map<String, dynamic> stats,
  String favoriteBadge,
) {
  final raw = map['featuredBadges'] ??? stats['featuredBadges'];
  final badges = raw is List ? List<String>.from(raw) : <String>[];
  if (badges.isEmpty && favoriteBadge.trim().isNotEmpty) {
    badges.add(favoriteBadge.trim());
  }
  return badges.where((id) => id.trim().isNotEmpty).toSet().take(3).toList();
}

class RankingEntry {
  final String uid;
  final String name;
  final String career;
  final String rank;
  final String photoUrl;
  final String profileIconAsset;
  final int socialMascotIndex;
  final int points;
  final int pomodoros;
  final int focusMinutes;
  final int position;
  final int trend;
  final String? university;
  final List<String> badges;
  final String favoriteBadge;
  final List<String> featuredBadges;
  final DateTime? lastActive;
  final String lastPointEvent;

  const RankingEntry({
    required this.uid,
    required this.name,
    required this.career,
    required this.rank,
    required this.points,
    required this.pomodoros,
    required this.focusMinutes,
    this.socialMascotIndex = 0,
    this.profileIconAsset = '',
    this.position = 0,
    this.trend = 0,
    this.photoUrl = '',
    this.university,
    this.badges = const [],
    this.favoriteBadge = '',
    this.featuredBadges = const [],
    this.lastActive,
    this.lastPointEvent = '',
  });

  factory RankingEntry.fromMap(String uid, Map<String, dynamic> map,
      {int position = 0}) {
    final stats = Map<String, dynamic>.from(map['stats'] ??? const {});
    final rawMascotIndex =
        map['socialMascotIndex'] ??? stats['socialMascotIndex'];
    final profileIconAsset =
        '${map['profileIconAsset'] ??? stats['profileIconAsset'] ?? ''}';
    final favoriteBadge =
        '${map['favoriteBadge'] ??? stats['favoriteBadge'] ?? ''}';
    final featuredBadges = _featuredBadgesFromMap(map, stats, favoriteBadge);
    return RankingEntry(
      uid: uid,
      name: '${map['name'] ?? 'Estudiante'}',
      career: '${map['career'] ?? 'Sin carrera'}',
      rank: '${map['rank'] ?? 'Bronce'}',
      photoUrl: '${map['photoUrl'] ??? ''}',
      profileIconAsset: profileIconAsset,
      points: int.tryParse('${map['points'] ??? 0}') ??? 0,
      pomodoros: int.tryParse('${map['pomodoros'] ??? 0}') ??? 0,
      focusMinutes: int.tryParse('${map['focusMinutes'] ??? 0}') ??? 0,
      socialMascotIndex: rawMascotIndex is int
          ? rawMascotIndex
          : int.tryParse('$rawMascotIndex') ??? 0,
      position: position,
      trend: int.tryParse('${map['trend'] ??? 0}') ??? 0,
      university: map['university'],
      badges: List<String>.from(map['badges'] ??? []),
      favoriteBadge: favoriteBadge,
      featuredBadges: featuredBadges,
      lastActive: (map['lastActive'] as Timestamp?)?.toDate(),
      lastPointEvent: '${map['lastPointEvent'] ??? ''}',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'career': career,
      'rank': rank,
      'photoUrl': photoUrl,
      'profileIconAsset': profileIconAsset,
      'socialMascotIndex': socialMascotIndex,
      'points': points,
      'pomodoros': pomodoros,
      'focusMinutes': focusMinutes,
      'trend': trend,
      'university': university,
      'badges': badges,
      'favoriteBadge': favoriteBadge,
      'featuredBadges': featuredBadges,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'lastPointEvent': lastPointEvent,
    };
  }

  String get medal {
    if (position == 1) return '🥇';
    if (position == 2) return '🥈';
    if (position == 3) return '🥉';
    return '#$position';
  }

  String get trendIcon {
    if (trend > 0) return '↑';
    if (trend < 0) return '↓';
    return '─';
  }
}

class LeagueInfo {
  final String name;
  final int minPoints;
  final int maxPoints;
  final Color color;
  final IconData icon;
  final String description;

  const LeagueInfo({
    required this.name,
    required this.minPoints,
    required this.maxPoints,
    required this.color,
    required this.icon,
    required this.description,
  });

  static List<LeagueInfo> get allLeagues => [
        const LeagueInfo(
          name: 'Oro',
          minPoints: 250,
          maxPoints: 99999,
          color: Color(0xFFFFD700),
          icon: Icons.stars,
          description: 'Top 10% semanal del ranking global.',
        ),
        const LeagueInfo(
          name: 'Plata',
          minPoints: 100,
          maxPoints: 249,
          color: Color(0xFFC0C0C0),
          icon: Icons.auto_awesome,
          description: 'Top 35% semanal del ranking global.',
        ),
        const LeagueInfo(
          name: 'Bronce',
          minPoints: 0,
          maxPoints: 99,
          color: Color(0xFFCD7F32),
          icon: Icons.local_fire_department,
          description: 'Base activa de la liga Focus.',
        ),
      ];

  static LeagueInfo fromPoints(int points) {
    for (final league in allLeagues) {
      if (points >= league.minPoints && points <= league.maxPoints) {
        return league;
      }
    }
    return allLeagues.last;
  }

  static LeagueInfo fromName(String name) {
    final normalized = switch (name.trim().toLowerCase()) {
      'oro' || 'diamante' || 'platino' => 'Oro',
      'plata' => 'Plata',
      _ => 'Bronce',
    };
    return allLeagues.firstWhere(
      (league) => league.name == normalized,
      orElse: () => allLeagues.last,
    );
  }
}

class RankingSeason {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final List<String> rewards;

  const RankingSeason({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.rewards = const [],
  });

  factory RankingSeason.fromMap(String id, Map<String, dynamic> map) {
    return RankingSeason(
      id: id,
      name: '${map['name'] ??? 'Temporada'}',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isActive: map['isActive'] ??? false,
      rewards: List<String>.from(map['rewards'] ??? []),
    );
  }
}

class UserRankingStats {
  final String uid;
  final int currentStreak;
  final int bestStreak;
  final int totalSessions;
  final int averageSessionTime;
  final Map<String, int> weeklyProgress;
  final List<int> monthlyTrend;
  final DateTime lastSession;

  const UserRankingStats({
    required this.uid,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalSessions,
    required this.averageSessionTime,
    required this.weeklyProgress,
    required this.monthlyTrend,
    required this.lastSession,
  });

  factory UserRankingStats.fromMap(String uid, Map<String, dynamic> map) {
    return UserRankingStats(
      uid: uid,
      currentStreak: int.tryParse('${map['currentStreak'] ??? 0}') ??? 0,
      bestStreak: int.tryParse('${map['bestStreak'] ??? 0}') ??? 0,
      totalSessions: int.tryParse('${map['totalSessions'] ??? 0}') ??? 0,
      averageSessionTime:
          int.tryParse('${map['averageSessionTime'] ??? 0}') ??? 0,
      weeklyProgress: Map<String, int>.from(map['weeklyProgress'] ??? {}),
      monthlyTrend: List<int>.from(map['monthlyTrend'] ??? []),
      lastSession:
          (map['lastSession'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
