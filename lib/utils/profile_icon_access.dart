const String defaultProfileIconAsset = 'assets/profile_icons/focus_scholar.png';
const String darkProfileIconAsset = 'assets/profile_icons/focus_dark.png';
const String darkFemaleProfileIconAsset =
    'assets/profile_icons/focus_dark_female.png';
const String customProfileIconAsset = 'custom_profile_icon://local';

const List<String> profileIconAssets = [
  defaultProfileIconAsset,
  'assets/profile_icons/focus_flame.png',
  'assets/profile_icons/focus_calm.png',
  'assets/profile_icons/focus_champion.png',
  'assets/profile_icons/focus_scholar_female.png',
  'assets/profile_icons/focus_flame_female.png',
  'assets/profile_icons/focus_calm_female.png',
  'assets/profile_icons/focus_champion_female.png',
  darkProfileIconAsset,
  darkFemaleProfileIconAsset,
  'assets/profile_icons/focus_programmer.png',
  'assets/profile_icons/focus_doctor.png',
  'assets/profile_icons/focus_teacher.png',
  'assets/profile_icons/focus_engineer.png',
  'assets/profile_icons/focus_architect.png',
  'assets/profile_icons/focus_lawyer.png',
  'assets/profile_icons/focus_programmer_female.png',
  'assets/profile_icons/focus_doctor_female.png',
  'assets/profile_icons/focus_teacher_female.png',
  'assets/profile_icons/focus_engineer_female.png',
  'assets/profile_icons/focus_architect_female.png',
  'assets/profile_icons/focus_lawyer_female.png',
  'assets/profile_icons/focus_pink_cool.png',
  'assets/profile_icons/focus_pink_cool_female.png',
  'assets/profile_icons/focus_pink_skater.png',
  'assets/profile_icons/focus_pink_skater_female.png',
  'assets/profile_icons/focus_pink_music.png',
  'assets/profile_icons/focus_pink_music_female.png',
  'assets/profile_icons/focus_pink_artist.png',
  'assets/profile_icons/focus_pink_artist_female.png',
  'assets/profile_icons/focus_red_basket.png',
  'assets/profile_icons/focus_purple_camera.png',
  'assets/profile_icons/focus_green_tech.png',
  'assets/profile_icons/focus_black_gamer.png',
  'assets/profile_icons/focus_orange_travel.png',
  'assets/profile_icons/focus_yellow_gym.png',
];

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
  String defaultAsset = defaultProfileIconAsset,
}) {
  return isProfileIconAllowedForEmail(asset, email) ? asset : defaultAsset;
}

String profileIconAssetFromIndex(
  Object? value, {
  String? email,
  bool enforceAccess = false,
}) {
  final index = _safeProfileIconIndex(value);
  final asset = profileIconAssets[index];
  if (!enforceAccess) return asset;
  return allowedProfileIconAssetOrDefault(asset, email);
}

String normalizeProfileIconAsset(
  String asset, {
  String? email,
  bool enforceAccess = false,
}) {
  if (asset == customProfileIconAsset) return customProfileIconAsset;
  if (!profileIconAssets.contains(asset)) return defaultProfileIconAsset;
  if (!enforceAccess) return asset;
  return allowedProfileIconAssetOrDefault(asset, email);
}

int _safeProfileIconIndex(Object? value) {
  final parsed = int.tryParse('$value') ?? 0;
  if (profileIconAssets.isEmpty) return 0;
  return parsed.clamp(0, profileIconAssets.length - 1).toInt();
}

String _normalizeEmail(String? email) => (email ?? '').trim().toLowerCase();

bool _matchesEmailUser(String? email, String allowedUser) {
  final normalizedEmail = _normalizeEmail(email);
  final normalizedUser = allowedUser.trim().toLowerCase();
  if (normalizedEmail.isEmpty) return false;
  return normalizedEmail == normalizedUser ||
      normalizedEmail.split('@').first == normalizedUser;
}
