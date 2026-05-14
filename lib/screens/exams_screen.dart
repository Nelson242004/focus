import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/exam.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../widgets/focus_drawer.dart';
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usa un horario válido en formato HH:MM.'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ya existe un examen de ese tipo para esa materia y fecha.',
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
                if (_editingExam == null) {
                  await provider.addExam(examToSave);
                } else {
                  await provider.updateExam(examToSave);
                }
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _editingExam == null
                          ? 'Examen guardado con recordatorios.'
                          : 'Examen actualizado.',
                    ),
                  ),
                );
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
        const SnackBar(content: Text('Examen eliminado.')),
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

  Future<void> _exportExamPdf(AppProvider provider, String type) async {
    final exams = type == 'all'
        ? provider.exams
        : provider.exams.where((exam) => exam.examType == type).toList();
    if (exams.isEmpty) return;
    final title = switch (type) {
      'partial' => 'Exámenes parciales',
      'final' => 'Exámenes finales',
      _ => 'Exámenes parciales y finales',
    };

    final iconData = await rootBundle.load('assets/icon.png');
    final iconImage = pw.MemoryImage(iconData.buffer.asUint8List());
    final sortedExams = [...exams]..sort((a, b) {
        final aMoment = combineDateAndTime(a.date, a.startTime);
        final bMoment = combineDateAndTime(b.date, b.startTime);
        return aMoment.compareTo(bMoment);
      });
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _examPdfPosterHeader(
              iconImage: iconImage,
              title: 'Exámenes',
              subtitle: title,
              detail: DateFormat('dd/MM/yyyy').format(DateTime.now()),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _examPdfInfoPill('${sortedExams.length} evaluaciones'),
                pw.SizedBox(width: 8),
                _examPdfInfoPill('Parciales y finales'),
                pw.SizedBox(width: 8),
                _examPdfInfoPill('Exámenes'),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFD7E3F4),
                  width: 0.7,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(1.1),
                  4: const pw.FlexColumnWidth(1.3),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFDBEAFE),
                    ),
                    children: [
                      _examPdfCell('Materia', bold: true),
                      _examPdfCell('Tipo', bold: true),
                      _examPdfCell('Fecha', bold: true),
                      _examPdfCell('Hora', bold: true),
                      _examPdfCell('Aula', bold: true),
                      _examPdfCell('Cuenta regresiva', bold: true),
                    ],
                  ),
                  ...sortedExams.map((exam) {
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: exam.isFinal
                            ? PdfColor.fromInt(0xFFF5F3FF)
                            : PdfColors.white,
                      ),
                      children: [
                        _examPdfCell(provider.subjectNameForExam(exam)),
                        _examPdfCell(exam.displayType),
                        _examPdfCell(
                            DateFormat('dd/MM/yyyy').format(exam.date)),
                        _examPdfCell(
                          exam.startTime.trim().isEmpty
                              ? 'Sin hora'
                              : exam.startTime,
                        ),
                        _examPdfCell(
                          exam.classroom.trim().isEmpty
                              ? 'Por confirmar'
                              : exam.classroom,
                        ),
                        _examPdfCell(_countdownLabel(exam)),
                      ],
                    );
                  }),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            _examPdfFooter(
              'Generado por Focus · Planifica tus evaluaciones con claridad',
            ),
          ],
        ),
      ),
    );

    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'examenes_${type}_$date.pdf',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF de exámenes listo para compartir.')),
    );
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf),
            onSelected: (value) {
              final provider = Provider.of<AppProvider>(context, listen: false);
              _exportExamPdf(provider, value);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('PDF de todos')),
              PopupMenuItem(value: 'partial', child: Text('PDF de parciales')),
              PopupMenuItem(value: 'final', child: Text('PDF de finales')),
            ],
          ),
          IconButton(
            onPressed: () => _showExamDialog(),
            icon: const Icon(Icons.add),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_late_rounded, size: 52),
                      const SizedBox(height: 12),
                      Text(
                        'Primero crea una materia',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cuando tengas tus materias, podrás registrar parciales y finales con una vista mucho más clara.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubjectsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Crear materia'),
                      ),
                    ],
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
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.14),
                                ),
                                child: const Icon(
                                  Icons.assignment_late_rounded,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nextExam == null
                                          ? 'No tienes exámenes próximos'
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
                                          ? 'Agrega parciales o finales para empezar a seguir tu calendario académico.'
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
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF2563EB);

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
                              ? Container(
                                  key: ValueKey(
                                    'empty-${_selectedCalendarDate.toIso8601String()}',
                                  ),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                  ),
                                  child: Text(
                                    'No hay exámenes para ${formatDate(_selectedCalendarDate)}.',
                                    textAlign: TextAlign.center,
                                  ),
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
                      'Tus exámenes y detalles',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${exams.length} exámenes en este filtro'),
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Gestiona tus parciales y finales',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _showExamDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Nuevo'),
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
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(Icons.event_busy_rounded, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay exámenes en este filtro',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Agrega uno nuevo o cambia el filtro para ver los próximos eventos.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: () => _showExamDialog(),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Agregar examen'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...exams.asMap().entries.map((entry) {
                          final index = entry.key;
                          final exam = entry.value;
                          final subjectName = provider.subjectNameForExam(exam);
                          final accent = exam.isFinal
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF2563EB);
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
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () =>
                                              _showExamDialog(exam: exam),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () =>
                                              _deleteExam(exam.id!),
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
    final accent =
        exam.isFinal ? const Color(0xFF7C3AED) : const Color(0xFF2563EB);
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

pw.Widget _examPdfPosterHeader({
  required pw.MemoryImage iconImage,
  required String title,
  required String subtitle,
  required String detail,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: pw.BoxDecoration(
      gradient: const pw.LinearGradient(
        colors: [
          PdfColor.fromInt(0xFF020617),
          PdfColor.fromInt(0xFF312E81),
          PdfColor.fromInt(0xFF2563EB),
        ],
      ),
      borderRadius: pw.BorderRadius.circular(18),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 42,
              height: 42,
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Image(iconImage),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FOCUS',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    color: PdfColors.white.shade(0.82),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Text(
          detail,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _examPdfInfoPill(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFEFF6FF),
      borderRadius: pw.BorderRadius.circular(999),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFBFDBFE)),
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: PdfColor.fromInt(0xFF1E3A8A),
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _examPdfCell(String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: pw.Text(
      value,
      maxLines: 2,
      style: bold
          ? pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
              color: PdfColor.fromInt(0xFF1E3A8A),
            )
          : pw.TextStyle(
              fontSize: 7.2,
              color: PdfColor.fromInt(0xFF0F172A),
            ),
    ),
  );
}

pw.Widget _examPdfFooter(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF8FAFC),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: 8,
        color: PdfColor.fromInt(0xFF64748B),
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
