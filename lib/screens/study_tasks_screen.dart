import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_task.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_empty_state.dart';
import '../widgets/focus_help_button.dart';

class StudyTasksScreen extends StatefulWidget {
  final bool showAppBar;

  const StudyTasksScreen({super.key, this.showAppBar = true});

  @override
  State<StudyTasksScreen> createState() => _StudyTasksScreenState();
}

class _StudyTasksScreenState extends State<StudyTasksScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  String _filter = 'active';
  int? _subjectId;
  String _priority = 'medium';
  String _status = 'pending';
  DateTime _dueDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _showTaskDialog({StudyTask? task}) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    _titleController.text = task?.title ?? '';
    _notesController.text = task?.notes ?? '';
    _subjectId = task?.subjectId ?? provider.subjects.firstOrNull?.id;
    _priority = task?.priority ?? 'medium';
    _status = task?.status ?? 'pending';
    _dueDate = task?.dueDate ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(task == null ? 'Nueva tarea' : 'Editar tarea'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa un título.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: _subjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Materia'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Sin materia'),
                      ),
                      ...provider.subjects.map(
                        (subject) => DropdownMenuItem<int?>(
                          value: subject.id,
                          child: Text(
                            subject.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _subjectId = value),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha límite'),
                    subtitle: Text(formatDate(_dueDate)),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: _dueDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 3)),
                      );
                      if (selected != null) {
                        setDialogState(() => _dueDate = selected);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'low', label: Text('Baja')),
                      ButtonSegment(value: 'medium', label: Text('Media')),
                      ButtonSegment(value: 'high', label: Text('Alta')),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (value) =>
                        setDialogState(() => _priority = value.first),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pendiente'),
                      ),
                      DropdownMenuItem(
                        value: 'inProgress',
                        child: Text('En progreso'),
                      ),
                      DropdownMenuItem(value: 'done', child: Text('Terminada')),
                    ],
                    onChanged: (value) => setDialogState(
                      () => _status = value ?? 'pending',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas o temas',
                    ),
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
                if (!formKey.currentState!.validate()) return;
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                final item = StudyTask(
                  id: task?.id,
                  subjectId: _subjectId,
                  title: _titleController.text.trim(),
                  notes: _notesController.text.trim(),
                  dueDate: _dueDate,
                  priority: _priority,
                  status: _status,
                  createdAt: task?.createdAt,
                  completedAt: _status == 'done'
                      ? (task?.completedAt ?? DateTime.now())
                      : null,
                );
                if (task == null) {
                  await provider.addStudyTask(item);
                } else {
                  await provider.updateStudyTask(item);
                }
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: FocusActionSnackContent(
                      icon: task == null
                          ? Icons.add_task_rounded
                          : Icons.check_circle_rounded,
                      message: task == null
                          ? 'Tarea guardada.'
                          : 'Tarea actualizada.',
                      color: FocusPalette.mint,
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTask(StudyTask task) async {
    if (task.id == null) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('Se eliminará "${task.title}".'),
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
    if (confirm == true && mounted) {
      await provider.deleteStudyTask(task.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: FocusActionSnackContent(
            icon: Icons.delete_rounded,
            message: 'Tarea eliminada.',
            color: FocusPalette.danger,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<StudyTask> _filteredTasks(AppProvider provider) {
    final items = switch (_filter) {
      'today' => provider.dueTodayStudyTasks,
      'overdue' => provider.overdueStudyTasks,
      'done' => provider.studyTasks.where((task) => task.isDone).toList(),
      _ => provider.activeStudyTasks,
    };
    return [...items];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Tareas'),
              actions: const [
                FocusHelpAction(
                  title: 'Ayuda de tareas',
                  message:
                      'Esta pantalla está pensada para ver rápido qué sigue y qué está vencido.',
                  sections: [
                    FocusHelpSection(
                      title: 'Como funciona',
                      items: [
                        'Activas muestra lo pendiente, Hoy prioriza lo urgente y Vencidas te ayuda a recuperar control.',
                        'La materia es opcional, pero ayuda a ordenar mejor tu semana.',
                        'La prioridad y el estado sirven para que la lista no se vuelva confusa.',
                      ],
                    ),
                    FocusHelpSection(
                      title: 'Tip',
                      items: [
                        'Usa el boton inferior para crear tareas nuevas sin cargar la barra superior.',
                      ],
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final tasks = _filteredTasks(provider);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
              children: [
                _TaskHero(provider: provider),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'active', label: Text('Activas')),
                      ButtonSegment(value: 'today', label: Text('Hoy')),
                      ButtonSegment(value: 'overdue', label: Text('Vencidas')),
                      ButtonSegment(value: 'done', label: Text('Terminadas')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (value) =>
                        setState(() => _filter = value.first),
                  ),
                ),
                const SizedBox(height: 14),
                if (tasks.isEmpty)
                  const _EmptyTasks()
                else
                  ...tasks.map(
                    (task) => _TaskCard(
                      task: task,
                      subjectName:
                          provider.getSubjectById(task.subjectId)?.name,
                      onToggle: (done) =>
                          provider.completeStudyTask(task, done),
                      onEdit: () => _showTaskDialog(task: task),
                      onDelete: () => _deleteTask(task),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tarea'),
      ),
    );
  }
}

class _TaskHero extends StatelessWidget {
  final AppProvider provider;

  const _TaskHero({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.task_alt_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${provider.activeStudyTasks.length} tareas activas',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.dueTodayStudyTasks.length} para hoy · ${provider.overdueStudyTasks.length} vencidas',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final StudyTask task;
  final String? subjectName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.subjectName,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = task.priority == 'high'
        ? FocusPalette.softAlert
        : task.priority == 'low'
            ? FocusPalette.calm
            : FocusPalette.points;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
                value: task.isDone,
                onChanged: (value) => onToggle(value ?? false)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TaskChip(
                        icon: Icons.calendar_today_rounded,
                        label: formatDate(task.dueDate),
                      ),
                      _TaskChip(
                        icon: Icons.flag_rounded,
                        label: task.priorityLabel,
                        color: color.withValues(alpha: 0.16),
                      ),
                      _TaskChip(
                        icon: Icons.hourglass_top_rounded,
                        label: task.statusLabel,
                      ),
                      if (subjectName != null)
                        _TaskChip(
                          icon: Icons.book_rounded,
                          label: subjectName!,
                        ),
                    ],
                  ),
                  if (task.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(task.notes),
                  ],
                  if (task.isOverdue) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Vencida',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _TaskChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return FocusCenteredEmptyState(
      height: MediaQuery.of(context).size.height * 0.42,
      icon: Icons.task_alt_rounded,
      iconKind: FocusAppIconKind.tasks,
      accent: FocusPalette.mint,
      title: 'Sin tareas por ahora',
      message: 'Crea un pendiente pequeño y déjalo conectado a tu materia.',
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
