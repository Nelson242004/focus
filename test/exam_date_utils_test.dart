import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/models/exam.dart';
import 'package:focus_app/utils/app_utils.dart';

void main() {
  test('calendarDaysUntil usa dias calendario y no horas restantes', () {
    final todayLate = DateTime(2026, 5, 27, 22);
    final tomorrowEarly = DateTime(2026, 5, 28, 8);

    expect(calendarDaysUntil(tomorrowEarly, from: todayLate), 1);
  });

  test('isExamUpcoming mantiene examenes sin hora activos durante su dia', () {
    final exam = Exam(
      subject: 'Matematica',
      date: DateTime(2026, 5, 27),
      startTime: '',
      classroom: '',
    );

    expect(isExamUpcoming(exam, now: DateTime(2026, 5, 27, 22)), isTrue);
  });

  test('isExamUpcoming marca pasado un examen con hora vencida', () {
    final exam = Exam(
      subject: 'Fisica',
      date: DateTime(2026, 5, 27),
      startTime: '08:00',
      classroom: '',
    );

    expect(isExamUpcoming(exam, now: DateTime(2026, 5, 27, 9)), isFalse);
  });
}
