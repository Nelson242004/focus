class FocusIconAssets {
  FocusIconAssets._();

  static const points = 'assets/metrics/focus_points.png';
  static const streak =
      'android/app/src/main/res/drawable-nodpi/focus_streak_fire.png';
  static const achievement = 'assets/badges/badge_focus.png';

  static const goldLeague = 'assets/medals/gold.png';
  static const silverLeague = 'assets/medals/silver.png';
  static const bronzeLeague = 'assets/medals/bronze.png';

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
