enum ThemeModeSetting { light, dark }

class AppSettings {
  ThemeModeSetting themeMode;
  int focusTime;
  int shortBreakTime;
  int longBreakTime;
  int weeklyGoal;
  String sound;
  String selectedIdentity;
  String startScreen;
  double textScale;
  bool animationsEnabled;
  String accentColor;
  bool notificationsEnabled;
  bool onboardingCompleted;
  String breakAfterFocus;

  AppSettings({
    this.themeMode = ThemeModeSetting.light,
    this.focusTime = 25,
    this.shortBreakTime = 5,
    this.longBreakTime = 15,
    this.weeklyGoal = 8,
    this.sound = 'chime',
    this.selectedIdentity =
        'Soy una persona constante que cumple lo que se propone.',
    this.startScreen = 'dashboard',
    this.textScale = 1.0,
    this.animationsEnabled = true,
    this.accentColor = '#1D4ED8',
    this.notificationsEnabled = true,
    this.onboardingCompleted = false,
    this.breakAfterFocus = 'auto',
  });

  Map<String, dynamic> toMap() {
    return {
      'themeMode': themeMode.index,
      'focusTime': focusTime,
      'shortBreakTime': shortBreakTime,
      'longBreakTime': longBreakTime,
      'weeklyGoal': weeklyGoal,
      'sound': sound,
      'selectedIdentity': selectedIdentity,
      'startScreen': startScreen,
      'textScale': textScale,
      'animationsEnabled': animationsEnabled,
      'accentColor': accentColor,
      'notificationsEnabled': notificationsEnabled,
      'onboardingCompleted': onboardingCompleted,
      'breakAfterFocus': breakAfterFocus,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final themeIndex = int.tryParse('${map['themeMode'] ?? 0}') ?? 0;
    final safeThemeIndex =
        themeIndex.clamp(0, ThemeModeSetting.values.length - 1);
    return AppSettings(
      themeMode: ThemeModeSetting.values[safeThemeIndex],
      focusTime: int.tryParse('${map['focusTime'] ?? 25}') ?? 25,
      shortBreakTime: int.tryParse('${map['shortBreakTime'] ?? 5}') ?? 5,
      longBreakTime: int.tryParse('${map['longBreakTime'] ?? 15}') ?? 15,
      weeklyGoal: int.tryParse('${map['weeklyGoal'] ?? 8}') ?? 8,
      sound: '${map['sound'] ?? 'chime'}',
      selectedIdentity: map['selectedIdentity']?.toString() ??
          'Soy una persona constante que cumple lo que se propone.',
      startScreen: '${map['startScreen'] ?? 'dashboard'}',
      textScale: double.tryParse('${map['textScale'] ?? 1.0}') ?? 1.0,
      animationsEnabled: _boolFromMap(map['animationsEnabled'], fallback: true),
      accentColor: '${map['accentColor'] ?? '#1D4ED8'}',
      notificationsEnabled:
          _boolFromMap(map['notificationsEnabled'], fallback: true),
      onboardingCompleted:
          _boolFromMap(map['onboardingCompleted'], fallback: false),
      breakAfterFocus: '${map['breakAfterFocus'] ?? 'auto'}',
    );
  }

  static bool _boolFromMap(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase().trim();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }
}
