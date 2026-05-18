import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../models/ranking_profile.dart';
import '../models/schedule.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (provider.lastLoadError != null) ...[
              const _LoadErrorBanner(),
              const SizedBox(height: 14),
            ],
            _FocusHero(provider: provider),
            const SizedBox(height: 16),
            _MetricGrid(provider: provider),
            const SizedBox(height: 16),
            _NextEventsCard(provider: provider),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: provider.levelProgress),
      duration: provider.settings.animationsEnabled
          ? const Duration(milliseconds: 700)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DashboardGreeting(provider: provider),
                    const SizedBox(height: 12),
                    Text(
                      'Nivel ${provider.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$remaining pts para subir',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroChip(
                          icon: Icons.stars_rounded,
                          label: '${provider.gamifiedPoints} pts',
                        ),
                        _HeroChip(
                          icon: Icons.local_fire_department_rounded,
                          label: '${provider.currentStreak} días',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              _LevelRing(
                level: provider.level,
                progress: value.clamp(0, 1),
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
      '👋 $greeting',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      width: 132,
      height: 132,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 12,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFFBBF24)),
          ),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.13),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFBBF24),
                    size: 28,
                  ),
                  Text(
                    'N$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
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

class _NextEventsCard extends StatelessWidget {
  final AppProvider provider;

  const _NextEventsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final nextClass = provider.nextScheduleEntry;
    final nextExam = provider.nextUpcomingExam;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Próximo',
            subtitle: '',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 16),
          _EventTile(
            icon: Icons.event_available_rounded,
            color: FocusPalette.cyan,
            title: nextClass == null ? 'Sin clase' : nextClass.subject.name,
            detail: nextClass == null
                ? 'Agrega horarios'
                : '${_relativeDayLabel(nextClass.startsAt)} · ${nextClass.schedule.startTime} · Aula ${_classroom(nextClass.schedule)}',
          ),
          const SizedBox(height: 12),
          _EventTile(
            icon: Icons.assignment_late_rounded,
            color: FocusPalette.coral,
            title: nextExam == null
                ? 'Sin examen'
                : provider.subjectNameForExam(nextExam),
            detail:
                nextExam == null ? 'Agrega exámenes' : _examDetail(nextExam),
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

class _EventTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  const _EventTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
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
    final compact = MediaQuery.of(context).size.width < 410;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: compact ? 2 : 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: compact ? 1.22 : 1.05,
      children: [
        _MetricCard(
          icon: Icons.stars_rounded,
          value: '${provider.gamifiedPoints}',
          label: 'Puntos',
          color: FocusPalette.primary,
        ),
        _MetricCard(
          icon: Icons.local_fire_department_rounded,
          value: '${provider.currentStreak}',
          label: 'Racha',
          color: const Color(0xFFEA580C),
        ),
        _MetricCard(
          icon: Icons.schedule_rounded,
          value: '${provider.weeklyFocusHours.toStringAsFixed(1)}h',
          label: 'Semana',
          color: const Color(0xFF059669),
        ),
        _MetricCard(
          icon: Icons.workspace_premium_rounded,
          value: '${provider.unlockedAchievementCount}',
          label: 'Logros',
          color: FocusPalette.teal,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
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
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
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
