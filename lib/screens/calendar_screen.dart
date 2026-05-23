import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_drawer.dart';
import '../widgets/focus_help_button.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final monthDays = _buildMonthDays(_focusedMonth);
        final dayItems = _eventsForDate(_selectedDate, provider);
        final monthItems = _monthItems(provider);
        final nextItems = _nextItems(provider);

        return Scaffold(
          drawer: const FocusDrawer(selectedRoute: 'calendar'),
          appBar: AppBar(
            title: const Text('Calendario'),
            actions: const [
              FocusHelpAction(
                title: 'Ayuda de calendario',
                message:
                    'El calendario junta exámenes, tareas y otras fechas para que veas tu carga de un vistazo.',
                sections: [
                  FocusHelpSection(
                    title: 'Vista',
                    items: [
                      'El resumen mensual te muestra cuánto se concentra en el mes actual.',
                      'Al tocar un día ves su agenda sin llenar toda la pantalla de texto.',
                    ],
                  ),
                  FocusHelpSection(
                    title: 'Tip',
                    items: [
                      'Usa Hoy para volver rápido a la fecha actual y revisar lo más cercano.',
                    ],
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                _CalendarHero(
                  monthLabel: _monthLabel(_focusedMonth),
                  totalEvents: monthItems.length,
                  selectedLabel: formatDate(_selectedDate),
                  onToday: () {
                    final now = DateTime.now();
                    setState(() {
                      _focusedMonth = DateTime(now.year, now.month);
                      _selectedDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                  onPrevious: () => setState(
                    () => _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month - 1),
                  ),
                  onNext: () => setState(
                    () => _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month + 1),
                  ),
                ),
                const SizedBox(height: 14),
                _MonthSummary(items: monthItems),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            _WeekdayHeader('L'),
                            _WeekdayHeader('M'),
                            _WeekdayHeader('M'),
                            _WeekdayHeader('J'),
                            _WeekdayHeader('V'),
                            _WeekdayHeader('S'),
                            _WeekdayHeader('D'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: monthDays.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final day = monthDays[index];
                            final items = _eventsForDate(day, provider);
                            return _CalendarDayTile(
                              day: day,
                              isCurrentMonth: day.month == _focusedMonth.month,
                              isToday: DateUtils.isSameDay(day, DateTime.now()),
                              isSelected:
                                  DateUtils.isSameDay(day, _selectedDate),
                              items: items,
                              onTap: () => setState(() => _selectedDate = day),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const _CalendarLegend(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _AgendaSection(
                  date: _selectedDate,
                  items: dayItems,
                ),
                const SizedBox(height: 16),
                _UpcomingSection(items: nextItems),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DateTime> _buildMonthDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysBefore = firstDay.weekday - 1;
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((daysBefore + totalDays) / 7).ceil() * 7;
    final startDay = firstDay.subtract(Duration(days: daysBefore));
    return List.generate(
      totalCells,
      (index) => startDay.add(Duration(days: index)),
    );
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  List<_CalendarItem> _monthItems(AppProvider provider) {
    final start = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final end = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final items = <_CalendarItem>[];
    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      items.addAll(_eventsForDate(day, provider));
    }
    return items;
  }

  List<_CalendarItem> _nextItems(AppProvider provider) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final items = <_CalendarItem>[];
    for (var offset = 0; offset < 14; offset++) {
      items.addAll(_eventsForDate(start.add(Duration(days: offset)), provider));
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    return items.take(5).toList();
  }

  List<_CalendarItem> _eventsForDate(DateTime date, AppProvider provider) {
    final normalized = DateTime(date.year, date.month, date.day);
    final items = <_CalendarItem>[];

    for (final exam in provider.exams) {
      if (DateUtils.isSameDay(exam.date, normalized)) {
        final time = exam.startTime.trim();
        items.add(
          _CalendarItem(
            title: provider.subjectNameForExam(exam),
            subtitle: [
              exam.displayType,
              if (time.isNotEmpty) time,
              if (exam.classroom.trim().isNotEmpty) 'Aula ${exam.classroom}',
            ].join(' · '),
            type: CalendarItemType.exam,
            color: exam.isFinal ? FocusPalette.softAlert : FocusPalette.action,
            date: normalized,
          ),
        );
      }
    }

    for (final task in provider.studyTasks) {
      if (!task.isDone && DateUtils.isSameDay(task.dueDate, normalized)) {
        final subject = provider.getSubjectById(task.subjectId);
        items.add(
          _CalendarItem(
            title: task.title,
            subtitle: [
              task.priorityLabel,
              if (subject != null) subject.name,
              task.statusLabel,
            ].join(' · '),
            type: CalendarItemType.task,
            color: task.isOverdue ? FocusPalette.error : FocusPalette.softAlert,
            date: normalized,
          ),
        );
      }
    }

    final weekday = normalized.weekday - 1;
    for (final schedule
        in provider.schedules.where((item) => item.dayOfWeek == weekday)) {
      final subject = provider.getSubjectById(schedule.subjectId);
      items.add(
        _CalendarItem(
          title: subject?.name ?? 'Clase',
          subtitle: '${schedule.startTime} a ${schedule.endTime}',
          type: CalendarItemType.classBlock,
          color: colorFromHex(subject?.color ?? '#10B981'),
          date: normalized,
        ),
      );
    }

    final dateKey = normalized.toIso8601String().split('T')[0];
    for (final habit in provider.habits) {
      final completed = habit.history.contains(dateKey);
      if (completed || DateUtils.isSameDay(normalized, DateTime.now())) {
        items.add(
          _CalendarItem(
            title: habit.name,
            subtitle: completed ? 'Hábito completado' : 'Hábito pendiente',
            type: CalendarItemType.habit,
            color:
                completed ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
            date: normalized,
          ),
        );
      }
    }

    for (final pomodoro in provider.pomodoros) {
      final pomodoroDate = DateTime.tryParse(pomodoro.date);
      if (pomodoroDate != null &&
          DateUtils.isSameDay(pomodoroDate, normalized)) {
        items.add(
          _CalendarItem(
            title: pomodoro.subject,
            subtitle: 'Pomodoro de ${pomodoro.duration} min',
            type: CalendarItemType.pomodoro,
            color: const Color(0xFF0EA5E9),
            date: normalized,
          ),
        );
      }
    }

    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }
}

class _CalendarHero extends StatelessWidget {
  final String monthLabel;
  final int totalEvents;
  final String selectedLabel;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _CalendarHero({
    required this.monthLabel,
    required this.totalEvents,
    required this.selectedLabel,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
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
                      'Agenda académica',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _HeroNavButton(
                  icon: Icons.chevron_left_rounded, onTap: onPrevious),
              const SizedBox(width: 6),
              _HeroNavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(label: '$totalEvents eventos este mes'),
              _HeroPill(label: selectedLabel),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
                ),
                onPressed: onToday,
                icon: const Icon(Icons.today_rounded),
                label: const Text('Hoy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;

  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.13),
      ),
      child: Text(
        label,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  final List<_CalendarItem> items;

  const _MonthSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    int count(CalendarItemType type) =>
        items.where((item) => item.type == type).length;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Exámenes',
            value: count(CalendarItemType.exam).toString(),
            color: FocusPalette.softAlert,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Clases',
            value: count(CalendarItemType.classBlock).toString(),
            color: FocusPalette.calm,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Tareas',
            value: count(CalendarItemType.task).toString(),
            color: FocusPalette.softAlert,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final List<_CalendarItem> items;
  final VoidCallback onTap;

  const _CalendarDayTile({
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasExam = items.any((item) => item.type == CalendarItemType.exam);
    final hasTask = items.any((item) => item.type == CalendarItemType.task);
    final hasClass =
        items.any((item) => item.type == CalendarItemType.classBlock);
    final background = isSelected
        ? colorScheme.primary
        : isToday
            ? colorScheme.primary.withValues(alpha: 0.18)
            : hasExam
                ? FocusPalette.softAlert.withValues(alpha: 0.14)
                : hasTask
                    ? FocusPalette.softAlert.withValues(alpha: 0.12)
                    : hasClass
                        ? FocusPalette.calm.withValues(alpha: 0.14)
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: isCurrentMonth ? 0.24 : 0.1,
                          );
    final textColor = isSelected
        ? Colors.white
        : isToday
            ? colorScheme.primary
            : isCurrentMonth
                ? null
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.55);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: background,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : isToday
                    ? colorScheme.primary
                    : hasExam
                        ? FocusPalette.softAlert.withValues(alpha: 0.5)
                        : hasTask
                            ? FocusPalette.softAlert.withValues(alpha: 0.44)
                            : hasClass
                                ? FocusPalette.calm.withValues(alpha: 0.48)
                                : colorScheme.outlineVariant
                                    .withValues(alpha: 0.18),
          ),
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMark extends StatelessWidget {
  final Color color;

  const _MiniMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(label: 'Examen', color: FocusPalette.softAlert),
        _LegendItem(label: 'Tarea', color: FocusPalette.softAlert),
        _LegendItem(label: 'Clase', color: FocusPalette.calm),
        _LegendItem(label: 'Hoy / seleccionado', color: FocusPalette.primary),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniMark(color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _AgendaSection extends StatelessWidget {
  final DateTime date;
  final List<_CalendarItem> items;

  const _AgendaSection({
    required this.date,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agenda del día',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(formatDate(date)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Icon(Icons.event_available_rounded, size: 42),
                  const SizedBox(height: 10),
                  Text(
                    'Nada programado para este día',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cuando tengas clases, exámenes, tareas, hábitos o pomodoros, aparecerán reunidos aquí.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...items.map((item) => _AgendaCard(item: item)),
      ],
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  final List<_CalendarItem> items;

  const _UpcomingSection({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Próximos 14 días',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => _AgendaCard(item: item, compactDate: true)),
      ],
    );
  }
}

class _HeroNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroNavButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;

  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final _CalendarItem item;
  final bool compactDate;

  const _AgendaCard({
    required this.item,
    this.compactDate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 56,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.subtitle),
                  if (compactDate) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatDate(item.date),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(color: item.color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

enum CalendarItemType { exam, task, classBlock, habit, pomodoro }

class _CalendarItem {
  final String title;
  final String subtitle;
  final CalendarItemType type;
  final Color color;
  final DateTime date;

  const _CalendarItem({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.color,
    required this.date,
  });

  int get priority {
    return switch (type) {
      CalendarItemType.exam => 0,
      CalendarItemType.task => 1,
      CalendarItemType.classBlock => 2,
      CalendarItemType.habit => 3,
      CalendarItemType.pomodoro => 4,
    };
  }

  String get label {
    return switch (type) {
      CalendarItemType.exam => 'EXAMEN',
      CalendarItemType.task => 'TAREA',
      CalendarItemType.classBlock => 'CLASE',
      CalendarItemType.habit => 'HÁBITO',
      CalendarItemType.pomodoro => 'FOCUS',
    };
  }
}
