import 'package:flutter/material.dart';

import 'focus_palette.dart';

const List<String> achievementBadgeIds = [
  'first_pomodoro',
  'streak_7',
  'streak_14',
  'streak_30',
  'pomodoros_25',
  'pomodoros_100',
  'weekly_mission',
  'habits_30',
  'habits_75',
  'max_level',
];

class BadgeVisualInfo {
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String asset;

  const BadgeVisualInfo({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.asset,
  });
}

BadgeVisualInfo badgeVisualInfo(String id) {
  return switch (id) {
    'first_pomodoro' => const BadgeVisualInfo(
        label: 'Inicio',
        title: 'Primer impulso',
        subtitle: 'Completa tu primer pomodoro. +50 pts',
        icon: Icons.play_circle_fill_rounded,
        color: FocusPalette.primary,
        asset: 'assets/badges/badge_first_pomodoro.png',
      ),
    'streak_7' => const BadgeVisualInfo(
        label: '7 días',
        title: 'Semana encendida',
        subtitle: 'Alcanza una racha de 7 días. +100 pts',
        icon: Icons.local_fire_department_rounded,
        color: FocusPalette.coral,
        asset: 'assets/badges/badge_streak_7.png',
      ),
    'streak_14' => const BadgeVisualInfo(
        label: '14 días',
        title: 'Racha imparable',
        subtitle: 'Sostén una racha de 14 días. +180 pts',
        icon: Icons.whatshot_rounded,
        color: FocusPalette.danger,
        asset: 'assets/badges/badge_streak_14.png',
      ),
    'streak_30' => const BadgeVisualInfo(
        label: '30 días',
        title: 'Mes de constancia',
        subtitle: 'Llega a una racha de 30 días. +400 pts',
        icon: Icons.local_fire_department_outlined,
        color: FocusPalette.amber,
        asset: 'assets/badges/badge_streak_30.png',
      ),
    'pomodoros_25' => const BadgeVisualInfo(
        label: '25 foco',
        title: 'Cazador de enfoque',
        subtitle: 'Suma 25 pomodoros en total. +150 pts',
        icon: Icons.bolt_rounded,
        color: FocusPalette.cyan,
        asset: 'assets/badges/badge_pomodoros_25.png',
      ),
    'pomodoros_100' => const BadgeVisualInfo(
        label: '100 foco',
        title: 'Cien sesiones',
        subtitle: 'Alcanza 100 pomodoros acumulados. +600 pts',
        icon: Icons.flash_on_rounded,
        color: FocusPalette.primaryDeep,
        asset: 'assets/badges/badge_pomodoros_100.png',
      ),
    'weekly_mission' => const BadgeVisualInfo(
        label: 'Misión',
        title: 'Misión semanal',
        subtitle: 'Completa 10 pomodoros en la misma semana. +120 pts',
        icon: Icons.flag_circle_rounded,
        color: FocusPalette.mint,
        asset: 'assets/badges/badge_weekly_mission.png',
      ),
    'habits_30' => const BadgeVisualInfo(
        label: 'Hábitos',
        title: 'Constancia atómica',
        subtitle: 'Marca 30 hábitos completados. +180 pts',
        icon: Icons.check_circle_rounded,
        color: FocusPalette.teal,
        asset: 'assets/badges/badge_habits_30.png',
      ),
    'habits_75' => const BadgeVisualInfo(
        label: 'Sistema',
        title: 'Sistema sólido',
        subtitle: 'Llega a 75 hábitos completados. +420 pts',
        icon: Icons.inventory_2_rounded,
        color: FocusPalette.mint,
        asset: 'assets/badges/badge_habits_75.png',
      ),
    'max_level' => const BadgeVisualInfo(
        label: 'Nivel max',
        title: 'Nivel máximo',
        subtitle: 'Llega al nivel 5. +500 pts',
        icon: Icons.diamond_rounded,
        color: FocusPalette.amber,
        asset: 'assets/badges/badge_max_level.png',
      ),
    _ => const BadgeVisualInfo(
        label: 'Logro',
        title: 'Logro Focus',
        subtitle: 'Insignia desbloqueada en Focus.',
        icon: Icons.military_tech_rounded,
        color: FocusPalette.primary,
        asset: 'assets/badges/badge_focus.png',
      ),
  };
}

String badgeAssetPath(String id) => badgeVisualInfo(id).asset;

