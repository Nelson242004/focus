import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/schedule.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';

class ScheduleBoard extends StatefulWidget {
  final String title;
  final List<int> visibleDays;
  final bool showPdfButton;

  const ScheduleBoard({
    super.key,
    required this.title,
    required this.visibleDays,
    this.showPdfButton = true,
  });

  @override
  State<ScheduleBoard> createState() => _ScheduleBoardState();
}

class _ScheduleBoardState extends State<ScheduleBoard> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _resolveInitialDay();
  }

  @override
  void didUpdateWidget(covariant ScheduleBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visibleDays.contains(_selectedDay)) {
      _selectedDay = _resolveInitialDay();
    }
  }

  int _resolveInitialDay() {
    final today = DateTime.now().weekday - 1;
    if (widget.visibleDays.contains(today)) return today;
    return widget.visibleDays.first;
  }

  void _stepDay(int delta) {
    final currentIndex = widget.visibleDays.indexOf(_selectedDay);
    if (currentIndex == -1) return;
    final nextIndex =
        (currentIndex + delta).clamp(0, widget.visibleDays.length - 1);
    if (nextIndex == currentIndex) return;
    setState(() => _selectedDay = widget.visibleDays[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final schedules = provider.weeklySchedulesMonToSat
            .where(
                (schedule) => widget.visibleDays.contains(schedule.dayOfWeek))
            .toList()
          ..sort((a, b) {
            final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (byDay != 0) return byDay;
            return a.startTime.compareTo(b.startTime);
          });

        if (schedules.isEmpty) {
          return _BoardShell(
            title: widget.title,
            showPdfButton: false,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child:
                      Text('Todavía no hay horarios cargados en esta vista.')),
            ),
          );
        }

        final daySchedules = schedules
            .where((schedule) => schedule.dayOfWeek == _selectedDay)
            .toList();

        return _BoardShell(
          title: widget.title,
          showPdfButton: widget.showPdfButton,
          onPdfTap: () => generateSchedulePdf(context,
              title: widget.title, visibleDays: widget.visibleDays),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.visibleDays.map((day) {
                    final selected = day == _selectedDay;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [
                                    Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.18),
                                    Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withValues(alpha: 0.12),
                                  ],
                                )
                              : null,
                          color: selected ? null : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _selectedDay = day),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            child: Text(
                              weekdayLabel(day),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < 120) return;
                  if (velocity < 0) {
                    _stepDay(1);
                  } else {
                    _stepDay(-1);
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: daySchedules.isEmpty
                      ? Container(
                          key: ValueKey('empty-$_selectedDay'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.35),
                          ),
                          child: Text(
                            'No hay clases cargadas para ${weekdayLabel(_selectedDay)}.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          key: ValueKey('day-$_selectedDay'),
                          children: daySchedules
                              .map((schedule) =>
                                  _ScheduleCard(schedule: schedule))
                              .toList(),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BoardShell extends StatelessWidget {
  final String title;
  final bool showPdfButton;
  final VoidCallback? onPdfTap;
  final Widget child;

  const _BoardShell({
    required this.title,
    required this.showPdfButton,
    this.onPdfTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (showPdfButton)
                  FilledButton.icon(
                    onPressed: onPdfTap,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;

  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final subject = provider.getSubjectById(schedule.subjectId);
    final color = colorFromHex(subject?.color ?? '#2563eb');
    final initials = (subject?.name.isNotEmpty ?? false)
        ? subject!.name.characters.first.toUpperCase()
        : 'M';
    final hasOverlap = provider.weeklySchedulesMonToSat.where((other) {
      if (other.id == schedule.id || other.dayOfWeek != schedule.dayOfWeek) {
        return false;
      }
      final start = timeToMinutes(schedule.startTime);
      final end = timeToMinutes(schedule.endTime);
      final otherStart = timeToMinutes(other.startTime);
      final otherEnd = timeToMinutes(other.endTime);
      return start < otherEnd && end > otherStart;
    }).isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color,
            child: Text(
              initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject?.name ?? 'Materia',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (hasOverlap)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.orange.withValues(alpha: 0.14),
                        ),
                        child: const Text(
                          'Superpuesta',
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${schedule.startTime} a ${schedule.endTime}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Aula ${schedule.classroom}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> generateSchedulePdf(
  BuildContext context, {
  required String title,
  required List<int> visibleDays,
}) async {
  final provider = Provider.of<AppProvider>(context, listen: false);
  final schedules = provider.weeklySchedulesMonToSat
      .where((schedule) => visibleDays.contains(schedule.dayOfWeek))
      .toList()
    ..sort((a, b) {
      final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (byDay != 0) return byDay;
      return a.startTime.compareTo(b.startTime);
    });
  if (schedules.isEmpty) return;

  final iconData = await rootBundle.load('assets/icon.png');
  final iconImage = pw.MemoryImage(iconData.buffer.asUint8List());
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _pdfPosterHeader(
            iconImage: iconImage,
            title: 'Materias',
            subtitle: 'Horario académico semanal',
            detail: DateFormat('dd/MM/yyyy').format(DateTime.now()),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _pdfInfoPill('${schedules.length} bloques'),
              pw.SizedBox(width: 8),
              _pdfInfoPill('${visibleDays.length} días visibles'),
              pw.SizedBox(width: 8),
              _pdfInfoPill(title),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: visibleDays.map((day) {
                final daySchedules = schedules
                    .where((schedule) => schedule.dayOfWeek == day)
                    .toList();
                return pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: pw.BorderRadius.circular(14),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFD7E3F4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFDBEAFE),
                            borderRadius: pw.BorderRadius.circular(10),
                          ),
                          child: pw.Text(
                            weekdayLabel(day).toUpperCase(),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColor.fromInt(0xFF1D4ED8),
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 7),
                        if (daySchedules.isEmpty)
                          pw.Text(
                            'Sin clases',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColor.fromInt(0xFF94A3B8),
                              fontSize: 8,
                            ),
                          )
                        else
                          ...daySchedules.map((schedule) {
                            final subject =
                                provider.getSubjectById(schedule.subjectId);
                            return _pdfClassBlock(
                              subject?.name ?? 'Materia',
                              '${schedule.startTime} - ${schedule.endTime}',
                              schedule.classroom.trim().isEmpty
                                  ? 'Aula por confirmar'
                                  : schedule.classroom,
                            );
                          }),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(height: 8),
          _pdfFooter('Generado por Focus · Organiza tu semana con claridad'),
        ],
      ),
    ),
  );

  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  await Printing.sharePdf(
      bytes: await pdf.save(), filename: 'horario_$date.pdf');
}

pw.Widget _pdfPosterHeader({
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
          PdfColor.fromInt(0xFF1D4ED8),
          PdfColor.fromInt(0xFF14B8A6),
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

pw.Widget _pdfInfoPill(String text) {
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

pw.Widget _pdfClassBlock(String subject, String time, String classroom) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.all(7),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          subject,
          maxLines: 2,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF0F172A),
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          time,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF2563EB),
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          classroom,
          maxLines: 1,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF64748B),
            fontSize: 6.5,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfFooter(String text) {
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
