import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_empty_state.dart';
import '../widgets/focus_metric_icon.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

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

    final messenger = ScaffoldMessenger.of(context);

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
              messenger.showSnackBar(
                SnackBar(
                  content: FocusActionSnackContent(
                    icon: habit == null
                        ? Icons.add_task_rounded
                        : Icons.check_circle_rounded,
                    message: habit == null
                        ? 'Hábito creado. Empieza con una repetición pequeña.'
                        : 'Hábito actualizado.',
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
        totalHabitCompletions: provider.totalHabitCompletions,
        weeklyMissionCompleted: provider.weeklyMissionCompleted,
        level: provider.level,
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
      appBar: AppBar(
        title: const Text('Hábitos atómicos'),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final habits = provider.habits;
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FocusProfileEmptyState(
                  icon: Icons.auto_awesome_rounded,
                  accent: FocusPalette.primary,
                  title: 'Carga tu primer hábito',
                  message: 'Empieza con una acción pequeña.',
                ),
              ),
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
          final bestStreak = habits.fold<int>(0,
              (max, habit) => habit.bestStreak > max ? habit.bestStreak : max);
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
              const SizedBox(height: 18),
              Text(
                'Hoy',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _HabitLimitNotice(
                currentHabits: habits.length,
                maxHabits: _maxHabits,
                canCreateMore: canCreateMore,
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
    final colorScheme = theme.colorScheme;
    final accent = colorScheme.primary;
    return Container(
      padding: FocusInsets.panel,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(FocusRadii.panel),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hábitos',
                      style: TextStyle(
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pequeños pasos.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$completedToday/$totalHabits completados hoy',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: accent.withValues(alpha: 0.10),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFFBBF24)),
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Mejor racha',
                  value: '$bestStreak días',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Constancia',
                  value: '${(averageConsistency * 100).round()}%',
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

  const _HeroMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: canCreateMore
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
            : colorScheme.errorContainer.withValues(alpha: 0.75),
        border: Border.all(
          color: canCreateMore
              ? colorScheme.outlineVariant
              : colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canCreateMore
                ? Icons.playlist_add_check_circle_rounded
                : Icons.info_rounded,
            color: canCreateMore ? colorScheme.primary : colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              canCreateMore
                  ? '$currentHabits/$maxHabits hábitos activos'
                  : 'Límite alcanzado: $maxHabits hábitos.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: canCreateMore ? null : FontWeight.w700,
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
    final last7Days = List.generate(
        7, (index) => DateTime.now().subtract(Duration(days: 6 - index)));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        habit.identity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                    onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
                IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniStat(
                    icon: Icons.local_fire_department_rounded,
                    metricIcon: FocusMetricIconKind.streak,
                    label: 'Racha actual',
                    value: '${habit.currentStreak}'),
                const SizedBox(width: 10),
                _MiniStat(
                    icon: Icons.emoji_events_rounded,
                    label: 'Mejor racha',
                    value: '${habit.bestStreak}'),
                const SizedBox(width: 10),
                _MiniStat(
                    icon: Icons.insights_rounded,
                    label: 'Constancia',
                    value: '$monthlyScore%'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: last7Days.map((date) {
                final key = date.toIso8601String().split('T')[0];
                final completed = habit.history.contains(key);
                return FocusMicroPop(
                  trigger: '$key-$completed',
                  fromScale: completed ? 0.82 : 0.96,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: completed
                          ? FocusPalette.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: completed
                            ? const Icon(
                                Icons.check_rounded,
                                key: ValueKey('done'),
                                color: Colors.white,
                                size: 18,
                              )
                            : Text(
                                '${date.day}',
                                key: ValueKey(date.day),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            FocusMicroPop(
              trigger: 'habit-${habit.id}-$doneToday',
              fromScale: doneToday ? 0.96 : 0.99,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onToggle,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      doneToday
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(doneToday),
                    ),
                  ),
                  label: Text(
                    doneToday ? 'Hábito completado hoy' : 'Marcar como hecho',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        doneToday ? FocusPalette.mint : FocusPalette.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final FocusMetricIconKind? metricIcon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    this.metricIcon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metricIcon != null)
              FocusMetricIcon(
                kind: metricIcon!,
                size: 20,
                color: colorScheme.primary,
              )
            else
              Icon(
                icon,
                size: 18,
                color: colorScheme.primary,
              ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
