import 'package:flutter/material.dart';

enum FocusMetricIconKind { points, streak }

class FocusMetricIcon extends StatelessWidget {
  final FocusMetricIconKind kind;
  final double size;
  final Color? color;

  const FocusMetricIcon({
    super.key,
    required this.kind,
    this.size = 22,
    this.color,
  });

  const FocusMetricIcon.points({
    super.key,
    this.size = 22,
    this.color,
  }) : kind = FocusMetricIconKind.points;

  const FocusMetricIcon.streak({
    super.key,
    this.size = 22,
    this.color,
  }) : kind = FocusMetricIconKind.streak;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    switch (kind) {
      case FocusMetricIconKind.points:
        return Icon(Icons.stars_rounded, size: size, color: iconColor);
      case FocusMetricIconKind.streak:
        return Icon(
          Icons.local_fire_department_rounded,
          size: size,
          color: iconColor,
        );
    }
  }
}
