class PomodoroTimerPreset {
  final String id;
  final String label;
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsPerCycle;
  final bool autoStartNext;
  final bool builtIn;

  const PomodoroTimerPreset({
    required this.id,
    required this.label,
    required this.focusMinutes,
    required this.shortBreakMinutes,
    required this.longBreakMinutes,
    required this.sessionsPerCycle,
    required this.autoStartNext,
    this.builtIn = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'focusMinutes': focusMinutes,
      'shortBreakMinutes': shortBreakMinutes,
      'longBreakMinutes': longBreakMinutes,
      'sessionsPerCycle': sessionsPerCycle,
      'autoStartNext': autoStartNext,
      'builtIn': builtIn,
    };
  }

  factory PomodoroTimerPreset.fromMap(Map<String, dynamic> map) {
    return PomodoroTimerPreset(
      id: '${map['id'] ?? ''}',
      label: '${map['label'] ?? 'Preset'}',
      focusMinutes: int.tryParse('${map['focusMinutes'] ?? 25}') ?? 25,
      shortBreakMinutes: int.tryParse('${map['shortBreakMinutes'] ?? 5}') ?? 5,
      longBreakMinutes: int.tryParse('${map['longBreakMinutes'] ?? 15}') ?? 15,
      sessionsPerCycle:
          (int.tryParse('${map['sessionsPerCycle'] ?? 4}') ?? 4).clamp(1, 8),
      autoStartNext: _boolFromMap(map['autoStartNext']),
      builtIn: _boolFromMap(map['builtIn']),
    );
  }

  static bool _boolFromMap(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1';
  }
}
