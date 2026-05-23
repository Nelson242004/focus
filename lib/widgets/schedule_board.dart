import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/schedule.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import 'focus_design_system.dart';

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
              child: FocusInlineState(
                icon: Icons.schedule_rounded,
                text: 'Agrega horarios para ver esta vista.',
              ),
            ),
          );
        }

        final daySchedules = schedules
            .where((schedule) => schedule.dayOfWeek == _selectedDay)
            .toList();

        return _BoardShell(
          title: widget.title,
          showPdfButton: widget.showPdfButton,
          onShareImageTap: () => shareScheduleImage(context,
              title: widget.title, visibleDays: widget.visibleDays),
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
                          borderRadius:
                              BorderRadius.circular(FocusRadii.control),
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.10)
                              : Colors.transparent,
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
                      ? FocusInlineState(
                          key: ValueKey('empty-$_selectedDay'),
                          icon: Icons.event_busy_rounded,
                          text:
                              'Sin clases para ${weekdayLabel(_selectedDay)}.',
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
  final VoidCallback? onShareImageTap;
  final VoidCallback? onPdfTap;
  final Widget child;

  const _BoardShell({
    required this.title,
    required this.showPdfButton,
    this.onShareImageTap,
    this.onPdfTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: FocusSurfaceCard(
        radius: FocusRadii.panel,
        accent: theme.colorScheme.primary,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (showPdfButton) ...[
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: onShareImageTap,
                        icon: const Icon(Icons.image_rounded, size: 18),
                        label: const Text('PNG'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: onPdfTap,
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 18,
                        ),
                        label: const Text('PDF'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                Text(
                  schedule.classroom.trim().isEmpty
                      ? 'Aula por confirmar'
                      : 'Aula ${schedule.classroom}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> shareScheduleImage(
  BuildContext context, {
  required String title,
  required List<int> visibleDays,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final provider = Provider.of<AppProvider>(context, listen: false);
  final schedules = provider.weeklySchedulesMonToSat
      .where((schedule) => visibleDays.contains(schedule.dayOfWeek))
      .toList()
    ..sort((a, b) {
      final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (byDay != 0) return byDay;
      return a.startTime.compareTo(b.startTime);
    });

  if (schedules.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No hay horarios para compartir.')),
    );
    return;
  }

  try {
    final bytes = await _buildScheduleShareImage(
      title: title,
      visibleDays: visibleDays,
      schedules: schedules,
      provider: provider,
    );
    final date = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'image/png',
          name: 'focus_horario_$date.png',
        ),
      ],
      text: 'Mi horario semanal en Focus',
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('No se pudo compartir la imagen: $error')),
    );
  }
}

Future<Uint8List> _buildScheduleShareImage({
  required String title,
  required List<int> visibleDays,
  required List<Schedule> schedules,
  required AppProvider provider,
}) async {
  const width = 1080.0;
  const height = 1920.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(width, height);

  final bgPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF020617),
        Color(0xFF0F172A),
        Color(0xFF0B3B4A),
      ],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, bgPaint);

  _drawGlow(canvas, const Offset(160, 180), 280, const Color(0xFF2563EB));
  _drawGlow(canvas, const Offset(920, 1520), 360, const Color(0xFF14B8A6));
  _drawGlow(canvas, const Offset(880, 360), 220, const Color(0xFF22C55E));

  final iconImage = await _loadUiImage('assets/icon.png');
  _drawHeader(canvas, iconImage, title);

  _drawText(
    canvas,
    'Tu semana, clara y lista para compartir.',
    const Offset(72, 304),
    936,
    const TextStyle(
      color: Color(0xFFC7D2FE),
      fontSize: 34,
      fontWeight: FontWeight.w700,
    ),
  );

  final days = visibleDays.take(6).toList();
  const left = 64.0;
  const gap = 24.0;
  const top = 356.0;
  const cardWidth = (width - left * 2 - gap) / 2;
  const cardHeight = 424.0;

  for (var index = 0; index < days.length; index++) {
    final day = days[index];
    final row = index ~/ 2;
    final col = index % 2;
    final rect = Rect.fromLTWH(
      left + col * (cardWidth + gap),
      top + row * (cardHeight + gap),
      cardWidth,
      cardHeight,
    );
    final daySchedules =
        schedules.where((schedule) => schedule.dayOfWeek == day).toList();
    _drawDayCard(canvas, rect, day, daySchedules, provider);
  }

  final totalBlocks = schedules.length;
  final totalSubjects = schedules
      .map((schedule) => schedule.subjectId)
      .where((id) => id > 0)
      .toSet()
      .length;
  _drawStats(canvas, totalBlocks, totalSubjects);
  _drawFooter(canvas);

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  iconImage.dispose();
  if (byteData == null) {
    throw StateError('No se pudo generar la imagen.');
  }
  return byteData.buffer.asUint8List();
}

Future<ui.Image> _loadUiImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
}

void _drawHeader(Canvas canvas, ui.Image iconImage, String title) {
  final rect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(64, 64, 952, 208),
    const Radius.circular(44),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF1D4ED8),
          Color(0xFF0F766E),
        ],
      ).createShader(rect.outerRect),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.18),
  );

  final logoRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(104, 106, 118, 118),
    const Radius.circular(28),
  );
  canvas.drawRRect(logoRect, Paint()..color = Colors.white);
  canvas.drawImageRect(
    iconImage,
    Rect.fromLTWH(
      0,
      0,
      iconImage.width.toDouble(),
      iconImage.height.toDouble(),
    ),
    const Rect.fromLTWH(120, 122, 86, 86),
    Paint()..filterQuality = FilterQuality.high,
  );

  _drawText(
    canvas,
    'FOCUS',
    const Offset(250, 108),
    460,
    const TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w900,
      letterSpacing: 5,
    ),
  );
  _drawText(
    canvas,
    title,
    const Offset(250, 148),
    560,
    const TextStyle(
      color: Colors.white,
      fontSize: 54,
      fontWeight: FontWeight.w900,
      height: 1.0,
    ),
    maxLines: 1,
  );
  _drawText(
    canvas,
    DateFormat("dd/MM/yyyy").format(DateTime.now()),
    const Offset(770, 126),
    190,
    const TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w800,
    ),
    textAlign: TextAlign.right,
  );
}

void _drawDayCard(
  Canvas canvas,
  Rect rect,
  int day,
  List<Schedule> schedules,
  AppProvider provider,
) {
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(38));
  canvas.drawRRect(
    rrect.shift(const Offset(0, 10)),
    Paint()..color = Colors.black.withValues(alpha: 0.18),
  );
  canvas.drawRRect(
    rrect,
    Paint()..color = Colors.white.withValues(alpha: 0.94),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.35),
  );

  _drawText(
    canvas,
    weekdayLabel(day).toUpperCase(),
    Offset(rect.left + 28, rect.top + 26),
    rect.width - 56,
    const TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 28,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
    ),
  );

  final countLabel =
      schedules.length == 1 ? '1 bloque' : '${schedules.length} bloques';
  _drawPill(
    canvas,
    Rect.fromLTWH(rect.right - 158, rect.top + 22, 126, 42),
    countLabel,
    const Color(0xFFEFF6FF),
    const Color(0xFF2563EB),
  );

  final availableHeight = rect.bottom - rect.top - 108;
  final maxBlocks = schedules.length > 5 ? 4 : math.min(5, schedules.length);
  final blockGap = schedules.length > 4 ? 8.0 : 12.0;
  final blockHeight = schedules.length > 4
      ? math.min(58.0, (availableHeight - blockGap * (maxBlocks - 1)) / 5)
      : 72.0;
  var y = rect.top + 82;
  for (var i = 0; i < maxBlocks; i++) {
    final schedule = schedules[i];
    final subject = provider.getSubjectById(schedule.subjectId);
    final color = colorFromHex(subject?.color ?? '#2563eb');
    _drawScheduleBlock(
      canvas,
      Rect.fromLTWH(rect.left + 24, y, rect.width - 48, blockHeight),
      subject?.name ?? 'Materia',
      '${schedule.startTime} - ${schedule.endTime}',
      schedule.classroom.trim().isEmpty
          ? 'Aula por confirmar'
          : 'Aula ${schedule.classroom}',
      color,
    );
    y += blockHeight + blockGap;
  }

  if (schedules.isEmpty) {
    _drawText(
      canvas,
      'Sin clases cargadas',
      Offset(rect.left + 24, rect.top + 154),
      rect.width - 48,
      const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      textAlign: TextAlign.center,
    );
  } else if (schedules.length > maxBlocks) {
    _drawOverflowBadge(canvas, rect, schedules.length - maxBlocks);
  }
}

void _drawScheduleBlock(
  Canvas canvas,
  Rect rect,
  String subject,
  String time,
  String classroom,
  Color color,
) {
  final compact = rect.height < 66;
  final dotRadius = compact ? 15.0 : 21.0;
  final titleSize = compact ? 17.0 : 21.0;
  final detailSize = compact ? 14.0 : 18.0;
  final titleTop = compact ? 7.0 : 10.0;
  final detailTop = compact ? 33.0 : 40.0;
  final leftInset = compact ? 60.0 : 72.0;
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(22));
  canvas.drawRRect(
    rrect,
    Paint()..color = const Color(0xFFF8FAFC),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left, rect.top, 8, rect.height),
      const Radius.circular(999),
    ),
    Paint()..color = color,
  );
  canvas.drawCircle(
    Offset(rect.left + 34, rect.top + rect.height / 2),
    dotRadius,
    Paint()..color = color,
  );
  canvas.drawCircle(
    Offset(rect.left + 34, rect.top + rect.height / 2),
    dotRadius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2.0 : 2.6
      ..color = Colors.white.withValues(alpha: 0.72),
  );
  _drawCenteredText(
    canvas,
    _subjectInitial(subject),
    Offset(rect.left + 34, rect.top + rect.height / 2),
    TextStyle(
      color: Colors.white,
      fontSize: compact ? 16 : 21,
      fontWeight: FontWeight.w900,
      height: 1.0,
    ),
  );
  _drawText(
    canvas,
    subject,
    Offset(rect.left + leftInset, rect.top + titleTop),
    rect.width - leftInset - 16,
    TextStyle(
      color: const Color(0xFF0F172A),
      fontSize: titleSize,
      fontWeight: FontWeight.w900,
      height: 1.05,
    ),
    maxLines: 1,
  );
  _drawText(
    canvas,
    '$time  ·  $classroom',
    Offset(rect.left + leftInset, rect.top + detailTop),
    rect.width - leftInset - 16,
    TextStyle(
      color: color,
      fontSize: detailSize,
      fontWeight: FontWeight.w800,
      height: 1.0,
    ),
    maxLines: 1,
  );
}

String _subjectInitial(String subject) {
  final trimmed = subject.trim();
  if (trimmed.isEmpty) return 'M';
  return trimmed.characters.first.toUpperCase();
}

void _drawCenteredText(
  Canvas canvas,
  String text,
  Offset center,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final offset = Offset(
    center.dx - painter.width / 2,
    center.dy - painter.height / 2,
  );
  painter.paint(canvas, offset);
}

void _drawOverflowBadge(Canvas canvas, Rect rect, int extraCount) {
  final badgeRect = Rect.fromLTWH(
    rect.left + 24,
    rect.bottom - 42,
    rect.width - 48,
    30,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(badgeRect, const Radius.circular(999)),
    Paint()..color = const Color(0xFFEFF6FF),
  );
  _drawText(
    canvas,
    '+ $extraCount bloque(s) más',
    Offset(badgeRect.left + 10, badgeRect.top + 6),
    badgeRect.width - 20,
    const TextStyle(
      color: Color(0xFF2563EB),
      fontSize: 16,
      fontWeight: FontWeight.w900,
    ),
    textAlign: TextAlign.center,
    maxLines: 1,
  );
}

void _drawStats(Canvas canvas, int totalBlocks, int totalSubjects) {
  final rect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(64, 1688, 952, 116),
    const Radius.circular(34),
  );
  canvas.drawRRect(
    rect,
    Paint()..color = Colors.white.withValues(alpha: 0.10),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.16),
  );
  _drawStatItem(canvas, const Offset(116, 1715), '$totalBlocks', 'bloques');
  _drawStatItem(canvas, const Offset(390, 1715), '$totalSubjects', 'materias');
  _drawStatItem(canvas, const Offset(688, 1715), 'Focus', 'organiza tu semana');
}

void _drawStatItem(Canvas canvas, Offset offset, String value, String label) {
  _drawText(
    canvas,
    value,
    offset,
    240,
    const TextStyle(
      color: Colors.white,
      fontSize: 34,
      fontWeight: FontWeight.w900,
    ),
    maxLines: 1,
  );
  _drawText(
    canvas,
    label,
    offset.translate(0, 44),
    250,
    const TextStyle(
      color: Color(0xFFCBD5E1),
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
    maxLines: 1,
  );
}

void _drawFooter(Canvas canvas) {
  _drawText(
    canvas,
    'Hecho con Focus · productividad para estudiantes',
    const Offset(64, 1842),
    952,
    const TextStyle(
      color: Color(0xFFE2E8F0),
      fontSize: 26,
      fontWeight: FontWeight.w800,
    ),
    textAlign: TextAlign.center,
  );
}

void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

void _drawPill(
  Canvas canvas,
  Rect rect,
  String text,
  Color background,
  Color foreground,
) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(999)),
    Paint()..color = background,
  );
  _drawText(
    canvas,
    text,
    Offset(rect.left + 8, rect.top + 10),
    rect.width - 16,
    TextStyle(
      color: foreground,
      fontSize: 16,
      fontWeight: FontWeight.w900,
    ),
    textAlign: TextAlign.center,
    maxLines: 1,
  );
}

double _drawText(
  Canvas canvas,
  String text,
  Offset offset,
  double maxWidth,
  TextStyle style, {
  int? maxLines,
  TextAlign textAlign = TextAlign.left,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: textAlign,
    textDirection: ui.TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '...',
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas, offset);
  return painter.height;
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
