import 'package:flutter/material.dart';

import '../utils/focus_icon_assets.dart';

enum FocusAppIconKind {
  focus,
  points,
  streak,
  pomodoro,
  subjects,
  exams,
  habits,
  friends,
  resources,
  achievements,
  ranking,
  settings,
  calendar,
  tasks,
  polytechnic,
  permissions,
  help,
  profile,
  notifications,
  backup,
}

class FocusAppIcon extends StatelessWidget {
  final FocusAppIconKind kind;
  final double size;
  final IconData fallback;
  final Color? fallbackColor;

  const FocusAppIcon({
    super.key,
    required this.kind,
    this.size = 28,
    this.fallback = Icons.center_focus_strong_rounded,
    this.fallbackColor,
  });

  const FocusAppIcon.points({
    super.key,
    this.size = 28,
    this.fallback = Icons.stars_rounded,
    this.fallbackColor,
  }) : kind = FocusAppIconKind.points;

  const FocusAppIcon.streak({
    super.key,
    this.size = 28,
    this.fallback = Icons.local_fire_department_rounded,
    this.fallbackColor,
  }) : kind = FocusAppIconKind.streak;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetFor(kind),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        fallback,
        size: size,
        color: fallbackColor ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }

  static String _assetFor(FocusAppIconKind kind) {
    return switch (kind) {
      FocusAppIconKind.focus => FocusIconAssets.focus,
      FocusAppIconKind.points => FocusIconAssets.iconPoints,
      FocusAppIconKind.streak => FocusIconAssets.iconStreak,
      FocusAppIconKind.pomodoro => FocusIconAssets.pomodoro,
      FocusAppIconKind.subjects => FocusIconAssets.subjects,
      FocusAppIconKind.exams => FocusIconAssets.exams,
      FocusAppIconKind.habits => FocusIconAssets.habits,
      FocusAppIconKind.friends => FocusIconAssets.friends,
      FocusAppIconKind.resources => FocusIconAssets.resources,
      FocusAppIconKind.achievements => FocusIconAssets.achievements,
      FocusAppIconKind.ranking => FocusIconAssets.ranking,
      FocusAppIconKind.settings => FocusIconAssets.settings,
      FocusAppIconKind.calendar => FocusIconAssets.calendar,
      FocusAppIconKind.tasks => FocusIconAssets.tasks,
      FocusAppIconKind.polytechnic => FocusIconAssets.polytechnic,
      FocusAppIconKind.permissions => FocusIconAssets.permissions,
      FocusAppIconKind.help => FocusIconAssets.help,
      FocusAppIconKind.profile => FocusIconAssets.profile,
      FocusAppIconKind.notifications => FocusIconAssets.notifications,
      FocusAppIconKind.backup => FocusIconAssets.backup,
    };
  }
}
