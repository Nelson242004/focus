import 'dart:convert';
import 'dart:io';

import 'package:focus_app/services/polytechnic_import_service.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
        'Uso: dart run tool/build_polytechnic_json.dart <entrada.xlsx> [salida.json]');
    exitCode = 64;
    return;
  }

  final inputPath = args[0];
  final outputPath = args.length > 1
      ? args[1]
      : inputPath.replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '.json');

  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    stderr.writeln('No existe el archivo de entrada: $inputPath');
    exitCode = 66;
    return;
  }

  stdout.writeln('Leyendo Excel...');
  final bytes = await inputFile.readAsBytes();
  final workbook = await PolytechnicImportService().parseWorkbookBytes(
    bytes,
    sourceName: inputFile.uri.pathSegments.isNotEmpty
        ? inputFile.uri.pathSegments.last
        : 'Horario Politecnica',
  );

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(workbook.toJson()));

  stdout.writeln('JSON generado en: $outputPath');
  stdout.writeln('Carreras: ${workbook.careers.length}');
}
