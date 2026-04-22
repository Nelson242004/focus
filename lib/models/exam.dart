class Exam {
  int? id;
  String subject;
  int? subjectId;
  String examType;
  String? examLabel;
  DateTime date;
  String startTime;
  String classroom;

  Exam({
    this.id,
    required this.subject,
    this.subjectId,
    this.examType = 'partial',
    this.examLabel,
    required this.date,
    required this.startTime,
    required this.classroom,
  });

  bool get isFinal => examType == 'final';

  String get displayType => examLabel != null && examLabel!.trim().isNotEmpty
      ? examLabel!.trim()
      : (isFinal ? 'Final' : 'Parcial');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': subject,
      'subject': subject,
      'subjectId': subjectId,
      'examType': examType,
      'examLabel': examLabel,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'classroom': classroom,
      'weight': 1.0,
      'grade': null,
      'minPassingGrade': 0.0,
    };
  }

  factory Exam.fromMap(Map<String, dynamic> map) {
    final parsedDate = DateTime.tryParse('${map['date'] ?? ''}');
    return Exam(
      id: int.tryParse('${map['id'] ?? ''}'),
      subject: '${map['subject'] ?? map['title'] ?? 'Materia'}',
      subjectId: int.tryParse('${map['subjectId'] ?? ''}'),
      examType: '${map['examType'] ?? 'partial'}',
      examLabel: map['examLabel']?.toString(),
      date: parsedDate ?? DateTime.now(),
      startTime: '${map['startTime'] ?? ''}',
      classroom: '${map['classroom'] ?? ''}',
    );
  }
}
