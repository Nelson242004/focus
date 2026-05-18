import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/schedule.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../widgets/focus_help_button.dart';

class WeeklyScheduleScreen extends StatelessWidget {
  const WeeklyScheduleScreen({super.key});

  static const _weekdays = [0, 1, 2, 3, 4];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario semanal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePdf(context),
          ),
          const FocusHelpAction(
            title: 'Ayuda de horario semanal',
            message:
                'Esta vista junta tus bloques de lunes a viernes para que revises rapido la distribucion de clases.',
            sections: [
              FocusHelpSection(
                title: 'Que muestra',
                items: [
                  'Solo aparecen horarios registrados de materias.',
                  'La tabla se arma segun tu primer bloque y tu ultimo bloque del dia.',
                ],
              ),
              FocusHelpSection(
                title: 'Extra',
                items: [
                  'El icono PDF exporta esta vista para compartirla o guardarla fuera de la app.',
                ],
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final schedules = provider.schedules
              .where((schedule) => _weekdays.contains(schedule.dayOfWeek))
              .toList()
            ..sort((a, b) {
              final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
              if (byDay != 0) return byDay;
              return a.startTime.compareTo(b.startTime);
            });

          if (provider.subjects.isEmpty || schedules.isEmpty) {
            return const Center(
                child: Text('No hay horarios registrados de lunes a viernes.'));
          }

          final slots = _buildTimeSlots(schedules);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calendario de materias',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                    'Vista semanal de lunes a viernes con todos los bloques registrados.'),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(86),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.blue.shade50),
                        children: [
                          _headerCell('Hora'),
                          ..._weekdays
                              .map((day) => _headerCell(weekdayLabel(day))),
                        ],
                      ),
                      ...slots.map((slot) {
                        return TableRow(
                          children: [
                            _timeCell(slot),
                            ..._weekdays.map((day) =>
                                _slotCell(provider, schedules, day, slot)),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<String> _buildTimeSlots(List<Schedule> schedules) {
    var minHour = 23;
    var maxHour = 0;

    for (final schedule in schedules) {
      final startMinutes = timeToMinutes(schedule.startTime);
      final endMinutes = timeToMinutes(schedule.endTime);
      if (startMinutes < 0 || endMinutes < 0) continue;
      final startHour = startMinutes ~/ 60;
      final endHour = ((endMinutes - 1) ~/ 60) + 1;
      if (startHour < minHour) minHour = startHour;
      if (endHour > maxHour) maxHour = endHour;
    }

    if (minHour > maxHour) {
      minHour = 8;
      maxHour = 18;
    }

    return List.generate(maxHour - minHour, (index) {
      final hour = minHour + index;
      return '${hour.toString().padLeft(2, '0')}:00';
    });
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _timeCell(String slot) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.grey.shade50,
      child: Text(
        slot,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _slotCell(AppProvider provider, List<Schedule> schedules,
      int dayOfWeek, String slot) {
    final startMinutes = timeToMinutes(slot);
    final endMinutes = startMinutes + 60;
    final matching = schedules.where((schedule) {
      if (schedule.dayOfWeek != dayOfWeek) return false;
      final scheduleStart = timeToMinutes(schedule.startTime);
      final scheduleEnd = timeToMinutes(schedule.endTime);
      return scheduleStart < endMinutes && scheduleEnd > startMinutes;
    }).toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 92, minWidth: 150),
      padding: const EdgeInsets.all(8),
      child: matching.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: matching.map((schedule) {
                final subject = provider.getSubjectById(schedule.subjectId);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorFromHex(subject?.color ?? '#3b82f6')
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: colorFromHex(subject?.color ?? '#3b82f6')),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject?.name ?? 'Materia',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('${schedule.startTime} - ${schedule.endTime}'),
                      Text('Aula ${schedule.classroom}'),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final schedules = provider.schedules
        .where((schedule) => _weekdays.contains(schedule.dayOfWeek))
        .toList()
      ..sort((a, b) {
        final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (byDay != 0) return byDay;
        return a.startTime.compareTo(b.startTime);
      });

    if (provider.subjects.isEmpty || schedules.isEmpty) return;

    final slots = _buildTimeSlots(schedules);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Horario semanal de materias',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Hora', bold: true),
                  ..._weekdays
                      .map((day) => _pdfCell(weekdayLabel(day), bold: true)),
                ],
              ),
              ...slots.map((slot) {
                final startMinutes = timeToMinutes(slot);
                final endMinutes = startMinutes + 60;
                return pw.TableRow(
                  children: [
                    _pdfCell(slot, bold: true),
                    ..._weekdays.map((day) {
                      final matching = schedules.where((schedule) {
                        if (schedule.dayOfWeek != day) return false;
                        final scheduleStart = timeToMinutes(schedule.startTime);
                        final scheduleEnd = timeToMinutes(schedule.endTime);
                        return scheduleStart < endMinutes &&
                            scheduleEnd > startMinutes;
                      }).toList();

                      final content = matching.map((schedule) {
                        final subject =
                            provider.getSubjectById(schedule.subjectId);
                        return '${subject?.name ?? 'Materia'}\n${schedule.startTime} - ${schedule.endTime}\nAula ${schedule.classroom}';
                      }).join('\n\n');

                      return _pdfCell(content);
                    }),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'horario_lunes_a_viernes_$date.pdf');
  }

  pw.Widget _pdfCell(String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        value,
        style: bold
            ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
            : const pw.TextStyle(fontSize: 9),
      ),
    );
  }
}
