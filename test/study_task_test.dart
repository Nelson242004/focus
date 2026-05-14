import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/models/study_task.dart';

void main() {
  group('StudyTask', () {
    test('serializa y restaura los datos académicos de una tarea', () {
      final createdAt = DateTime(2026, 5, 10, 9, 30);
      final completedAt = DateTime(2026, 5, 12, 18);
      final task = StudyTask(
        id: 7,
        subjectId: 3,
        title: 'Resolver práctica 4',
        notes: 'Matrices y determinantes',
        dueDate: DateTime(2026, 5, 14),
        priority: 'high',
        status: 'done',
        createdAt: createdAt,
        completedAt: completedAt,
      );

      final restored = StudyTask.fromMap(task.toMap());

      expect(restored.id, 7);
      expect(restored.subjectId, 3);
      expect(restored.title, 'Resolver práctica 4');
      expect(restored.notes, 'Matrices y determinantes');
      expect(restored.priority, 'high');
      expect(restored.priorityLabel, 'Alta');
      expect(restored.status, 'done');
      expect(restored.statusLabel, 'Terminada');
      expect(restored.createdAt, createdAt);
      expect(restored.completedAt, completedAt);
    });

    test('detecta vencimiento solo en tareas activas', () {
      final overdue = StudyTask(
        title: 'Leer capítulo',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      final doneOverdue = StudyTask(
        title: 'Entregar informe',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        status: 'done',
      );

      expect(overdue.isOverdue, isTrue);
      expect(doneOverdue.isOverdue, isFalse);
    });
  });
}
