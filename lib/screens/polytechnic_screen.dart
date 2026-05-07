import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../models/schedule.dart';
import '../models/subject.dart';
import '../providers/app_provider.dart';
import '../services/notification_service.dart';
import '../services/polytechnic_cache_service.dart';
import '../services/polytechnic_import_service.dart';
import '../utils/app_utils.dart';
import '../widgets/focus_drawer.dart';
import 'grade_calculator_screen.dart';
import 'subjects_screen.dart';

enum _SubjectSelectionState { none, taking }

class PolytechnicScreen extends StatefulWidget {
  const PolytechnicScreen({super.key});

  @override
  State<PolytechnicScreen> createState() => _PolytechnicScreenState();
}

class _PolytechnicScreenState extends State<PolytechnicScreen> {
  final _cacheService = PolytechnicCacheService();
  PolytechnicWorkbook? _workbook;
  bool _loadingWorkbook = false;
  bool _importing = false;
  bool _showImportFlow = false;
  String? _loadedFileName;
  String _loadingMessage = 'Procesando archivo...';
  int _currentStep = 0;
  final Set<String> _selectedCareerCodes = {};
  final Map<String, _SubjectSelectionState> _subjectStates = {};
  final Map<String, String> _selectedSectionCodes = {};

  @override
  Widget build(BuildContext context) {
    final workbook = _workbook;
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'polytechnic'),
      appBar: AppBar(
        title: const Text('Politécnica'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_showImportFlow &&
                  workbook == null &&
                  !_loadingWorkbook) ...[
                const _CalculatorShortcutCard(),
                const SizedBox(height: 12),
                _ImportShortcutCard(
                  onTap: () => setState(() => _showImportFlow = true),
                ),
              ] else ...[
                _HeroCard(
                  loadedFileName: _loadedFileName,
                  loading: _loadingWorkbook,
                  onLoadPressed: _pickWorkbook,
                ),
                if (workbook != null) ...[
                  const SizedBox(height: 12),
                  _WorkbookSummaryCard(workbook: workbook),
                ],
              ],
              if (workbook != null) ...[
                const SizedBox(height: 16),
                _WizardProgress(currentStep: _currentStep),
                const SizedBox(height: 16),
                if (_currentStep == 0) _buildCareerStep(workbook),
                if (_currentStep == 1) _buildSubjectsStep(),
                if (_currentStep == 2) _buildSectionsStep(),
                const SizedBox(height: 16),
                _buildStepActions(),
              ],
            ],
          ),
          if (_loadingWorkbook)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 14),
                          Text(_loadingMessage),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCareerStep(PolytechnicWorkbook workbook) {
    return _StepCard(
      step: 'Paso 1',
      title: 'Selecciona tu carrera',
      subtitle:
          'Elige una o varias carreras para filtrar el plan y avanzar al siguiente paso.',
      child: Column(
        children: workbook.careers.map((career) {
          final selected = _selectedCareerCodes.contains(career.code);
          final totalSubjects = career.semesters
              .fold<int>(0, (sum, semester) => sum + semester.subjects.length);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: CheckboxListTile(
              value: selected,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(career.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${career.code} · ${career.semesters.length} semestres · $totalSubjects materias',
              ),
              onChanged: (_) => setState(() {
                if (selected) {
                  _selectedCareerCodes.remove(career.code);
                  for (final subject in career.semesters
                      .expand((semester) => semester.subjects)) {
                    _subjectStates.remove(subject.key);
                    _selectedSectionCodes.remove(subject.key);
                  }
                } else {
                  _selectedCareerCodes.add(career.code);
                }
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubjectsStep() {
    if (_selectedCareerCodes.isEmpty) {
      return const _StepCard(
        step: 'Paso 2',
        title: 'Selecciona materias por semestre',
        subtitle: 'Primero debes elegir al menos una carrera.',
        child: _MutedHint(text: 'Todavía no hay carreras seleccionadas.'),
      );
    }

    final availableSubjects = _selectedCareers
        .expand((career) => career.semesters)
        .expand((semester) => semester.subjects)
        .length;
    final selectedSubjects = _takingSubjects.length;

    return _StepCard(
      step: 'Paso 2',
      title: 'Elige las materias que vas a cursar',
      subtitle:
          'Toca una materia para seleccionarla. Solo las seleccionadas pasarán al paso de profesor y sección.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectionHint(
            selected: selectedSubjects,
            total: availableSubjects,
          ),
          const SizedBox(height: 12),
          ..._selectedCareers
              .expand((career) => career.semesters)
              .map((semester) {
            final subjects = _selectedCareers
                .expand((item) => item.semesters)
                .where((item) => item.number == semester.number)
                .expand((item) => item.subjects)
                .toList();
            if (subjects.isEmpty) {
              return const SizedBox.shrink();
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  title: Text(
                    'Semestre ${semester.number}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(_semesterSummary(subjects)),
                  children: subjects.map((subject) {
                    final state = _subjectStates[subject.key] ??
                        _SubjectSelectionState.none;
                    final selected = state == _SubjectSelectionState.taking;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _toggleSubject(subject),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.55)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.25),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                ),
                                child: Icon(
                                  selected
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  color: selected
                                      ? Colors.white
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      selected
                                          ? 'Se importará con horario, profesor, sección y exámenes.'
                                          : 'Toca para agregarla a tu horario.',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionsStep() {
    final takingSubjects = _takingSubjects;
    if (takingSubjects.isEmpty) {
      return const _StepCard(
        step: 'Paso 3',
        title: 'Profesor y sección',
        subtitle: 'Solo las materias seleccionadas llegan a este paso.',
        child: _MutedHint(
          text:
              'No hay materias para elegir sección. Selecciona al menos una materia en el paso anterior.',
        ),
      );
    }

    return _StepCard(
      step: 'Paso 3',
      title: 'Elige profesor y sección',
      subtitle:
          'Aquí solo aparecen las materias que vas a cursar. Estos datos se guardan como opcionales, así que no afectan a usuarios fuera de Politécnica.',
      child: Column(
        children: takingSubjects.map((subject) {
          final selectedCode =
              _selectedSectionCodes[subject.key] ?? subject.sections.first.code;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${subject.careerCode} · Semestre ${subject.semester}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ...subject.sections.map((section) {
                    final isSelected = section.code == selectedCode;
                    final scheduleText = section.schedules.isEmpty
                        ? 'Sin horario visible en el archivo'
                        : section.schedules
                            .map(
                              (schedule) =>
                                  '${weekdayLabel(schedule.dayOfWeek)} ${schedule.startTime}-${schedule.endTime}',
                            )
                            .join(' · ');
                    return RadioListTile<String>(
                      value: section.code,
                      groupValue: selectedCode,
                      contentPadding: EdgeInsets.zero,
                      title: Text(section.label,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (section.teacher.isNotEmpty) Text(section.teacher),
                          Text(scheduleText),
                          if (section.defaultClassroom.isNotEmpty)
                            Text('Aula base: ${section.defaultClassroom}'),
                          if (section.exams.isNotEmpty)
                            Text('${section.exams.length} exámenes detectados'),
                        ],
                      ),
                      selected: isSelected,
                      onChanged: (value) => setState(() {
                        if (value != null) {
                          _selectedSectionCodes[subject.key] = value;
                        }
                      }),
                    );
                  }),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepActions() {
    final isLastStep = _currentStep == 2;
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Atrás'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _stepActionEnabled
                ? (isLastStep ? _importSelection : _goNext)
                : null,
            icon: Icon(isLastStep
                ? Icons.download_done_rounded
                : Icons.arrow_forward_rounded),
            label: Text(isLastStep
                ? (_importing ? 'Importando...' : 'Importar materias')
                : _currentStep == 1
                    ? 'Elegir secciones'
                    : 'Siguiente'),
          ),
        ),
      ],
    );
  }

  bool get _stepActionEnabled {
    switch (_currentStep) {
      case 0:
        return _selectedCareerCodes.isNotEmpty;
      case 1:
        return _takingSubjects.isNotEmpty;
      case 2:
        return !_importing &&
            _takingSubjects.every(
                (subject) => _selectedSectionCodes.containsKey(subject.key));
    }
    return false;
  }

  void _goNext() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _toggleSubject(PolytechnicSubjectOption subject) {
    final selected =
        _subjectStates[subject.key] == _SubjectSelectionState.taking;
    setState(() {
      if (selected) {
        _subjectStates.remove(subject.key);
        _selectedSectionCodes.remove(subject.key);
      } else {
        _subjectStates[subject.key] = _SubjectSelectionState.taking;
        _selectedSectionCodes.putIfAbsent(
          subject.key,
          () => subject.sections.first.code,
        );
      }
    });
  }

  List<PolytechnicCareer> get _selectedCareers {
    final workbook = _workbook;
    if (workbook == null) {
      return const [];
    }
    return workbook.careers
        .where((career) => _selectedCareerCodes.contains(career.code))
        .toList();
  }

  List<PolytechnicSubjectOption> get _takingSubjects {
    return _selectedCareers
        .expand((career) => career.semesters)
        .expand((semester) => semester.subjects)
        .where((subject) =>
            _subjectStates[subject.key] == _SubjectSelectionState.taking)
        .toList();
  }

  String _semesterSummary(List<PolytechnicSubjectOption> subjects) {
    final taking = subjects
        .where((subject) =>
            _subjectStates[subject.key] == _SubjectSelectionState.taking)
        .length;
    return taking == 0
        ? '${subjects.length} materias disponibles'
        : '$taking seleccionadas de ${subjects.length}';
  }

  Future<void> _pickWorkbook() async {
    setState(() {
      _loadingWorkbook = true;
      _loadingMessage = 'Abriendo archivo...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final pickedFile = result.files.single;
      final bytes = pickedFile.bytes;
      if (bytes == null) {
        throw StateError('No se pudo leer el archivo seleccionado.');
      }

      final extension = (pickedFile.extension ?? '').toLowerCase();
      PolytechnicWorkbook workbook;
      if (extension == 'json') {
        setState(() => _loadingMessage = 'Leyendo JSON optimizado...');
        workbook = await compute<Map<String, dynamic>, PolytechnicWorkbook>(
          parsePolytechnicJsonInBackground,
          {'json': utf8.decode(bytes)},
        );
      } else {
        setState(() => _loadingMessage = 'Calculando cache...');
        final hash = await _cacheService.hashBytes(bytes);
        setState(() => _loadingMessage = 'Buscando versión rápida...');
        final cached = await _cacheService.load(hash);
        if (cached != null) {
          workbook = cached;
        } else {
          setState(
              () => _loadingMessage = 'Convirtiendo Excel por primera vez...');
          workbook = await compute<Map<String, dynamic>, PolytechnicWorkbook>(
            parsePolytechnicWorkbookInBackground,
            {
              'bytes': bytes,
              'sourceName': pickedFile.name,
            },
          );
          setState(() => _loadingMessage = 'Guardando cache local...');
          await _cacheService.save(hash, workbook);
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _workbook = workbook;
        _loadedFileName = pickedFile.name;
        _currentStep = 0;
        _selectedCareerCodes.clear();
        _subjectStates.clear();
        _selectedSectionCodes.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingWorkbook = false);
      }
    }
  }

  Future<void> _importSelection() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final takingSubjects = _takingSubjects;
    if (takingSubjects.isEmpty) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar horario Politécnica'),
        content: const Text(
          'Se importarán las materias seleccionadas con sus horarios, profesores, secciones y exámenes detectados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() => _importing = true);
    try {
      await provider.clearAcademicData();

      final createdSubjects = <String, Subject>{};
      var importedSchedules = 0;
      var importedExams = 0;
      var importedPartials = 0;
      var importedFinals = 0;
      for (final subjectOption in takingSubjects) {
        final sectionCode = _selectedSectionCodes[subjectOption.key] ??
            subjectOption.sections.first.code;
        final section = subjectOption.sections.firstWhere(
          (item) => item.code == sectionCode,
          orElse: () => subjectOption.sections.first,
        );

        Subject? subject = provider.getSubjectByName(subjectOption.name) ??
            createdSubjects[subjectOption.name];
        if (subject == null) {
          final draftSubject = Subject(
            name: subjectOption.name,
            color: _colorForSubject(subjectOption.name),
            icon: _iconForSubject(subjectOption.name),
            defaultClassroom: section.defaultClassroom.isEmpty
                ? null
                : section.defaultClassroom,
            professorName: section.teacher.isEmpty ? null : section.teacher,
            sectionCode: section.code.isEmpty ? null : section.code,
          );

          if (section.schedules.isNotEmpty) {
            final firstSchedule = section.schedules.first;
            subject = await provider.addSubjectWithInitialSchedule(
              draftSubject,
              Schedule(
                subjectId: -1,
                dayOfWeek: firstSchedule.dayOfWeek,
                startTime: firstSchedule.startTime,
                endTime: firstSchedule.endTime,
                classroom: firstSchedule.classroom,
              ),
            );

            for (final extraSchedule in section.schedules.skip(1)) {
              await provider.addSchedule(
                Schedule(
                  subjectId: subject.id!,
                  dayOfWeek: extraSchedule.dayOfWeek,
                  startTime: extraSchedule.startTime,
                  endTime: extraSchedule.endTime,
                  classroom: extraSchedule.classroom,
                ),
              );
            }
            importedSchedules += section.schedules.length;
          } else {
            await provider.addSubject(draftSubject);
            subject = provider.getSubjectByName(subjectOption.name);
          }
        }

        if (subject == null || subject.id == null) {
          continue;
        }
        createdSubjects[subjectOption.name] = subject;

        for (final examTemplate in section.exams) {
          final alreadyExists = provider.exams.any(
            (exam) =>
                exam.subjectId == subject!.id &&
                exam.examType == examTemplate.examType &&
                DateUtils.isSameDay(exam.date, examTemplate.date) &&
                exam.startTime == examTemplate.startTime &&
                exam.classroom == examTemplate.classroom,
          );
          if (!alreadyExists) {
            await provider.addExam(
              Exam(
                subject: subject.name,
                subjectId: subject.id,
                examType: examTemplate.examType,
                examLabel: examTemplate.label,
                date: examTemplate.date,
                startTime: examTemplate.startTime,
                classroom: examTemplate.classroom,
              ),
            );
            importedExams++;
            if (examTemplate.examType == 'final') {
              importedFinals++;
            } else {
              importedPartials++;
            }
          }
        }
      }

      await provider.syncExamNotifications();
      final pendingNotifications =
          await NotificationService.pendingNotificationsCount();

      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Importación completada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Carreras elegidas: ${_selectedCareerCodes.length}'),
              Text('Materias importadas: ${createdSubjects.length}'),
              Text('Bloques horarios: $importedSchedules'),
              Text('Exámenes importados: $importedExams'),
              Text('Parciales: $importedPartials'),
              Text('Finales: $importedFinals'),
              Text('Avisos pendientes: $pendingNotifications'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _goToSubjectsScreen();
              },
              child: const Text('Ver materias'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  String _colorForSubject(String subjectName) {
    const palette = [
      '#2563EB',
      '#0F766E',
      '#7C3AED',
      '#EA580C',
      '#DB2777',
      '#16A34A',
      '#D97706',
      '#0891B2',
    ];
    final index = subjectName.hashCode.abs() % palette.length;
    return palette[index];
  }

  String _iconForSubject(String subjectName) {
    final lower = subjectName.toLowerCase();
    if (lower.contains('cálculo') ||
        lower.contains('calculo') ||
        lower.contains('algebra') ||
        lower.contains('mat')) {
      return 'calculate';
    }
    if (lower.contains('física') || lower.contains('fisica')) {
      return 'science';
    }
    if (lower.contains('algorit') ||
        lower.contains('program') ||
        lower.contains('datos')) {
      return 'code';
    }
    if (lower.contains('red')) {
      return 'router';
    }
    if (lower.contains('econom')) {
      return 'payments';
    }
    return 'book';
  }

  void _goToSubjectsScreen() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SubjectsScreen()),
      (route) => false,
    );
  }
}

class _CalculatorShortcutCard extends StatelessWidget {
  const _CalculatorShortcutCard();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GradeCalculatorScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: primary.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.calculate_rounded, color: primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculadora Politécnica',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calcula firma, ponderado y objetivos de nota para planificar mejor tus finales.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportShortcutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ImportShortcutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: primary.withValues(alpha: 0.14),
                ),
                child:
                    Icon(Icons.upload_file_rounded, color: primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importación automática',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Carga el Excel oficial y elige carrera, materias, horarios, profesores, secciones y exámenes.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbookSummaryCard extends StatelessWidget {
  final PolytechnicWorkbook workbook;

  const _WorkbookSummaryCard({required this.workbook});

  @override
  Widget build(BuildContext context) {
    final careerCount = workbook.careers.length;
    final semesterCount = workbook.careers.fold<int>(
      0,
      (sum, career) => sum + career.semesters.length,
    );
    final subjectCount = workbook.careers.fold<int>(
      0,
      (sum, career) =>
          sum +
          career.semesters.fold<int>(
            0,
            (semesterSum, semester) => semesterSum + semester.subjects.length,
          ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _WorkbookChip(label: '$careerCount carreras'),
            _WorkbookChip(label: '$semesterCount semestres'),
            _WorkbookChip(label: '$subjectCount materias'),
          ],
        ),
      ),
    );
  }
}

class _WorkbookChip extends StatelessWidget {
  final String label;

  const _WorkbookChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SelectionHint extends StatelessWidget {
  final int selected;
  final int total;

  const _SelectionHint({
    required this.selected,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: primary.withValues(alpha: 0.10),
        border: Border.all(color: primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: primary,
            child: Text(
              '$selected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selected == 0
                  ? 'Selecciona al menos una materia para continuar.'
                  : '$selected de $total materias seleccionadas.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardProgress extends StatelessWidget {
  final int currentStep;

  const _WizardProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Carrera', 'Materias', 'Sección'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: List.generate(labels.length, (index) {
            final active = index <= currentStep;
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String? loadedFileName;
  final bool loading;
  final VoidCallback onLoadPressed;

  const _HeroCard({
    required this.loadedFileName,
    required this.loading,
    required this.onLoadPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF222222) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.school_rounded, color: primary, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              'Importación automática',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Subí el Excel oficial y Focus te guía para elegir carrera, materias, profesores, secciones, horarios y exámenes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ImportChip(text: '1. Carrera'),
                _ImportChip(text: '2. Materias'),
                _ImportChip(text: '3. Secciones'),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: loading ? null : onLoadPressed,
              icon: Icon(loadedFileName == null
                  ? Icons.upload_file_rounded
                  : Icons.change_circle_rounded),
              label: Text(
                  loadedFileName == null ? 'Cargar Excel' : 'Cambiar Excel'),
            ),
            if (loadedFileName != null) ...[
              const SizedBox(height: 14),
              Text(
                'Archivo cargado: $loadedFileName',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportChip extends StatelessWidget {
  final String text;

  const _ImportChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: primary.withValues(alpha: 0.10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MutedHint extends StatelessWidget {
  final String text;

  const _MutedHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text),
    );
  }
}

