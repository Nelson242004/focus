import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FocusDeepLink {
  final String friendCode;

  const FocusDeepLink.friend(this.friendCode);
}

class DeepLinkService {
  DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('focus_deep_link');

  static Future<FocusDeepLink?> initialLink() async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<String>('getInitialLink');
      return parse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<FocusDeepLink?> consumeLatestLink() async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<String>('consumeLatestLink');
      return parse(raw);
    } catch (_) {
      return null;
    }
  }

  static FocusDeepLink? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;

    final friend = uri.queryParameters['friend'] ??
        uri.queryParameters['code'] ??
        (uri.scheme == 'focus' && uri.host == 'friend'
            ? (uri.pathSegments.isEmpty ? null : uri.pathSegments.first)
            : null);
    final code = friend?.trim();
    if (code == null || code.isEmpty) return null;
    return FocusDeepLink.friend(code);
  }
}
