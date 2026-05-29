import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_task.dart';
import '../providers/app_provider.dart';
import '../services/pomodoro_task_launch_service.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_empty_state.dart';
import '../widgets/focus_help_button.dart';
import '../widgets/focus_main_navigation_scope.dart';

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
                      'Tareas es para pendientes concretos, con filtros rápidos.',
                  sections: [
                    FocusHelpSection(
                      title: 'Cómo funciona',
                      items: [
                        'Activas muestra lo pendiente; Hoy prioriza vencimientos del día.',
                        'Vencidas muestra lo que necesita atención inmediata.',
                        'La materia es opcional, pero ayuda a ordenar mejor tu semana.',
                        'Prioridad y estado sirven para ordenar sin llenar la pantalla de texto.',
                      ],
                    ),
                    FocusHelpSection(
                      title: 'Uso rápido',
                      items: [
                        'Usa el botón inferior para crear tareas nuevas.',
                        'Marca como completada una tarea cuando ya la resolviste.',
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
        child: FocusPageBackground(
          child: Consumer<AppProvider>(
            builder: (context, provider, _) {
              if (provider.studyTasks.isEmpty) {
                return const _EmptyTasks();
              }
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
                        ButtonSegment(
                            value: 'overdue', label: Text('Vencidas')),
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
                        onStartPomodoro: () => _startPomodoroForTask(task),
                        onEdit: () => _showTaskDialog(task: task),
                        onDelete: () => _deleteTask(task),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tarea'),
      ),
    );
  }

  void _startPomodoroForTask(StudyTask task) {
    PomodoroTaskLaunchService.startFromTask(task);
    FocusMainNavigationScope.maybeOf(context)?.call(1);
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
  final VoidCallback onStartPomodoro;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.subjectName,
    required this.onToggle,
    required this.onStartPomodoro,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = task.priority == 'high'
        ? FocusPalette.danger
        : task.priority == 'low'
            ? FocusPalette.mint
            : FocusPalette.amber;
    final accent = task.isOverdue
        ? FocusPalette.danger
        : task.isDone
            ? FocusPalette.muted
            : priorityColor;
    final subject = subjectName?.trim();
    final statusLabel = task.isOverdue
        ? 'Vencida'
        : task.isDone
            ? 'Terminada'
            : task.statusLabel;
    final secondary = [
      if (subject != null && subject.isNotEmpty) subject,
      formatDate(task.dueDate),
      task.priorityLabel,
    ].join(' · ');

    final compactSecondary = secondary.replaceAll(' \u00C2\u00B7 ', ' | ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FocusSurfaceCard(
        padding: EdgeInsets.zero,
        radius: 20,
        accent: accent,
        elevated: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onEdit,
          child: Row(
            children: [
              const SizedBox(width: 12),
              _TaskCheckButton(
                done: task.isDone,
                color: accent,
                onChanged: onToggle,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.04,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isDone
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.56)
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        compactSecondary.isEmpty
                            ? statusLabel
                            : compactSecondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!task.isDone)
                IconButton(
                  tooltip: 'Iniciar Pomodoro para esta tarea',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.timer_rounded, size: 21),
                  color: FocusPalette.primary,
                  onPressed: onStartPomodoro,
                ),
              _TaskStatusDot(label: statusLabel, color: accent),
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                iconSize: 20,
                padding: EdgeInsets.zero,
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
      ),
    );
  }
}

class _TaskStatusDot extends StatelessWidget {
  final String label;
  final Color color;

  const _TaskStatusDot({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 9,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _TaskCheckButton extends StatelessWidget {
  final bool done;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _TaskCheckButton({
    required this.done,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => onChanged(!done),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : color.withValues(alpha: 0.10),
          border: Border.all(
            color: done ? color : color.withValues(alpha: 0.34),
            width: 1.6,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: done
              ? const Icon(
                  Icons.check_rounded,
                  key: ValueKey('done'),
                  size: 18,
                  color: Colors.white,
                )
              : Icon(
                  Icons.circle_outlined,
                  key: const ValueKey('todo'),
                  size: 14,
                  color: color.withValues(alpha: 0.55),
                ),
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return const FocusCenteredEmptyState(
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
