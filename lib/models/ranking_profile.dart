class RankingProfile {
  final String uid;
  final String name;
  final String career;
  final String rank;
  final String photoUrl;

  const RankingProfile({
    required this.uid,
    required this.name,
    required this.career,
    required this.rank,
    this.photoUrl = '',
  });

  factory RankingProfile.fromMap(String uid, Map<String, dynamic> map) {
    return RankingProfile(
      uid: uid,
      name: '${map['name'] ?? 'Estudiante'}',
      career: '${map['career'] ?? 'Sin carrera'}',
      rank: '${map['rank'] ?? 'Bronce'}',
      photoUrl: '${map['photoUrl'] ?? ''}',
    );
  }
}

class RankingEntry {
  final String uid;
  final String name;
  final String career;
  final String rank;
  final String photoUrl;
  final int points;
  final int pomodoros;
  final int focusMinutes;

  const RankingEntry({
    required this.uid,
    required this.name,
    required this.career,
    required this.rank,
    required this.points,
    required this.pomodoros,
    required this.focusMinutes,
    this.photoUrl = '',
  });

  factory RankingEntry.fromMap(String uid, Map<String, dynamic> map) {
    return RankingEntry(
      uid: uid,
      name: '${map['name'] ?? 'Estudiante'}',
      career: '${map['career'] ?? 'Sin carrera'}',
      rank: '${map['rank'] ?? 'Bronce'}',
      photoUrl: '${map['photoUrl'] ?? ''}',
      points: int.tryParse('${map['points'] ?? 0}') ?? 0,
      pomodoros: int.tryParse('${map['pomodoros'] ?? 0}') ?? 0,
      focusMinutes: int.tryParse('${map['focusMinutes'] ?? 0}') ?? 0,
    );
  }
}
