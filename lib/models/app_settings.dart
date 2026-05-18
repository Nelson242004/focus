enum ThemeModeSetting { light, dark }

class AppSettings {
  ThemeModeSetting themeMode;
  int focusTime;
  int shortBreakTime;
  int longBreakTime;
  int weeklyGoal;
  int weeklyFocusMinutesGoal;
  int dailyHabitGoal;
  int streakGoal;
  String sound;
  String selectedIdentity;
  String startScreen;
  double textScale;
  bool animationsEnabled;
  String accentColor;
  bool notificationsEnabled;
  bool examReminderDayBefore;
  bool examReminderTwoHoursBefore;
  bool examReminderThirtyMinutesBefore;
  bool onboardingCompleted;
  String breakAfterFocus;
  String userName;

  AppSettings({
    this.themeMode = ThemeModeSetting.light,
    this.focusTime = 25,
    this.shortBreakTime = 5,
    this.longBreakTime = 15,
    this.weeklyGoal = 8,
    this.weeklyFocusMinutesGoal = 300,
    this.dailyHabitGoal = 3,
    this.streakGoal = 7,
    this.sound = 'chime',
    this.selectedIdentity =
        'Soy una persona constante que cumple lo que se propone.',
    this.startScreen = 'dashboard',
    this.textScale = 1.0,
    this.animationsEnabled = true,
    this.accentColor = '#1D4ED8',
    this.notificationsEnabled = true,
    this.examReminderDayBefore = true,
    this.examReminderTwoHoursBefore = true,
    this.examReminderThirtyMinutesBefore = false,
    this.onboardingCompleted = false,
    this.breakAfterFocus = 'auto',
    this.userName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'themeMode': themeMode.index,
      'focusTime': focusTime,
      'shortBreakTime': shortBreakTime,
      'longBreakTime': longBreakTime,
      'weeklyGoal': weeklyGoal,
      'weeklyFocusMinutesGoal': weeklyFocusMinutesGoal,
      'dailyHabitGoal': dailyHabitGoal,
      'streakGoal': streakGoal,
      'sound': sound,
      'selectedIdentity': selectedIdentity,
      'startScreen': startScreen,
      'textScale': textScale,
      'animationsEnabled': animationsEnabled,
      'accentColor': accentColor,
      'notificationsEnabled': notificationsEnabled,
      'examReminderDayBefore': examReminderDayBefore,
      'examReminderTwoHoursBefore': examReminderTwoHoursBefore,
      'examReminderThirtyMinutesBefore': examReminderThirtyMinutesBefore,
      'onboardingCompleted': onboardingCompleted,
      'breakAfterFocus': breakAfterFocus,
      'userName': userName,
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
      weeklyFocusMinutesGoal:
          int.tryParse('${map['weeklyFocusMinutesGoal'] ?? 300}') ?? 300,
      dailyHabitGoal: int.tryParse('${map['dailyHabitGoal'] ?? 3}') ?? 3,
      streakGoal: int.tryParse('${map['streakGoal'] ?? 7}') ?? 7,
      sound: '${map['sound'] ?? 'chime'}',
      selectedIdentity: map['selectedIdentity']?.toString() ??
          'Soy una persona constante que cumple lo que se propone.',
      startScreen: '${map['startScreen'] ?? 'dashboard'}',
      textScale: double.tryParse('${map['textScale'] ?? 1.0}') ?? 1.0,
      animationsEnabled: _boolFromMap(map['animationsEnabled'], fallback: true),
      accentColor: '${map['accentColor'] ?? '#1D4ED8'}',
      notificationsEnabled:
          _boolFromMap(map['notificationsEnabled'], fallback: true),
      examReminderDayBefore:
          _boolFromMap(map['examReminderDayBefore'], fallback: true),
      examReminderTwoHoursBefore:
          _boolFromMap(map['examReminderTwoHoursBefore'], fallback: true),
      examReminderThirtyMinutesBefore:
          _boolFromMap(map['examReminderThirtyMinutesBefore'], fallback: false),
      onboardingCompleted:
          _boolFromMap(map['onboardingCompleted'], fallback: false),
      breakAfterFocus: '${map['breakAfterFocus'] ?? 'auto'}',
      userName: '${map['userName'] ?? ''}',
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
