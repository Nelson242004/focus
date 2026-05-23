import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../models/ranking_profile.dart';
import '../models/schedule.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_metric_icon.dart';
import 'exams_screen.dart';
import 'friends_screen.dart';
import 'habits_screen.dart';
import 'pomodoro_screen.dart';
import 'subjects_screen.dart';

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
              child: _FocusHero(provider: provider),
            ),
            if (_GettingStartedCard.shouldShow(provider)) ...[
              FocusGap.section,
              FocusStaggeredItem(
                index: 1,
                child: _GettingStartedCard(provider: provider),
              ),
            ],
            FocusGap.section,
            FocusStaggeredItem(
              index: 2,
              child: _TodayCenter(provider: provider),
            ),
            FocusGap.section,
            FocusStaggeredItem(
              index: 3,
              child: const _QuickActions(),
            ),
            FocusGap.section,
            FocusStaggeredItem(
              index: 4,
              child: _NextEventsCard(provider: provider),
            ),
            FocusGap.section,
            FocusStaggeredItem(
              index: 5,
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

class _FocusHero extends StatelessWidget {
  final AppProvider provider;

  const _FocusHero({required this.provider});

  @override
  Widget build(BuildContext context) {
    final remaining =
        (provider.nextLevelTarget - provider.gamifiedPoints).clamp(0, 999999);
    final isMaxLevel = provider.level >= AppProvider.maxLevel;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: provider.levelProgress),
      duration: provider.settings.animationsEnabled
          ? const Duration(milliseconds: 700)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          padding: FocusInsets.panel,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FocusRadii.panel),
            gradient: const LinearGradient(
              colors: FocusPalette.studyGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: FocusPalette.cyan.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              _LevelRing(
                level: provider.level,
                progress: value.clamp(0, 1),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DashboardGreeting(provider: provider),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Text(
                        'Progreso Focus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nivel ${provider.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isMaxLevel
                          ? 'Llegaste al nivel máximo.'
                          : '$remaining pts para subir de nivel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
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
    if (RankingService.currentUser == null) {
      return _GreetingText(name: provider.settings.userName.trim());
    }
    return StreamBuilder<RankingProfile?>(
      stream: RankingService.profileStream(),
      builder: (context, snapshot) {
        final rankingName = snapshot.data?.name.trim() ?? '';
        final localName = provider.settings.userName.trim();
        return _GreetingText(
          name: rankingName.isNotEmpty ? rankingName : localName,
        );
      },
    );
  }
}

class _GreetingText extends StatelessWidget {
  final String name;

  const _GreetingText({required this.name});

  @override
  Widget build(BuildContext context) {
    final greeting = name.isEmpty ? 'Hola, vamos con todo' : 'Hola, $name';
    return Text(
      greeting,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _LevelRing extends StatelessWidget {
  final int level;
  final double progress;

  const _LevelRing({
    required this.level,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      height: 152,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 12,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            valueColor: const AlwaysStoppedAnimation(FocusPalette.amber),
          ),
          Center(
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.13),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: FocusPalette.amber,
                    size: 26,
                  ),
                  Text(
                    'N$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
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

class _GettingStartedCard extends StatelessWidget {
  final AppProvider provider;

  const _GettingStartedCard({required this.provider});

  static bool shouldShow(AppProvider provider) {
    return RankingService.currentUser == null ||
        provider.subjects.isEmpty ||
        provider.pomodoros.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StartStep(
        label: 'Crear perfil',
        done: RankingService.currentUser != null,
        icon: Icons.person_rounded,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        ),
      ),
      _StartStep(
        label: 'Cargar materias',
        done: provider.subjects.isNotEmpty,
        icon: Icons.menu_book_rounded,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubjectsScreen()),
        ),
      ),
      _StartStep(
        label: 'Probar Pomodoro',
        done: provider.pomodoros.isNotEmpty,
        icon: Icons.timer_rounded,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PomodoroScreen()),
        ),
      ),
    ];

    return FocusSurfaceCard(
      padding: FocusInsets.cardRelaxed,
      radius: FocusRadii.card,
      accent: FocusPalette.primary,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusSectionHeader(
            icon: Icons.route_rounded,
            title: 'Primeros pasos',
            subtitle: 'Configura lo básico',
            iconSize: 40,
            action: TextButton(
              onPressed: () => _openFirstPending(context, steps),
              child: const Text('Empezar'),
            ),
          ),
          FocusGap.sm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps.map((step) => _StartStepChip(step: step)).toList(),
          ),
        ],
      ),
    );
  }

  void _openFirstPending(BuildContext context, List<_StartStep> steps) {
    final pending = steps.where((step) => !step.done);
    if (pending.isEmpty) return;
    pending.first.onTap();
  }
}

class _StartStep {
  final String label;
  final bool done;
  final IconData icon;
  final VoidCallback onTap;

  const _StartStep({
    required this.label,
    required this.done,
    required this.icon,
    required this.onTap,
  });
}

class _StartStepChip extends StatelessWidget {
  final _StartStep step;

  const _StartStepChip({required this.step});

  @override
  Widget build(BuildContext context) {
    final color = step.done ? FocusPalette.mint : FocusPalette.primary;
    return ActionChip(
      avatar: Icon(
        step.done ? Icons.check_circle_rounded : step.icon,
        color: color,
        size: 18,
      ),
      label: Text(step.label),
      onPressed: step.done ? null : step.onTap,
      side: BorderSide(color: color.withValues(alpha: 0.22)),
    );
  }
}

class _TodayCenter extends StatelessWidget {
  final AppProvider provider;

  const _TodayCenter({required this.provider});

  @override
  Widget build(BuildContext context) {
    final nextClass = provider.nextScheduleEntry;
    final nextExam = provider.nextUpcomingExam;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final completedHabits =
        provider.habits.where((habit) => habit.history.contains(today)).length;
    final pendingHabits =
        (provider.habits.length - completedHabits).clamp(0, 999);
    final nextNow = nextClass != null
        ? '${nextClass.subject.name} · ${_relativeDayLabel(nextClass.startsAt)}'
        : nextExam != null
            ? '${provider.subjectNameForExam(nextExam)} · ${formatDate(nextExam.date)}'
            : 'Pomodoro rápido';
    final missing = pendingHabits > 0
        ? '$pendingHabits hábitos'
        : provider.subjects.isEmpty
            ? 'Materias'
            : nextExam == null
                ? 'Exámenes'
                : 'Nada urgente';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Hoy',
          subtitle: 'Qué tienes, qué haces y qué falta',
          icon: Icons.today_rounded,
        ),
        FocusGap.sm,
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final items = [
              _TodayCard(
                icon: Icons.event_available_rounded,
                color: FocusPalette.cyan,
                label: 'Qué tengo hoy',
                value: nextClass == null
                    ? 'Sin clase cercana'
                    : nextClass.subject.name,
              ),
              _TodayCard(
                icon: Icons.play_circle_fill_rounded,
                color: FocusPalette.primary,
                label: 'Qué hago ahora',
                value: nextNow,
              ),
              _TodayCard(
                icon: Icons.checklist_rounded,
                color: FocusPalette.amber,
                label: 'Qué falta',
                value: missing,
              ),
            ];
            if (compact) {
              return Column(
                children: [
                  for (final item in items) ...[
                    item,
                    if (item != items.last) const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (final item in items) ...[
                  Expanded(child: item),
                  if (item != items.last) const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _TodayCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return FocusSurfaceCard(
      padding: const EdgeInsets.all(16),
      radius: FocusRadii.card,
      accent: color,
      elevated: false,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Acciones rápidas',
          subtitle: 'Un toque y sigues',
          icon: Icons.flash_on_rounded,
        ),
        FocusGap.sm,
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 540 ? 2 : 4;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 2 ? 1.7 : 1.25,
              children: [
                _QuickActionCard(
                  icon: Icons.timer_rounded,
                  color: FocusPalette.primary,
                  label: 'Pomodoro 25 min',
                  onTap: () => _open(context, const PomodoroScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.menu_book_rounded,
                  color: FocusPalette.cyan,
                  label: 'Agregar materia',
                  onTap: () => _open(context, const SubjectsScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.check_circle_rounded,
                  color: FocusPalette.mint,
                  label: 'Marcar hábito',
                  onTap: () => _open(context, const HabitsScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.assignment_rounded,
                  color: FocusPalette.amber,
                  label: 'Próximo examen',
                  onTap: () => _open(context, const ExamsScreen()),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(FocusRadii.card),
      onTap: onTap,
      child: FocusSurfaceCard(
        padding: const EdgeInsets.all(14),
        radius: FocusRadii.card,
        accent: color,
        elevated: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Próximo',
          subtitle: 'Clase y examen más cercanos',
          icon: Icons.bolt_rounded,
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
            );
            final examCard = _EventCard(
              icon: Icons.assignment_late_rounded,
              color: FocusPalette.amber,
              eyebrow: 'Examen',
              title: nextExam == null
                  ? 'Sin examen cercano'
                  : provider.subjectNameForExam(nextExam),
              detail: nextExamDetail,
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
  final IconData icon;
  final Color color;
  final String eyebrow;
  final String title;
  final String detail;

  const _EventCard({
    required this.icon,
    required this.color,
    required this.eyebrow,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return FocusSurfaceCard(
      padding: FocusInsets.cardRelaxed,
      radius: FocusRadii.card,
      accent: color,
      elevated: false,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FocusSectionHeader(
      icon: icon,
      title: title,
      subtitle: subtitle,
      iconSize: 42,
    );
  }
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
