class FocusModeStatus {
  final bool active;
  final int blockedAttempts;
  final String lastBlockedApp;
  final int remainingSeconds;

  const FocusModeStatus({
    this.active = false,
    this.blockedAttempts = 0,
    this.lastBlockedApp = '',
    this.remainingSeconds = 0,
  });

  factory FocusModeStatus.fromMap(Map<String, dynamic> map) {
    return FocusModeStatus(
      active: map['active'] == true,
      blockedAttempts: int.tryParse('${map['blockedAttempts'] ?? 0}') ?? 0,
      lastBlockedApp: '${map['lastBlockedApp'] ?? ''}',
      remainingSeconds: int.tryParse('${map['remainingSeconds'] ?? 0}') ?? 0,
    );
  }
}
