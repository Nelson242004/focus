import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'focus_layered_avatar.dart';
import 'focus_profile_icon_image.dart';

enum FocusMascotState {
  idle,
  studying,
  pomodoro,
  rest,
  celebrating,
  worried,
  exam,
  ranking,
  shield,
}

class FocusProfileMascot extends StatefulWidget {
  final double size;
  final FocusMascotState state;
  final FocusAvatarConfig fallbackConfig;
  final String? profileIconAsset;
  final bool animate;

  const FocusProfileMascot({
    super.key,
    required this.size,
    required this.fallbackConfig,
    this.profileIconAsset,
    this.state = FocusMascotState.idle,
    this.animate = true,
  });

  @override
  State<FocusProfileMascot> createState() => _FocusProfileMascotState();
}

class _FocusProfileMascotState extends State<FocusProfileMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fallbackController;

  @override
  void initState() {
    super.initState();
    _fallbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.animate) {
      _fallbackController.repeat();
    }
  }

  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FocusProfileMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_fallbackController.isAnimating) {
      _fallbackController.repeat();
    } else if (!widget.animate && _fallbackController.isAnimating) {
      _fallbackController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _fallback();
  }

  Widget _fallback({double opacity = 1}) {
    return Opacity(
      opacity: opacity,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _fallbackController,
          builder: (context, _) {
            final config = _fallbackConfigForState();
            final asset = widget.profileIconAsset ?? config.presetAsset;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: FocusProfileIconImage(
                asset: asset,
                key: ValueKey(asset),
                width: widget.size * 0.94,
                height: widget.size * 0.94,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            );
          },
        ),
      ),
    );
  }

  FocusAvatarConfig _fallbackConfigForState() {
    final mood = switch (widget.state) {
      FocusMascotState.celebrating ||
      FocusMascotState.ranking =>
        FocusAvatarMood.happy,
      FocusMascotState.pomodoro ||
      FocusMascotState.studying ||
      FocusMascotState.exam ||
      FocusMascotState.shield =>
        FocusAvatarMood.focused,
      FocusMascotState.worried => FocusAvatarMood.focused,
      FocusMascotState.rest || FocusMascotState.idle => FocusAvatarMood.normal,
    };
    final accessory = switch (widget.state) {
      FocusMascotState.pomodoro || FocusMascotState.studying => 'laptop',
      FocusMascotState.rest => 'headphones',
      FocusMascotState.celebrating || FocusMascotState.ranking => 'trophy',
      FocusMascotState.exam => 'pencil',
      FocusMascotState.shield || FocusMascotState.worried => 'book',
      FocusMascotState.idle => widget.fallbackConfig.accessory,
    };
    return widget.fallbackConfig.copyWith(mood: mood, accessory: accessory);
  }
}

// ignore: unused_element
class _ProfileIconMascotEffectsPainter extends CustomPainter {
  final FocusAvatarConfig config;
  final FocusMascotState state;
  final double progress;

  const _ProfileIconMascotEffectsPainter({
    required this.config,
    required this.state,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = math.sin(progress * math.pi * 2);
    final color = _stateColor();

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.86),
        width: size.width * 0.58,
        height: size.height * 0.12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    canvas.drawCircle(
      center,
      size.shortestSide * (0.43 + pulse * 0.018),
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    if (state == FocusMascotState.pomodoro ||
        state == FocusMascotState.shield) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.shortestSide * 0.45),
        -math.pi / 2,
        math.pi * 1.45 + pulse * 0.35,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.022
          ..strokeCap = StrokeCap.round,
      );
    }

    if (state == FocusMascotState.celebrating ||
        state == FocusMascotState.ranking) {
      for (var i = 0; i < 8; i++) {
        final angle = progress * math.pi * 2 + i * math.pi / 4;
        final radius = size.shortestSide * (0.34 + (i % 2) * 0.08);
        _drawSpark(
          canvas,
          Offset(
            center.dx + math.cos(angle) * radius,
            center.dy + math.sin(angle) * radius,
          ),
          size.shortestSide * 0.025,
          i.isEven ? const Color(0xFFFFD166) : const Color(0xFF38BDF8),
        );
      }
    }
  }

  Color _stateColor() {
    return switch (state) {
      FocusMascotState.rest => const Color(0xFF22C55E),
      FocusMascotState.celebrating ||
      FocusMascotState.ranking =>
        const Color(0xFFF59E0B),
      FocusMascotState.exam ||
      FocusMascotState.worried =>
        const Color(0xFFFF6B6B),
      FocusMascotState.shield => const Color(0xFF38BDF8),
      _ => const Color(0xFF2563EB),
    };
  }

  void _drawSpark(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.36, center.dy - radius * 0.36)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * 0.36, center.dy + radius * 0.36)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.36, center.dy + radius * 0.36)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * 0.36, center.dy - radius * 0.36)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant _ProfileIconMascotEffectsPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.state != state ||
        oldDelegate.progress != progress;
  }
}

// ignore: unused_element
class _ProfileIconMascotOverlayPainter extends CustomPainter {
  final FocusAvatarConfig config;
  final FocusMascotState state;
  final double progress;

  const _ProfileIconMascotOverlayPainter({
    required this.config,
    required this.state,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (state == FocusMascotState.idle) return;

    final color = switch (state) {
      FocusMascotState.rest => const Color(0xFF22C55E),
      FocusMascotState.exam ||
      FocusMascotState.worried =>
        const Color(0xFFFF6B6B),
      FocusMascotState.celebrating ||
      FocusMascotState.ranking =>
        const Color(0xFFF59E0B),
      FocusMascotState.shield => const Color(0xFF38BDF8),
      _ => const Color(0xFF2563EB),
    };

    _drawStateChip(canvas, size, color);
    if (state == FocusMascotState.shield) {
      _drawShield(canvas, size);
    } else if (state == FocusMascotState.rest) {
      _drawSleepBubble(canvas, size);
    } else if (state == FocusMascotState.exam) {
      _drawExamBadge(canvas, size);
    }
  }

  void _drawStateChip(Canvas canvas, Size size, Color color) {
    final icon = switch (state) {
      FocusMascotState.rest => Icons.bedtime_rounded,
      FocusMascotState.celebrating => Icons.auto_awesome_rounded,
      FocusMascotState.ranking => Icons.emoji_events_rounded,
      FocusMascotState.worried => Icons.priority_high_rounded,
      FocusMascotState.exam => Icons.edit_note_rounded,
      FocusMascotState.shield => Icons.shield_rounded,
      FocusMascotState.pomodoro => Icons.timer_rounded,
      FocusMascotState.studying => Icons.menu_book_rounded,
      FocusMascotState.idle => Icons.bolt_rounded,
    };
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.68,
        size.height * 0.68,
        size.width * 0.22,
        size.height * 0.22,
      ),
      Radius.circular(size.shortestSide * 0.06),
    );
    canvas.drawRRect(
      rect.shift(Offset(0, size.height * 0.018)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withValues(alpha: 0.82)],
        ).createShader(rect.outerRect),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: const Color(0xFF102033),
          fontSize: size.shortestSide * 0.12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        rect.outerRect.center.dx - painter.width / 2,
        rect.outerRect.center.dy - painter.height / 2,
      ),
    );
  }

  void _drawShield(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.52);
    final radius = size.shortestSide * (0.43 + math.sin(progress * 6) * 0.01);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.025,
    );
  }

  void _drawSleepBubble(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Zz',
        style: TextStyle(
          color: const Color(0xFF22C55E).withValues(alpha: 0.82),
          fontWeight: FontWeight.w900,
          fontSize: size.shortestSide * 0.12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(size.width * 0.18, size.height * 0.14),
    );
  }

  void _drawExamBadge(Canvas canvas, Size size) {
    final firstPaint = Paint()..color = const Color(0xFFFFD166);
    canvas.drawCircle(
      Offset(size.width * 0.23, size.height * 0.76),
      size.shortestSide * 0.048,
      firstPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.26, size.height * 0.72),
      size.shortestSide * 0.022,
      Paint()..color = const Color(0xFFFF6B6B),
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileIconMascotOverlayPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.state != state ||
        oldDelegate.progress != progress;
  }
}
