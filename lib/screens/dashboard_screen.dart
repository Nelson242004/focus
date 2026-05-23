import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../models/schedule.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_metric_icon.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: FocusInsets.pageCompact,
          children: [
            if (provider.lastLoadError != null) ...[
              const _LoadErrorBanner(),
              FocusGap.md,
            ],
            FocusStaggeredItem(
              index: 0,
              child: _NextEventsCard(provider: provider),
            ),
            FocusGap.section,
            FocusStaggeredItem(
              index: 1,
              child: _MetricGrid(provider: provider),
            ),
          ],
        );
      },
    );
  }
}

class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: FocusInsets.card,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(FocusRadii.card),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Algunos datos no se cargaron bien. Revisa Ajustes o crea un backup.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextEventsCard extends StatelessWidget {
  final AppProvider provider;

  const _NextEventsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final nextClass = provider.nextScheduleEntry;
    final nextExam = provider.nextUpcomingExam;
    final nextClassDetail = nextClass == null
        ? 'Agrega horarios'
        : '${_relativeDayLabel(nextClass.startsAt)} · ${nextClass.schedule.startTime} · Aula ${_classroom(nextClass.schedule)}';
    final nextExamDetail =
        nextExam == null ? 'Agrega exámenes' : _examDetail(nextExam);
    final nextClassAt = nextClass?.startsAt;
    final nextExamAt = nextExam == null
        ? null
        : combineDateAndTime(nextExam.date, nextExam.startTime);

    return FocusSurfaceCard(
      padding: FocusInsets.cardRelaxed,
      radius: FocusRadii.panel,
      accent: FocusPalette.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusSectionHeader(
            icon: Icons.bolt_rounded,
            title: 'Próximo',
            subtitle: _summary(nextClassAt, nextExamAt),
            iconSize: 42,
          ),
          FocusGap.md,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: FocusPalette.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: FocusPalette.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: FocusPalette.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _priorityText(nextClass, nextExam, nextExamAt),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
          FocusGap.sm,
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final classCard = _EventCard(
                icon: Icons.event_available_rounded,
                color: FocusPalette.cyan,
                eyebrow: 'Clase',
                title: nextClass == null
                    ? 'Sin clase cercana'
                    : nextClass.subject.name,
                detail: nextClassDetail,
                badge: nextClassAt == null
                    ? 'Pendiente'
                    : _relativeDayLabel(nextClassAt),
              );
              final examCard = _EventCard(
                icon: Icons.assignment_late_rounded,
                color: FocusPalette.amber,
                eyebrow: 'Examen',
                title: nextExam == null
                    ? 'Sin examen cercano'
                    : provider.subjectNameForExam(nextExam),
                detail: nextExamDetail,
                badge: nextExamAt == null
                    ? 'Pendiente'
                    : _relativeDayLabel(nextExamAt),
              );
              if (compact) {
                return Column(
                  children: [
                    classCard,
                    const SizedBox(height: 10),
                    examCard,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: classCard),
                  const SizedBox(width: 10),
                  Expanded(child: examCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _summary(DateTime? classAt, DateTime? examAt) {
    if (classAt == null && examAt == null) {
      return 'Carga clase y examen para ordenar tu día';
    }
    if (classAt != null && examAt == null) {
      return 'Primero: clase ${_relativeDayLabel(classAt)}';
    }
    if (classAt == null && examAt != null) {
      return 'Primero: examen ${_relativeDayLabel(examAt)}';
    }
    if (classAt!.isBefore(examAt!)) {
      return 'Primero: clase ${_relativeDayLabel(classAt)}';
    }
    return 'Primero: examen ${_relativeDayLabel(examAt)}';
  }

  String _priorityText(
    UpcomingScheduleEntry? nextClass,
    Exam? nextExam,
    DateTime? examAt,
  ) {
    if (nextClass == null && nextExam == null) {
      return 'Cuando agregues tus datos, Focus te muestra qué viene primero.';
    }
    if (nextClass != null &&
        (examAt == null || nextClass.startsAt.isBefore(examAt))) {
      return 'Tu próxima clase es ${nextClass.subject.name}.';
    }
    if (nextExam != null) {
      return 'Tu próximo examen es ${provider.subjectNameForExam(nextExam)}.';
    }
    return 'Revisa tu clase más cercana antes de seguir.';
  }

  String _examDetail(Exam exam) {
    final parts = [
      exam.displayType,
      formatDate(exam.date),
      if (exam.startTime.trim().isNotEmpty) exam.startTime.trim(),
      if (exam.classroom.trim().isNotEmpty) 'Aula ${exam.classroom.trim()}',
    ];
    return parts.join(' · ');
  }
}

class _EventCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String eyebrow;
  final String title;
  final String detail;
  final String badge;

  const _EventCard({
    required this.icon,
    required this.color,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FocusRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final AppProvider provider;

  const _MetricGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        metricIcon: FocusMetricIconKind.points,
        value: '${provider.gamifiedPoints}',
        label: 'Puntos',
        color: FocusPalette.primary,
      ),
      _MetricData(
        metricIcon: FocusMetricIconKind.streak,
        value: '${provider.currentStreak}',
        label: 'Racha',
        color: FocusPalette.amber,
      ),
      _MetricData(
        icon: Icons.schedule_rounded,
        value: '${provider.weeklyFocusHours.toStringAsFixed(1)}h',
        label: 'Semana',
        color: FocusPalette.mint,
      ),
      _MetricData(
        icon: Icons.emoji_events_rounded,
        value: '${provider.unlockedAchievementCount}',
        label: 'Logros',
        color: FocusPalette.teal,
      ),
    ];

    return FocusSurfaceCard(
      padding: const EdgeInsets.all(12),
      radius: FocusRadii.card,
      elevated: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 380 ? 2 : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: columns == 2 ? 2.45 : 1.65,
            ),
            itemBuilder: (context, index) => _MetricCard(data: metrics[index]),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data.metricIcon != null)
            FocusMetricIcon(
              kind: data.metricIcon!,
              size: 22,
              color: data.color,
            )
          else
            Icon(data.icon, color: data.color, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final IconData? icon;
  final FocusMetricIconKind? metricIcon;
  final String value;
  final String label;
  final Color color;

  const _MetricData({
    this.icon,
    this.metricIcon,
    required this.value,
    required this.label,
    required this.color,
  });
}

String _relativeDayLabel(DateTime date) {
  final now = DateTime.now();
  if (DateUtils.isSameDay(now, date)) return 'Hoy';
  if (DateUtils.isSameDay(now.add(const Duration(days: 1)), date)) {
    return 'Mañana';
  }
  return weekdayLabel(date.weekday - 1);
}

String _classroom(Schedule schedule) {
  final room = schedule.classroom.trim();
  return room.isEmpty ? 'sin aula' : room;
}
