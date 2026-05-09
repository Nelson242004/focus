import 'focus_shield_app.dart';

class FocusModeConfig {
  final bool enabled;
  final List<FocusShieldApp> blockedApps;
  final String protectionLevel;

  const FocusModeConfig({
    this.enabled = false,
    this.blockedApps = const [],
    this.protectionLevel = 'strict',
  });

  FocusModeConfig copyWith({
    bool? enabled,
    List<FocusShieldApp>? blockedApps,
    String? protectionLevel,
  }) {
    return FocusModeConfig(
      enabled: enabled ?? this.enabled,
      blockedApps: blockedApps ?? this.blockedApps,
      protectionLevel: protectionLevel ?? this.protectionLevel,
    );
  }
}
