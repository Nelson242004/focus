import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../utils/app_utils.dart';

class ProgressShareService {
  static Future<void> shareWeeklyProgress(
    BuildContext context,
    AppProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _buildProgressImage(provider);
      final date = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'image/png',
            name: 'focus_progreso_$date.png',
          ),
        ],
        text: 'Mi progreso de estudio en Focus',
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo compartir el progreso: $error')),
      );
    }
  }

  static Future<Uint8List> _buildProgressImage(AppProvider provider) async {
    const width = 1080.0;
    const height = 1920.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(width, height);

    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF020617),
          Color(0xFF0F172A),
          Color(0xFF0B3B4A),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    _drawGlow(canvas, const Offset(190, 240), 300, const Color(0xFF1D4ED8));
    _drawGlow(canvas, const Offset(930, 520), 230, const Color(0xFF38BDF8));
    _drawGlow(canvas, const Offset(900, 1660), 360, const Color(0xFF14B8A6));

    final iconImage = await _loadUiImage('assets/icon.png');
    _drawHeader(canvas, iconImage);

    final strongestSubject = provider.subjects.isEmpty
        ? null
        : provider.subjects.map((subject) {
            final hours = provider.pomodoros
                .where((pomodoro) => pomodoro.subject == subject.name)
                .fold<double>(
                  0,
                  (sum, pomodoro) => sum + pomodoro.duration / 60,
                );
            return MapEntry(subject.name, hours);
          }).reduce((a, b) => a.value >= b.value ? a : b);

    final cards = [
      _ProgressMetric('Puntos', '${provider.gamifiedPoints}',
          'Tu progreso total dentro de Focus', const Color(0xFF2563EB)),
      _ProgressMetric('Racha', '${provider.currentStreak}',
          'Días seguidos manteniendo constancia', const Color(0xFFEA580C)),
      _ProgressMetric(
          'Horas',
          '${provider.totalFocusHours.toStringAsFixed(1)}h',
          'Tiempo acumulado de estudio',
          const Color(0xFF059669)),
      _ProgressMetric('Semana', '${provider.weeklyPomodoros}',
          'Pomodoros completados esta semana', const Color(0xFF7C3AED)),
    ];

    const left = 64.0;
    const gap = 24.0;
    const top = 356.0;
    const cardWidth = (width - left * 2 - gap) / 2;
    const cardHeight = 220.0;

    for (var index = 0; index < cards.length; index++) {
      final row = index ~/ 2;
      final col = index % 2;
      final rect = Rect.fromLTWH(
        left + col * (cardWidth + gap),
        top + row * (cardHeight + gap),
        cardWidth,
        cardHeight,
      );
      _drawMetricCard(canvas, rect, cards[index]);
    }

    final focusRect = const Rect.fromLTWH(64, 860, 952, 260);
    _drawInsightCard(
      canvas,
      focusRect,
      'Lectura semanal',
      'Llevas ${provider.weeklyFocusHours.toStringAsFixed(1)} horas esta semana y tu mejor materia es ${strongestSubject?.key ?? 'General'}.',
      const Color(0xFF0EA5E9),
    );

    final nextClass = provider.nextScheduleEntry;
    final nextExam = provider.nextUpcomingExam;
    final eventsRect = const Rect.fromLTWH(64, 1150, 952, 398);
    _drawEventsCard(
      canvas,
      eventsRect,
      nextClassTitle: nextClass?.subject.name ?? 'Sin próxima clase',
      nextClassDetail: nextClass == null
          ? 'Carga un horario para verlo aquí.'
          : '${weekdayLabel(nextClass.schedule.dayOfWeek)} · ${nextClass.schedule.startTime} a ${nextClass.schedule.endTime}',
      nextExamTitle: nextExam == null
          ? 'Sin próximo examen'
          : provider.subjectNameForExam(nextExam),
      nextExamDetail: nextExam == null
          ? 'Cuando cargues exámenes aparecerán aquí.'
          : '${nextExam.displayType} · ${formatDate(nextExam.date)} · ${nextExam.startTime}',
    );

    final summaryRect = const Rect.fromLTWH(64, 1584, 952, 180);
    _drawSummaryPill(
      canvas,
      summaryRect,
      'Hecho con Focus · organiza tu semestre y estudia con intención',
    );

    _drawText(
      canvas,
      'Comparte tu avance y sigue construyendo tu mejor semana.',
      const Offset(72, 1798),
      936,
      const TextStyle(
        color: Color(0xFFE2E8F0),
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
      textAlign: TextAlign.center,
    );

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

  static Future<ui.Image> _loadUiImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static void _drawHeader(Canvas canvas, ui.Image iconImage) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(64, 64, 952, 236),
      const Radius.circular(44),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
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
      const Rect.fromLTWH(106, 112, 122, 122),
      const Radius.circular(30),
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
      const Rect.fromLTWH(124, 130, 86, 86),
      Paint()..filterQuality = FilterQuality.high,
    );

    _drawText(
      canvas,
      'FOCUS',
      const Offset(258, 108),
      430,
      const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: 5,
      ),
    );
    _drawText(
      canvas,
      'Progreso semanal',
      const Offset(258, 146),
      540,
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
      'Tu constancia, clara y lista para compartir.',
      const Offset(258, 212),
      560,
      const TextStyle(
        color: Color(0xFFE0F2FE),
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 2,
    );
    _drawText(
      canvas,
      DateFormat('dd/MM/yyyy').format(DateTime.now()),
      const Offset(796, 126),
      180,
      const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w800,
      ),
      textAlign: TextAlign.right,
    );
  }

  static void _drawMetricCard(
      Canvas canvas, Rect rect, _ProgressMetric metric) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(34));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 10)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.38),
    );

    final badgeRect = Rect.fromLTWH(rect.left + 24, rect.top + 20, 72, 72);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(22)),
      Paint()..color = metric.color.withValues(alpha: 0.12),
    );
    _drawText(
      canvas,
      metric.label.characters.first,
      Offset(badgeRect.left + 24, badgeRect.top + 10),
      24,
      TextStyle(
        color: metric.color,
        fontSize: 32,
        fontWeight: FontWeight.w900,
      ),
    );
    _drawText(
      canvas,
      metric.label,
      Offset(rect.left + 24, rect.top + 110),
      rect.width - 48,
      const TextStyle(
        color: Color(0xFF334155),
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 1,
    );
    _drawText(
      canvas,
      metric.value,
      Offset(rect.left + 24, rect.top + 144),
      rect.width - 48,
      const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 56,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
      maxLines: 1,
    );
    _drawText(
      canvas,
      metric.caption,
      Offset(rect.left + 24, rect.top + 194),
      rect.width - 48,
      const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 1,
    );
  }

  static void _drawInsightCard(
    Canvas canvas,
    Rect rect,
    String title,
    String body,
    Color accent,
  ) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(36));
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 24, rect.top + 28, 186, 52),
        const Radius.circular(999),
      ),
      Paint()..color = accent.withValues(alpha: 0.16),
    );
    _drawText(
      canvas,
      title,
      Offset(rect.left + 44, rect.top + 40),
      150,
      TextStyle(
        color: accent,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    );
    _drawText(
      canvas,
      body,
      Offset(rect.left + 28, rect.top + 104),
      rect.width - 56,
      const TextStyle(
        color: Colors.white,
        fontSize: 38,
        fontWeight: FontWeight.w900,
        height: 1.18,
      ),
      maxLines: 4,
    );
  }

  static void _drawEventsCard(
    Canvas canvas,
    Rect rect, {
    required String nextClassTitle,
    required String nextClassDetail,
    required String nextExamTitle,
    required String nextExamDetail,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(36));
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.40),
    );
    _drawEventBlock(
      canvas,
      Rect.fromLTWH(rect.left + 24, rect.top + 26, rect.width - 48, 152),
      'Próxima clase',
      nextClassTitle,
      nextClassDetail,
      const Color(0xFF0EA5E9),
    );
    _drawEventBlock(
      canvas,
      Rect.fromLTWH(rect.left + 24, rect.top + 194, rect.width - 48, 152),
      'Próximo examen',
      nextExamTitle,
      nextExamDetail,
      const Color(0xFF7C3AED),
    );
  }

  static void _drawEventBlock(
    Canvas canvas,
    Rect rect,
    String label,
    String title,
    String detail,
    Color accent,
  ) {
    final card = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    canvas.drawRRect(
      card,
      Paint()..color = const Color(0xFFF8FAFC),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 20, rect.top + 22, 168, 40),
        const Radius.circular(999),
      ),
      Paint()..color = accent.withValues(alpha: 0.14),
    );
    _drawText(
      canvas,
      label,
      Offset(rect.left + 38, rect.top + 30),
      134,
      TextStyle(
        color: accent,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
    _drawText(
      canvas,
      title,
      Offset(rect.left + 20, rect.top + 74),
      rect.width - 40,
      const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 32,
        fontWeight: FontWeight.w900,
        height: 1.1,
      ),
      maxLines: 2,
    );
    _drawText(
      canvas,
      detail,
      Offset(rect.left + 20, rect.top + 118),
      rect.width - 40,
      const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 2,
    );
  }

  static void _drawSummaryPill(Canvas canvas, Rect rect, String text) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(34)),
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(34)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    _drawText(
      canvas,
      text,
      Offset(rect.left + 26, rect.top + 66),
      rect.width - 52,
      const TextStyle(
        color: Colors.white,
        fontSize: 30,
        fontWeight: FontWeight.w900,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
    );
  }

  static void _drawGlow(
      Canvas canvas, Offset center, double radius, Color color) {
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

  static double _drawText(
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
}

class _ProgressMetric {
  final String label;
  final String value;
  final String caption;
  final Color color;

  const _ProgressMetric(this.label, this.value, this.caption, this.color);
}
