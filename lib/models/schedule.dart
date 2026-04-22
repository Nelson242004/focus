class Schedule {
  int? id;
  int subjectId;
  int dayOfWeek; // 0 = lunes, 1 = martes, ..., 6 = domingo
  String startTime; // formato "HH:MM"
  String endTime;
  String classroom;

  Schedule({
    this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.classroom,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'classroom': classroom,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: int.tryParse('${map['id'] ?? ''}'),
      subjectId: int.tryParse('${map['subjectId'] ?? -1}') ?? -1,
      dayOfWeek: int.tryParse('${map['dayOfWeek'] ?? 0}') ?? 0,
      startTime: '${map['startTime'] ?? '08:00'}',
      endTime: '${map['endTime'] ?? '09:00'}',
      classroom: '${map['classroom'] ?? ''}',
    );
  }
}
