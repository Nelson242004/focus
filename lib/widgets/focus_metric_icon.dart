import 'package:flutter/material.dart';

import '../utils/focus_icon_assets.dart';

enum FocusMetricIconKind { points, streak }

class FocusMetricIcon extends StatelessWidget {
  static const pointsAsset = FocusIconAssets.points;
  static const streakAsset = FocusIconAssets.streak;

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
    switch (kind) {
      case FocusMetricIconKind.points:
        return Image.asset(
          pointsAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      case FocusMetricIconKind.streak:
        return Image.asset(
          streakAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
    }
  }
}
