class Pomodoro {
  int? id;
  String date;
  String subject;
  int duration; // minutos
  int? taskId;
  String taskTitle;
  String sessionGoal;
  bool? goalAchieved;
  String note;

  Pomodoro({
    this.id,
    required this.date,
    required this.subject,
    required this.duration,
    this.taskId,
    this.taskTitle = '',
    this.sessionGoal = '',
    this.goalAchieved,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'subject': subject,
      'duration': duration,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'sessionGoal': sessionGoal,
      'goalAchieved': goalAchieved == null ? null : (goalAchieved! ? 1 : 0),
      'note': note,
    };
  }

  factory Pomodoro.fromMap(Map<String, dynamic> map) {
    return Pomodoro(
      id: int.tryParse('${map['id'] ?? ''}'),
      date: '${map['date'] ?? DateTime.now().toIso8601String()}',
      subject: '${map['subject'] ?? 'Sin materia'}',
      duration: int.tryParse('${map['duration'] ?? 25}') ?? 25,
      taskId: int.tryParse('${map['taskId'] ?? ''}'),
      taskTitle: '${map['taskTitle'] ?? ''}',
      sessionGoal: '${map['sessionGoal'] ?? ''}',
      goalAchieved: map['goalAchieved'] == null
          ? null
          : '${map['goalAchieved']}' == '1' ||
              '${map['goalAchieved']}'.toLowerCase() == 'true',
      note: '${map['note'] ?? ''}',
    );
  }
}
