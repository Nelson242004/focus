import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_drawer.dart';
import '../widgets/focus_empty_state.dart';
import '../widgets/focus_help_button.dart';
import '../widgets/time_picker_field.dart';
import 'subjects_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final _classroomController = TextEditingController();
  int? _selectedSubjectId;
  String _selectedExamType = 'all';
  String _dialogExamType = 'partial';
  String _selectedTime = '';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  late DateTime _focusedMonth;
  late DateTime _selectedCalendarDate;
  Exam? _editingExam;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedCalendarDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _classroomController.dispose();
    super.dispose();
  }

  Future<void> _showExamDialog({Exam? exam}) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    _editingExam = exam;
    _classroomController.text = exam?.classroom ?? '';
    _selectedTime = exam?.startTime ?? '';
    _selectedDate = exam?.date ?? DateTime.now().add(const Duration(days: 1));
    _selectedSubjectId = exam?.subjectId ?? provider.subjects.firstOrNull?.id;
    _dialogExamType = exam?.examType ?? 'partial';
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(exam == null ? 'Nuevo examen' : 'Editar examen'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'partial', label: Text('Parcial')),
                      ButtonSegment(value: 'final', label: Text('Final')),
                    ],
                    selected: {_dialogExamType},
                    onSelectionChanged: (value) =>
                        setDialogState(() => _dialogExamType = value.first),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSubjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Materia'),
                    items: provider.subjects
                        .map(
                          (subject) => DropdownMenuItem(
                            value: subject.id,
                            child: Text(
                              subject.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => _selectedSubjectId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona una materia.' : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha'),
                    subtitle: Text(formatDate(_selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: _selectedDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (date != null) {
                        setDialogState(() => _selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TimePickerField(
                          label: 'Hora (opcional)',
                          value: _selectedTime,
                          onChanged: (value) =>
                              setDialogState(() => _selectedTime = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Quitar hora',
                        onPressed: () =>
                            setDialogState(() => _selectedTime = ''),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _classroomController,
                    decoration:
                        const InputDecoration(labelText: 'Aula (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Solo la materia y la fecha son obligatorias. Si luego tienes más datos, puedes completarlos.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (_selectedTime.trim().isNotEmpty &&
                    !isValidTime(_selectedTime)) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: FocusActionSnackContent(
                        icon: Icons.access_time_rounded,
                        message: 'Usa un horario válido en formato HH:MM.',
                        color: FocusPalette.amber,
                      ),
                    ),
                  );
                  return;
                }
                final subject = provider.getSubjectById(_selectedSubjectId);
                if (subject == null) return;
                final duplicate = provider.exams.any((item) {
                  if (_editingExam?.id != null && item.id == _editingExam!.id) {
                    return false;
                  }
                  return item.subjectId == subject.id &&
                      item.examType == _dialogExamType &&
                      DateUtils.isSameDay(item.date, _selectedDate);
                });
                if (duplicate) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: FocusActionSnackContent(
                        icon: Icons.warning_amber_rounded,
                        message:
                            'Ya existe un examen de ese tipo para esa materia y fecha.',
                        color: FocusPalette.amber,
                      ),
                    ),
                  );
                  return;
                }
                final examToSave = Exam(
                  id: _editingExam?.id,
                  subject: subject.name,
                  subjectId: subject.id,
                  examType: _dialogExamType,
                  date: _selectedDate,
                  startTime: _selectedTime,
                  classroom: _classroomController.text.trim(),
                );
                try {
                  if (_editingExam == null) {
                    await provider.addExam(examToSave);
                  } else {
                    await provider.updateExam(examToSave);
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: FocusActionSnackContent(
                        icon: _editingExam == null
                            ? Icons.assignment_late_rounded
                            : Icons.check_circle_rounded,
                        message: _editingExam == null
                            ? 'Examen guardado.'
                            : 'Examen actualizado.',
                        color: FocusPalette.mint,
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: FocusActionSnackContent(
                        icon: Icons.error_outline_rounded,
                        message:
                            error.toString().replaceFirst('Bad state: ', ''),
                        color: FocusPalette.danger,
                      ),
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExam(int id) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar examen'),
        content: const Text('Esta acción eliminará el examen de la lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await provider.deleteExam(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: FocusActionSnackContent(
            icon: Icons.delete_rounded,
            message: 'Examen eliminado.',
            color: FocusPalette.danger,
          ),
        ),
      );
    }
  }

  List<Exam> _filteredExams(AppProvider provider) {
    final filtered = _selectedExamType == 'all'
        ? [...provider.exams]
        : provider.exams
            .where((exam) => exam.examType == _selectedExamType)
            .toList();
    filtered.sort((a, b) {
      final aMoment = combineDateAndTime(a.date, a.startTime);
      final bMoment = combineDateAndTime(b.date, b.startTime);
      final now = DateTime.now();
      final aUpcoming = !aMoment.isBefore(now);
      final bUpcoming = !bMoment.isBefore(now);
      if (aUpcoming != bUpcoming) {
        return aUpcoming ? -1 : 1;
      }
      if (aUpcoming) {
        return aMoment.compareTo(bMoment);
      }
      return bMoment.compareTo(aMoment);
    });
    return filtered;
  }

  String _countdownLabel(Exam exam) {
    final examMoment = combineDateAndTime(exam.date, exam.startTime);
    final days = examMoment.difference(DateTime.now()).inDays;
    if (days < 0) return 'Ya pasó';
    if (days == 0) return 'Es hoy';
    if (days == 1) return 'Falta 1 día';
    return 'Faltan $days días';
  }

  Exam? _nextUpcomingExam(List<Exam> exams) {
    for (final exam in exams) {
      final moment = combineDateAndTime(exam.date, exam.startTime);
      if (!moment.isBefore(DateTime.now())) return exam;
    }
    return null;
  }

  List<DateTime> _buildMonthDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysBefore = firstDay.weekday - 1;
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((daysBefore + totalDays) / 7).ceil() * 7;
    final startDay = firstDay.subtract(Duration(days: daysBefore));
    return List.generate(
        totalCells, (index) => startDay.add(Duration(days: index)));
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

  List<Exam> _examsForDate(List<Exam> exams, DateTime date) {
    return exams.where((exam) => DateUtils.isSameDay(exam.date, date)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'exams'),
      appBar: AppBar(
        title: const Text('Exámenes'),
        actions: const [
          FocusHelpAction(
            title: 'Ayuda de exámenes',
            message:
                'Aquí ves lo próximo, tu calendario y los parciales o finales de cada materia.',
            sections: [
              FocusHelpSection(
                title: 'Datos importantes',
                items: [
                  'Solo la materia y la fecha son obligatorias.',
                  'La hora y el aula pueden completarse después.',
                  'No se permiten duplicados del mismo tipo para una materia en la misma fecha.',
                ],
              ),
              FocusHelpSection(
                title: 'Uso rápido',
                items: [
                  'El boton inferior crea un examen nuevo.',
                  'El calendario te ayuda a detectar semanas cargadas sin meter demasiado texto en pantalla.',
                ],
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            if (provider.subjects.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FocusProfileEmptyState(
                    icon: Icons.assignment_late_rounded,
                    accent: FocusPalette.softAlert,
                    title: 'Primero crea una materia',
                    message: 'Los exámenes necesitan una materia.',
                  ),
                ),
              );
            }

            final exams = _filteredExams(provider);
            final nextExam = _nextUpcomingExam(exams);
            final monthDays = _buildMonthDays(_focusedMonth);
            final selectedDayExams =
                _examsForDate(exams, _selectedCalendarDate);

            return ListView(
              padding: const EdgeInsets.only(bottom: 36),
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: LinearGradient(
                              colors: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const [Color(0xFF0F172A), Color(0xFF312E81)]
                                  : const [
                                      Color(0xFFF8FAFC),
                                      Color(0xFFEDE9FE)
                                    ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: FocusPalette.softAlert
                                      .withValues(alpha: 0.14),
                                ),
                                child: const Icon(
                                  Icons.assignment_late_rounded,
                                  color: FocusPalette.softAlert,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nextExam == null
                                          ? 'Sin exámenes'
                                          : _countdownLabel(nextExam),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      nextExam == null
                                          ? 'Agrega tu próximo parcial o final.'
                                          : '${provider.subjectNameForExam(nextExam)} · ${nextExam.displayType} · ${formatDate(nextExam.date)}${nextExam.startTime.trim().isEmpty ? '' : ' · ${nextExam.startTime}'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Calendario de exámenes',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month - 1,
                                );
                              }),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              _monthLabel(_focusedMonth),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month + 1,
                                );
                              }),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: monthDays.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.15,
                          ),
                          itemBuilder: (context, index) {
                            final day = monthDays[index];
                            final isSelected =
                                DateUtils.isSameDay(day, _selectedCalendarDate);
                            final isToday =
                                DateUtils.isSameDay(day, DateTime.now());
                            final isCurrentMonth =
                                day.month == _focusedMonth.month;
                            final dayExams = _examsForDate(exams, day);
                            final hasFinal =
                                dayExams.any((exam) => exam.isFinal);
                            final hasExam = dayExams.isNotEmpty;
                            final colorScheme = Theme.of(context).colorScheme;
                            final accent = hasFinal
                                ? FocusPalette.softAlert
                                : FocusPalette.primary;

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCalendarDate = day),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: isSelected
                                      ? colorScheme.tertiary
                                          .withValues(alpha: 0.2)
                                      : isToday
                                          ? colorScheme.primary
                                              .withValues(alpha: 0.16)
                                          : hasExam
                                              ? accent.withValues(alpha: 0.14)
                                              : colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(
                                                  alpha: isCurrentMonth
                                                      ? 0.24
                                                      : 0.12,
                                                ),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.tertiary
                                        : isToday
                                            ? colorScheme.primary
                                            : hasExam
                                                ? accent
                                                : colorScheme.outlineVariant
                                                    .withValues(
                                                    alpha: isCurrentMonth
                                                        ? 0.2
                                                        : 0.08,
                                                  ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? colorScheme.tertiary
                                          : isToday
                                              ? colorScheme.primary
                                              : hasExam
                                                  ? accent
                                                  : isCurrentMonth
                                                      ? null
                                                      : colorScheme
                                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: selectedDayExams.isEmpty
                              ? FocusInlineState(
                                  key: ValueKey(
                                    'empty-${_selectedCalendarDate.toIso8601String()}',
                                  ),
                                  icon: Icons.event_busy_rounded,
                                  text:
                                      'Sin exámenes el ${formatDate(_selectedCalendarDate)}.',
                                  accent: FocusPalette.amber,
                                )
                              : Column(
                                  key: ValueKey(
                                    'day-${_selectedCalendarDate.toIso8601String()}',
                                  ),
                                  children: selectedDayExams
                                      .map(
                                        (exam) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _ExamCalendarChip(
                                            exam: exam,
                                            subjectName: provider
                                                .subjectNameForExam(exam),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    title: Text(
                      'Exámenes',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${exams.length} visibles'),
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Parciales y finales',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('Todos')),
                            ButtonSegment(
                                value: 'partial', label: Text('Parciales')),
                            ButtonSegment(
                                value: 'final', label: Text('Finales')),
                          ],
                          selected: {_selectedExamType},
                          onSelectionChanged: (value) =>
                              setState(() => _selectedExamType = value.first),
                        ),
                      ),
                      if (exams.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: FocusProfileEmptyState(
                            icon: Icons.event_busy_rounded,
                            accent: FocusPalette.softAlert,
                            title: provider.exams.isEmpty
                                ? 'Carga tu primer examen'
                                : 'Sin resultados',
                            message: provider.exams.isEmpty
                                ? 'Agrega un parcial o final.'
                                : 'Cambia el filtro o crea uno nuevo.',
                          ),
                        )
                      else
                        ...exams.asMap().entries.map((entry) {
                          final index = entry.key;
                          final exam = entry.value;
                          final subjectName = provider.subjectNameForExam(exam);
                          final accent = exam.isFinal
                              ? FocusPalette.softAlert
                              : FocusPalette.primary;
                          final isUpcoming =
                              combineDateAndTime(exam.date, exam.startTime)
                                  .isAfter(DateTime.now());
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(
                              milliseconds: 320 + (index * 90),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) =>
                                Transform.translate(
                              offset: Offset(0, 12 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            color:
                                                accent.withValues(alpha: 0.14),
                                          ),
                                          child: Center(
                                            child: Text(
                                              exam.isFinal ? 'F' : 'P',
                                              style: TextStyle(
                                                color: accent,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subjectName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _countdownLabel(exam),
                                                style: TextStyle(
                                                  color: accent,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Más acciones',
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showExamDialog(exam: exam);
                                            } else if (value == 'delete') {
                                              _deleteExam(exam.id!);
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: ListTile(
                                                leading: Icon(Icons.edit),
                                                title: Text('Editar'),
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: ListTile(
                                                leading: Icon(Icons.delete),
                                                title: Text('Eliminar'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _InfoChip(
                                          label: exam.displayType,
                                          color: accent.withValues(alpha: 0.16),
                                        ),
                                        _InfoChip(label: formatDate(exam.date)),
                                        if (exam.startTime.trim().isNotEmpty)
                                          _InfoChip(label: exam.startTime),
                                        if (exam.classroom.trim().isNotEmpty)
                                          _InfoChip(
                                            label: 'Aula ${exam.classroom}',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isUpcoming
                                          ? _examReminderLabel(provider, exam)
                                          : 'Este examen ya forma parte de tu historial académico.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final hasSubjects = provider.subjects.isNotEmpty;
          return FloatingActionButton.extended(
            onPressed: hasSubjects
                ? () => _showExamDialog()
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubjectsScreen(),
                      ),
                    ),
            icon: const Icon(Icons.add_rounded),
            label: Text(hasSubjects ? 'Examen' : 'Materia'),
          );
        },
      ),
    );
  }

  String _examReminderLabel(AppProvider provider, Exam exam) {
    if (!provider.settings.notificationsEnabled) {
      return 'Recordatorios desactivados desde Configuración.';
    }
    final labels = <String>[
      if (provider.settings.examReminderDayBefore) '1 día antes',
      if (exam.startTime.trim().isNotEmpty &&
          provider.settings.examReminderTwoHoursBefore)
        '2 horas antes',
      if (exam.startTime.trim().isNotEmpty &&
          provider.settings.examReminderThirtyMinutesBefore)
        '30 minutos antes',
    ];
    if (labels.isEmpty) return 'Sin recordatorios activos para este examen.';
    return 'Recordatorios activos: ${labels.join(', ')}.';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _InfoChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
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

class _ExamCalendarChip extends StatelessWidget {
  final Exam exam;
  final String subjectName;

  const _ExamCalendarChip({
    required this.exam,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    final accent = exam.isFinal ? FocusPalette.softAlert : FocusPalette.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent,
            ),
            child: Center(
              child: Text(
                exam.isFinal ? 'F' : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
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
                  subjectName,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    exam.displayType,
                    if (exam.startTime.trim().isNotEmpty) exam.startTime,
                    if (exam.classroom.trim().isNotEmpty)
                      'Aula ${exam.classroom}',
                  ].join(' · '),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
