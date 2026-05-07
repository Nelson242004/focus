import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/services/polytechnic_import_service.dart';

void main() {
  group('Importador Politécnica', () {
    test('lee el formato antiguo con hojas por carrera si el archivo existe',
        () async {
      final file = File(
        r'C:\Users\Nelson\Downloads\Horario de clases y examenes .Segundo Periodo Academico version web26112025.xlsx',
      );
      if (!file.existsSync()) {
        return;
      }

      final workbook = await PolytechnicImportService().parseWorkbookBytes(
        await file.readAsBytes(),
        sourceName: file.uri.pathSegments.last,
      );

      expect(workbook.careers, isNotEmpty);

      final informatica = workbook.careers.firstWhere(
        (career) => career.code == 'IIN',
      );
      final informaticaSubjects = informatica.semesters
          .expand((semester) => semester.subjects)
          .toList();
      expect(informaticaSubjects.length, greaterThan(20));
      final informaticaSections =
          informaticaSubjects.expand((subject) => subject.sections).toList();
      expect(informaticaSections.length, greaterThan(20));
      expect(
        informaticaSections.where((section) => section.schedules.isNotEmpty),
        isNotEmpty,
      );
      expect(
        informaticaSections.where((section) => section.exams.isNotEmpty),
        isNotEmpty,
      );

      final sistemasProduccion = workbook.careers.firstWhere(
        (career) => career.code == 'ISP',
      );
      final sistemasProduccionSubjects = sistemasProduccion.semesters
          .expand((semester) => semester.subjects)
          .toList();
      expect(sistemasProduccionSubjects.length, greaterThan(1));
    });
  });
}
