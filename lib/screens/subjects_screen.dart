import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule.dart';
import '../models/subject.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_empty_state.dart';
import '../widgets/focus_help_button.dart';
import '../widgets/schedule_board.dart';
import '../widgets/time_picker_field.dart';
import 'subject_schedule_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _classroomController = TextEditingController();
  final _professorController = TextEditingController();
  final _sectionController = TextEditingController();
  Color _selectedColor = FocusPalette.primary;
  bool _addInitialSchedule = false;
  int _selectedDay = 0;
  String _startTime = '08:00';
  String _endTime = '09:00';

  @override
  void dispose() {
    _nameController.dispose();
    _classroomController.dispose();
    _professorController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Bad state: ', '');
  }

  Future<void> _showSubjectDialog({Subject? subject}) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _nameController.text = subject?.name ?? '';
    _classroomController.text = subject?.defaultClassroom ?? '';
    _professorController.text = subject?.professorName ?? '';
    _sectionController.text = subject?.sectionCode ?? '';
    _selectedColor =
        subject != null ? colorFromHex(subject.color) : FocusPalette.primary;
    _addInitialSchedule = false;
    _selectedDay = 0;
    _startTime = '08:00';
    _endTime = '09:00';
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(subject == null ? 'Nueva materia' : 'Editar materia'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    onChanged: (_) => setDialogState(() {}),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa un nombre.'
                        : null,
                  ),
                  if (subject == null && provider.subjects.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sugeridas',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _subjectSuggestions(provider)
                            .map(
                              (suggestion) => ActionChip(
                                label: Text(
                                  suggestion.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () => setDialogState(() {
                                  _nameController.text = suggestion.name;
                                  _classroomController.text =
                                      suggestion.defaultClassroom ??
                                          _classroomController.text;
                                  _professorController.text =
                                      suggestion.professorName ??
                                          _professorController.text;
                                  _sectionController.text =
                                      suggestion.sectionCode ??
                                          _sectionController.text;
                                  _selectedColor =
                                      colorFromHex(suggestion.color);
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _classroomController,
                    decoration: InputDecoration(
                      labelText: subject == null
                          ? 'Aula inicial (opcional)'
                          : 'Aula por defecto',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _professorController,
                    decoration:
                        const InputDecoration(labelText: 'Profesor (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sectionController,
                    decoration:
                        const InputDecoration(labelText: 'Sección (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  if (subject == null) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Agregar horario ahora'),
                      subtitle: const Text(
                          'Opcional. También puedes hacerlo después.'),
                      value: _addInitialSchedule,
                      onChanged: (value) =>
                          setDialogState(() => _addInitialSchedule = value),
                    ),
                  ],
                  if (subject == null && _addInitialSchedule) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDay,
                      decoration: const InputDecoration(
                        labelText: 'Día de clase',
                        helperText: 'Obligatorio al registrar una materia.',
                      ),
                      items: List.generate(
                        6,
                        (index) => DropdownMenuItem(
                          value: index,
                          child: Text(weekdayLabel(index)),
                        ),
                      ),
                      validator: (value) =>
                          value == null ? 'Selecciona un día.' : null,
                      onChanged: (value) =>
                          setDialogState(() => _selectedDay = value ?? 0),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TimePickerField(
                            label: 'Inicio',
                            value: _startTime,
                            onChanged: (value) =>
                                setDialogState(() => _startTime = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TimePickerField(
                            label: 'Fin',
                            value: _endTime,
                            onChanged: (value) =>
                                setDialogState(() => _endTime = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'El horario se puede cambiar después desde la materia.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      const Text('Color'),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final color = await showDialog<Color>(
                            context: dialogContext,
                            builder: (_) => _ColorPickerDialog(
                                initialColor: _selectedColor),
                          );
                          if (color != null) {
                            setDialogState(() => _selectedColor = color);
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          color: _selectedColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                if (subject == null && _addInitialSchedule) {
                  if (!isValidTime(_startTime) || !isValidTime(_endTime)) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Usa formato HH:MM.')),
                    );
                    return;
                  }
                  if (timeToMinutes(_endTime) <= timeToMinutes(_startTime)) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La hora de fin debe ser mayor que la de inicio.',
                        ),
                      ),
                    );
                    return;
                  }
                }

                final draftSubject = Subject(
                  id: subject?.id,
                  name: _nameController.text.trim(),
                  color: colorToHex(_selectedColor),
                  icon: subject?.icon ?? 'book',
                  defaultClassroom: _classroomController.text.trim().isEmpty
                      ? null
                      : _classroomController.text.trim(),
                  professorName: _professorController.text.trim().isEmpty
                      ? null
                      : _professorController.text.trim(),
                  sectionCode: _sectionController.text.trim().isEmpty
                      ? null
                      : _sectionController.text.trim(),
                );

                try {
                  if (subject == null) {
                    if (_addInitialSchedule) {
                      final schedule = Schedule(
                        subjectId: -1,
                        dayOfWeek: _selectedDay,
                        startTime: _startTime,
                        endTime: _endTime,
                        classroom: _classroomController.text.trim(),
                      );
                      await provider.addSubjectWithInitialSchedule(
                        draftSubject,
                        schedule,
                        validateConflict: false,
                      );
                    } else {
                      await provider.addSubject(draftSubject);
                    }
                  } else {
                    await provider.updateSubject(draftSubject);
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        subject == null
                            ? 'Materia guardada.'
                            : 'Materia actualizada.',
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(_friendlyError(error))),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  List<Subject> _subjectSuggestions(AppProvider provider) {
    final query = _nameController.text.trim().toLowerCase();
    final items = [...provider.subjects];
    if (query.isEmpty) {
      return items.take(6).toList();
    }
    final starts =
        items.where((subject) => subject.name.toLowerCase().startsWith(query));
    final contains = items.where(
      (subject) =>
          !subject.name.toLowerCase().startsWith(query) &&
          subject.name.toLowerCase().contains(query),
    );
    return [...starts, ...contains].take(6).toList();
  }

  Future<void> _deleteSubject(Subject subject) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final scheduleCount = provider.schedules
        .where((schedule) => schedule.subjectId == subject.id)
        .length;
    final examCount =
        provider.exams.where((exam) => exam.subjectId == subject.id).length;
    final taskCount = provider.studyTasks
        .where((task) => task.subjectId == subject.id && !task.isDone)
        .length;
    final resourceCount = subject.id == null
        ? 0
        : provider.resourcesForSubject(subject.id!).length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar materia'),
        content: Text(
          'Se eliminará ${subject.name} y $scheduleCount bloques de horario. $examCount exámenes, $taskCount tareas activas y $resourceCount recursos quedarán sin materia vinculada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted && subject.id != null) {
      await provider.deleteSubject(subject.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materia eliminada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Materias'),
        actions: const [
          FocusHelpAction(
            title: 'Ayuda de materias',
            message:
                'Aqui organizas tus clases y dejas lista la base para horarios, examenes y tareas.',
            sections: [
              FocusHelpSection(
                title: 'Que guardar',
                items: [
                  'Con el nombre ya puedes crear una materia.',
                  'Aula, profesor, seccion y color son opcionales y sirven para ordenar mejor.',
                  'Puedes agregar el horario al crearla o hacerlo despues.',
                ],
              ),
              FocusHelpSection(
                title: 'Consejos',
                items: [
                  'Mantener pocas materias bien cargadas hace que el dashboard y el calendario se vean mas claros.',
                  'Si eliminas una materia, sus horarios se borran y examenes, tareas y recursos quedan sin vinculo.',
                ],
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final subjects = provider.subjects;
            return ListView(
              padding: const EdgeInsets.only(bottom: 36),
              children: [
                const ScheduleBoard(
                  title: 'Horario semanal',
                  visibleDays: [0, 1, 2, 3, 4, 5],
                ),
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    title: Text(
                      'Tus materias y detalles',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${subjects.length} materias registradas'),
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Gestiona tus materias',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _showSubjectDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Nueva'),
                            ),
                          ],
                        ),
                      ),
                      if (subjects.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: FocusEmptyState(
                            icon: Icons.menu_book_rounded,
                            accent: const Color(0xFF0EA5E9),
                            title: 'Carga tu primera materia',
                            message:
                                'Empieza solo con el nombre. Después puedes sumar horarios, aula, profesor y sección.',
                            action: FilledButton.icon(
                              onPressed: () => _showSubjectDialog(),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Agregar materia'),
                            ),
                          ),
                        )
                      else
                        ...subjects.map((subject) {
                          final subjectSchedules = provider.schedules
                              .where((schedule) =>
                                  schedule.subjectId == subject.id)
                              .toList()
                            ..sort((a, b) {
                              final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
                              if (byDay != 0) return byDay;
                              return a.startTime.compareTo(b.startTime);
                            });
                          final subjectExams = provider.exams
                              .where((exam) => exam.subjectId == subject.id)
                              .toList();
                          final resourceCount = subject.id == null
                              ? 0
                              : provider
                                  .resourcesForSubject(subject.id!)
                                  .length;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor:
                                            colorFromHex(subject.color),
                                        child: const Icon(
                                          Icons.book,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              subject.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            if (subject.defaultClassroom !=
                                                    null &&
                                                subject.defaultClassroom!
                                                    .isNotEmpty)
                                              Text(
                                                'Aula base: ${subject.defaultClassroom}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            if (subject.sectionCode != null &&
                                                subject.sectionCode!
                                                    .trim()
                                                    .isNotEmpty)
                                              Text(
                                                'Sección: ${subject.sectionCode}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            if (subject.professorName != null &&
                                                subject.professorName!
                                                    .trim()
                                                    .isNotEmpty)
                                              Text(
                                                'Profesor: ${subject.professorName}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _SubjectInfoChip(
                                        icon: Icons.schedule_rounded,
                                        label:
                                            '${subjectSchedules.length} bloques',
                                      ),
                                      _SubjectInfoChip(
                                        icon: Icons.assignment_rounded,
                                        label:
                                            '${subjectExams.length} exámenes',
                                      ),
                                      _SubjectInfoChip(
                                        icon: Icons.task_alt_rounded,
                                        label:
                                            '${provider.studyTasks.where((task) => task.subjectId == subject.id && !task.isDone).length} tareas',
                                      ),
                                      _SubjectInfoChip(
                                        icon: Icons.link_rounded,
                                        label: '$resourceCount recursos',
                                      ),
                                    ],
                                  ),
                                  if (subjectSchedules.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.38),
                                      ),
                                      child: Text(
                                        'Próximo bloque: ${weekdayLabel(subjectSchedules.first.dayOfWeek)} · ${subjectSchedules.first.startTime} a ${subjectSchedules.first.endTime}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  SubjectScheduleScreen(
                                                subject: subject,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.schedule),
                                        label: const Text('Horarios'),
                                      ),
                                      const Spacer(),
                                      PopupMenuButton<String>(
                                        tooltip: 'Más acciones',
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showSubjectDialog(
                                                subject: subject);
                                          } else if (value == 'delete') {
                                            _deleteSubject(subject);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: ListTile(
                                              leading: Icon(Icons.edit),
                                              title: Text('Editar'),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: ListTile(
                                              leading: Icon(Icons.delete),
                                              title: Text('Eliminar'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubjectInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SubjectInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  final Color initialColor;

  const _ColorPickerDialog({required this.initialColor});

  @override
  Widget build(BuildContext context) {
    const colors = [
      FocusPalette.primary,
      FocusPalette.cyan,
      FocusPalette.teal,
      FocusPalette.mint,
      FocusPalette.amber,
      FocusPalette.coral,
      FocusPalette.primaryDeep,
      FocusPalette.danger,
    ];

    return AlertDialog(
      title: const Text('Selecciona un color'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: colors.map((color) {
          final selected = color.toARGB32() == initialColor.toARGB32();
          return GestureDetector(
            onTap: () => Navigator.pop(context, color),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.black : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

