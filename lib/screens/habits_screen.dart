import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/app_provider.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';

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
      );
      return;
    }
    await _showHabitDialog();
  }

  void _showHabitFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
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
                  content: Text(
                    habit == null
                        ? 'Hábito creado. Empieza con una repetición pequeña.'
                        : 'Hábito actualizado.',
                  ),
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
    } catch (error) {
      debugPrint('Focus ranking habit sync skipped: $error');
      feedbackMessage =
          'Hábito completado. No se pudo sincronizar el ranking ahora, pero tu progreso local quedó guardado.';
    }
    _showHabitFeedback(feedbackMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hábitos atómicos'),
        actions: [
          IconButton(
              onPressed: _createHabit, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final habits = provider.habits;
          if (habits.isEmpty) {
            return _EmptyHabitsState(onCreate: _createHabit);
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
            padding: const EdgeInsets.all(16),
            children: [
              _HabitsHero(
                completedToday: completedToday,
                totalHabits: habits.length,
                bestStreak: bestStreak,
                averageConsistency: averageConsistency,
              ),
              const SizedBox(height: 16),
              const _AtomicPrinciples(),
              const SizedBox(height: 18),
              Text(
                'Tus sistemas diarios',
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
                onCreate: _createHabit,
              ),
              const SizedBox(height: 12),
              ...orderedHabits.map((habit) => _HabitCard(
                    habit: habit,
                    onToggle: () => _toggleHabit(habit),
                    onEdit: () => _showHabitDialog(habit: habit),
                    onDelete: () async {
                      await Provider.of<AppProvider>(context, listen: false)
                          .deleteHabit(habit.id!);
                    },
                  )),
            ],
          );
        },
      ),
    );
  }

  String _dateToString(DateTime date) => date.toIso8601String().split('T')[0];
}

class _EmptyHabitsState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyHabitsState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: FocusPalette.examGradient),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 42),
            ),
            const SizedBox(height: 18),
            Text(
              'Empieza pequeño, pero empieza hoy',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inspirado en Hábitos Atómicos: construye sistemas fáciles de repetir y deja que la identidad haga el resto.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear mi primer hábito'),
            ),
          ],
        ),
      ),
    );
  }
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: FocusPalette.studyGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: FocusPalette.primaryDeep.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                      'Identidad en construcción',
                      style:
                          TextStyle(color: Colors.white70, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cada repetición refuerza quién eres.',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$completedToday de $totalHabits hábitos completados hoy',
                      style: const TextStyle(color: Colors.white70),
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
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFFBBF24)),
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900),
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
                      label: 'Mejor racha', value: '$bestStreak días')),
              const SizedBox(width: 10),
              Expanded(
                  child: _HeroMetric(
                      label: 'Constancia',
                      value: '${(averageConsistency * 100).round()}%')),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _AtomicPrinciples extends StatelessWidget {
  const _AtomicPrinciples();

  @override
  Widget build(BuildContext context) {
    const principles = [
      (
        icon: Icons.visibility_rounded,
        title: 'Hazlo obvio',
        text: 'Ten una señal clara para empezar.'
      ),
      (
        icon: Icons.favorite_rounded,
        title: 'Hazlo atractivo',
        text: 'Asocia el hábito con algo valioso.'
      ),
      (
        icon: Icons.touch_app_rounded,
        title: 'Hazlo fácil',
        text: 'Reduce la fricción al mínimo.'
      ),
      (
        icon: Icons.celebration_rounded,
        title: 'Hazlo satisfactorio',
        text: 'Cierra el día con una pequeña victoria.'
      ),
    ];

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: principles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = principles[index];
          return Container(
            width: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Theme.of(context).cardColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(item.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(item.text),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HabitLimitNotice extends StatelessWidget {
  final int currentHabits;
  final int maxHabits;
  final bool canCreateMore;
  final VoidCallback onCreate;

  const _HabitLimitNotice({
    required this.currentHabits,
    required this.maxHabits,
    required this.canCreateMore,
    required this.onCreate,
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
                  ? '$currentHabits de $maxHabits hábitos activos. Mantén pocos para que sean fáciles de repetir.'
                  : 'Tienes $maxHabits hábitos activos. Para crear otro, edita o elimina uno primero.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: canCreateMore ? null : FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            tooltip: canCreateMore
                ? 'Crear hábito'
                : 'Ver por qué no puedes crear más',
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
                        'Identidad asociada: ${habit.identity}',
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
                return Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: completed
                        ? FocusPalette.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: completed ? Colors.white : null),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onToggle,
                icon: Icon(doneToday
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded),
                label: Text(
                    doneToday ? 'Hábito completado hoy' : 'Marcar como hecho'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      doneToday ? FocusPalette.mint : FocusPalette.primary,
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
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
