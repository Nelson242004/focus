class FocusShieldApp {
  final String packageName;
  final String label;

  const FocusShieldApp({
    required this.packageName,
    required this.label,
  });

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'label': label,
    };
  }

  factory FocusShieldApp.fromMap(Map<String, dynamic> map) {
    return FocusShieldApp(
      packageName: '${map['packageName'] ?? ''}',
      label: '${map['label'] ?? 'App'}',
    );
  }
}
