class FocusModeStatus {
  final bool active;
  final int blockedAttempts;
  final String lastBlockedApp;
  final int remainingSeconds;
  final int lastBlockedAtMillis;

  const FocusModeStatus({
    this.active = false,
    this.blockedAttempts = 0,
    this.lastBlockedApp = '',
    this.remainingSeconds = 0,
    this.lastBlockedAtMillis = 0,
  });

  factory FocusModeStatus.fromMap(Map<String, dynamic> map) {
    return FocusModeStatus(
      active: map['active'] == true,
      blockedAttempts: int.tryParse('${map['blockedAttempts'] ?? 0}') ?? 0,
      lastBlockedApp: '${map['lastBlockedApp'] ?? ''}',
      remainingSeconds: int.tryParse('${map['remainingSeconds'] ?? 0}') ?? 0,
      lastBlockedAtMillis:
          int.tryParse('${map['lastBlockedAtMillis'] ?? 0}') ?? 0,
    );
  }
}
