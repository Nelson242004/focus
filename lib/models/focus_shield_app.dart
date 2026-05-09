class FocusShieldApp {
  final String packageName;
  final String label;
  final String iconBase64;

  const FocusShieldApp({
    required this.packageName,
    required this.label,
    this.iconBase64 = '',
  });

  FocusShieldApp copyWith({
    String? packageName,
    String? label,
    String? iconBase64,
  }) {
    return FocusShieldApp(
      packageName: packageName ?? this.packageName,
      label: label ?? this.label,
      iconBase64: iconBase64 ?? this.iconBase64,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'label': label,
      'iconBase64': iconBase64,
    };
  }

  factory FocusShieldApp.fromMap(Map<String, dynamic> map) {
    return FocusShieldApp(
      packageName: '${map['packageName'] ?? ''}',
      label: '${map['label'] ?? 'App'}',
      iconBase64: '${map['iconBase64'] ?? ''}',
    );
  }

  static const List<String> recommendedPackageOrder = [
    'com.instagram.android',
    'com.zhiliaoapp.musically',
    'com.google.android.youtube',
    'com.whatsapp',
    'org.telegram.messenger',
    'com.twitter.android',
    'com.facebook.katana',
    'com.facebook.orca',
    'com.facebook.lite',
    'com.discord',
    'com.spotify.music',
    'com.netflix.mediaclient',
    'com.android.chrome',
    'com.brave.browser',
    'org.mozilla.firefox',
    'com.sec.android.app.sbrowser',
    'com.snapchat.android',
    'com.pinterest',
    'com.instagram.barcelona',
  ];

  bool get isRecommended {
    final pkg = packageName.toLowerCase();
    if (recommendedPackageOrder.contains(pkg)) return true;
    final labelValue = label.toLowerCase();
    return labelValue.contains('instagram') ||
        labelValue.contains('tiktok') ||
        labelValue.contains('youtube') ||
        labelValue.contains('whatsapp') ||
        labelValue.contains('telegram') ||
        labelValue.contains('facebook') ||
        labelValue.contains('messenger') ||
        labelValue.contains('x') ||
        labelValue.contains('twitter') ||
        labelValue.contains('discord') ||
        labelValue.contains('spotify') ||
        labelValue.contains('netflix') ||
        labelValue.contains('chrome') ||
        labelValue.contains('brave') ||
        labelValue.contains('firefox') ||
        labelValue.contains('snapchat') ||
        labelValue.contains('threads') ||
        labelValue.contains('pinterest');
  }
}
