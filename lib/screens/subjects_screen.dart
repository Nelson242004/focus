import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule.dart';
import '../models/subject.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_empty_state.dart';
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
                      const SnackBar(
                        content: FocusActionSnackContent(
                          icon: Icons.access_time_rounded,
                          message: 'Usa formato HH:MM.',
                          color: FocusPalette.amber,
                        ),
                      ),
                    );
                    return;
                  }
                  if (timeToMinutes(_endTime) <= timeToMinutes(_startTime)) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: FocusActionSnackContent(
                          icon: Icons.warning_amber_rounded,
                          message:
                              'La hora de fin debe ser mayor que la de inicio.',
                          color: FocusPalette.amber,
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
                      content: FocusActionSnackContent(
                        icon: subject == null
                            ? Icons.menu_book_rounded
                            : Icons.check_circle_rounded,
                        message: subject == null
                            ? 'Materia guardada.'
                            : 'Materia actualizada.',
                        color: FocusPalette.mint,
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: FocusActionSnackContent(
                        icon: Icons.error_outline_rounded,
                        message: _friendlyError(error),
                        color: FocusPalette.danger,
                      ),
                    ),
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
        const SnackBar(
          content: FocusActionSnackContent(
            icon: Icons.delete_rounded,
            message: 'Materia eliminada.',
            color: FocusPalette.danger,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Materias'),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final subjects = provider.subjects;
            return ListView(
              padding: const EdgeInsets.only(bottom: 108),
              children: [
                _SubjectsPanel(
                  provider: provider,
                  subjects: subjects,
                  onEdit: (subject) => _showSubjectDialog(subject: subject),
                  onDelete: _deleteSubject,
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-subject',
        elevation: 8,
        onPressed: () => _showSubjectDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar materia'),
      ),
    );
  }
}

class _SubjectsPanel extends StatelessWidget {
  final AppProvider provider;
  final List<Subject> subjects;
  final ValueChanged<Subject> onEdit;
  final ValueChanged<Subject> onDelete;

  const _SubjectsPanel({
    required this.provider,
    required this.subjects,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return Padding(
        padding: FocusInsets.pageCompact,
        child: FocusProfileEmptyState(
          icon: Icons.menu_book_rounded,
          accent: const Color(0xFF0EA5E9),
          title: 'Carga tu primera materia',
          message: 'Empieza con el nombre y suma detalles luego.',
        ),
      );
    }

    return Padding(
      padding: FocusInsets.pageCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusSectionHeader(
            icon: Icons.menu_book_rounded,
            title: 'Tus materias',
            subtitle: '${subjects.length} registradas',
            accent: const Color(0xFF0EA5E9),
          ),
          FocusGap.section,
          ...subjects.map(
            (subject) => Padding(
              padding: const EdgeInsets.only(bottom: FocusSpacing.sm),
              child: _SubjectCard(
                provider: provider,
                subject: subject,
                onEdit: () => onEdit(subject),
                onDelete: () => onDelete(subject),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final AppProvider provider;
  final Subject subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubjectCard({
    required this.provider,
    required this.subject,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = colorFromHex(subject.color);
    final subjectSchedules = provider.schedules
        .where((schedule) => schedule.subjectId == subject.id)
        .toList()
      ..sort((a, b) {
        final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (byDay != 0) return byDay;
        return a.startTime.compareTo(b.startTime);
      });
    final subjectExams =
        provider.exams.where((exam) => exam.subjectId == subject.id).toList();
    final taskCount = provider.studyTasks
        .where((task) => task.subjectId == subject.id && !task.isDone)
        .length;
    final resourceCount = subject.id == null
        ? 0
        : provider.resourcesForSubject(subject.id!).length;

    return FocusSurfaceCard(
      padding: EdgeInsets.zero,
      radius: FocusRadii.card,
      accent: accent,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 7,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(FocusRadii.card),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: FocusInsets.cardRelaxed,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            subject.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: FocusSpacing.sm),
                        PopupMenuButton<String>(
                          tooltip: 'Más acciones',
                          icon: const Icon(Icons.more_horiz_rounded),
                          onSelected: (value) {
                            if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_rounded),
                                title: Text('Editar'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_rounded),
                                title: Text('Eliminar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    FocusGap.sm,
                    _SubjectSummaryLine(
                      schedules: subjectSchedules.length,
                      exams: subjectExams.length,
                      tasks: taskCount,
                      resources: resourceCount,
                    ),
                    FocusGap.sm,
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        leading: Icon(Icons.tune_rounded, color: accent),
                        title: const Text(
                          'Detalles',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text('Horarios y datos asociados'),
                        children: [
                          const SizedBox(height: FocusSpacing.sm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (subject.professorName?.trim().isNotEmpty ==
                                    true)
                                  _SubjectInfoChip(
                                    icon: Icons.person_rounded,
                                    label:
                                        'Prof. ${subject.professorName!.trim()}',
                                  ),
                                if (subject.defaultClassroom
                                        ?.trim()
                                        .isNotEmpty ==
                                    true)
                                  _SubjectInfoChip(
                                    icon: Icons.meeting_room_rounded,
                                    label:
                                        'Aula ${subject.defaultClassroom!.trim()}',
                                  ),
                                if (subject.sectionCode?.trim().isNotEmpty ==
                                    true)
                                  _SubjectInfoChip(
                                    icon: Icons.groups_rounded,
                                    label:
                                        'Sección ${subject.sectionCode!.trim()}',
                                  ),
                                _SubjectInfoChip(
                                  icon: Icons.schedule_rounded,
                                  label: '${subjectSchedules.length} bloques',
                                ),
                                _SubjectInfoChip(
                                  icon: Icons.assignment_rounded,
                                  label: '${subjectExams.length} exámenes',
                                ),
                                _SubjectInfoChip(
                                  icon: Icons.task_alt_rounded,
                                  label: '$taskCount tareas',
                                ),
                                _SubjectInfoChip(
                                  icon: Icons.link_rounded,
                                  label: '$resourceCount recursos',
                                ),
                              ],
                            ),
                          ),
                          if (subjectSchedules.isNotEmpty) ...[
                            FocusGap.md,
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(FocusSpacing.md),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(FocusRadii.control),
                                color: accent.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.14),
                                ),
                              ),
                              child: Text(
                                'Próximo bloque: ${weekdayLabel(subjectSchedules.first.dayOfWeek)} · ${subjectSchedules.first.startTime} a ${subjectSchedules.first.endTime}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          FocusGap.md,
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SubjectScheduleScreen(
                                      subject: subject,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.calendar_month_rounded),
                              label: const Text('Horarios'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectSummaryLine extends StatelessWidget {
  final int schedules;
  final int exams;
  final int tasks;
  final int resources;

  const _SubjectSummaryLine({
    required this.schedules,
    required this.exams,
    required this.tasks,
    required this.resources,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Text(
      '$schedules horarios · $exams exámenes · $tasks tareas · $resources recursos',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.chip),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
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
      FocusPalette.teal,
      FocusPalette.mint,
      FocusPalette.amber,
      FocusPalette.softAlert,
      FocusPalette.primaryDeep,
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
