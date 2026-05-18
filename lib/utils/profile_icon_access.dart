const String darkProfileIconAsset = 'assets/profile_icons/focus_dark.png';
const String darkFemaleProfileIconAsset =
    'assets/profile_icons/focus_dark_female.png';

bool isProfileIconAllowedForEmail(String asset, String? email) {
  return switch (asset) {
    darkProfileIconAsset => _matchesEmailUser(email, 'gabrielnelson242004'),
    darkFemaleProfileIconAsset =>
      _normalizeEmail(email) == 'daigaona131@gmail.com',
    _ => true,
  };
}

String allowedProfileIconAssetOrDefault(
  String asset,
  String? email, {
  required String defaultAsset,
}) {
  return isProfileIconAllowedForEmail(asset, email) ? asset : defaultAsset;
}

String _normalizeEmail(String? email) => (email ?? '').trim().toLowerCase();

bool _matchesEmailUser(String? email, String allowedUser) {
  final normalizedEmail = _normalizeEmail(email);
  final normalizedUser = allowedUser.trim().toLowerCase();
  if (normalizedEmail.isEmpty) return false;
  return normalizedEmail == normalizedUser ||
      normalizedEmail.split('@').first == normalizedUser;
}
