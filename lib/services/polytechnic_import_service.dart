import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class PolytechnicWorkbook {
  final String sourceName;
  final List<PolytechnicCareer> careers;

  const PolytechnicWorkbook({
    required this.sourceName,
    required this.careers,
  });

  Map<String, dynamic> toJson() => {
        'sourceName': sourceName,
        'careers': careers.map((career) => career.toJson()).toList(),
      };

  factory PolytechnicWorkbook.fromJson(Map<String, dynamic> json) {
    return PolytechnicWorkbook(
      sourceName: (json['sourceName'] as String?) ?? 'Horario Politécnica',
      careers: ((json['careers'] as List?) ?? const [])
          .whereType<Map>()
          .map((career) =>
              PolytechnicCareer.fromJson(Map<String, dynamic>.from(career)))
          .toList(),
    );
  }
}

class PolytechnicCareer {
  final String code;
  final String name;
  final List<PolytechnicSemester> semesters;

  const PolytechnicCareer({
    required this.code,
    required this.name,
    required this.semesters,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'semesters': semesters.map((semester) => semester.toJson()).toList(),
      };

  factory PolytechnicCareer.fromJson(Map<String, dynamic> json) {
    return PolytechnicCareer(
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      semesters: ((json['semesters'] as List?) ?? const [])
          .whereType<Map>()
          .map((semester) =>
              PolytechnicSemester.fromJson(Map<String, dynamic>.from(semester)))
          .toList(),
    );
  }
}

class PolytechnicSemester {
  final int number;
  final List<PolytechnicSubjectOption> subjects;

  const PolytechnicSemester({
    required this.number,
    required this.subjects,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'subjects': subjects.map((subject) => subject.toJson()).toList(),
      };

  factory PolytechnicSemester.fromJson(Map<String, dynamic> json) {
    return PolytechnicSemester(
      number: (json['number'] as num?)?.toInt() ?? 0,
      subjects: ((json['subjects'] as List?) ?? const [])
          .whereType<Map>()
          .map((subject) => PolytechnicSubjectOption.fromJson(
              Map<String, dynamic>.from(subject)))
          .toList(),
    );
  }
}

class PolytechnicSubjectOption {
  final String careerCode;
  final String careerName;
  final int semester;
  final String name;
  final List<PolytechnicSectionOption> sections;

  const PolytechnicSubjectOption({
    required this.careerCode,
    required this.careerName,
    required this.semester,
    required this.name,
    required this.sections,
  });

  String get key => '$careerCode|$semester|$name';

  Map<String, dynamic> toJson() => {
        'careerCode': careerCode,
        'careerName': careerName,
        'semester': semester,
        'name': name,
        'sections': sections.map((section) => section.toJson()).toList(),
      };

  factory PolytechnicSubjectOption.fromJson(Map<String, dynamic> json) {
    return PolytechnicSubjectOption(
      careerCode: (json['careerCode'] as String?) ?? '',
      careerName: (json['careerName'] as String?) ?? '',
      semester: (json['semester'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      sections: ((json['sections'] as List?) ?? const [])
          .whereType<Map>()
          .map((section) => PolytechnicSectionOption.fromJson(
              Map<String, dynamic>.from(section)))
          .toList(),
    );
  }
}

class PolytechnicSectionOption {
  final String code;
  final String teacher;
  final String defaultClassroom;
  final String shift;
  final List<PolytechnicScheduleTemplate> schedules;
  final List<PolytechnicExamTemplate> exams;

  const PolytechnicSectionOption({
    required this.code,
    required this.teacher,
    required this.defaultClassroom,
    required this.shift,
    required this.schedules,
    required this.exams,
  });

  String get label => code.isEmpty ? 'Sección sin código' : 'Sección $code';

  Map<String, dynamic> toJson() => {
        'code': code,
        'teacher': teacher,
        'defaultClassroom': defaultClassroom,
        'shift': shift,
        'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
        'exams': exams.map((exam) => exam.toJson()).toList(),
      };

  factory PolytechnicSectionOption.fromJson(Map<String, dynamic> json) {
    return PolytechnicSectionOption(
      code: (json['code'] as String?) ?? '',
      teacher: (json['teacher'] as String?) ?? '',
      defaultClassroom: (json['defaultClassroom'] as String?) ?? '',
      shift: (json['shift'] as String?) ?? '',
      schedules: ((json['schedules'] as List?) ?? const [])
          .whereType<Map>()
          .map((schedule) => PolytechnicScheduleTemplate.fromJson(
              Map<String, dynamic>.from(schedule)))
          .toList(),
      exams: ((json['exams'] as List?) ?? const [])
          .whereType<Map>()
          .map((exam) =>
              PolytechnicExamTemplate.fromJson(Map<String, dynamic>.from(exam)))
          .toList(),
    );
  }
}

class PolytechnicScheduleTemplate {
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String classroom;

  const PolytechnicScheduleTemplate({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.classroom,
  });

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'classroom': classroom,
      };

  factory PolytechnicScheduleTemplate.fromJson(Map<String, dynamic> json) {
    return PolytechnicScheduleTemplate(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      startTime: (json['startTime'] as String?) ?? '08:00',
      endTime: (json['endTime'] as String?) ?? '09:00',
      classroom: (json['classroom'] as String?) ?? '',
    );
  }
}

class PolytechnicExamTemplate {
  final String examType;
  final String label;
  final DateTime date;
  final String startTime;
  final String classroom;

  const PolytechnicExamTemplate({
    required this.examType,
    required this.label,
    required this.date,
    required this.startTime,
    required this.classroom,
  });

  Map<String, dynamic> toJson() => {
        'examType': examType,
        'label': label,
        'date': date.toIso8601String(),
        'startTime': startTime,
        'classroom': classroom,
      };

  factory PolytechnicExamTemplate.fromJson(Map<String, dynamic> json) {
    return PolytechnicExamTemplate(
      examType: (json['examType'] as String?) ?? 'partial',
      label: (json['label'] as String?) ?? '',
      date:
          DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.now(),
      startTime: (json['startTime'] as String?) ?? '08:00',
      classroom: (json['classroom'] as String?) ?? '',
    );
  }
}

class PolytechnicImportService {
  static const _mainSheetName = '2026_1';
  static const _codesSheetName = 'Códigos';

  Future<PolytechnicWorkbook> parseWorkbookBytes(
    Uint8List bytes, {
    String sourceName = 'Horario Politécnica',
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final files = {
      for (final file in archive.files.where((item) => item.isFile))
        file.name: file,
    };

    final sharedStrings = _readSharedStrings(files['xl/sharedStrings.xml']);
    final sheetTargets = _readSheetTargets(files);

    final mainSheetPath = sheetTargets[_mainSheetName];
    if (mainSheetPath == null) {
      throw StateError('No se encontro la hoja $_mainSheetName en el Excel.');
    }

    final codesSheetPath = sheetTargets[_codesSheetName];
    final careerNames = codesSheetPath == null
        ? <String, String>{}
        : _readCareerCodes(files[codesSheetPath], sharedStrings);
    final grouped = <String, _CareerBucket>{};

    for (final row in _readSheetRows(files[mainSheetPath], sharedStrings)) {
      final rowNumber = row.rowNumber;
      if (rowNumber <= 10) {
        continue;
      }

      final subjectName = _valueAt(row.values, 1);
      final normalizedCareer = _normalizeCareer(
        rawCode: _valueAt(row.values, 14),
        rawName: _valueAt(row.values, 15),
        careerNames: careerNames,
      );
      final careerCode = normalizedCareer.code;
      final careerName = normalizedCareer.name;
      final semester = _resolveSemester(
        semGroup: _valueAt(row.values, 13),
        level: _valueAt(row.values, 12),
      );
      final sectionCode = _valueAt(row.values, 22);

      if (subjectName.isEmpty ||
          careerCode.isEmpty ||
          careerName.isEmpty ||
          semester == null ||
          sectionCode.isEmpty) {
        continue;
      }

      final teacher = _buildTeacher(row.values);
      final defaultClassroom = _valueAt(row.values, 30);
      final shift = _valueAt(row.values, 21);
      final schedules = _extractSchedules(row.values, defaultClassroom);
      final exams = _extractExams(row.values);

      final careerBucket = grouped.putIfAbsent(
        careerCode,
        () => _CareerBucket(
          code: careerCode,
          name: careerNames[careerCode] ?? careerName,
        ),
      );
      final semesterBucket = careerBucket.semesters.putIfAbsent(
        semester,
        () => _SemesterBucket(number: semester),
      );
      final subjectBucket = semesterBucket.subjects.putIfAbsent(
        subjectName,
        () => _SubjectBucket(
          careerCode: careerCode,
          careerName: careerBucket.name,
          semester: semester,
          name: subjectName,
        ),
      );

      subjectBucket.sections.add(
        PolytechnicSectionOption(
          code: sectionCode,
          teacher: teacher,
          defaultClassroom:
              schedules.firstOrNull?.classroom ?? defaultClassroom,
          shift: shift,
          schedules: schedules,
          exams: exams,
        ),
      );
    }

    final careers = grouped.values.map((career) {
      final semesters = career.semesters.values.map((semester) {
        final subjects = semester.subjects.values.map((subject) {
          subject.sections.sort((a, b) => a.code.compareTo(b.code));
          return PolytechnicSubjectOption(
            careerCode: subject.careerCode,
            careerName: subject.careerName,
            semester: subject.semester,
            name: subject.name,
            sections: subject.sections,
          );
        }).toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return PolytechnicSemester(number: semester.number, subjects: subjects);
      }).toList()
        ..sort((a, b) => a.number.compareTo(b.number));
      return PolytechnicCareer(
        code: career.code,
        name: career.name,
        semesters: semesters,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (careers.isEmpty) {
      throw StateError(
          'No se encontraron materias validas para importar en el Excel.');
    }

    return PolytechnicWorkbook(sourceName: sourceName, careers: careers);
  }

  Map<String, String> _readSheetTargets(Map<String, ArchiveFile> files) {
    final workbook = _parseXml(files['xl/workbook.xml']);
    final rels = _parseXml(files['xl/_rels/workbook.xml.rels']);
    if (workbook == null || rels == null) {
      return {};
    }

    final relationMap = <String, String>{};
    for (final relation in rels.findAllElements('Relationship')) {
      final id = relation.getAttribute('Id') ?? '';
      final target = relation.getAttribute('Target') ?? '';
      if (id.isNotEmpty && target.isNotEmpty) {
        relationMap[id] = target.startsWith('xl/') ? target : 'xl/$target';
      }
    }

    final sheetMap = <String, String>{};
    for (final sheet in workbook.findAllElements('sheet')) {
      final name = sheet.getAttribute('name') ?? '';
      final relationId = sheet.getAttribute(
            'id',
            namespace:
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
          ) ??
          '';
      final target = relationMap[relationId];
      if (name.isNotEmpty && target != null) {
        sheetMap[name] = target;
      }
    }
    return sheetMap;
  }

  List<String> _readSharedStrings(ArchiveFile? file) {
    final xml = _parseXml(file);
    if (xml == null) {
      return const [];
    }
    return xml.findAllElements('si').map((item) {
      final texts =
          item.findAllElements('t').map((node) => node.innerText).join();
      return texts.trim();
    }).toList();
  }

  Map<String, String> _readCareerCodes(
      ArchiveFile? file, List<String> sharedStrings) {
    final codes = <String, String>{};
    for (final row in _readSheetRows(file, sharedStrings)) {
      final code = _valueAt(row.values, 0);
      final name = _valueAt(row.values, 1);
      if (code.isNotEmpty && name.isNotEmpty) {
        codes[code] = name;
      }
    }
    return codes;
  }

  Iterable<_ParsedRow> _readSheetRows(
      ArchiveFile? file, List<String> sharedStrings) sync* {
    final xml = _parseXml(file);
    if (xml == null) {
      return;
    }

    for (final row in xml.findAllElements('row')) {
      final rowNumber = int.tryParse(row.getAttribute('r') ?? '') ?? 0;
      final values = <int, String>{};
      for (final cell in row.findElements('c')) {
        final reference = cell.getAttribute('r') ?? '';
        final columnIndex = _columnIndexFromReference(reference);
        if (columnIndex < 0) {
          continue;
        }
        final value = _readCellValue(cell, sharedStrings).trim();
        if (value.isNotEmpty) {
          values[columnIndex] = value;
        }
      }
      yield _ParsedRow(rowNumber: rowNumber, values: values);
    }
  }

  String _readCellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t') ?? '';
    final rawValue = cell.getElement('v')?.innerText ?? '';
    if (type == 's') {
      final index = int.tryParse(rawValue);
      if (index == null || index < 0 || index >= sharedStrings.length) {
        return '';
      }
      return sharedStrings[index];
    }
    if (type == 'inlineStr') {
      return cell.findAllElements('t').map((item) => item.innerText).join();
    }
    if (type == 'b') {
      return rawValue == '1' ? 'Si' : 'No';
    }
    return rawValue;
  }

  XmlDocument? _parseXml(ArchiveFile? file) {
    if (file == null) {
      return null;
    }
    final content = utf8.decode(file.content as List<int>);
    return XmlDocument.parse(content);
  }

  int _columnIndexFromReference(String reference) {
    final match = RegExp(r'^([A-Z]+)').firstMatch(reference.toUpperCase());
    if (match == null) {
      return -1;
    }
    final letters = match.group(1)!;
    int value = 0;
    for (final unit in letters.codeUnits) {
      value = value * 26 + (unit - 64);
    }
    return value - 1;
  }

  String _valueAt(Map<int, String> row, int index) => row[index]?.trim() ?? '';

  _NormalizedCareer _normalizeCareer({
    required String rawCode,
    required String rawName,
    required Map<String, String> careerNames,
  }) {
    final code = rawCode.trim();
    final name = rawName.trim();

    if (_isNumericCode(code) && !_isNumericCode(name) && name.length <= 8) {
      return _NormalizedCareer(
        code: name,
        name: careerNames[name] ?? name,
      );
    }

    if (!_isNumericCode(code) && careerNames.containsKey(code)) {
      return _NormalizedCareer(
        code: code,
        name: careerNames[code]!,
      );
    }

    return _NormalizedCareer(
      code: code,
      name: name.isNotEmpty ? name : (careerNames[code] ?? code),
    );
  }

  bool _isNumericCode(String value) => RegExp(r'^\d+$').hasMatch(value.trim());

  List<PolytechnicScheduleTemplate> _extractSchedules(
    Map<int, String> row,
    String fallbackClassroom,
  ) {
    const scheduleColumns = [
      (day: 0, roomCol: 72, timeCol: 73),
      (day: 1, roomCol: 74, timeCol: 75),
      (day: 2, roomCol: 76, timeCol: 77),
      (day: 3, roomCol: 78, timeCol: 79),
      (day: 4, roomCol: 80, timeCol: 81),
      (day: 5, roomCol: 82, timeCol: 83),
    ];

    final schedules = <PolytechnicScheduleTemplate>[];
    for (final item in scheduleColumns) {
      final room = _valueAt(row, item.roomCol);
      final rawTime = _valueAt(row, item.timeCol);
      final range = _parseTimeRange(rawTime);
      if (range == null) {
        continue;
      }
      schedules.add(
        PolytechnicScheduleTemplate(
          dayOfWeek: item.day,
          startTime: range.$1,
          endTime: range.$2,
          classroom: room.isNotEmpty ? room : fallbackClassroom,
        ),
      );
    }
    return schedules;
  }

  List<PolytechnicExamTemplate> _extractExams(Map<int, String> row) {
    final exams = <PolytechnicExamTemplate>[];
    const examColumns = [
      (
        type: 'partial',
        label: 'Primer parcial',
        dateCol: 53,
        timeCol: 54,
        roomCol: 55
      ),
      (
        type: 'partial',
        label: 'Segundo parcial',
        dateCol: 56,
        timeCol: 57,
        roomCol: 58
      ),
      (type: 'final', label: 'Final 1', dateCol: 59, timeCol: 60, roomCol: 61),
      (type: 'final', label: 'Final 2', dateCol: 64, timeCol: 65, roomCol: 66),
    ];

    for (final item in examColumns) {
      final date = _parseDate(_valueAt(row, item.dateCol));
      final time = _normalizeSingleTime(_valueAt(row, item.timeCol));
      if (date == null || time == null) {
        continue;
      }
      exams.add(
        PolytechnicExamTemplate(
          examType: item.type,
          label: item.label,
          date: date,
          startTime: time,
          classroom: _valueAt(row, item.roomCol),
        ),
      );
    }
    exams.sort((a, b) {
      final dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) return dateComparison;
      return a.startTime.compareTo(b.startTime);
    });
    return exams;
  }

  String _buildTeacher(Map<int, String> row) {
    final parts = [
      _valueAt(row, 46),
      _valueAt(row, 48),
      _valueAt(row, 49),
    ].where((item) => item.isNotEmpty).toList();
    return parts.join(' ');
  }

  int? _parseSemester(String raw) {
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(0)!);
  }

  int? _resolveSemester({
    required String semGroup,
    required String level,
  }) {
    final parsedSemGroup = _parseSemester(semGroup);
    if (parsedSemGroup != null) {
      return parsedSemGroup;
    }
    return _parseSemester(level);
  }

  DateTime? _parseDate(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    final serial = double.tryParse(raw.replaceAll(',', '.'));
    if (serial != null) {
      final wholeDays = serial.floor();
      if (wholeDays > 0) {
        return DateTime(1899, 12, 30).add(Duration(days: wholeDays));
      }
    }
    final match = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(raw);
    if (match == null) {
      return null;
    }
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final yearRaw = int.tryParse(match.group(3)!);
    if (day == null || month == null || yearRaw == null) {
      return null;
    }
    final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
    return DateTime(year, month, day);
  }

  (String, String)? _parseTimeRange(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    final parts = raw.split('-');
    if (parts.length != 2) {
      return null;
    }
    final start = _normalizeSingleTime(parts[0]);
    final end = _normalizeSingleTime(parts[1]);
    if (start == null || end == null) {
      return null;
    }
    return (start, end);
  }

  String? _normalizeSingleTime(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    final serial = double.tryParse(raw.replaceAll(',', '.'));
    if (serial != null) {
      final timePortion =
          serial >= 1 ? serial - serial.floorToDouble() : serial;
      final totalMinutes = (timePortion * 24 * 60).round();
      final hour = (totalMinutes ~/ 60) % 24;
      final minute = totalMinutes % 60;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

Future<PolytechnicWorkbook> parsePolytechnicWorkbookInBackground(
  Map<String, dynamic> payload,
) async {
  final bytes = payload['bytes'] as Uint8List;
  final sourceName = payload['sourceName'] as String? ?? 'Horario Politécnica';
  return PolytechnicImportService().parseWorkbookBytes(
    bytes,
    sourceName: sourceName,
  );
}

Future<PolytechnicWorkbook> parsePolytechnicJsonInBackground(
  Map<String, dynamic> payload,
) async {
  final jsonString = payload['json'] as String? ?? '{}';
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  return PolytechnicWorkbook.fromJson(data);
}

class _ParsedRow {
  final int rowNumber;
  final Map<int, String> values;

  const _ParsedRow({
    required this.rowNumber,
    required this.values,
  });
}

class _NormalizedCareer {
  final String code;
  final String name;

  const _NormalizedCareer({
    required this.code,
    required this.name,
  });
}

class _CareerBucket {
  final String code;
  final String name;
  final Map<int, _SemesterBucket> semesters = {};

  _CareerBucket({
    required this.code,
    required this.name,
  });
}

class _SemesterBucket {
  final int number;
  final Map<String, _SubjectBucket> subjects = {};

  _SemesterBucket({
    required this.number,
  });
}

class _SubjectBucket {
  final String careerCode;
  final String careerName;
  final int semester;
  final String name;
  final List<PolytechnicSectionOption> sections = [];

  _SubjectBucket({
    required this.careerCode,
    required this.careerName,
    required this.semester,
    required this.name,
  });
}
