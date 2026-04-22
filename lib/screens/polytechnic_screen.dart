import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../models/schedule.dart';
import '../models/subject.dart';
import '../providers/app_provider.dart';
import '../services/polytechnic_cache_service.dart';
import '../services/polytechnic_import_service.dart';
import '../utils/app_utils.dart';
import '../widgets/focus_drawer.dart';

enum _SubjectSelectionState { none, taking, completed }

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
      drawer: const FocusDrawer(selectedRoute: 'subjects'),
      appBar: AppBar(
        title: const Text('Politécnica'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroCard(
                loadedFileName: _loadedFileName,
                loading: _loadingWorkbook,
                onLoadPressed: _pickWorkbook,
                onReloadPressed: _pickWorkbook,
              ),
              if (workbook != null) ...[
                const SizedBox(height: 12),
                _WorkbookSummaryCard(workbook: workbook),
              ],
              const SizedBox(height: 16),
              if (workbook == null)
                const _EmptyStateCard(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Carga el archivo oficial',
                  message:
                      'El estudiante solo necesita su Excel. La app convierte y optimiza el archivo por dentro para que después funcione más rápido.',
                )
              else ...[
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

    return _StepCard(
      step: 'Paso 2',
      title: 'Marca que materias vas a cursar',
      subtitle:
          'Puedes marcar una materia como `Cursar` o `Hecha`. Las materias marcadas como `Hecha` no pasan al paso de secciones.',
      child: Column(
        children: _selectedCareers
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
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Cursar'),
                              selected: state == _SubjectSelectionState.taking,
                              onSelected: (_) => setState(() {
                                _subjectStates[subject.key] =
                                    _SubjectSelectionState.taking;
                                _selectedSectionCodes.putIfAbsent(
                                  subject.key,
                                  () => subject.sections.first.code,
                                );
                              }),
                            ),
                            ChoiceChip(
                              label: const Text('Hecha'),
                              selected:
                                  state == _SubjectSelectionState.completed,
                              onSelected: (_) => setState(() {
                                _subjectStates[subject.key] =
                                    _SubjectSelectionState.completed;
                                _selectedSectionCodes.remove(subject.key);
                              }),
                            ),
                            ChoiceChip(
                              label: const Text('Sin marcar'),
                              selected: state == _SubjectSelectionState.none,
                              onSelected: (_) => setState(() {
                                _subjectStates.remove(subject.key);
                                _selectedSectionCodes.remove(subject.key);
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionsStep() {
    final takingSubjects = _takingSubjects;
    if (takingSubjects.isEmpty) {
      return const _StepCard(
        step: 'Paso 3',
        title: 'Profesor y sección',
        subtitle:
            'Solo las materias marcadas como `Cursar` llegan a este paso.',
        child: _MutedHint(
          text:
              'No hay materias para elegir sección. Marca al menos una materia como `Cursar` en el paso anterior.',
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
              label: const Text('Atras'),
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
                ? (_importing ? 'Importando...' : 'Finalizar')
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
        return _takingSubjects.isNotEmpty || _completedSubjects.isNotEmpty;
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

  List<PolytechnicSubjectOption> get _completedSubjects {
    return _selectedCareers
        .expand((career) => career.semesters)
        .expand((semester) => semester.subjects)
        .where((subject) =>
            _subjectStates[subject.key] == _SubjectSelectionState.completed)
        .toList();
  }

  String _semesterSummary(List<PolytechnicSubjectOption> subjects) {
    final taking = subjects
        .where((subject) =>
            _subjectStates[subject.key] == _SubjectSelectionState.taking)
        .length;
    final completed = subjects
        .where((subject) =>
            _subjectStates[subject.key] == _SubjectSelectionState.completed)
        .length;
    return '$taking para cursar · $completed hechas';
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
        setState(() => _loadingMessage = 'Buscando version rapida...');
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
        _selectedCareerCodes
          ..clear()
          ..addAll(workbook.careers.take(1).map((career) => career.code));
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
          'Se importarán solo las materias marcadas como `Cursar`. Las materias marcadas como `Hecha` no pedirán profesor ni sección y no se cargarán a la app.',
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
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Listo'),
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
  final VoidCallback onReloadPressed;

  const _HeroCard({
    required this.loadedFileName,
    required this.loading,
    required this.onLoadPressed,
    required this.onReloadPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
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
              'Importación automática para Politécnica',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'El estudiante solo sube el Excel. La app lo interpreta, acelera internamente y te guía paso a paso hasta la importación final.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: loading ? null : onLoadPressed,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(loadedFileName == null
                      ? 'Cargar Excel'
                      : 'Cambiar Excel'),
                ),
                if (loadedFileName != null)
                  OutlinedButton.icon(
                    onPressed: loading ? null : onReloadPressed,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar archivo'),
                  ),
              ],
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

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
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
