import 'package:flutter/material.dart';

import 'focus_app_icon.dart';

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
        return FocusAppIcon(
          kind: FocusAppIconKind.points,
          size: size,
          fallback: Icons.stars_rounded,
          fallbackColor: iconColor,
        );
      case FocusMetricIconKind.streak:
        return FocusAppIcon(
          kind: FocusAppIconKind.streak,
          size: size,
          fallback: Icons.local_fire_department_rounded,
          fallbackColor: iconColor,
        );
    }
  }
}
