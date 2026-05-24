class FocusIconAssets {
  FocusIconAssets._();

  static const goldLeague = 'assets/medals/gold.png';
  static const silverLeague = 'assets/medals/silver.png';
  static const bronzeLeague = 'assets/medals/bronze.png';
  static const points = 'assets/focus_icons/focus_points.png';
  static const streak = 'assets/focus_icons/focus_streak.png';
  static const focus = 'assets/focus_icons/focus_focus.png';
  static const pomodoro = 'assets/focus_icons/focus_pomodoro.png';
  static const subjects = 'assets/focus_icons/focus_subjects.png';
  static const exams = 'assets/focus_icons/focus_exams.png';
  static const habits = 'assets/focus_icons/focus_habits.png';
  static const friends = 'assets/focus_icons/focus_friends.png';
  static const resources = 'assets/focus_icons/focus_resources.png';
  static const achievements = 'assets/focus_icons/focus_achievements.png';
  static const ranking = 'assets/focus_icons/focus_ranking.png';
  static const settings = 'assets/focus_icons/focus_settings.png';
  static const calendar = 'assets/focus_icons/focus_calendar.png';
  static const tasks = 'assets/focus_icons/focus_tasks.png';
  static const polytechnic = 'assets/focus_icons/focus_polytechnic.png';
  static const permissions = 'assets/focus_icons/focus_permissions.png';
  static const help = 'assets/focus_icons/focus_help.png';
  static const profile = 'assets/focus_icons/focus_profile.png';
  static const notifications = 'assets/focus_icons/focus_notifications.png';
  static const backup = 'assets/focus_icons/focus_backup.png';
  static const iconPoints = 'assets/focus_icons/focus_points.png';
  static const iconStreak = 'assets/focus_icons/focus_streak.png';

  static String league(String value) {
    return switch (value.trim().toLowerCase()) {
      'oro' || 'diamante' || 'platino' => goldLeague,
      'plata' => silverLeague,
      _ => bronzeLeague,
    };
  }

  static String leagueByPosition(int position) {
    return switch (position) {
      1 => goldLeague,
      2 => silverLeague,
      3 => bronzeLeague,
      _ => bronzeLeague,
    };
  }
}
