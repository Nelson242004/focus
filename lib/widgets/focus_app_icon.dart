import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    return Icon(
      _iconFor(kind),
      size: size,
      color: fallbackColor ?? Theme.of(context).colorScheme.primary,
    );
  }

  static IconData _iconFor(FocusAppIconKind kind) {
    return switch (kind) {
      FocusAppIconKind.focus => LucideIcons.target,
      FocusAppIconKind.points => LucideIcons.coins,
      FocusAppIconKind.streak => LucideIcons.flame,
      FocusAppIconKind.pomodoro => LucideIcons.timer,
      FocusAppIconKind.subjects => LucideIcons.bookOpen,
      FocusAppIconKind.exams => LucideIcons.clipboardCheck,
      FocusAppIconKind.habits => LucideIcons.listChecks,
      FocusAppIconKind.friends => LucideIcons.users,
      FocusAppIconKind.resources => LucideIcons.folderOpen,
      FocusAppIconKind.achievements => LucideIcons.award,
      FocusAppIconKind.ranking => LucideIcons.trophy,
      FocusAppIconKind.settings => LucideIcons.settings,
      FocusAppIconKind.calendar => LucideIcons.calendarDays,
      FocusAppIconKind.tasks => LucideIcons.squareCheckBig,
      FocusAppIconKind.polytechnic => LucideIcons.graduationCap,
      FocusAppIconKind.permissions => LucideIcons.shieldCheck,
      FocusAppIconKind.help => LucideIcons.circleHelp,
      FocusAppIconKind.profile => LucideIcons.userRound,
      FocusAppIconKind.notifications => LucideIcons.bell,
      FocusAppIconKind.backup => LucideIcons.cloudUpload,
    };
  }
}
