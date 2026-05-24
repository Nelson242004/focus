import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../models/schedule.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../utils/profile_icon_access.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_metric_icon.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return FocusPageBackground(
          child: ListView(
            padding: FocusInsets.pageCompact,
            children: [
              if (provider.lastLoadError != null) ...[
                const _LoadErrorBanner(),
                FocusGap.md,
              ],
              FocusStaggeredItem(
                index: 0,
                child: _DashboardGreeting(provider: provider),
              ),
              FocusGap.md,
              FocusStaggeredItem(
                index: 1,
                child: _MetricGrid(provider: provider),
              ),
              FocusGap.section,
              FocusStaggeredItem(
                index: 2,
                child: _NextEventsCard(provider: provider),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardGreeting extends StatelessWidget {
  final AppProvider provider;

  const _DashboardGreeting({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (RankingService.currentUser != null) {
      return StreamBuilder(
        stream: RankingService.profileStream(),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final profileName = profile?.name.trim() ?? '';
          final name = profileName.isNotEmpty
              ? profileName
              : _fallbackDashboardName(provider);
          final asset = profileIconAssetFromIndex(
            profile?.stats['socialMascotIndex'],
            email: RankingService.currentUser?.email,
            enforceAccess: true,
          );
          return _DashboardGreetingLayout(name: name, avatarAsset: asset);
        },
      );
    }

    return _DashboardGreetingLayout(
      name: _fallbackDashboardName(provider),
      avatarAsset: defaultProfileIconAsset,
    );
  }

  String _fallbackDashboardName(AppProvider provider) {
    final localName = provider.settings.userName.trim();
    final authName = RankingService.currentUser?.displayName?.trim() ?? '';
    final emailName = RankingService.currentUser?.email?.split('@').first ?? '';
    final name = localName.isNotEmpty
        ? localName
        : authName.isNotEmpty
            ? authName
            : emailName.isNotEmpty
                ? emailName
                : 'Estudiante';
    return name.split(' ').first;
  }
}

class _DashboardGreetingLayout extends StatelessWidget {
  final String name;
  final String avatarAsset;

  const _DashboardGreetingLayout({
    required this.name,
    required this.avatarAsset,
  });

  @override
  Widget build(BuildContext context) {
    return FocusCuteCard(
      accent: FocusPalette.primary,
      padding: const EdgeInsets.fromLTRB(20, 18, 4, 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 122),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 118, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hola, $name 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Organiza tu día con calma.',
                    style: FocusTypography.helper(context),
                  ),
                  const SizedBox(height: 12),
                  const FocusPill(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Pequeños pasos, gran enfoque',
                    color: FocusPalette.amber,
                  ),
                ],
              ),
            ),
            Positioned(
              right: -6,
              bottom: -4,
              child: Image.asset(
                avatarAsset,
                width: 132,
                height: 132,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  defaultProfileIconAsset,
                  width: 132,
                  height: 132,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner();

  @override
  Widget build(BuildContext context) {
    return FocusSurfaceCard(
      padding: FocusInsets.card,
      accent: FocusPalette.danger,
      elevated: false,
      child: Row(
        children: [
          const FocusIconBadge(
            icon: Icons.warning_amber_rounded,
            color: FocusPalette.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Algunos datos no se cargaron bien. Revisa Ajustes o crea un backup.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LevelOverviewCard extends StatelessWidget {
  final AppProvider provider;

  const _LevelOverviewCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final points = provider.gamifiedPoints;
    final level = provider.level;
    final remaining =
        level >= AppProvider.maxLevel ? 0 : provider.nextLevelTarget - points;

    return FocusCuteCard(
      accent: FocusPalette.primary,
      padding: FocusInsets.panel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          final circle = _LevelCircle(
            level: level,
            progress: provider.levelProgress,
            size: compact ? 142 : 128,
            onHero: false,
          );
          final copy = _LevelCopy(
            points: points,
            level: level,
            remaining: remaining,
            progress: provider.levelProgress,
          );
          if (compact) {
            return Column(
              children: [
                circle,
                FocusGap.md,
                copy,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 18),
              circle,
            ],
          );
        },
      ),
    );
  }
}

class _LevelCopy extends StatelessWidget {
  final int points;
  final int level;
  final int remaining;
  final double progress;

  const _LevelCopy({
    required this.points,
    required this.level,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 390;
    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        const FocusPill(
          icon: Icons.auto_graph_rounded,
          label: 'Progreso Focus',
          color: FocusPalette.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Nivel $level',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FocusMetricIcon.points(size: 22),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                '$points puntos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: FocusPalette.primary.withValues(alpha: 0.10),
            valueColor: const AlwaysStoppedAnimation(FocusPalette.mint),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          level >= AppProvider.maxLevel
              ? 'Nivel máximo alcanzado.'
              : '$remaining puntos para subir.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _LevelCircle extends StatelessWidget {
  final int level;
  final double progress;
  final double size;
  final bool onHero;

  const _LevelCircle({
    required this.level,
    required this.progress,
    required this.size,
    this.onHero = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 13,
            strokeCap: StrokeCap.round,
            backgroundColor: onHero
                ? Colors.white.withValues(alpha: 0.18)
                : FocusPalette.primary.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation(
              onHero ? FocusPalette.mint : FocusPalette.primary,
            ),
          ),
          Center(
            child: Container(
              width: size * 0.68,
              height: size * 0.68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: FocusPalette.socialGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: FocusPalette.primary.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Nivel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$level',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.25,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
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
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusSectionHeader(
            icon: Icons.event_note_rounded,
            iconKind: FocusAppIconKind.calendar,
            title: 'Próximo',
            subtitle: 'Clase y examen',
            iconSize: 42,
          ),
          FocusGap.md,
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final classCard = _EventCard(
                iconKind: FocusAppIconKind.subjects,
                fallbackIcon: Icons.event_available_rounded,
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
                iconKind: FocusAppIconKind.exams,
                fallbackIcon: Icons.assignment_late_rounded,
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
  final FocusAppIconKind iconKind;
  final IconData fallbackIcon;
  final Color color;
  final String eyebrow;
  final String title;
  final String detail;
  final String badge;

  const _EventCard({
    required this.iconKind,
    required this.fallbackIcon,
    required this.color,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: FocusInsets.card,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FocusRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          FocusAssetBadge(
            kind: iconKind,
            fallback: fallbackIcon,
            color: color,
            size: 50,
            iconSize: 32,
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
          FocusPill(label: badge, color: color),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final AppProvider provider;

  const _MetricGrid({
    required this.provider,
  });

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
        iconKind: FocusAppIconKind.pomodoro,
        value: '${provider.weeklyFocusHours.toStringAsFixed(1)}h',
        label: 'Semana',
        color: FocusPalette.mint,
      ),
      _MetricData(
        icon: Icons.emoji_events_rounded,
        iconKind: FocusAppIconKind.achievements,
        value: '${provider.unlockedAchievementCount}',
        label: 'Logros',
        color: FocusPalette.teal,
      ),
    ];

    return LayoutBuilder(
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
          itemBuilder: (context, index) => FocusStaggeredItem(
            index: index,
            child: _MetricCard(data: metrics[index]),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: data.color.withValues(alpha: 0.12),
        ),
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
          else if (data.iconKind != null)
            FocusAppIcon(
              kind: data.iconKind!,
              size: 24,
              fallback: data.icon ?? Icons.auto_awesome_rounded,
              fallbackColor: data.color,
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
  final FocusAppIconKind? iconKind;
  final FocusMetricIconKind? metricIcon;
  final String value;
  final String label;
  final Color color;

  const _MetricData({
    this.icon,
    this.iconKind,
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
