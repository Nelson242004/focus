import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_drawer.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final points = provider.gamifiedPoints;
        final level = provider.level;
        final remaining = provider.level >= AppProvider.maxLevel
            ? 0
            : provider.nextLevelTarget - points;
        final achievements = [
          _AchievementData(
            title: 'Primer impulso',
            subtitle: 'Completa tu primer pomodoro. +50 pts',
            unlocked: provider.pomodoros.isNotEmpty,
            icon: Icons.play_circle_fill_rounded,
          ),
          _AchievementData(
            title: 'Semana encendida',
            subtitle: 'Alcanza una racha de 7 días. +100 pts',
            unlocked: provider.currentStreak >= 7,
            icon: Icons.local_fire_department_rounded,
          ),
          _AchievementData(
            title: 'Racha imparable',
            subtitle: 'Sostén una racha de 14 días. +180 pts',
            unlocked: provider.currentStreak >= 14,
            icon: Icons.whatshot_rounded,
          ),
          _AchievementData(
            title: 'Mes de constancia',
            subtitle: 'Llega a una racha de 30 días. +400 pts',
            unlocked: provider.currentStreak >= 30,
            icon: Icons.local_fire_department_outlined,
          ),
          _AchievementData(
            title: 'Cazador de enfoque',
            subtitle: 'Suma 25 pomodoros en total. +150 pts',
            unlocked: provider.pomodoros.length >= 25,
            icon: Icons.bolt_rounded,
          ),
          _AchievementData(
            title: 'Cien sesiones',
            subtitle: 'Alcanza 100 pomodoros acumulados. +600 pts',
            unlocked: provider.pomodoros.length >= 100,
            icon: Icons.flash_on_rounded,
          ),
          _AchievementData(
            title: 'Misión semanal',
            subtitle: 'Completa 10 pomodoros en la misma semana. +120 pts',
            unlocked: provider.weeklyMissionCompleted,
            icon: Icons.flag_circle_rounded,
          ),
          _AchievementData(
            title: 'Constancia atómica',
            subtitle: 'Marca 30 hábitos completados. +180 pts',
            unlocked: provider.totalHabitCompletions >= 30,
            icon: Icons.check_circle_rounded,
          ),
          _AchievementData(
            title: 'Sistema sólido',
            subtitle: 'Llega a 75 hábitos completados. +420 pts',
            unlocked: provider.totalHabitCompletions >= 75,
            icon: Icons.inventory_2_rounded,
          ),
          _AchievementData(
            title: 'Nivel máximo',
            subtitle: 'Llega al nivel 5. +500 pts',
            unlocked: provider.level >= AppProvider.maxLevel,
            icon: Icons.diamond_rounded,
          ),
        ];

        return Scaffold(
          drawer: const FocusDrawer(selectedRoute: 'achievements'),
          appBar: AppBar(
            title: const Text('Logros'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AchievementsHero(
                points: points,
                level: level,
                progress: provider.levelProgress,
                remaining: remaining,
                rewardTitle: provider.streakRewardTitle,
              ),
              const SizedBox(height: 16),
              _MissionCard(provider: provider),
              const SizedBox(height: 16),
              const _GuideCard(
                title: 'Equivalencias de puntos',
                items: [
                  'Cada pomodoro completado suma ${RankingService.pointsPerPomodoro} puntos por bloque de 25 min.',
                  'Pomodoro sin distracciones suma +${RankingService.distractionFreeBonus} puntos.',
                  'Cada hábito completado suma ${RankingService.pointsPerHabitCompletion} puntos.',
                  'Los logros suman puntos una sola vez al desbloquearse.',
                  'Los niveles suben cada 200 puntos.',
                  'El progreso máximo llega hasta el nivel 5.',
                ],
              ),
              const SizedBox(height: 16),
              _GuideCard(
                title: 'Ruta de niveles',
                items: List.generate(
                  AppProvider.maxLevel,
                  (index) =>
                      'Nivel ${index + 1}: desde ${index * AppProvider.pointsPerLevel} puntos.',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Insignias',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...achievements
                  .map((achievement) => _AchievementTile(data: achievement)),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementsHero extends StatelessWidget {
  final int points;
  final int level;
  final double progress;
  final int remaining;
  final String rewardTitle;

  const _AchievementsHero({
    required this.points,
    required this.level,
    required this.progress,
    required this.remaining,
    required this.rewardTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: FocusPalette.studyGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: FocusPalette.primaryDeep.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tu progreso gamificado',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      'Nivel $level de ${AppProvider.maxLevel}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text('$points puntos acumulados',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      level >= AppProvider.maxLevel
                          ? 'Ya alcanzaste el nivel máximo.'
                          : '$remaining puntos para subir de nivel.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFFBBF24)),
                    ),
                    Center(
                        child:
                            _LevelMedallion(level: level, progress: progress)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Recompensa por racha: $rewardTitle',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ],
      ),
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
          color: const Color(0xFF86EFAC)
        ),
      3 => (icon: Icons.shield_rounded, color: const Color(0xFFFDE68A)),
      4 => (icon: Icons.auto_awesome_rounded, color: FocusPalette.cyan),
      _ => (icon: Icons.diamond_rounded, color: FocusPalette.teal),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
                color: config.color.withValues(alpha: 0.95), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: config.color.withValues(alpha: 0.28),
                blurRadius: 14,
              ),
            ],
          ),
          child: Icon(config.icon, color: config.color, size: 23),
        ),
        const SizedBox(height: 5),
        Text('${(progress * 100).round()}%',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  final AppProvider provider;

  const _MissionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Misión semanal',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                'Completa ${provider.weeklyMissionTarget} pomodoros esta semana para desbloquear una insignia extra.'),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: provider.weeklyMissionProgress,
                minHeight: 10,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(FocusPalette.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
                '${provider.weeklyMissionProgressCount} de ${provider.weeklyMissionTarget} completados'),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _GuideCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item)),
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

class _AchievementTile extends StatelessWidget {
  final _AchievementData data;

  const _AchievementTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final accent = data.unlocked ? FocusPalette.primary : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: accent.withValues(alpha: 0.14),
              ),
              child: Icon(data.icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(data.subtitle),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(data.unlocked ? 'Desbloqueado' : 'Bloqueado',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _AchievementData {
  final String title;
  final String subtitle;
  final bool unlocked;
  final IconData icon;

  const _AchievementData({
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.icon,
  });
}
