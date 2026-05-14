class StudyTask {
  int? id;
  int? subjectId;
  String title;
  String notes;
  DateTime dueDate;
  String priority;
  String status;
  DateTime createdAt;
  DateTime? completedAt;

  StudyTask({
    this.id,
    this.subjectId,
    required this.title,
    this.notes = '',
    required this.dueDate,
    this.priority = 'medium',
    this.status = 'pending',
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isDone => status == 'done';

  bool get isOverdue {
    if (isDone) return false;
    final today = DateTime.now();
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final current = DateTime(today.year, today.month, today.day);
    return due.isBefore(current);
  }

  String get priorityLabel => switch (priority) {
        'high' => 'Alta',
        'low' => 'Baja',
        _ => 'Media',
      };

  String get statusLabel => switch (status) {
        'done' => 'Terminada',
        'inProgress' => 'En progreso',
        _ => 'Pendiente',
      };

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'title': title,
      'notes': notes,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory StudyTask.fromMap(Map<String, dynamic> map) {
    return StudyTask(
      id: int.tryParse('${map['id'] ?? ''}'),
      subjectId: int.tryParse('${map['subjectId'] ?? ''}'),
      title: '${map['title'] ?? 'Tarea'}',
      notes: '${map['notes'] ?? ''}',
      dueDate: DateTime.tryParse('${map['dueDate'] ?? ''}') ?? DateTime.now(),
      priority: '${map['priority'] ?? 'medium'}',
      status: '${map['status'] ?? 'pending'}',
      createdAt:
          DateTime.tryParse('${map['createdAt'] ?? ''}') ?? DateTime.now(),
      completedAt: DateTime.tryParse('${map['completedAt'] ?? ''}'),
    );
  }
}
