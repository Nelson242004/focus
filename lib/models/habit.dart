class Habit {
  int? id;
  String name;
  String identity;
  int streak;
  List<String> history;
  DateTime createdAt;

  Habit({
    this.id,
    required this.name,
    this.identity = 'Soy alguien que cumple incluso cuando no tiene ganas.',
    this.streak = 0,
    required this.history,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get currentStreak {
    if (history.isEmpty) return 0;
    final dates = history.map(DateTime.parse).toList()
      ..sort((a, b) => b.compareTo(a));
    final today = _dateToString(DateTime.now());
    final yesterday =
        _dateToString(DateTime.now().subtract(const Duration(days: 1)));

    if (!history.contains(today) && !history.contains(yesterday)) return 0;

    var streakCount = 1;
    var current = dates.first;
    for (var i = 1; i < dates.length; i++) {
      final previousDate = dates[i];
      final diff = current.difference(previousDate).inDays;
      if (diff == 1) {
        streakCount++;
        current = previousDate;
      } else {
        break;
      }
    }
    return streakCount;
  }

  int get bestStreak {
    if (history.isEmpty) return 0;
    final dates = history.map(DateTime.parse).toList()
      ..sort((a, b) => a.compareTo(b));
    var maxStreak = 1;
    var current = 1;
    for (var i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 1;
      }
    }
    return maxStreak;
  }

  double completionPercentage(int days) {
    if (history.isEmpty || days <= 0) return 0.0;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    var completed = 0;
    for (var i = 0; i < days; i++) {
      final dateStr = _dateToString(startDate.add(Duration(days: i)));
      if (history.contains(dateStr)) completed++;
    }
    return completed / days;
  }

  static String _dateToString(DateTime date) =>
      date.toIso8601String().split('T')[0];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'identity': identity,
      'streak': streak,
      'history': history.join(','),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: int.tryParse('${map['id'] ?? ''}'),
      name: '${map['name'] ?? 'Hábito'}',
      identity: map['identity']?.toString() ??
          'Soy alguien que cumple incluso cuando no tiene ganas.',
      streak: int.tryParse('${map['streak'] ?? 0}') ?? 0,
      history: map['history']
          .toString()
          .split(',')
          .where((e) => e.isNotEmpty)
          .toList(),
      createdAt:
          DateTime.tryParse('${map['createdAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}
