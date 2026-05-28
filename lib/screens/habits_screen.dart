import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_empty_state.dart';
import '../widgets/focus_feedback.dart';

class HabitsScreen extends StatefulWidget {
  final bool showAppBar;

  const HabitsScreen({super.key, this.showAppBar = true});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _nameController = TextEditingController();
  static const int _maxHabits = 8;

  static const List<String> _identityOptions = [
    'Soy alguien que cumple incluso cuando no tiene ganas.',
    'Soy una persona constante que construye progreso pequeño.',
    'Soy alguien que protege su energía y su enfoque.',
    'Soy una persona ordenada que termina lo que empieza.',
    'Soy alguien que estudia con calma y vuelve a empezar rápido.',
  ];

  String _identityLabel(String identity) {
    return switch (identity) {
      'Soy alguien que cumple incluso cuando no tiene ganas.' =>
        'Constancia real',
      'Soy una persona constante que construye progreso pequeño.' =>
        'Progreso pequeño',
      'Soy alguien que protege su energía y su enfoque.' => 'Energía y enfoque',
      'Soy una persona ordenada que termina lo que empieza.' =>
        'Orden y cierre',
      'Soy alguien que estudia con calma y vuelve a empezar rápido.' =>
        'Calma y retorno',
      _ => 'Identidad',
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createHabit() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.habits.length >= _maxHabits) {
      _showHabitFeedback(
        'Llegaste al límite de $_maxHabits hábitos activos. Edita o elimina uno antes de crear otro.',
        icon: Icons.info_rounded,
        color: FocusPalette.amber,
      );
      return;
    }
    await _showHabitDialog();
  }

  void _showHabitFeedback(
    String message, {
    IconData icon = Icons.check_circle_rounded,
    Color color = FocusPalette.mint,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: FocusActionSnackContent(
            icon: icon,
            message: message,
            color: color,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  String _rankingFeedbackMessage(HabitRankingResult result) {
    return switch (result.status) {
      HabitRankingStatus.awarded =>
        'Hábito completado. +${result.points} puntos para el ranking.',
      HabitRankingStatus.signedOut =>
        'Hábito completado en este dispositivo. Inicia sesión para sumar puntos al ranking.',
      HabitRankingStatus.missingHabit =>
        'Hábito completado. El ranking se actualizará desde la próxima repetición.',
      HabitRankingStatus.tooNew =>
        'Hábito completado. Los hábitos nuevos suman puntos después de 24 horas para evitar trampas.',
      HabitRankingStatus.alreadyAwardedToday =>
        'Hábito completado. Este hábito ya había sumado puntos hoy.',
      HabitRankingStatus.dailyLimitReached =>
        'Hábito completado. Ya alcanzaste el máximo de ${RankingService.maxRankingHabitsPerDay} hábitos con puntos hoy.',
    };
  }

  Future<void> _showHabitDialog({Habit? habit}) async {
    if (habit == null) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (provider.habits.length >= _maxHabits) {
        _showHabitFeedback(
          'Llegaste al límite de $_maxHabits hábitos activos. Edita o elimina uno antes de crear otro.',
          icon: Icons.info_rounded,
          color: FocusPalette.amber,
        );
        return;
      }
    }
    final formKey = GlobalKey<FormState>();
    _nameController.text = habit?.name ?? '';
    final initialIdentity = habit?.identity ?? _identityOptions.first;
    var selectedIdentity = _identityOptions.contains(initialIdentity)
        ? initialIdentity
        : _identityOptions.first;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(habit == null ? 'Nuevo hábito' : 'Editar hábito'),
        content: StatefulBuilder(
          builder: (context, setLocalState) {
            return Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Hábito',
                        hintText:
                            'Ej: Leer 10 páginas o estudiar inglés 20 min',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Escribe un hábito.'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedIdentity,
                      decoration: const InputDecoration(
                          labelText: 'Identidad asociada'),
                      items: _identityOptions
                          .map((identity) => DropdownMenuItem(
                                value: identity,
                                child: Text(_identityLabel(identity),
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      selectedItemBuilder: (context) => _identityOptions
                          .map((identity) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(_identityLabel(identity),
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setLocalState(() =>
                            selectedIdentity = value ?? _identityOptions.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        selectedIdentity,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final provider = Provider.of<AppProvider>(context, listen: false);
              if (habit == null) {
                await provider.addHabit(Habit(
                  name: _nameController.text.trim(),
                  identity: selectedIdentity,
                  history: [],
                ));
              } else {
                await provider.updateHabit(
                  Habit(
                    id: habit.id,
                    name: _nameController.text.trim(),
                    identity: selectedIdentity,
                    history: habit.history,
                    streak: habit.streak,
                    createdAt: habit.createdAt,
                  ),
                );
              }
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              showFocusFeedback(
                context,
                message: habit == null
                    ? 'Hábito creado. Empieza con una repetición pequeña.'
                    : 'Hábito actualizado.',
                icon: habit == null
                    ? Icons.add_task_rounded
                    : Icons.check_circle_rounded,
                celebration: habit == null,
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHabit(Habit habit) async {
    final today = _dateToString(DateTime.now());
    final newHistory = List<String>.from(habit.history);
    final wasCompleted = newHistory.contains(today);
    if (wasCompleted) {
      _showHabitFeedback(
        'Este hábito ya quedó registrado hoy. No se puede desmarcar para mantener tus rachas y puntos consistentes.',
        icon: Icons.lock_rounded,
        color: FocusPalette.amber,
      );
      return;
    }
    newHistory.add(today);
    final updatedHabit = Habit(
      id: habit.id,
      name: habit.name,
      identity: habit.identity,
      history: newHistory,
      streak: habit.streak,
      createdAt: habit.createdAt,
    );
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.updateHabit(updatedHabit);
    var feedbackMessage = 'Hábito completado. Pequeña victoria registrada.';
    try {
      final rankingResult = await RankingService.submitHabitCompletion(
        habitId: habit.id,
        habitCreatedAt: habit.createdAt,
      );
      feedbackMessage = _rankingFeedbackMessage(rankingResult);
      await RankingService.syncAchievementAwards(
        pomodoros: provider.pomodoros.length,
        currentStreak: provider.currentStreak,
        totalHabitCompletions: provider.totalHabitCompletions,
        weeklyMissionCompleted: provider.weeklyMissionCompleted,
        level: provider.level,
        maxLevel: AppProvider.maxLevel,
      );
      await RankingService.syncSocialStats(
        currentStreak: provider.currentStreak,
        totalPomodoros: provider.pomodoros.length,
        totalFocusMinutes: provider.totalFocusMinutes,
        totalHabitCompletions: provider.totalHabitCompletions,
        weeklyMissionCompleted: provider.weeklyMissionCompleted,
        level: provider.level,
        bestStreak: provider.bestStreak,
        focusPoints: provider.gamifiedPoints,
        weeklyPomodoros: provider.weeklyPomodoros,
        weeklyFocusMinutes: provider.weeklyFocusMinutes,
      );
    } catch (error) {
      debugPrint('Focus ranking habit sync skipped: $error');
      feedbackMessage =
          'Hábito completado. No se pudo sincronizar el ranking ahora, pero tu progreso local quedó guardado.';
    }
    final awardedPoints = feedbackMessage.contains('+');
    final isWarning = feedbackMessage.contains('evitar trampas') ||
        feedbackMessage.contains('máximo') ||
        feedbackMessage.contains('ya había');
    _showHabitFeedback(
      feedbackMessage,
      icon: awardedPoints
          ? Icons.bolt_rounded
          : isWarning
              ? Icons.info_rounded
              : Icons.check_circle_rounded,
      color: awardedPoints
          ? FocusPalette.amber
          : isWarning
              ? FocusPalette.amber
              : FocusPalette.mint,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Hábitos'),
            )
          : null,
      body: FocusPageBackground(
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final habits = provider.habits;
            if (habits.isEmpty) {
              return const FocusCenteredEmptyState(
                icon: Icons.auto_awesome_rounded,
                iconKind: FocusAppIconKind.habits,
                accent: FocusPalette.primary,
                title: 'Tu primer hábito te espera',
                message: 'Elige una acción pequeñita y empieza suave.',
              );
            }

            final today = _dateToString(DateTime.now());
            final completedToday =
                habits.where((habit) => habit.history.contains(today)).length;
            final orderedHabits = [...habits]..sort((a, b) {
                final aDone = a.history.contains(today);
                final bDone = b.history.contains(today);
                if (aDone != bDone) return aDone ? 1 : -1;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
            final bestStreak = habits.fold<int>(
                0,
                (max, habit) =>
                    habit.bestStreak > max ? habit.bestStreak : max);
            final averageConsistency = habits
                    .map((habit) => habit.completionPercentage(30))
                    .fold<double>(0, (sum, value) => sum + value) /
                habits.length;
            final canCreateMore = habits.length < _maxHabits;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
              children: [
                _HabitsHero(
                  completedToday: completedToday,
                  totalHabits: habits.length,
                  bestStreak: bestStreak,
                  averageConsistency: averageConsistency,
                ),
                if (!canCreateMore) ...[
                  const SizedBox(height: 12),
                  _HabitLimitNotice(
                    currentHabits: habits.length,
                    maxHabits: _maxHabits,
                    canCreateMore: canCreateMore,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Hoy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                ...orderedHabits.asMap().entries.map(
                      (entry) => FocusStaggeredItem(
                        index: entry.key,
                        child: _HabitCard(
                          habit: entry.value,
                          onToggle: () => _toggleHabit(entry.value),
                          onEdit: () => _showHabitDialog(habit: entry.value),
                          onDelete: () async {
                            await Provider.of<AppProvider>(
                              context,
                              listen: false,
                            ).deleteHabit(entry.value.id!);
                          },
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createHabit,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Hábito'),
      ),
    );
  }

  String _dateToString(DateTime date) => date.toIso8601String().split('T')[0];
}

class _HabitsHero extends StatelessWidget {
  final int completedToday;
  final int totalHabits;
  final int bestStreak;
  final double averageConsistency;

  const _HabitsHero({
    required this.completedToday,
    required this.totalHabits,
    required this.bestStreak,
    required this.averageConsistency,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalHabits == 0 ? 0.0 : completedToday / totalHabits;
    final theme = Theme.of(context);
    return FocusSurfaceCard(
      padding: const EdgeInsets.all(16),
      radius: 26,
      accent: FocusPalette.mint,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const FocusAssetBadge(
                kind: FocusAppIconKind.habits,
                fallback: Icons.checklist_rounded,
                color: FocusPalette.mint,
                size: 48,
                iconSize: 29,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedToday/$totalHabits hoy',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      completedToday == totalHabits
                          ? 'Rutina completa'
                          : 'Pequeñas victorias',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.42),
                      valueColor:
                          const AlwaysStoppedAnimation(FocusPalette.mint),
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
              valueColor: const AlwaysStoppedAnimation(FocusPalette.mint),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Mejor',
                  value: '$bestStreak días',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Constancia',
                  value: '${(averageConsistency * 100).round()}%',
                  icon: Icons.insights_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: FocusPalette.mint, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
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

class _HabitLimitNotice extends StatelessWidget {
  final int currentHabits;
  final int maxHabits;
  final bool canCreateMore;

  const _HabitLimitNotice({
    required this.currentHabits,
    required this.maxHabits,
    required this.canCreateMore,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: canCreateMore
            ? FocusPalette.mint.withValues(alpha: 0.09)
            : colorScheme.errorContainer.withValues(alpha: 0.75),
        border: Border.all(
          color: canCreateMore
              ? FocusPalette.mint.withValues(alpha: 0.20)
              : colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canCreateMore
                ? Icons.playlist_add_check_circle_rounded
                : Icons.info_rounded,
            color: canCreateMore ? FocusPalette.mint : colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              canCreateMore
                  ? '$currentHabits/$maxHabits activos'
                  : 'Límite alcanzado',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HabitCard({
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doneToday = habit.history.contains(today);
    final monthlyScore = (habit.completionPercentage(30) * 100).round();
    final accent = doneToday ? FocusPalette.mint : FocusPalette.teal;
    final last7Days = List.generate(
        7, (index) => DateTime.now().subtract(Duration(days: 6 - index)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FocusSurfaceCard(
        padding: EdgeInsets.zero,
        radius: 20,
        accent: accent,
        elevated: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FocusMicroPop(
                      trigger: 'check-${habit.id}-$doneToday',
                      fromScale: doneToday ? 0.86 : 0.98,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onToggle,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: doneToday
                                ? accent
                                : accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.34),
                              width: 1.4,
                            ),
                          ),
                          child: Icon(
                            doneToday ? Icons.check_rounded : Icons.add_rounded,
                            color: doneToday ? Colors.white : accent,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              _MiniStat(
                                icon: Icons.local_fire_department_rounded,
                                text: '${habit.currentStreak} días',
                                color: FocusPalette.amber,
                              ),
                              const SizedBox(width: 8),
                              _MiniStat(
                                icon: Icons.insights_rounded,
                                text: '$monthlyScore%',
                                color: FocusPalette.mint,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Opciones',
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _HabitChain(
                          last7Days: last7Days, history: habit.history),
                    ),
                    const SizedBox(width: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: doneToday
                          ? Container(
                              key: const ValueKey('done-chip'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color:
                                    FocusPalette.mint.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color:
                                      FocusPalette.mint.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Text(
                                'Hecho',
                                style: TextStyle(
                                  color: FocusPalette.mint,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : FilledButton(
                              key: const ValueKey('pending-button'),
                              onPressed: onToggle,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(92, 36),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                backgroundColor: FocusPalette.teal,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Cumplir'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _HabitChain extends StatelessWidget {
  final List<DateTime> last7Days;
  final List<String> history;

  const _HabitChain({
    required this.last7Days,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: last7Days.map((date) {
        final key = date.toIso8601String().split('T')[0];
        final completed = history.contains(key);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: FocusMicroPop(
              trigger: '$key-$completed',
              fromScale: completed ? 0.82 : 0.96,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 8,
                decoration: BoxDecoration(
                  color: completed
                      ? FocusPalette.mint
                      : colorScheme.outlineVariant.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
