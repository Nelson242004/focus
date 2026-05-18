import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum FocusAvatarMood { normal, focused, happy }

const focusAvatarHairColors = <String, Color>{
  'ink': Color(0xFF102033),
  'brown': Color(0xFF7C4A28),
  'blue': Color(0xFF2563EB),
  'teal': Color(0xFF0F766E),
  'rose': Color(0xFFBE185D),
  'violet': Color(0xFF7C3AED),
};

const focusAvatarEyeColors = <String, Color>{
  'night': Color(0xFF111827),
  'blue': Color(0xFF2563EB),
  'green': Color(0xFF16A34A),
  'amber': Color(0xFFD97706),
};

const focusAvatarSkinColors = <String, Color>{
  'sky': Color(0xFF8DE7F4),
  'peach': Color(0xFFF7C7A8),
  'gold': Color(0xFFE0A96D),
  'cocoa': Color(0xFF9A6A4F),
};

const focusAvatarOutfitColors = <String, Color>{
  'informatics': Color(0xFF2563EB),
  'medicine': Color(0xFFEFF6FF),
  'engineering': Color(0xFFF59E0B),
  'law': Color(0xFF1E293B),
  'design': Color(0xFFEC4899),
  'business': Color(0xFF0F766E),
};

class FocusAvatarConfig {
  final bool feminine;
  final String hair;
  final String hairColor;
  final String eyeColor;
  final String skinTone;
  final String outfit;
  final String accessory;
  final FocusAvatarMood mood;

  const FocusAvatarConfig({
    this.feminine = false,
    this.hair = 'scholar',
    this.hairColor = 'ink',
    this.eyeColor = 'night',
    this.skinTone = 'sky',
    this.outfit = 'informatics',
    this.accessory = 'book',
    this.mood = FocusAvatarMood.normal,
  });

  factory FocusAvatarConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const FocusAvatarConfig();
    return FocusAvatarConfig(
      feminine: map['feminine'] == true,
      hair: '${map['hair'] ?? 'scholar'}',
      hairColor: '${map['hairColor'] ?? 'ink'}',
      eyeColor: '${map['eyeColor'] ?? 'night'}',
      skinTone: '${map['skinTone'] ?? 'sky'}',
      outfit: '${map['outfit'] ?? 'informatics'}',
      accessory: '${map['accessory'] ?? 'book'}',
      mood: _moodFromName('${map['mood'] ?? 'normal'}'),
    );
  }

  factory FocusAvatarConfig.fromProfileIndex(int index) {
    final feminine = index >= 4;
    final normalized = index % 4;
    return switch (normalized) {
      1 => FocusAvatarConfig(
          feminine: feminine,
          hair: 'flame',
          hairColor: feminine ? 'rose' : 'brown',
          eyeColor: 'amber',
          outfit: 'engineering',
          accessory: 'pencil',
          mood: FocusAvatarMood.happy,
        ),
      2 => FocusAvatarConfig(
          feminine: feminine,
          hair: 'calm',
          hairColor: feminine ? 'teal' : 'blue',
          eyeColor: 'green',
          outfit: 'medicine',
          accessory: 'headphones',
          mood: FocusAvatarMood.normal,
        ),
      3 => FocusAvatarConfig(
          feminine: feminine,
          hair: 'champion',
          hairColor: feminine ? 'violet' : 'ink',
          eyeColor: 'blue',
          outfit: 'business',
          accessory: 'trophy',
          mood: FocusAvatarMood.happy,
        ),
      _ => FocusAvatarConfig(
          feminine: feminine,
          hair: 'scholar',
          hairColor: feminine ? 'violet' : 'ink',
          eyeColor: 'night',
          outfit: 'informatics',
          accessory: 'laptop',
          mood: FocusAvatarMood.focused,
        ),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'feminine': feminine,
      'hair': hair,
      'hairColor': hairColor,
      'eyeColor': eyeColor,
      'skinTone': skinTone,
      'outfit': outfit,
      'accessory': accessory,
      'mood': mood.name,
    };
  }

  FocusAvatarConfig copyWith({
    bool? feminine,
    String? hair,
    String? hairColor,
    String? eyeColor,
    String? skinTone,
    String? outfit,
    String? accessory,
    FocusAvatarMood? mood,
  }) {
    return FocusAvatarConfig(
      feminine: feminine ?? this.feminine,
      hair: hair ?? this.hair,
      hairColor: hairColor ?? this.hairColor,
      eyeColor: eyeColor ?? this.eyeColor,
      skinTone: skinTone ?? this.skinTone,
      outfit: outfit ?? this.outfit,
      accessory: accessory ?? this.accessory,
      mood: mood ?? this.mood,
    );
  }

  static FocusAvatarMood _moodFromName(String name) {
    return FocusAvatarMood.values.firstWhere(
      (mood) => mood.name == name,
      orElse: () => FocusAvatarMood.normal,
    );
  }

  String get presetAsset {
    final suffix = feminine ? '_female' : '';
    final preset = switch (hair) {
      'flame' => 'flame',
      'calm' => 'calm',
      'champion' => 'champion',
      _ => 'scholar',
    };
    return 'assets/profile_icons/focus_$preset$suffix.png';
  }
}

class FocusLayeredAvatar extends StatefulWidget {
  final double size;
  final FocusAvatarConfig config;
  final bool animate;

  const FocusLayeredAvatar({
    super.key,
    required this.size,
    required this.config,
    this.animate = true,
  });

  @override
  State<FocusLayeredAvatar> createState() => _FocusLayeredAvatarState();
}

class _FocusLayeredAvatarState extends State<FocusLayeredAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathingController;
  Timer? _blinkTimer;
  bool _blink = false;
  bool _lookLeft = false;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animate) {
      _breathingController.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  @override
  void didUpdateWidget(covariant FocusLayeredAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_breathingController.isAnimating) {
      _breathingController.repeat(reverse: true);
      _scheduleBlink();
    }
    if (!widget.animate && _breathingController.isAnimating) {
      _breathingController.stop();
      _blinkTimer?.cancel();
      setState(() {
        _blink = false;
        _lookLeft = false;
      });
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathingController.dispose();
    super.dispose();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(const Duration(milliseconds: 2800), () async {
      if (!mounted || !widget.animate) return;
      setState(() => _blink = true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() {
        _blink = false;
        _lookLeft = !_lookLeft;
      });
      _scheduleBlink();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        final breathe =
            widget.animate ? 1 + (_breathingController.value * 0.012) : 1.0;
        return Transform.scale(scale: breathe, child: child);
      },
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                widget.config.presetAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FocusAvatarPresetOverlayPainter(
                    config: widget.config,
                    blink: _blink,
                    lookLeft: _lookLeft,
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

class _FocusAvatarPresetOverlayPainter extends CustomPainter {
  final FocusAvatarConfig config;
  final bool blink;
  final bool lookLeft;

  const _FocusAvatarPresetOverlayPainter({
    required this.config,
    required this.blink,
    required this.lookLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512;
    canvas.scale(s);
    _drawMoodSpark(canvas);
    _drawCareerBadge(canvas);
  }

  void _drawMoodSpark(Canvas canvas) {
    final color = switch (config.mood) {
      FocusAvatarMood.happy => const Color(0xFFFFD166),
      FocusAvatarMood.focused => const Color(0xFF38BDF8),
      FocusAvatarMood.normal => const Color(0xFF22C55E),
    };
    final paint = Paint()..color = color.withValues(alpha: blink ? 0.38 : 0.62);
    final x = lookLeft ? 126.0 : 386.0;
    _drawStar(canvas, Offset(x, 92), 16, 7, paint);
    _drawStar(canvas, Offset(x + 28, 128), 9, 4,
        paint..color = color.withValues(alpha: 0.42));
  }

  void _drawCareerBadge(Canvas canvas) {
    final outfitColor = focusAvatarOutfitColors[config.outfit] ??
        focusAvatarOutfitColors['informatics']!;
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(340, 350, 112, 92),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = outfitColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final center = const Offset(396, 396);
    switch (config.accessory) {
      case 'laptop':
        _drawLaptop(canvas, center, outfitColor);
        break;
      case 'headphones':
        _drawHeadphones(canvas, center, outfitColor);
        break;
      case 'pencil':
        _drawPencil(canvas, center, outfitColor);
        break;
      case 'trophy':
        _drawTrophy(canvas, center);
        break;
      default:
        _drawBook(canvas, center, outfitColor);
    }
  }

  void _drawLaptop(Canvas canvas, Offset c, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 58, height: 38),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, -1), width: 42, height: 22),
        const Radius.circular(4),
      ),
      Paint()..color = color,
    );
  }

  void _drawBook(Canvas canvas, Offset c, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 58, height: 58),
        const Radius.circular(9),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawLine(
      c.translate(0, -25),
      c.translate(0, 25),
      Paint()
        ..color = color
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    for (final y in [-14.0, 0.0, 14.0]) {
      canvas.drawLine(
        c.translate(-20, y),
        c.translate(-6, y),
        Paint()
          ..color = const Color(0xFF0F172A).withValues(alpha: 0.36)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawPencil(Canvas canvas, Offset c, Color color) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -34, 18, 68),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFFFFD166),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-9, -34)
        ..lineTo(9, -34)
        ..lineTo(0, -54)
        ..close(),
      Paint()..color = const Color(0xFFE0A96D),
    );
    canvas.drawCircle(const Offset(0, -54), 3, Paint()..color = color);
    canvas.restore();
  }

  void _drawHeadphones(Canvas canvas, Offset c, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, -4), width: 58, height: 48),
      math.pi,
      math.pi,
      false,
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(-30, 8), width: 16, height: 28),
        const Radius.circular(8),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(30, 8), width: 16, height: 28),
        const Radius.circular(8),
      ),
      Paint()..color = color,
    );
  }

  void _drawTrophy(Canvas canvas, Offset c) {
    final gold = Paint()..color = const Color(0xFFFFD166);
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -8), width: 52, height: 44),
        gold);
    canvas.drawRect(
        Rect.fromCenter(center: c.translate(0, 20), width: 12, height: 30),
        Paint()..color = const Color(0xFFF59E0B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, 38), width: 50, height: 18),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFD97706),
    );
  }

  void _drawStar(
      Canvas canvas, Offset center, double outer, double inner, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? outer : inner;
      final p =
          Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FocusAvatarPresetOverlayPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.blink != blink ||
        oldDelegate.lookLeft != lookLeft;
  }
}
