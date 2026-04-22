class Pomodoro {
  int? id;
  String date;
  String subject;
  int duration; // minutos

  Pomodoro({
    this.id,
    required this.date,
    required this.subject,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'subject': subject,
      'duration': duration,
    };
  }

  factory Pomodoro.fromMap(Map<String, dynamic> map) {
    return Pomodoro(
      id: int.tryParse('${map['id'] ?? ''}'),
      date: '${map['date'] ?? DateTime.now().toIso8601String()}',
      subject: '${map['subject'] ?? 'Sin materia'}',
      duration: int.tryParse('${map['duration'] ?? 25}') ?? 25,
    );
  }
}
