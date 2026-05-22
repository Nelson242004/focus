import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_drawer.dart';
import '../widgets/focus_help_button.dart';
import 'study_tasks_screen.dart';

class ExamModeScreen extends StatelessWidget {
  const ExamModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'examMode'),
      appBar: AppBar(
        title: const Text('Modo examen'),
        actions: const [
          FocusHelpAction(
            title: 'Ayuda de modo examen',
            message:
                'Esta pantalla toma tu proximo examen y arma una vista concentrada en preparacion.',
            sections: [
              FocusHelpSection(
                title: 'Que muestra',
                items: [
                  'Plan de preparacion, tareas relacionadas y contexto de la materia.',
                  'Si no hay exámenes próximos, la pantalla te lo muestra limpio para que cargues uno primero.',
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
            final exams = provider.exams
                .where((exam) => !combineDateAndTime(exam.date, exam.startTime)
                    .isBefore(DateTime.now()))
                .toList()
              ..sort((a, b) => combineDateAndTime(a.date, a.startTime)
                  .compareTo(combineDateAndTime(b.date, b.startTime)));
            final exam = exams.isEmpty ? null : exams.first;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _ExamModeHero(exam: exam, provider: provider),
                const SizedBox(height: 14),
                if (exam == null)
                  const _EmptyExamMode()
                else ...[
                  _PreparationPlan(exam: exam, provider: provider),
                  const SizedBox(height: 14),
                  _ExamTasks(exam: exam, provider: provider),
                  const SizedBox(height: 14),
                  _SubjectStats(exam: exam, provider: provider),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExamModeHero extends StatelessWidget {
  final Exam? exam;
  final AppProvider provider;

  const _ExamModeHero({
    required this.exam,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final title = exam == null
        ? 'Sin exámenes próximos'
        : '${provider.subjectNameForExam(exam!)} · ${exam!.displayType}';
    final subtitle = exam == null
        ? 'Carga un examen para que Focus arme una preparación guiada.'
        : '${formatDate(exam!.date)}${exam!.startTime.trim().isEmpty ? '' : ' · ${exam!.startTime}'}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [FocusPalette.ink, FocusPalette.softAlert],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparationPlan extends StatelessWidget {
  final Exam exam;
  final AppProvider provider;

  const _PreparationPlan({
    required this.exam,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final days = combineDateAndTime(exam.date, exam.startTime)
        .difference(DateTime.now())
        .inDays
        .clamp(0, 999);
    final suggestedPomodoros = days <= 1
        ? 6
        : days <= 3
            ? 4
            : 2;
    final subject = provider.subjectNameForExam(exam);
    return _PremiumPanel(
      icon: Icons.auto_awesome_rounded,
      title: 'Plan sugerido',
      children: [
        _PlanStep(
          icon: Icons.timer_rounded,
          title: '$suggestedPomodoros pomodoros por día',
          detail: 'Prioriza bloques de 25 minutos para $subject.',
        ),
        _PlanStep(
          icon: Icons.task_alt_rounded,
          title: 'Cierra tareas pendientes',
          detail:
              'Termina primero las tareas de prioridad alta vinculadas a esta materia.',
        ),
        _PlanStep(
          icon: Icons.menu_book_rounded,
          title: 'Repaso final',
          detail: days == 0
              ? 'Hoy toca repasar fórmulas y errores.'
              : 'Deja el último día para repaso y práctica.',
        ),
      ],
    );
  }
}

class _ExamTasks extends StatelessWidget {
  final Exam exam;
  final AppProvider provider;

  const _ExamTasks({
    required this.exam,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = provider.upcomingStudyTasks(
      limit: 4,
      subjectId: exam.subjectId,
    );
    return _PremiumPanel(
      icon: Icons.checklist_rounded,
      title: 'Pendientes de la materia',
      action: TextButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StudyTasksScreen()),
        ),
        icon: const Icon(Icons.open_in_new_rounded),
        label: const Text('Ver tareas'),
      ),
      children: tasks.isEmpty
          ? [const Text('No hay tareas activas para esta materia.')]
          : tasks
              .map(
                (task) => _PlanStep(
                  icon: task.isOverdue
                      ? Icons.warning_rounded
                      : Icons.radio_button_unchecked_rounded,
                  title: task.title,
                  detail: '${formatDate(task.dueDate)} · ${task.priorityLabel}',
                ),
              )
              .toList(),
    );
  }
}

class _SubjectStats extends StatelessWidget {
  final Exam exam;
  final AppProvider provider;

  const _SubjectStats({
    required this.exam,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final subjectName = provider.subjectNameForExam(exam);
    final minutes = provider.focusMinutesForSubject(subjectName);
    final resources = exam.subjectId == null
        ? 0
        : provider.resourcesForSubject(exam.subjectId!).length;
    return _PremiumPanel(
      icon: Icons.insights_rounded,
      title: 'Estado de preparación',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(
              icon: Icons.timer_rounded,
              label: '${(minutes / 60).toStringAsFixed(1)}h estudiadas',
            ),
            _StatChip(
              icon: Icons.link_rounded,
              label: '$resources recursos',
            ),
            _StatChip(
              icon: Icons.assignment_rounded,
              label:
                  '${provider.upcomingStudyTasks(subjectId: exam.subjectId).length} tareas',
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? action;
  final List<Widget> children;

  const _PremiumPanel({
    required this.icon,
    required this.title,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PlanStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _PlanStep({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyExamMode extends StatelessWidget {
  const _EmptyExamMode();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.assignment_late_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'Carga tu próximo examen',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Focus usará la fecha, materia, tareas y pomodoros para armar una preparación más inteligente.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
