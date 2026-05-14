import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../models/schedule.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import 'exam_mode_screen.dart';
import 'exams_screen.dart';
import 'pomodoro_screen.dart';
import 'settings_screen.dart';
import 'study_tasks_screen.dart';
import 'subjects_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _askedForName = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        _maybeAskForUserName(provider);
        final nextExam = provider.nextUpcomingExam;
        final nextClass = provider.nextScheduleEntry;
        final nextExamMeta = nextExam == null
            ? null
            : [
                if (nextExam.startTime.trim().isNotEmpty)
                  'Hora ${nextExam.startTime}',
                if (nextExam.classroom.trim().isNotEmpty)
                  'Aula ${nextExam.classroom}',
              ].join(' · ');

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _PremiumHero(provider: provider),
            const SizedBox(height: 16),
            const _QuickActions(),
            const SizedBox(height: 16),
            _AcademicSnapshot(provider: provider),
            const SizedBox(height: 16),
            _MetricGrid(provider: provider),
            const SizedBox(height: 16),
            _EventPanel(
              title: 'Próxima clase',
              accent: const Color(0xFF0EA5E9),
              icon: Icons.event_available_rounded,
              emptyText:
                  'Aún no tienes una clase agendada para las próximas horas.',
              headline: nextClass?.subject.name,
              detail: nextClass == null
                  ? null
                  : '${weekdayLabel(nextClass.schedule.dayOfWeek)} · ${nextClass.schedule.startTime} a ${nextClass.schedule.endTime}',
              meta: null,
            ),
            const SizedBox(height: 12),
            _EventPanel(
              title: 'Próximo examen',
              accent: const Color(0xFF7C3AED),
              icon: Icons.assignment_late_rounded,
              emptyText: 'No hay exámenes cercanos por ahora.',
              headline: nextExam == null
                  ? null
                  : provider.subjectNameForExam(nextExam),
              detail: nextExam == null
                  ? null
                  : '${nextExam.displayType} · ${formatDate(nextExam.date)}',
              meta: nextExamMeta?.isEmpty ?? true ? null : nextExamMeta,
            ),
          ],
        );
      },
    );
  }

  void _maybeAskForUserName(AppProvider provider) {
    if (_askedForName || provider.settings.userName.trim().isNotEmpty) return;
    _askedForName = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showUserNameDialog(provider);
    });
  }

  Future<void> _showUserNameDialog(AppProvider provider) async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('¿Cómo te llamas?'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                hintText: 'Ej. Nelson',
              ),
              onSubmitted: (value) =>
                  Navigator.of(dialogContext).pop(value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(''),
                child: const Text('Después'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );
      final cleaned = (name ?? '').trim();
      if (cleaned.isNotEmpty) {
        await provider.updateUserName(cleaned);
      }
    } finally {
      controller.dispose();
    }
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accesos rápidos',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionButton(
                  icon: Icons.timer_rounded,
                  label: 'Pomodoro',
                  onTap: () => _openPomodoro(context),
                ),
                _ActionButton(
                  icon: Icons.book_rounded,
                  label: 'Materia',
                  onTap: () => _open(context, const SubjectsScreen()),
                ),
                _ActionButton(
                  icon: Icons.assignment_rounded,
                  label: 'Examen',
                  onTap: () => _open(context, const ExamsScreen()),
                ),
                _ActionButton(
                  icon: Icons.task_alt_rounded,
                  label: 'Tareas',
                  onTap: () => _open(context, const StudyTasksScreen()),
                ),
                _ActionButton(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Modo examen',
                  onTap: () => _open(context, const ExamModeScreen()),
                ),
                _ActionButton(
                  icon: Icons.tune_rounded,
                  label: 'Ajustes',
                  onTap: () => _open(context, const SettingsScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openPomodoro(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          appBar: _PomodoroQuickAppBar(),
          body: PomodoroScreen(),
        ),
      ),
    );
  }
}

class _PomodoroQuickAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _PomodoroQuickAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Pomodoro'));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AcademicSnapshot extends StatelessWidget {
  final AppProvider provider;

  const _AcademicSnapshot({required this.provider});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday - 1;
    final todaySchedules = provider.weeklySchedulesMonToSat
        .where((schedule) => schedule.dayOfWeek == today)
        .toList();
    final nextExams = _upcomingExams(provider).take(3).toList();
    final nextTasks = provider.upcomingStudyTasks(limit: 3);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Resumen académico',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SnapshotChip(
                  icon: Icons.book_rounded,
                  label: '${provider.subjects.length} materias',
                ),
                _SnapshotChip(
                  icon: Icons.view_week_rounded,
                  label: '${provider.schedules.length} horarios',
                ),
                _SnapshotChip(
                  icon: Icons.assignment_rounded,
                  label: '${provider.exams.length} exámenes',
                ),
                _SnapshotChip(
                  icon: Icons.task_alt_rounded,
                  label: '${provider.activeStudyTasks.length} tareas',
                ),
                _SnapshotChip(
                  icon: Icons.link_rounded,
                  label: '${provider.resources.length} recursos',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MiniList(
              title: 'Clases de hoy',
              emptyText: 'Hoy no tienes clases cargadas.',
              children: todaySchedules
                  .map((schedule) => _scheduleLine(provider, schedule))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _MiniList(
              title: 'Exámenes próximos',
              emptyText: 'No tienes exámenes próximos.',
              children:
                  nextExams.map((exam) => _examLine(provider, exam)).toList(),
            ),
            const SizedBox(height: 12),
            _MiniList(
              title: 'Tareas prioritarias',
              emptyText: 'No tienes tareas activas.',
              children: nextTasks.map((task) {
                final subject = provider.getSubjectById(task.subjectId)?.name;
                return '${formatDate(task.dueDate)} · ${task.title}${subject == null ? '' : ' · $subject'}';
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<Exam> _upcomingExams(AppProvider provider) {
    final now = DateTime.now();
    return provider.exams
        .where((exam) =>
            !combineDateAndTime(exam.date, exam.startTime).isBefore(now))
        .toList()
      ..sort((a, b) => combineDateAndTime(a.date, a.startTime)
          .compareTo(combineDateAndTime(b.date, b.startTime)));
  }

  String _scheduleLine(AppProvider provider, Schedule schedule) {
    final subject = provider.getSubjectById(schedule.subjectId);
    final room = schedule.classroom.trim().isEmpty
        ? ''
        : ' · Aula ${schedule.classroom.trim()}';
    return '${schedule.startTime} a ${schedule.endTime} · ${subject?.name ?? 'Materia'}$room';
  }

  String _examLine(AppProvider provider, Exam exam) {
    final time =
        exam.startTime.trim().isEmpty ? '' : ' · ${exam.startTime.trim()}';
    return '${formatDate(exam.date)}$time · ${provider.subjectNameForExam(exam)} · ${exam.displayType}';
  }
}

class _SnapshotChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SnapshotChip({
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

class _MiniList extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<String> children;

  const _MiniList({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final lines = children.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          Text(emptyText)
        else
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PremiumHero extends StatelessWidget {
  final AppProvider provider;

  const _PremiumHero({required this.provider});

  @override
  Widget build(BuildContext context) {
    final remaining =
        (provider.nextLevelTarget - provider.gamifiedPoints).clamp(0, 999999);
    final userName = provider.settings.userName.trim();
    final greeting =
        userName.isEmpty ? '👋 Hola, vamos con todo' : '👋 Hola, $userName';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: provider.levelProgress),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? const [
                      Color(0xFF020617),
                      Color(0xFF0F172A),
                      Color(0xFF1D4ED8),
                    ]
                  : const [
                      Color(0xFF0F172A),
                      Color(0xFF1D4ED8),
                      Color(0xFF38BDF8),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nivel ${provider.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${provider.gamifiedPoints} puntos acumulados',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$remaining puntos para subir de nivel',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: value.clamp(0, 1),
                          strokeWidth: 11,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFFBBF24),
                          ),
                        ),
                        Center(
                          child: _LevelMedallion(
                            level: provider.level,
                            progress: value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value.clamp(0, 1),
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFBBF24)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelMedallion extends StatelessWidget {
  final int level;
  final double progress;

  const _LevelMedallion({
    required this.level,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final config = switch (level) {
      1 => (icon: Icons.rocket_launch_rounded, color: const Color(0xFF93C5FD)),
      2 => (
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFF86EFAC),
        ),
      3 => (icon: Icons.shield_rounded, color: const Color(0xFFFDE68A)),
      4 => (icon: Icons.auto_awesome_rounded, color: const Color(0xFFF9A8D4)),
      _ => (icon: Icons.diamond_rounded, color: const Color(0xFFC4B5FD)),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: config.color.withValues(alpha: 0.9),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: config.color.withValues(alpha: 0.28),
                blurRadius: 16,
              ),
            ],
          ),
          child: Icon(config.icon, color: config.color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          '${(progress * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final AppProvider provider;

  const _MetricGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 420;
    final items = [
      _MetricData(
        Icons.stars_rounded,
        const Color(0xFF2563EB),
        '${provider.gamifiedPoints}',
        'Puntos',
      ),
      _MetricData(
        Icons.local_fire_department_rounded,
        const Color(0xFFEA580C),
        '${provider.currentStreak}',
        'Racha',
      ),
      _MetricData(
        Icons.schedule_rounded,
        const Color(0xFF059669),
        '${provider.totalFocusHours.toStringAsFixed(1)}h',
        'Horas',
      ),
      _MetricData(
        Icons.task_alt_rounded,
        const Color(0xFF7C3AED),
        '${provider.weeklyPomodoros}',
        'Pomodoros semana',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: compact ? 1.1 : 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 350 + (index * 120)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.icon, color: item.color),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EventPanel extends StatelessWidget {
  final String title;
  final String? headline;
  final String? detail;
  final String? meta;
  final String emptyText;
  final IconData icon;
  final Color accent;

  const _EventPanel({
    required this.title,
    required this.headline,
    required this.detail,
    required this.meta,
    required this.emptyText,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = headline != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasData ? headline! : emptyText,
                    style: TextStyle(
                      fontWeight: hasData ? FontWeight.w800 : FontWeight.w600,
                      fontSize: hasData ? 18 : 15,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 6),
                    Text(detail!, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  if (meta != null) ...[
                    const SizedBox(height: 4),
                    Text(meta!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _MetricData(this.icon, this.color, this.value, this.label);
}
