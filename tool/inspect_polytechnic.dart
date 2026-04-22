import 'dart:io';
import 'package:focus_app/services/polytechnic_import_service.dart';

void main() async {
  final bytes = await File(r'C:\Users\Nelson\Downloads\Horario de clases y examenes Primer Periodo 2026versionweb09042026.xlsx').readAsBytes();
  final workbook = await PolytechnicImportService().parseWorkbookBytes(bytes, sourceName: 'test');
  final career = workbook.careers.firstWhere((c) => c.code == 'IIN');
  final subjectCount = career.semesters.fold<int>(0, (sum, s) => sum + s.subjects.length);
  print('IIN sem=${career.semesters.length} subj=$subjectCount');
  for (final subject in career.semesters.expand((s) => s.subjects).where((s) {
    final n = s.name.toLowerCase();
    return n.contains('invest') || n.contains('metod') || n.contains('base de datos');
  })) {
    print('SUBJECT ${subject.name} sem=${subject.semester}');
    for (final section in subject.sections) {
      print('  SEC ${section.code} exams=${section.exams.length}');
      for (final exam in section.exams) {
        print('    ${exam.label} ${exam.startTime} ${exam.classroom}');
      }
    }
  }
}
