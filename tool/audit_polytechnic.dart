import 'dart:io';
import 'package:focus_app/services/polytechnic_import_service.dart';

void main() async {
  final bytes = await File(r'C:\Users\Nelson\Downloads\Horario de clases y examenes Primer Periodo 2026versionweb09042026.xlsx').readAsBytes();
  final workbook = await PolytechnicImportService().parseWorkbookBytes(bytes, sourceName: 'test');
  for (final career in workbook.careers) {
    final subjectCount = career.semesters.fold<int>(0, (sum, s) => sum + s.subjects.length);
    final sectionCount = career.semesters.expand((s) => s.subjects).fold<int>(0, (sum, s) => sum + s.sections.length);
    final examCount = career.semesters.expand((s) => s.subjects).expand((s) => s.sections).fold<int>(0, (sum, sec) => sum + sec.exams.length);
    print('${career.code}|subjects=$subjectCount|sections=$sectionCount|exams=$examCount');
  }
}
