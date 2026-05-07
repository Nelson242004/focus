import 'focus_shield_app.dart';

class FocusModeConfig {
  final bool enabled;
  final List<FocusShieldApp> blockedApps;

  const FocusModeConfig({
    this.enabled = false,
    this.blockedApps = const [],
  });

  FocusModeConfig copyWith({
    bool? enabled,
    List<FocusShieldApp>? blockedApps,
  }) {
    return FocusModeConfig(
      enabled: enabled ?? this.enabled,
      blockedApps: blockedApps ?? this.blockedApps,
    );
  }
}
