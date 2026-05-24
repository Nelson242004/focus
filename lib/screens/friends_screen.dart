import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ranking_profile.dart';
import '../providers/app_provider.dart';
import '../services/friends_service.dart';
import '../services/ranking_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/badge_assets.dart';
import '../utils/focus_icon_assets.dart';
import '../utils/focus_palette.dart';
import '../utils/profile_icon_access.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_empty_state.dart';
import '../widgets/focus_feedback.dart';
import '../widgets/focus_help_button.dart';
import '../widgets/focus_layered_avatar.dart';
import '../widgets/focus_metric_icon.dart';
import '../widgets/focus_profile_mascot.dart';
import '../widgets/focus_public_profile_sheet.dart';
import '../widgets/focus_social_components.dart';
import 'auth_gate_screen.dart';

class FriendsScreen extends StatefulWidget {
  final String? initialFriendCode;
  final bool showAppBar;

  const FriendsScreen({
    super.key,
    this.initialFriendCode,
    this.showAppBar = true,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  Future<List<RankingProfile>>? _searchFuture;
  late Future<RankingProfile?> _profileFuture;
  Stream<List<RankingProfile>>? _friendsStream;
  int? _lastSyncedLocalStreak;
  bool _syncingLocalStats = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = RankingService.ensureProfile();
    _friendsStream = RankingService.currentUser == null
        ? null
        : FriendsService.friendsStream();
    final initialCode = widget.initialFriendCode?.trim();
    if (initialCode != null && initialCode.isNotEmpty) {
      _searchController.text = initialCode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _searchFuture = FriendsService.searchUsers(_searchController.text);
    });
  }

  void _syncLocalStatsToProfile(
    AppProvider provider,
    RankingProfile profile,
  ) {
    final localStreak = provider.currentStreak;
    final remoteStreak = _profileStreak(profile);
    if (_syncingLocalStats || RankingService.currentUser == null) {
      return;
    }
    if (_lastSyncedLocalStreak == localStreak && remoteStreak == localStreak) {
      return;
    }
    if (remoteStreak == localStreak && _lastSyncedLocalStreak == localStreak) {
      return;
    }
    _syncingLocalStats = true;
    RankingService.syncSocialStats(
      currentStreak: localStreak,
      totalPomodoros: provider.pomodoros.length,
      totalHabitCompletions: provider.totalHabitCompletions,
      weeklyMissionCompleted: provider.weeklyMissionCompleted,
      level: provider.level,
    ).then((_) async {
      _lastSyncedLocalStreak = localStreak;
      if (!mounted) return;
      final updatedProfile = await RankingService.fetchProfile();
      if (!mounted || updatedProfile == null) return;
      setState(() => _profileFuture = Future.value(updatedProfile));
    }).catchError((Object error) {
      debugPrint('Focus profile stats sync skipped: $error');
    }).whenComplete(() {
      _syncingLocalStats = false;
    });
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) {
      setState(() {
        _profileFuture = RankingService.ensureProfile();
        _friendsStream = FriendsService.friendsStream();
      });
    }
  }

  Future<void> _copyFriendCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    showFocusFeedback(
      context,
      message: 'Código $code copiado.',
      icon: Icons.copy_rounded,
    );
  }

  Future<void> _shareFriendInvite(RankingProfile profile) async {
    final code = RankingService.friendCodeForUid(profile.uid);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ShareProfileSheet(
        profile: profile,
        friendCode: code,
        inviteLink: _friendInviteLink(code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Perfil'),
              actions: const [
                FocusHelpAction(
                  title: 'Ayuda de perfil',
                  message:
                      'Desde aquí editas tu perfil público y gestionas amigos sin cargar la pantalla con explicaciones largas.',
                  sections: [
                    FocusHelpSection(
                      title: 'Perfil público',
                      items: [
                        'Tu nombre y carrera son los datos que otros pueden ver en funciones sociales.',
                        'Puedes cambiar personaje y color de fondo desde el editor del perfil.',
                      ],
                    ),
                    FocusHelpSection(
                      title: 'Amigos',
                      items: [
                        'Tu código sirve para que te agreguen rápido.',
                        'Buscar te permite enviar solicitudes y compartir facilita invitar fuera de la app.',
                        'El ranking entre amigos toma tu perfil público, no la información privada de tu cuenta.',
                      ],
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: RankingService.currentUser == null
          ? _LoginRequiredPanel(onLogin: _openLogin)
          : FutureBuilder<RankingProfile?>(
              future: _profileFuture,
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const FocusSkeletonList(
                    heights: [210, 118, 96, 132],
                  );
                }
                if (profileSnapshot.hasError) {
                  return _ErrorPanel(
                    message: RankingService.friendlyRankingError(
                      profileSnapshot.error,
                    ),
                    onRetry: () => setState(
                      () => _profileFuture = RankingService.ensureProfile(),
                    ),
                  );
                }
                final user = RankingService.currentUser;
                final profile = profileSnapshot.data;
                if (user != null && profile == null) {
                  return _ErrorPanel(
                    message: 'No se pudo preparar tu perfil. Toca reintentar.',
                    onRetry: () => setState(
                      () => _profileFuture = RankingService.ensureProfile(),
                    ),
                  );
                }
                final loadedProfile = profile!;
                final localProvider =
                    Provider.of<AppProvider>(context, listen: false);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _syncLocalStatsToProfile(localProvider, loadedProfile);
                  }
                });
                return StreamBuilder<List<RankingProfile>>(
                  stream: _friendsStream ??= FriendsService.friendsStream(),
                  builder: (context, friendsSnapshot) {
                    if (friendsSnapshot.hasError) {
                      return _ErrorPanel(
                        message: RankingService.friendlyRankingError(
                          friendsSnapshot.error,
                        ),
                        onRetry: () => setState(() {}),
                      );
                    }
                    final friends =
                        friendsSnapshot.data ?? const <RankingProfile>[];
                    return RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
                        children: [
                          _ProfileReveal(
                            index: 0,
                            child: _DuolingoFriendsHeader(
                              profile: loadedProfile,
                              friendsCount: friends.length,
                              onCopy: _copyFriendCode,
                              onShare: () => _shareFriendInvite(loadedProfile),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ProfileReveal(
                            index: 1,
                            child: _FriendsHubDuo(
                              friends: friends,
                              search: _SearchCard(
                                controller: _searchController,
                                searchFuture: _searchFuture,
                                friends: friends,
                                onSearch: _search,
                                onViewProfile: _showFriendProfile,
                                onPreviewProfile: _showCandidateProfile,
                              ),
                              requests: _RequestsCard(
                                compact: true,
                                onChanged: () => setState(() {}),
                              ),
                              list: _FriendsList(
                                friends: friends,
                                onViewProfile: _showFriendProfile,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ProfileReveal(
                            index: 2,
                            child: _SocialSummaryCard(
                              friendsCount: friends.length,
                              profile: loadedProfile,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ProfileReveal(
                            index: 3,
                            child: _FriendStreaks(
                              profile: loadedProfile,
                              friends: friends,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ProfileReveal(
                            index: 4,
                            child: Consumer<AppProvider>(
                              builder: (context, provider, _) =>
                                  _AchievementProgressSection(
                                provider: provider,
                                unlockedBadges: loadedProfile.badges.toSet(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ProfileReveal(
                            index: 5,
                            child: _AllBadgesGrid(
                              profile: loadedProfile,
                            ),
                          ),
                          /*
                          _CollapsibleFriendsSection(
                            icon: Icons.person_add_alt_1_rounded,
                            title: 'Agregar amigo',
                            subtitle: 'Código, nombre o correo',
                            child: _SearchCard(
                              controller: _searchController,
                              searchFuture: _searchFuture,
                              onSearch: _search,
                              onSendRequest: _sendRequest,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FocusSummaryGrid(profile: profile),
                          const SizedBox(height: 18),
                          _FriendStreaks(
                            profile: profile,
                            friends: friends,
                          ),
                          const SizedBox(height: 18),
                          _MonthlyMedals(
                            profile: profile,
                            friendsCount: friends.length,
                          ),
                          const SizedBox(height: 18),
                          _SocialInfoSection(
                            profile: profile,
                            friendsCount: friends.length,
                          ),
                          const SizedBox(height: 18),
                          _RequestsCard(
                            onChanged: () => setState(() {
                              _friendsRankingFuture = null;
                            }),
                          ),
                          const SizedBox(height: 10),
                          _FriendsRanking(
                            future: _friendsRankingFuture,
                            friendsCount: friends.length,
                            onRefresh: () =>
                                setState(() => _loadFriendsRanking(friends)),
                          ),
                          const SizedBox(height: 10),
                          _FriendsList(
                            friends: friends,
                            onRemove: _removeFriend,
                          ),
                          */
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<bool> _sendRequest(RankingProfile profile) async {
    try {
      HapticFeedback.selectionClick();
      await FriendsService.sendRequest(profile);
      if (!mounted) return true;
      setState(() => _searchFuture = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: FocusActionSnackContent(
            icon: Icons.person_add_alt_1_rounded,
            message: 'Solicitud enviada a ${profile.name}.',
            color: FocusPalette.mint,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: FocusActionSnackContent(
            icon: Icons.error_outline_rounded,
            message: RankingService.friendlyRankingError(error),
            color: FocusPalette.danger,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<void> _removeFriend(RankingProfile friend) async {
    try {
      await FriendsService.removeFriend(friend.uid);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: FocusActionSnackContent(
            icon: Icons.person_remove_rounded,
            message: '${friend.name} salió de tus amigos.',
            color: FocusPalette.amber,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: FocusActionSnackContent(
            icon: Icons.error_outline_rounded,
            message: RankingService.friendlyRankingError(error),
            color: FocusPalette.danger,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showFriendProfile(RankingProfile friend) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FocusPublicProfileSheet(
        profile: friend,
        onRemove: () async {
          await _removeFriend(friend);
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _showCandidateProfile(
    RankingProfile profile,
    List<RankingProfile> friends,
  ) async {
    final isFriend = friends.any((friend) => friend.uid == profile.uid);
    if (isFriend) {
      await _showFriendProfile(profile);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FocusPublicProfileSheet(
        profile: profile,
        isFriend: false,
        onSendRequest: () => _sendRequest(profile),
      ),
    );
  }
}

class _LoginRequiredPanel extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoginRequiredPanel({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.people_alt_rounded,
      title: 'Inicia sesión para usar tu perfil',
      message:
          'Crea tu perfil para competir con compañeros y aparecer en rankings.',
      action: FilledButton.icon(
        onPressed: onLogin,
        icon: const Icon(Icons.login_rounded),
        label: const Text('Iniciar sesión'),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPanel({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.warning_amber_rounded,
      title: 'No se pudo cargar Perfil',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: FocusProfileEmptyState(
          icon: icon,
          iconKind: FocusAppIconKind.friends,
          title: title,
          message: message,
          action: action,
        ),
      ),
    );
  }
}

class _SocialProfileHeader extends StatefulWidget {
  final RankingProfile profile;
  final int friendsCount;
  final Future<void> Function(String code) onCopy;
  final VoidCallback onShare;

  const _SocialProfileHeader({
    required this.profile,
    required this.friendsCount,
    required this.onCopy,
    required this.onShare,
  });

  @override
  State<_SocialProfileHeader> createState() => _SocialProfileHeaderState();
}

class _SocialProfileHeaderState extends State<_SocialProfileHeader> {
  late int _themeIndex;
  late int _profileIconIndex;

  @override
  void initState() {
    super.initState();
    _themeIndex = _safeIndex(
      widget.profile.stats['socialThemeIndex'],
      _socialThemes.length,
    );
    _profileIconIndex = _safeProfileIconIndex(
      widget.profile.stats['socialMascotIndex'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final code = RankingService.friendCodeForUid(profile.uid);
    final theme = _socialThemes[_themeIndex];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => widget.onCopy(code),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.white.withValues(alpha: 0.18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        code,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.copy_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _ProfileIconBadge(
                      option: _profileIcons[_profileIconIndex],
                      colors: theme.colors,
                      onTap: () => _showProfileIconPicker(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        foregroundColor: FocusPalette.ink,
                        fixedSize: const Size(38, 38),
                      ),
                      onPressed: widget.onShare,
                      tooltip: 'Compartir código',
                      icon: const Icon(Icons.ios_share_rounded, size: 17),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileIconPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Icono de perfil',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige cómo quieres aparecer en Perfil.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: _availableProfileIconIndexes().length,
                itemBuilder: (context, index) {
                  final actualIndex = _availableProfileIconIndexes()[index];
                  final option = _profileIcons[actualIndex];
                  final canUse = _isProfileIconAllowed(option.asset);
                  return _ProfileIconChoice(
                    option: option,
                    selected: actualIndex == _profileIconIndex,
                    onTap: () async {
                      if (!canUse) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Este personaje está reservado para otra cuenta.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      if (actualIndex == _profileIconIndex) return;
                      final previous = _profileIconIndex;
                      setState(() => _profileIconIndex = actualIndex);
                      try {
                        await RankingService.updateSocialStyle(
                          mascotIndex: actualIndex,
                          profileIconAsset: option.asset,
                        );
                        await WidgetSyncService.syncProfileIconAsset(
                          option.asset,
                        );
                      } catch (error) {
                        if (!mounted) return;
                        setState(() => _profileIconIndex = previous);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              RankingService.friendlyRankingError(error),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuolingoFriendsHeader extends StatefulWidget {
  final RankingProfile profile;
  final int friendsCount;
  final Future<void> Function(String code) onCopy;
  final VoidCallback onShare;

  const _DuolingoFriendsHeader({
    required this.profile,
    required this.friendsCount,
    required this.onCopy,
    required this.onShare,
  });

  @override
  State<_DuolingoFriendsHeader> createState() => _DuolingoFriendsHeaderState();
}

class _DuolingoFriendsHeaderState extends State<_DuolingoFriendsHeader> {
  late int _themeIndex;
  late int _profileIconIndex;

  @override
  void initState() {
    super.initState();
    _themeIndex = _safeIndex(
      widget.profile.stats['socialThemeIndex'],
      _socialThemes.length,
    );
    _profileIconIndex = _safeProfileIconIndex(
      widget.profile.stats['socialMascotIndex'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final code = RankingService.friendCodeForUid(profile.uid);
    final theme = _socialThemes[_themeIndex];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FocusRadii.panel),
          gradient: LinearGradient(
            colors: theme.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.35, 0.12),
                    radius: 0.82,
                    colors: [
                      Colors.white.withValues(alpha: 0.24),
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -34,
              top: -38,
              child: _SoftHeaderCircle(size: 130, alpha: 0.08),
            ),
            Positioned(
              left: -54,
              bottom: -70,
              child: _SoftHeaderCircle(size: 190, alpha: 0.06),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CareerPill(career: profile.career),
                      ],
                    ),
                  ),
                  _HeaderIconButton(
                    onPressed: widget.onShare,
                    tooltip: 'Compartir código',
                    icon: Icons.ios_share_rounded,
                  ),
                ],
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.32),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _ProfileIconBadge(
                    option: _profileIcons[_profileIconIndex],
                    colors: theme.colors,
                    size: 226,
                    onTap: () => _showAvatarBuilder(context),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 24,
                    child: _HeaderIconButton(
                      onPressed: () => _showAvatarBuilder(context),
                      tooltip: 'Cambiar personaje',
                      icon: Icons.edit_rounded,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 22,
              right: 18,
              bottom: 16,
              child: Row(
                children: [
                  Flexible(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => widget.onCopy(code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.black.withValues(alpha: 0.17),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.45,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.copy_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarBuilder(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ProfileIconPickerSheet(
        selectedIndex: _profileIconIndex,
        selectedThemeIndex: _themeIndex,
        onSelected: (index, themeIndex) async {
          if (!_isProfileIconAllowed(_profileIcons[index].asset)) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Este personaje está reservado para otra cuenta.',
                ),
              ),
            );
            return;
          }
          final previousIndex = _profileIconIndex;
          final previousThemeIndex = _themeIndex;
          final config = FocusAvatarConfig.fromProfileIndex(index);
          setState(() {
            _profileIconIndex = index;
            _themeIndex = themeIndex;
          });
          try {
            await RankingService.updateSocialStyle(
              mascotIndex: index,
              themeIndex: themeIndex,
              profileIconAsset: _profileIcons[index].asset,
            );
            await RankingService.updateSocialAvatar(config.toMap());
            await WidgetSyncService.syncProfileIconAsset(
              _profileIcons[index].asset,
            );
          } catch (error) {
            if (!mounted) return;
            setState(() {
              _profileIconIndex = previousIndex;
              _themeIndex = previousThemeIndex;
            });
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text(RankingService.friendlyRankingError(error)),
              ),
            );
          }
        },
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  const _HeaderIconButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        foregroundColor: FocusPalette.ink,
        fixedSize: const Size(38, 38),
        minimumSize: const Size(38, 38),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
    );
  }
}

class _SoftHeaderCircle extends StatelessWidget {
  final double size;
  final double alpha;

  const _SoftHeaderCircle({
    required this.size,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _CareerPill extends StatelessWidget {
  final String career;

  const _CareerPill({required this.career});

  @override
  Widget build(BuildContext context) {
    final label = career.trim().isEmpty ? 'Sin carrera' : career.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineSocialStatus extends StatelessWidget {
  final RankingProfile profile;

  const _InlineSocialStatus({required this.profile});

  @override
  Widget build(BuildContext context) {
    final status = _socialStatus(profile);
    return Row(
      children: [
        Icon(status.icon, size: 13, color: status.color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: status.color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class _ShareProfileSheet extends StatefulWidget {
  final RankingProfile profile;
  final String friendCode;
  final String inviteLink;

  const _ShareProfileSheet({
    required this.profile,
    required this.friendCode,
    required this.inviteLink,
  });

  @override
  State<_ShareProfileSheet> createState() => _ShareProfileSheetState();
}

class _ShareProfileSheetState extends State<_ShareProfileSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _copyInvite() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            'Agrégame en Focus con mi código ${widget.friendCode}\n${widget.inviteLink}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: FocusActionSnackContent(
          icon: Icons.ios_share_rounded,
          message: 'Invitación copiada.',
          color: FocusPalette.mint,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final data = bytes?.buffer.asUint8List();
      if (data == null) return;
      await Share.shareXFiles(
        [
          XFile.fromData(
            data,
            mimeType: 'image/png',
            name: 'focus_profile_${widget.friendCode}.png',
          ),
        ],
        text: 'Agrégame en Focus: ${widget.inviteLink}',
        subject: 'Mi perfil de Focus',
      );
    } catch (_) {
      await _copyInvite();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _cardKey,
              child: _PublicProfileCard(
                profile: widget.profile,
                friendCode: widget.friendCode,
                inviteLink: widget.inviteLink,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyInvite,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Copiar enlace'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sharing ? null : _shareImage,
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicProfileCard extends StatelessWidget {
  final RankingProfile profile;
  final String friendCode;
  final String inviteLink;

  const _PublicProfileCard({
    required this.profile,
    required this.friendCode,
    required this.inviteLink,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [FocusPalette.primaryDeep, FocusPalette.cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: FocusPalette.primary.withValues(alpha: 0.20),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProfileIconAvatar(profile: profile, size: 82),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.career,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _CareerPill(career: profile.career),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _PublicCardMetric(
                  icon: Icons.bolt_rounded,
                  metricIcon: FocusMetricIconKind.points,
                  label: '${profile.totalPoints} pts',
                ),
                const SizedBox(width: 8),
                _PublicCardMetric(
                  icon: Icons.emoji_events_rounded,
                  assetIcon: _rankMedalAsset(profile.rank),
                  label: _leagueLabel(profile.rank),
                ),
                const SizedBox(width: 8),
                _PublicCardMetric(
                  icon: Icons.local_fire_department_rounded,
                  metricIcon: FocusMetricIconKind.streak,
                  label: '${_profileStreak(profile)} días',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PublicFriendCodePill(friendCode: friendCode),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: QrImageView(
                    data: inviteLink,
                    size: 82,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Escanea o usa el código para agregarme a Focus.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicCardMetric extends StatelessWidget {
  final IconData icon;
  final String? assetIcon;
  final FocusMetricIconKind? metricIcon;
  final String label;

  const _PublicCardMetric({
    required this.icon,
    this.assetIcon,
    this.metricIcon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (metricIcon != null)
              FocusMetricIcon(kind: metricIcon!, size: 17, color: Colors.white)
            else if (assetIcon != null)
              Image.asset(
                assetIcon!,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              )
            else
              Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicFriendCodePill extends StatelessWidget {
  final String friendCode;

  const _PublicFriendCodePill({required this.friendCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            color: Colors.white.withValues(alpha: 0.90),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Código de amigo',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              friendCode,
              style: const TextStyle(
                color: FocusPalette.primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialSummaryCard extends StatelessWidget {
  final int friendsCount;
  final RankingProfile profile;

  const _SocialSummaryCard({
    required this.friendsCount,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : FocusPalette.ink;
    return FocusSurfaceCard(
      padding: FocusInsets.cardRelaxed,
      accent: FocusPalette.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusSectionHeader(
            icon: Icons.insights_rounded,
            iconKind: FocusAppIconKind.friends,
            title: 'Resumen',
            accent: FocusPalette.teal,
          ),
          FocusGap.md,
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.local_fire_department_rounded,
                  metricIcon: FocusMetricIconKind.streak,
                  iconColor: FocusPalette.amber,
                  label: 'Racha',
                  value: '${_profileStreak(profile)} días',
                  valueColor: textColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.people_alt_rounded,
                  iconColor: FocusPalette.cyan,
                  label: 'Amigos',
                  value: '$friendsCount',
                  valueColor: textColor,
                ),
              ),
            ],
          ),
          FocusGap.sm,
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.emoji_events_rounded,
                  assetIcon: _rankMedalAsset(profile.rank),
                  iconColor: FocusPalette.cyan,
                  label: 'Liga',
                  value: _leagueLabel(profile.rank),
                  valueColor: textColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.bolt_rounded,
                  metricIcon: FocusMetricIconKind.points,
                  iconColor: FocusPalette.amber,
                  label: 'Puntos',
                  value: '${profile.totalPoints} pts',
                  valueColor: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _ProfileReveal({
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (index * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final eased = Curves.easeOutCubic.transform(value);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * (18 + index * 2)),
            child: Transform.scale(
              scale: 0.985 + (0.015 * eased),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String? assetIcon;
  final FocusMetricIconKind? metricIcon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryMetric({
    required this.icon,
    this.assetIcon,
    this.metricIcon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        color: iconColor.withValues(alpha: 0.07),
        border: Border.all(color: iconColor.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          if (metricIcon != null)
            FocusMetricIcon(kind: metricIcon!, size: 26, color: iconColor)
          else if (assetIcon == null)
            Icon(icon, color: iconColor, size: 26)
          else
            Image.asset(
              assetIcon!,
              width: 26,
              height: 26,
              fit: BoxFit.contain,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: FocusPalette.muted,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileIconBadge extends StatelessWidget {
  final _ProfileIconOption option;
  final List<Color> colors;
  final double size;
  final VoidCallback onTap;

  const _ProfileIconBadge({
    required this.option,
    required this.colors,
    this.size = 118,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cambiar icono',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.36),
                      colors.last.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.58, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              Positioned(
                right: 10,
                top: 14,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white.withValues(alpha: 0.38),
                  size: 18,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: _ProfileIconArtwork(
                    asset: option.asset,
                    size: size,
                    animate: true,
                    celebrate: true,
                    selected: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileIconChoice extends StatelessWidget {
  final _ProfileIconOption option;
  final bool selected;
  final double pageDelta;
  final VoidCallback onTap;

  const _ProfileIconChoice({
    required this.option,
    required this.selected,
    this.pageDelta = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tilt = (pageDelta * 0.08).clamp(-0.08, 0.08);
    final slideX = (pageDelta * 12).clamp(-12.0, 12.0);
    final slideY = pageDelta.abs().clamp(0.0, 1.0) * 6;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Transform.translate(
        offset: Offset(slideX, slideY),
        child: Transform.rotate(
          angle: -tilt,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: selected
                  ? FocusPalette.primary.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: selected
                    ? FocusPalette.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: _profileIconAccent(option.asset)
                        .withValues(alpha: 0.18),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: _ProfileIconArtwork(
                          asset: option.asset,
                          size: 72,
                          animate: true,
                          selected: selected,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      option.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: selected ? FocusPalette.primary : null,
                      ),
                    ),
                  ],
                ),
                if (selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.transparent,
                              _profileIconAccent(option.asset)
                                  .withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileIconPickerSheet extends StatefulWidget {
  final int selectedIndex;
  final int selectedThemeIndex;
  final Future<void> Function(int index, int themeIndex) onSelected;

  const _ProfileIconPickerSheet({
    required this.selectedIndex,
    required this.selectedThemeIndex,
    required this.onSelected,
  });

  @override
  State<_ProfileIconPickerSheet> createState() =>
      _ProfileIconPickerSheetState();
}

class _ProfileIconPickerSheetState extends State<_ProfileIconPickerSheet> {
  late final PageController _pageController;
  late final List<int> _availableIndexes;
  late int _selectedIndex;
  late int _selectedThemeIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _availableIndexes = _availableProfileIconIndexes();
    _selectedIndex = _availableIndexes.contains(widget.selectedIndex)
        ? widget.selectedIndex
        : _availableIndexes.first;
    _selectedThemeIndex = _safeIndex(
      widget.selectedThemeIndex,
      _socialThemes.length,
    );
    _pageController = PageController(
      initialPage: _availableIndexes.indexOf(_selectedIndex),
      viewportFraction: 0.48,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _currentPickerPage() {
    if (!_pageController.hasClients) {
      return _availableIndexes.indexOf(_selectedIndex).toDouble();
    }
    final page = _pageController.page;
    if (page == null) {
      return _availableIndexes.indexOf(_selectedIndex).toDouble();
    }
    return page;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _profileIcons[_selectedIndex];
    final selectedTheme = _socialThemes[_selectedThemeIndex];
    final selectedConfig = FocusAvatarConfig.fromProfileIndex(_selectedIndex);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elige tu personaje',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: FocusPalette.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (_selectedIndex == widget.selectedIndex &&
                              _selectedThemeIndex ==
                                  widget.selectedThemeIndex) {
                            Navigator.pop(context);
                            return;
                          }
                          setState(() => _saving = true);
                          await widget.onSelected(
                            _selectedIndex,
                            _selectedThemeIndex,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Guardar'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 236,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: selectedTheme.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: RadialGradient(
                          center: const Alignment(0.35, 0.12),
                          radius: 0.82,
                          colors: [
                            Colors.white.withValues(alpha: 0.24),
                            Colors.white.withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -34,
                    top: -38,
                    child: _SoftHeaderCircle(size: 130, alpha: 0.08),
                  ),
                  Positioned(
                    left: -54,
                    bottom: -70,
                    child: _SoftHeaderCircle(size: 190, alpha: 0.06),
                  ),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1).animate(
                              animation,
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: FocusProfileMascot(
                        key: ValueKey(selected.asset),
                        size: 196,
                        fallbackConfig: selectedConfig,
                        profileIconAsset: selected.asset,
                        state: FocusMascotState.celebrating,
                        animate: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Color de fondo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  selectedTheme.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FocusPalette.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _socialThemes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final theme = _socialThemes[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _selectedThemeIndex = index),
                    child: _ThemeChoicePill(
                      theme: theme,
                      selected: index == _selectedThemeIndex,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 126,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _availableIndexes.length,
                onPageChanged: (pageIndex) => setState(
                  () => _selectedIndex = _availableIndexes[pageIndex],
                ),
                itemBuilder: (context, index) {
                  final actualIndex = _availableIndexes[index];
                  final option = _profileIcons[actualIndex];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      final page = _currentPickerPage();
                      final delta = index - page;
                      final active = delta.abs() < 0.5;
                      final scale = (1 - delta.abs() * 0.12).clamp(0.84, 1.0);
                      return AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        scale: scale,
                        curve: Curves.easeOutBack,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: _ProfileIconChoice(
                            option: option,
                            selected: active,
                            pageDelta: delta,
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                              );
                              setState(() => _selectedIndex = actualIndex);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIconArtwork extends StatefulWidget {
  final String asset;
  final double size;
  final bool animate;
  final bool celebrate;
  final bool selected;

  const _ProfileIconArtwork({
    required this.asset,
    required this.size,
    this.animate = true,
    this.celebrate = false,
    this.selected = false,
  });

  @override
  State<_ProfileIconArtwork> createState() => _ProfileIconArtworkState();
}

class _ProfileIconArtworkState extends State<_ProfileIconArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ProfileIconArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = widget.animate ? _controller.value : 0.0;
        final wave = math.sin(progress * math.pi * 2);
        final bounce = widget.celebrate
            ? -math.sin(progress * math.pi * 2).abs() * widget.size * 0.05
            : 0.0;
        final drift = widget.animate ? wave * widget.size * 0.012 : 0.0;
        final scale = widget.celebrate
            ? 1 + wave * 0.014
            : widget.selected
                ? 1.02 + wave * 0.01
                : 1 + wave * 0.006;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: widget.size * 0.06,
              child: Container(
                width: widget.size * 0.46,
                height: widget.size * 0.08,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(widget.size),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _profileIconAccent(widget.asset).withValues(
                        alpha:
                            widget.selected || widget.celebrate ? 0.22 : 0.10,
                      ),
                      _profileIconAccent(widget.asset).withValues(
                        alpha:
                            widget.selected || widget.celebrate ? 0.10 : 0.04,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (widget.selected || widget.celebrate)
              ...List.generate(widget.celebrate ? 6 : 4, (index) {
                final angle = progress * math.pi * 2 + (index * math.pi / 3);
                final radius = widget.size * (widget.celebrate ? 0.34 : 0.28);
                return Positioned(
                  left: widget.size / 2 +
                      math.cos(angle) * radius -
                      widget.size * 0.035,
                  top: widget.size / 2 +
                      math.sin(angle) * radius -
                      widget.size * 0.035,
                  child: Icon(
                    index.isEven
                        ? Icons.auto_awesome_rounded
                        : Icons.circle_rounded,
                    size: widget.size * (widget.celebrate ? 0.07 : 0.045),
                    color: index.isEven
                        ? FocusPalette.amber.withValues(
                            alpha: widget.celebrate ? 0.85 : 0.68,
                          )
                        : Colors.white.withValues(
                            alpha: widget.celebrate ? 0.78 : 0.52,
                          ),
                  ),
                );
              }),
            Transform.translate(
              offset: Offset(0, bounce + drift),
              child: Transform.scale(
                scale: scale,
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.05),
                  child: Image.asset(
                    widget.asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image_not_supported_rounded,
                      size: widget.size * 0.36,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeChoicePill extends StatelessWidget {
  final _SocialTheme theme;
  final bool selected;

  const _ThemeChoicePill({
    required this.theme,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected
            ? FocusPalette.primary.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: selected
              ? FocusPalette.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeDot(colors: theme.colors, selected: selected),
          const SizedBox(width: 8),
          Text(
            theme.name,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? FocusPalette.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeDot extends StatelessWidget {
  final List<Color> colors;
  final bool selected;

  const _ThemeDot({
    required this.colors,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.25),
          width: selected ? 2 : 1,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _MiniMascot extends StatelessWidget {
  final _MascotOption option;
  final bool selected;

  const _MiniMascot({
    required this.option,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: selected ? 0.98 : 0.24),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.25),
          width: selected ? 2 : 1,
        ),
      ),
      child: Icon(option.icon, color: option.color, size: 17),
    );
  }
}

// ignore: unused_element
class _MascotAvatar extends StatelessWidget {
  final _MascotOption option;
  final double size;

  const _MascotAvatar({
    required this.option,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.94),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 8,
            top: 8,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: option.color.withValues(alpha: 0.25),
              size: 18,
            ),
          ),
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  option.color.withValues(alpha: 0.9),
                  option.color.withValues(alpha: 0.55),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(option.icon, color: Colors.white, size: size * 0.34),
          ),
        ],
      ),
    );
  }
}

class _SocialTheme {
  final String name;
  final List<Color> colors;

  const _SocialTheme(this.name, this.colors);
}

class _MascotOption {
  final String name;
  final IconData icon;
  final Color color;

  const _MascotOption(this.name, this.icon, this.color);
}

class _ProfileIconOption {
  final String name;
  final String asset;

  const _ProfileIconOption(this.name, this.asset);
}

const _socialThemes = [
  _SocialTheme('Focus', [FocusPalette.primaryDeep, FocusPalette.cyan]),
  _SocialTheme('Bosque', [FocusPalette.teal, FocusPalette.mint]),
  _SocialTheme('Amanecer', [FocusPalette.amber, FocusPalette.mint]),
  _SocialTheme('Noche', [FocusPalette.ink, FocusPalette.primaryDeep]),
  _SocialTheme('Laguna', [Color(0xFF0369A1), Color(0xFF06B6D4)]),
  _SocialTheme('Menta', [FocusPalette.teal, FocusPalette.mint]),
  _SocialTheme('Lavanda', [Color(0xFF6D28D9), Color(0xFFA78BFA)]),
  _SocialTheme('Cereza', [Color(0xFFBE123C), Color(0xFFFB7185)]),
  _SocialTheme('Solar', [FocusPalette.amber, FocusPalette.primary]),
  _SocialTheme('Grafito', [Color(0xFF111827), Color(0xFF475569)]),
  _SocialTheme('Océano', [Color(0xFF1E3A8A), Color(0xFF14B8A6)]),
  _SocialTheme('Aurora', [Color(0xFF7C2D12), Color(0xFFDB2777)]),
  _SocialTheme('Lima', [Color(0xFF365314), Color(0xFF84CC16)]),
  _SocialTheme('Cielo', [Color(0xFF2563EB), Color(0xFF93C5FD)]),
  _SocialTheme('Uva', [Color(0xFF581C87), Color(0xFFE879F9)]),
  _SocialTheme('Tinta', [Color(0xFF020617), Color(0xFF334155)]),
];

const _profileIcons = [
  _ProfileIconOption('Scholar', 'assets/profile_icons/focus_scholar.png'),
  _ProfileIconOption('Flame', 'assets/profile_icons/focus_flame.png'),
  _ProfileIconOption('Calma', 'assets/profile_icons/focus_calm.png'),
  _ProfileIconOption('Champion', 'assets/profile_icons/focus_champion.png'),
  _ProfileIconOption(
    'Scholar F',
    'assets/profile_icons/focus_scholar_female.png',
  ),
  _ProfileIconOption('Flame F', 'assets/profile_icons/focus_flame_female.png'),
  _ProfileIconOption(
    'Calma F',
    'assets/profile_icons/focus_calm_female.png',
  ),
  _ProfileIconOption(
    'Champion F',
    'assets/profile_icons/focus_champion_female.png',
  ),
  _ProfileIconOption('Dark', 'assets/profile_icons/focus_dark.png'),
  _ProfileIconOption('Dark F', 'assets/profile_icons/focus_dark_female.png'),
  _ProfileIconOption(
      'Programador', 'assets/profile_icons/focus_programmer.png'),
  _ProfileIconOption('Médico', 'assets/profile_icons/focus_doctor.png'),
  _ProfileIconOption('Docente', 'assets/profile_icons/focus_teacher.png'),
  _ProfileIconOption('Ingeniería', 'assets/profile_icons/focus_engineer.png'),
  _ProfileIconOption(
      'Arquitectura', 'assets/profile_icons/focus_architect.png'),
  _ProfileIconOption('Derecho', 'assets/profile_icons/focus_lawyer.png'),
  _ProfileIconOption(
    'Programadora',
    'assets/profile_icons/focus_programmer_female.png',
  ),
  _ProfileIconOption('Médica', 'assets/profile_icons/focus_doctor_female.png'),
  _ProfileIconOption(
    'Docente F',
    'assets/profile_icons/focus_teacher_female.png',
  ),
  _ProfileIconOption(
    'Ingeniera',
    'assets/profile_icons/focus_engineer_female.png',
  ),
  _ProfileIconOption(
    'Arquitecta',
    'assets/profile_icons/focus_architect_female.png',
  ),
  _ProfileIconOption(
    'Abogada',
    'assets/profile_icons/focus_lawyer_female.png',
  ),
  _ProfileIconOption('Cool', 'assets/profile_icons/focus_pink_cool.png'),
  _ProfileIconOption(
    'Cool F',
    'assets/profile_icons/focus_pink_cool_female.png',
  ),
  _ProfileIconOption(
    'Creativa F',
    'assets/profile_icons/focus_pink_skater.png',
  ),
  _ProfileIconOption(
    'Skater F',
    'assets/profile_icons/focus_pink_skater_female.png',
  ),
  _ProfileIconOption('DJ', 'assets/profile_icons/focus_pink_music.png'),
  _ProfileIconOption(
    'DJ F',
    'assets/profile_icons/focus_pink_music_female.png',
  ),
  _ProfileIconOption(
    'Social F',
    'assets/profile_icons/focus_pink_artist.png',
  ),
  _ProfileIconOption(
    'Artista F',
    'assets/profile_icons/focus_pink_artist_female.png',
  ),
  _ProfileIconOption('Basket', 'assets/profile_icons/focus_red_basket.png'),
  _ProfileIconOption(
    'Cámara',
    'assets/profile_icons/focus_purple_camera.png',
  ),
  _ProfileIconOption('Tech', 'assets/profile_icons/focus_green_tech.png'),
  _ProfileIconOption('Gamer', 'assets/profile_icons/focus_black_gamer.png'),
  _ProfileIconOption(
    'Viaje',
    'assets/profile_icons/focus_orange_travel.png',
  ),
  _ProfileIconOption('Gym', 'assets/profile_icons/focus_yellow_gym.png'),
];

// ignore: unused_element
const _socialMascots = [
  _MascotOption('Búho', Icons.psychology_alt_rounded, FocusPalette.primary),
  _MascotOption('Cohete', Icons.rocket_launch_rounded, FocusPalette.amber),
  _MascotOption('Hoja', Icons.eco_rounded, FocusPalette.mint),
  _MascotOption('Rayo', Icons.bolt_rounded, FocusPalette.amber),
];

int _safeIndex(Object? value, int length) {
  final parsed = int.tryParse('$value') ?? 0;
  if (length <= 0) return 0;
  return parsed.clamp(0, length - 1).toInt();
}

int _safeProfileIconIndex(Object? value) {
  final index = _safeIndex(value, _profileIcons.length);
  return _isProfileIconAllowed(_profileIcons[index].asset) ? index : 0;
}

bool _isProfileIconAllowed(String asset) {
  return isProfileIconAllowedForEmail(asset, RankingService.currentUser?.email);
}

List<int> _availableProfileIconIndexes() {
  final indexes = <int>[];
  for (var index = 0; index < _profileIcons.length; index++) {
    if (_isProfileIconAllowed(_profileIcons[index].asset)) {
      indexes.add(index);
    }
  }
  return indexes.isEmpty ? const [0] : indexes;
}

String _profileIconAssetForDisplay(int index) {
  final safeIndex = _safeIndex(index, _profileIcons.length);
  return _profileIcons[safeIndex].asset;
}

Color _profileIconAccent(String asset) {
  final normalized = asset.toLowerCase();
  if (normalized.contains('dark')) return const Color(0xFF38BDF8);
  if (normalized.contains('flame')) return FocusPalette.softAlert;
  if (normalized.contains('calm')) return FocusPalette.mint;
  if (normalized.contains('champion')) return const Color(0xFFF59E0B);
  if (normalized.contains('pink')) return const Color(0xFFEC4899);
  if (normalized.contains('red')) return FocusPalette.softAlert;
  if (normalized.contains('purple')) return const Color(0xFF8B5CF6);
  if (normalized.contains('green')) return const Color(0xFF10B981);
  if (normalized.contains('black')) return const Color(0xFF38BDF8);
  if (normalized.contains('orange')) return FocusPalette.softAlert;
  if (normalized.contains('yellow')) return const Color(0xFFEAB308);
  if (normalized.contains('programmer')) return const Color(0xFF6366F1);
  if (normalized.contains('doctor')) return FocusPalette.softAlert;
  if (normalized.contains('teacher')) return const Color(0xFF14B8A6);
  if (normalized.contains('engineer')) return const Color(0xFF0EA5E9);
  if (normalized.contains('architect')) return FocusPalette.softAlert;
  if (normalized.contains('lawyer')) return const Color(0xFF8B5CF6);
  return FocusPalette.primary;
}

int _profileStreak(RankingProfile profile) {
  return int.tryParse('${profile.stats['currentStreak'] ?? 0}') ?? 0;
}

String _friendInviteLink(String code) {
  final encoded = Uri.encodeComponent(code);
  return 'https://policode.netlify.app/focus?friend=$encoded';
}

_SocialStatus _socialStatus(RankingProfile profile) {
  final now = DateTime.now();
  final active = profile.lastActive;
  final event = profile.lastPointEvent.toLowerCase();
  final streak = _profileStreak(profile);
  if (active != null && now.difference(active).inMinutes <= 45) {
    if (event == 'pomodoro') {
      return const _SocialStatus(
        'Estudió hace poco',
        Icons.timer_rounded,
        FocusPalette.mint,
      );
    }
    if (event == 'habit') {
      return const _SocialStatus(
        'Completó un hábito',
        Icons.check_circle_rounded,
        FocusPalette.teal,
      );
    }
    return const _SocialStatus(
      'Activo recientemente',
      Icons.bolt_rounded,
      FocusPalette.cyan,
      FocusMetricIconKind.points,
    );
  }
  if (active != null && _isSameDay(active, now)) {
    return const _SocialStatus(
      'Estudió hoy',
      Icons.school_rounded,
      FocusPalette.primary,
    );
  }
  if (streak > 0) {
    return const _SocialStatus(
      'Racha activa',
      Icons.local_fire_department_rounded,
      FocusPalette.amber,
      FocusMetricIconKind.streak,
    );
  }
  if (active != null) {
    final days = now.difference(active).inDays.clamp(1, 999);
    return _SocialStatus(
      'Última vez hace $days d',
      Icons.history_rounded,
      FocusPalette.muted,
    );
  }
  return const _SocialStatus(
    'Listo para enfocarse',
    Icons.auto_awesome_rounded,
    FocusPalette.muted,
  );
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SocialStatus {
  final String label;
  final IconData icon;
  final Color color;
  final FocusMetricIconKind? metricIcon;

  const _SocialStatus(
    this.label,
    this.icon,
    this.color, [
    this.metricIcon,
  ]);
}

List<_AchievementProgress> _nextAchievementProgress(
  AppProvider provider,
  Set<String> unlockedBadges,
) {
  final items = <_AchievementProgress>[
    _AchievementProgress(
      id: 'first_pomodoro',
      current: provider.pomodoros.length,
      target: 1,
      unitSingular: 'sesión',
      unitPlural: 'sesiones',
    ),
    _AchievementProgress(
      id: 'first_habit',
      current: provider.totalHabitCompletions,
      target: 1,
      unitSingular: 'hábito',
      unitPlural: 'hábitos',
    ),
    _AchievementProgress(
      id: 'pomodoros_5',
      current: provider.pomodoros.length,
      target: 5,
      unitSingular: 'sesión',
      unitPlural: 'sesiones',
    ),
    _AchievementProgress(
      id: 'habits_5',
      current: provider.totalHabitCompletions,
      target: 5,
      unitSingular: 'hábito',
      unitPlural: 'hábitos',
    ),
    _AchievementProgress(
      id: 'streak_3',
      current: provider.currentStreak,
      target: 3,
      unitSingular: 'día de racha',
      unitPlural: 'días de racha',
    ),
    _AchievementProgress(
      id: 'streak_7',
      current: provider.currentStreak,
      target: 7,
      unitSingular: 'día de racha',
      unitPlural: 'días de racha',
    ),
    _AchievementProgress(
      id: 'streak_14',
      current: provider.currentStreak,
      target: 14,
      unitSingular: 'día de racha',
      unitPlural: 'días de racha',
    ),
    _AchievementProgress(
      id: 'streak_30',
      current: provider.currentStreak,
      target: 30,
      unitSingular: 'día de racha',
      unitPlural: 'días de racha',
    ),
    _AchievementProgress(
      id: 'pomodoros_25',
      current: provider.pomodoros.length,
      target: 25,
      unitSingular: 'sesión',
      unitPlural: 'sesiones',
    ),
    _AchievementProgress(
      id: 'pomodoros_100',
      current: provider.pomodoros.length,
      target: 100,
      unitSingular: 'sesión',
      unitPlural: 'sesiones',
    ),
    _AchievementProgress(
      id: 'weekly_mission',
      current: provider.weeklyMissionProgressCount,
      target: provider.weeklyMissionTarget,
      unitSingular: 'pomodoro semanal',
      unitPlural: 'pomodoros semanales',
    ),
    _AchievementProgress(
      id: 'habits_30',
      current: provider.totalHabitCompletions,
      target: 30,
      unitSingular: 'hábito',
      unitPlural: 'hábitos',
    ),
    _AchievementProgress(
      id: 'habits_75',
      current: provider.totalHabitCompletions,
      target: 75,
      unitSingular: 'hábito',
      unitPlural: 'hábitos',
    ),
    _AchievementProgress(
      id: 'max_level',
      current: provider.level,
      target: AppProvider.maxLevel,
      unitSingular: 'nivel',
      unitPlural: 'niveles',
    ),
  ];

  return items
      .where((item) => !unlockedBadges.contains(item.id) && !item.completed)
      .toList()
    ..sort((a, b) => b.progress.compareTo(a.progress));
}

class _AchievementProgress {
  final String id;
  final int current;
  final int target;
  final String unitSingular;
  final String unitPlural;

  const _AchievementProgress({
    required this.id,
    required this.current,
    required this.target,
    required this.unitSingular,
    required this.unitPlural,
  });

  bool get completed => current >= target;
  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);

  String get remainingText {
    final remaining = (target - current).clamp(0, target);
    if (remaining == 0) return 'Listo para desbloquear.';
    final unit = remaining == 1 ? unitSingular : unitPlural;
    return 'Te faltan $remaining $unit.';
  }
}

int _profileBestStreak(RankingProfile profile) {
  return int.tryParse('${profile.stats['bestStreak'] ?? 0}') ??
      _profileStreak(profile);
}

String _rankMedalAsset(String rank) {
  return FocusIconAssets.league(rank);
}

String _leagueLabel(String rank) {
  return switch (rank.trim().toLowerCase()) {
    'oro' || 'diamante' || 'platino' => 'Oro',
    'plata' => 'Plata',
    _ => 'Bronce',
  };
}

/*
                Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FocusPalette.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        code,
                        style: TextStyle(
                          color: FocusPalette.ink.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton.filledTonal(
                    tooltip: 'Copiar código',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.86),
                      foregroundColor: FocusPalette.ink,
                    ),
                    onPressed: () => onCopy(code),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 74),
                  child: _FocusAvatar(name: profile.name, size: 112),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Row(
              children: [
                _SocialStat(label: 'Perfil', value: '$friendsCount'),
                _SocialStat(label: 'Puntos', value: '${profile.weeklyPoints}'),
                _SocialStat(
                  label: 'Racha',
                  value: '${profile.stats['currentStreak'] ?? 0}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
*/

// ignore: unused_element
class _FocusAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _FocusAvatar({
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: _InitialAvatar(name: name, size: size * 0.78),
      ),
    );
  }
}

// ignore: unused_element
class _CompactFriendHeader extends StatelessWidget {
  final RankingProfile profile;
  final int friendsCount;
  final Future<void> Function(String code) onCopy;

  const _CompactFriendHeader({
    required this.profile,
    required this.friendsCount,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final code = RankingService.friendCodeForUid(profile.uid);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: FocusPalette.studyGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _InitialAvatar(name: profile.name, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  friendsCount == 0 ? 'Perfil' : '$friendsCount amigos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Copiar código',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: FocusPalette.primaryDeep,
            ),
            onPressed: () => onCopy(code),
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _FriendCodeHero extends StatelessWidget {
  final RankingProfile profile;
  final int friendsCount;
  final Future<void> Function(String code) onCopy;

  const _FriendCodeHero({
    required this.profile,
    required this.friendsCount,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final code = RankingService.friendCodeForUid(profile.uid);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: FocusPalette.studyGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: FocusPalette.primaryDeep.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 4,
            child: Icon(
              Icons.groups_3_rounded,
              color: Colors.white.withValues(alpha: 0.12),
              size: 86,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _InitialAvatar(name: profile.name, size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Círculo Focus',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          friendsCount == 0
                              ? 'Invita compañeros y compara puntos.'
                              : '$friendsCount amigos activos.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white.withValues(alpha: 0.13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tu código de amigo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: FocusPalette.primaryDeep,
                      ),
                      onPressed: () => onCopy(code),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copiar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    icon: Icons.emoji_events_rounded,
                    label: 'Ranking por puntos',
                  ),
                  _HeroChip(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Solicitudes rápidas',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsPanel extends StatelessWidget {
  final Widget child;

  const _FriendsPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return FocusSurfaceCard(
      padding: const EdgeInsets.all(12),
      radius: 22,
      elevated: true,
      child: child,
    );
  }
}

class _FriendsHubDuo extends StatefulWidget {
  final List<RankingProfile> friends;
  final Widget search;
  final Widget requests;
  final Widget list;

  const _FriendsHubDuo({
    required this.friends,
    required this.search,
    required this.requests,
    required this.list,
  });

  @override
  State<_FriendsHubDuo> createState() => _FriendsHubDuoState();
}

class _FriendsHubDuoState extends State<_FriendsHubDuo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _FriendsPanel(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _expanded
                      ? FocusPalette.primary.withValues(alpha: 0.65)
                      : FocusPalette.muted.withValues(alpha: 0.35),
                  width: 2,
                ),
                color: _expanded
                    ? FocusPalette.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 25),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'AGREGA AMIGOS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                    ),
                  ),
                  if (widget.friends.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: FocusPalette.primary.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        '${widget.friends.length}',
                        style: const TextStyle(
                          color: FocusPalette.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.28),
                ),
                child: Column(
                  children: [
                    widget.search,
                    const SizedBox(height: 12),
                    widget.requests,
                    const SizedBox(height: 12),
                    widget.list,
                  ],
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _FriendsHub extends StatelessWidget {
  final List<RankingProfile> friends;
  final Widget search;
  final Widget requests;
  final Widget list;

  const _FriendsHub({
    required this.friends,
    required this.search,
    required this.requests,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    return _FriendsPanel(
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 14),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: null,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: FocusPalette.studyGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.group_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perfil',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friends.isEmpty
                        ? 'Busca por código o nombre'
                        : '${friends.length} amigos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FocusPalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            if (friends.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: FocusPalette.primary.withValues(alpha: 0.1),
                ),
                child: Text(
                  '${friends.length}',
                  style: const TextStyle(
                    color: FocusPalette.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        /* old friends tile
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.people_alt_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: const Text(
            'Perfil',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            friends.isEmpty
                ? 'Busca y agrega compañeros'
                : '${friends.length} amigos',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          */
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.28),
            ),
            child: Column(
              children: [
                search,
                const SizedBox(height: 12),
                requests,
                list,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CollapsibleFriendsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _CollapsibleFriendsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _FriendsPanel(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return FocusSectionHeader(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: action,
      iconSize: 36,
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _InitialAvatar({
    required this.name,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'F' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: FocusPalette.calmGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ProfileIconAvatar extends StatelessWidget {
  final RankingProfile profile;
  final double size;

  const _ProfileIconAvatar({
    required this.profile,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    final index = _safeIndex(
      profile.stats['socialMascotIndex'],
      _profileIcons.length,
    );
    final asset = _profileIconAssetForDisplay(index);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  FocusPalette.primary.withValues(alpha: 0.12),
                  FocusPalette.cyan.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          _ProfileIconArtwork(
            asset: asset,
            size: size,
            animate: true,
          ),
        ],
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyInline({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return FocusInlineState(icon: icon, text: text);
  }
}

// ignore: unused_element
class _FocusSummaryGrid extends StatelessWidget {
  final RankingProfile profile;

  const _FocusSummaryGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    final streak = int.tryParse('${profile.stats['currentStreak'] ?? 0}') ?? 0;
    return _SocialSection(
      title: 'Resumen',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.9,
        children: [
          _SummaryItem(
            icon: Icons.local_fire_department_rounded,
            metricIcon: FocusMetricIconKind.streak,
            color: FocusPalette.amber,
            value: '$streak días',
          ),
          _SummaryItem(
            icon: Icons.stars_rounded,
            metricIcon: FocusMetricIconKind.points,
            color: FocusPalette.amber,
            value: '${profile.totalPoints} pts',
          ),
          _SummaryItem(
            icon: Icons.emoji_events_rounded,
            assetIcon: _rankMedalAsset(profile.rank),
            color: FocusPalette.cyan,
            value: _leagueLabel(profile.rank),
          ),
          _SummaryItem(
            icon: Icons.timer_rounded,
            color: FocusPalette.mint,
            value: '${profile.pomodoros} sesiones',
          ),
        ],
      ),
    );
  }
}

class _AchievementProgressSection extends StatelessWidget {
  final AppProvider provider;
  final Set<String> unlockedBadges;

  const _AchievementProgressSection({
    required this.provider,
    required this.unlockedBadges,
  });

  @override
  Widget build(BuildContext context) {
    final items =
        _nextAchievementProgress(provider, unlockedBadges).take(3).toList();
    return _SocialSection(
      title: 'Logros en progreso',
      child: items.isEmpty
          ? const FocusInlineState(
              icon: Icons.workspace_premium_rounded,
              text: 'Ya tienes todos los logros principales desbloqueados.',
              accent: FocusPalette.amber,
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _AchievementProgressTile(item: items[index]),
                  if (index != items.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _AchievementProgressTile extends StatelessWidget {
  final _AchievementProgress item;

  const _AchievementProgressTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final info = badgeVisualInfo(item.id);
    return FocusSurfaceCard(
      padding: const EdgeInsets.all(13),
      radius: 20,
      elevated: false,
      accent: info.color,
      child: Row(
        children: [
          Image.asset(
            info.asset,
            width: 34,
            height: 34,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(info.icon, color: info.color, size: 24),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        info.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${item.current.clamp(0, item.target)} / ${item.target}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: item.progress,
                  color: info.color,
                  backgroundColor: info.color.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 6),
                Text(
                  item.remainingText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: FocusPalette.muted,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendStreaks extends StatelessWidget {
  final RankingProfile profile;
  final List<RankingProfile> friends;

  const _FriendStreaks({
    required this.profile,
    required this.friends,
  });

  @override
  Widget build(BuildContext context) {
    return _SocialSection(
      title: 'Rachas entre amigos',
      child: StreamBuilder<List<FriendStreak>>(
        stream: FriendsService.friendStreaksStream(),
        builder: (context, streakSnapshot) {
          final streaks = streakSnapshot.data ?? const <FriendStreak>[];
          final visibleStreaks = streaks.take(5).toList();
          final emptySlots =
              (5 - visibleStreaks.length - 1).clamp(0, 4).toInt();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<List<FriendStreakRequest>>(
                stream: FriendsService.incomingStreakRequestsStream(),
                builder: (context, requestSnapshot) {
                  final requests =
                      requestSnapshot.data ?? const <FriendStreakRequest>[];
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      ...requests.map(
                        (request) => _StreakRequestTile(
                          request: request,
                          onChanged: () {},
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ...visibleStreaks.map(
                      (streak) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _StreakBubble(
                          streak: streak,
                          currentUser: profile,
                        ),
                      ),
                    ),
                    if (visibleStreaks.length < 5)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _AddFriendBubble(
                          onTap: () => _showStartStreakSheet(
                            context,
                            friends,
                            streaks,
                          ),
                        ),
                      ),
                    ...List.generate(
                      emptySlots,
                      (_) => const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _EmptyStreakBubble(),
                      ),
                    ),
                  ],
                ),
              ),
              if (streaks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Aún no tienes rachas privadas. Toca + para invitar a un amigo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FocusPalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _RecentBadges extends StatelessWidget {
  final RankingProfile profile;

  const _RecentBadges({required this.profile});

  @override
  Widget build(BuildContext context) {
    final badges = profile.badges.reversed.take(5).toList();
    return _SocialSection(
      title: 'Últimas insignias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: badges.isEmpty
                  ? const [
                      _EmptyBadgeBubble(),
                    ]
                  : badges
                      .map(
                        (badgeId) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _BadgeBubble(badgeId: badgeId),
                        ),
                      )
                      .toList(),
            ),
          ),
          if (badges.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Completa pomodoros, rachas y hábitos para ganar insignias.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FocusPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _RecentBadgesDuo extends StatelessWidget {
  final RankingProfile profile;

  const _RecentBadgesDuo({required this.profile});

  @override
  Widget build(BuildContext context) {
    final badges = profile.badges.reversed.take(5).toList();
    final emptySlots = (5 - badges.length).clamp(0, 5).toInt();
    return _SocialSection(
      title: 'Logros',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                ...badges.map(
                  (badgeId) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _BadgeBubble(badgeId: badgeId),
                  ),
                ),
                ...List.generate(
                  emptySlots,
                  (_) => const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: _EmptyBadgeBubble(),
                  ),
                ),
              ],
            ),
          ),
          if (badges.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Completa sesiones y hábitos para desbloquear logros.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FocusPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllBadgesGrid extends StatelessWidget {
  final RankingProfile profile;

  const _AllBadgesGrid({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = profile.badges.toSet();
    final orderedBadges = [
      ...achievementBadgeIds.where(unlocked.contains),
      ...profile.badges.where((id) => !achievementBadgeIds.contains(id)),
    ];
    final badges = orderedBadges.toSet().toList();

    return _SocialSection(
      title: 'Insignias',
      child: badges.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _EmptyBadgeBubble(),
                const SizedBox(height: 6),
                Text(
                  'Completa sesiones y hábitos para desbloquear insignias.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FocusPalette.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: badges.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 14,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final badgeId = badges[index];
                return _BadgeBubble(badgeId: badgeId);
              },
            ),
    );
  }
}

class _BadgeBubble extends StatelessWidget {
  final String badgeId;

  const _BadgeBubble({
    required this.badgeId,
  });

  @override
  Widget build(BuildContext context) {
    final info = badgeVisualInfo(badgeId);
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: info.color.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: info.color.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Image.asset(
                info.asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  info.icon,
                  color: info.color,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBadgeBubble extends StatelessWidget {
  const _EmptyBadgeBubble();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: FocusPalette.muted.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.military_tech_outlined,
              color: FocusPalette.muted.withValues(alpha: 0.75),
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vacío',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FocusPalette.muted,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _MonthlyMedals extends StatelessWidget {
  final RankingProfile profile;
  final int friendsCount;

  const _MonthlyMedals({
    required this.profile,
    required this.friendsCount,
  });

  @override
  Widget build(BuildContext context) {
    final streak = _profileStreak(profile);
    final bestStreak = _profileBestStreak(profile);
    final medals = [
      _MonthlyMedal(
        label: 'Racha',
        icon: Icons.local_fire_department_rounded,
        metricIcon: FocusMetricIconKind.streak,
        color: FocusPalette.amber,
        current: streak,
        goal: 7,
        unlocked: streak >= 7 || profile.badges.contains('streak_7'),
      ),
      _MonthlyMedal(
        label: 'Sesiones',
        icon: Icons.timer_rounded,
        color: FocusPalette.cyan,
        current: profile.pomodoros,
        goal: 10,
        unlocked: profile.pomodoros >= 10,
      ),
      _MonthlyMedal(
        label: 'Foco',
        icon: Icons.shield_rounded,
        color: FocusPalette.mint,
        current: profile.focusMinutes,
        goal: 250,
        unlocked: profile.focusMinutes >= 250,
      ),
      _MonthlyMedal(
        label: 'Social',
        icon: Icons.workspace_premium_rounded,
        color: FocusPalette.amber,
        current: friendsCount,
        goal: 3,
        unlocked: friendsCount >= 3 || bestStreak >= 14,
      ),
    ];
    return _SocialSection(
      title: 'Medallas mensuales',
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: medals.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) => _MedalBubble(medal: medals[index]),
        ),
      ),
    );
  }
}

class _MonthlyMedal {
  final String label;
  final IconData icon;
  final FocusMetricIconKind? metricIcon;
  final Color color;
  final int current;
  final int goal;
  final bool unlocked;

  const _MonthlyMedal({
    required this.label,
    required this.icon,
    this.metricIcon,
    required this.color,
    required this.current,
    required this.goal,
    required this.unlocked,
  });

  double get progress => goal <= 0 ? 0 : (current / goal).clamp(0, 1);
}

class _SocialSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SocialSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: FocusPalette.muted,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String? assetIcon;
  final FocusMetricIconKind? metricIcon;
  final Color color;
  final String value;

  const _SummaryItem({
    required this.icon,
    this.assetIcon,
    this.metricIcon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          if (metricIcon != null)
            FocusMetricIcon(kind: metricIcon!, size: 24, color: color)
          else if (assetIcon == null)
            Icon(icon, color: color)
          else
            Image.asset(
              assetIcon!,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBubble extends StatelessWidget {
  final FriendStreak streak;
  final RankingProfile currentUser;

  const _StreakBubble({
    required this.streak,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final sharedStreak =
        _sharedStreak(currentUser, streak.friend).clamp(0, 999).toInt();
    final active = sharedStreak > 0;
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _confirmRemoveStreak(context, streak),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _ProfileIconAvatar(profile: streak.friend, size: 62),
                Positioned(
                  right: 3,
                  bottom: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: active ? FocusPalette.amber : FocusPalette.muted,
                      border: Border.all(
                        color: Theme.of(context).cardColor,
                        width: 3,
                      ),
                    ),
                    child: Text(
                      sharedStreak <= 0 ? '0' : '$sharedStreak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            streak.friend.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

int _sharedStreak(RankingProfile a, RankingProfile b) {
  final first = _profileStreak(a);
  final second = _profileStreak(b);
  if (first <= 0 || second <= 0) return 0;
  return first < second ? first : second;
}

Future<void> _confirmRemoveStreak(
  BuildContext context,
  FriendStreak streak,
) async {
  final remove = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar racha'),
      content: Text('¿Quieres quitar la racha con ${streak.friend.name}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (remove != true || !context.mounted) return;
  try {
    await FriendsService.removeStreak(streak.id);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: FocusActionSnackContent(
          icon: Icons.error_outline_rounded,
          message: RankingService.friendlyRankingError(error),
          color: FocusPalette.danger,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

void _showStartStreakSheet(
  BuildContext context,
  List<RankingProfile> friends,
  List<FriendStreak> streaks,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _StartStreakSheet(
      rootContext: context,
      friends: friends,
      streaks: streaks,
    ),
  );
}

class _StartStreakSheet extends StatefulWidget {
  final BuildContext rootContext;
  final List<RankingProfile> friends;
  final List<FriendStreak> streaks;

  const _StartStreakSheet({
    required this.rootContext,
    required this.friends,
    required this.streaks,
  });

  @override
  State<_StartStreakSheet> createState() => _StartStreakSheetState();
}

class _StartStreakSheetState extends State<_StartStreakSheet> {
  String? _sendingUid;

  @override
  Widget build(BuildContext context) {
    final activeIds = widget.streaks.map((streak) => streak.friend.uid).toSet();
    final candidates = widget.friends
        .where((friend) => !activeIds.contains(friend.uid))
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Iniciar racha',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              candidates.isEmpty
                  ? 'Agrega amigos primero o elimina una racha activa.'
                  : 'Elige un amigo. La racha empieza cuando acepte.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (candidates.isEmpty)
              const _EmptyInline(
                icon: Icons.people_alt_rounded,
                text: 'No hay amigos disponibles para una nueva racha.',
              )
            else
              ...candidates.take(12).map(
                    (friend) => _ProfileTile(
                      profile: friend,
                      trailing: IconButton.filledTonal(
                        tooltip: 'Invitar a racha',
                        onPressed: _sendingUid == null
                            ? () async {
                                setState(() => _sendingUid = friend.uid);
                                HapticFeedback.selectionClick();
                                try {
                                  Navigator.of(context).pop();
                                  await FriendsService.sendStreakRequest(
                                      friend);
                                  if (!widget.rootContext.mounted) return;
                                  ScaffoldMessenger.of(widget.rootContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Invitación de racha enviada a ${friend.name}.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (error) {
                                  if (!widget.rootContext.mounted) return;
                                  ScaffoldMessenger.of(widget.rootContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        RankingService.friendlyRankingError(
                                          error,
                                        ),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _sendingUid = null);
                                  }
                                }
                              }
                            : null,
                        icon: _sendingUid == friend.uid
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.local_fire_department_rounded),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StreakRequestTile extends StatelessWidget {
  final FriendStreakRequest request;
  final VoidCallback onChanged;

  const _StreakRequestTile({
    required this.request,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: FocusPalette.amber.withValues(alpha: 0.08),
        border: Border.all(color: FocusPalette.amber.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: FocusPalette.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${request.fromName} quiere iniciar una racha contigo.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Aceptar',
            onPressed: () async {
              try {
                await FriendsService.acceptStreakRequest(request);
                onChanged();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(RankingService.friendlyRankingError(error)),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_rounded),
          ),
          IconButton(
            tooltip: 'Rechazar',
            onPressed: () async {
              try {
                await FriendsService.rejectStreakRequest(request);
                onChanged();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(RankingService.friendlyRankingError(error)),
                  ),
                );
              }
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _MedalBubble extends StatelessWidget {
  final _MonthlyMedal medal;

  const _MedalBubble({required this.medal});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Opacity(
            opacity: medal.unlocked ? 1 : 0.48,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    medal.color.withValues(alpha: 0.95),
                    medal.color.withValues(alpha: 0.55),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: medal.color.withValues(
                      alpha: medal.unlocked ? 0.22 : 0.0,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: medal.unlocked && medal.metricIcon != null
                  ? Center(
                      child: FocusMetricIcon(
                        kind: medal.metricIcon!,
                        size: 34,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      medal.unlocked ? medal.icon : Icons.lock_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            medal.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: medal.progress,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(medal.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _SocialInfoSection extends StatelessWidget {
  final RankingProfile profile;
  final int friendsCount;

  const _SocialInfoSection({
    required this.profile,
    required this.friendsCount,
  });

  @override
  Widget build(BuildContext context) {
    final nextUpdate = RankingService.nextHourlyUpdate();
    final reset = RankingService.nextWeeklyReset();
    final updateLabel = '${nextUpdate.hour.toString().padLeft(2, '0')}:00';
    final resetLabel =
        '${reset.day.toString().padLeft(2, '0')}/${reset.month.toString().padLeft(2, '0')}';
    return _FriendsPanel(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 10),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: const Text(
            'Cómo funciona',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Perfil, ranking, rachas y medallas'),
          children: [
            _InfoTile(
              icon: Icons.public_rounded,
              title: 'Ranking global',
              text:
                  'Ordena a todos por puntos semanales. Se actualiza cerca de $updateLabel y reinicia el $resetLabel.',
            ),
            _InfoTile(
              icon: Icons.groups_rounded,
              title: 'Ranking de amigos',
              text:
                  'Compara tus puntos solo con tus amigos. Ahora tienes $friendsCount amigos agregados.',
            ),
            _InfoTile(
              icon: Icons.local_fire_department_rounded,
              title: 'Rachas entre amigos',
              text:
                  'Muestra quién mantiene más días de estudio seguidos. Tu racha actual es ${_profileStreak(profile)} días.',
            ),
            _InfoTile(
              icon: Icons.military_tech_rounded,
              title: 'Medallas mensuales',
              text:
                  'Se desbloquean por constancia: racha, sesiones, minutos de enfoque y actividad social.',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFriendBubble extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddFriendBubble({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: FocusPalette.muted.withValues(alpha: 0.45),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          color: FocusPalette.muted.withValues(alpha: 0.8),
          size: 30,
        ),
      ),
    );
  }
}

class _EmptyStreakBubble extends StatelessWidget {
  const _EmptyStreakBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: FocusPalette.muted.withValues(alpha: 0.28),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.add_rounded,
        color: FocusPalette.muted.withValues(alpha: 0.38),
        size: 28,
      ),
    );
  }
}

// ignore: unused_element
class _FriendsRanking extends StatelessWidget {
  final Future<List<RankingEntry>>? future;
  final int friendsCount;
  final VoidCallback onRefresh;

  const _FriendsRanking({
    required this.future,
    required this.friendsCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return _FriendsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.leaderboard_rounded,
            title: 'Ranking de amigos',
            subtitle: friendsCount == 0
                ? 'Apareces tú hasta que agregues compañeros.'
                : 'Competencia semanal solo por puntos.',
            action: IconButton(
              tooltip: 'Actualizar',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<RankingEntry>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const FocusSkeletonColumn(
                  heights: [74, 64],
                  spacing: 10,
                );
              }
              if (snapshot.hasError) {
                return _EmptyInline(
                  icon: Icons.warning_amber_rounded,
                  text: RankingService.friendlyRankingError(snapshot.error),
                );
              }
              final entries = snapshot.data ?? const <RankingEntry>[];
              if (entries.isEmpty) {
                return const _EmptyInline(
                  icon: Icons.leaderboard_rounded,
                  text: 'Completa un Pomodoro para empezar tu ranking.',
                );
              }
              final leader = entries.first;
              return Column(
                children: [
                  _LeaderCard(entry: leader),
                  const SizedBox(height: 10),
                  ...entries.skip(1).map((entry) => _FriendRankTile(
                        entry: entry,
                        isCurrentUser:
                            entry.uid == RankingService.currentUser?.uid,
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final RankingEntry entry;

  const _LeaderCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = entry.uid == RankingService.currentUser?.uid;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [FocusPalette.primaryDeep, FocusPalette.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? 'Vas liderando' : 'Líder semanal',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '#1',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${entry.points} pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FriendRankTile extends StatelessWidget {
  final RankingEntry entry;
  final bool isCurrentUser;

  const _FriendRankTile({
    required this.entry,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final accent = entry.position <= 3
        ? FocusPalette.amber
        : Theme.of(context).colorScheme.primary;
    return FocusFriendCard(
      title: isCurrentUser ? '${entry.name} (tú)' : entry.name,
      subtitle: entry.career,
      leadingLabel: '#${entry.position}',
      trailingLabel: '${entry.points} pts',
      accent: accent,
      highlighted: isCurrentUser,
    );
  }
}

class _RequestsCard extends StatefulWidget {
  final VoidCallback onChanged;
  final bool compact;

  const _RequestsCard({
    required this.onChanged,
    this.compact = false,
  });

  @override
  State<_RequestsCard> createState() => _RequestsCardState();
}

class _RequestsCardState extends State<_RequestsCard> {
  bool _showSent = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: FriendsService.incomingRequestsStream(),
      builder: (context, incomingSnapshot) {
        if (incomingSnapshot.hasError) {
          return _FriendsPanel(
            child: _EmptyInline(
              icon: Icons.warning_amber_rounded,
              text: RankingService.friendlyRankingError(incomingSnapshot.error),
            ),
          );
        }
        final incoming = incomingSnapshot.data ?? const <FriendRequest>[];
        return StreamBuilder<List<FriendRequest>>(
          stream: FriendsService.outgoingRequestsStream(),
          builder: (context, outgoingSnapshot) {
            if (outgoingSnapshot.hasError) {
              return _FriendsPanel(
                child: _EmptyInline(
                  icon: Icons.warning_amber_rounded,
                  text: RankingService.friendlyRankingError(
                    outgoingSnapshot.error,
                  ),
                ),
              );
            }
            final outgoing = outgoingSnapshot.data ?? const <FriendRequest>[];
            if (widget.compact && incoming.isEmpty && outgoing.isEmpty) {
              return const SizedBox.shrink();
            }

            final visibleRequests = _showSent ? outgoing : incoming;
            if (_showSent && outgoing.isEmpty && incoming.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _showSent = false);
              });
            }

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanelTitle(
                  icon: Icons.mark_email_unread_rounded,
                  title: 'Solicitudes',
                  subtitle: _showSent
                      ? '${outgoing.length} enviadas pendientes.'
                      : incoming.isEmpty
                          ? 'Sin pendientes por ahora.'
                          : '${incoming.length} esperando respuesta.',
                ),
                const SizedBox(height: 12),
                _RequestTabs(
                  selectedSent: _showSent,
                  incomingCount: incoming.length,
                  outgoingCount: outgoing.length,
                  onChanged: (sent) => setState(() => _showSent = sent),
                ),
                const SizedBox(height: 12),
                if (visibleRequests.isEmpty)
                  _EmptyInline(
                    icon: _showSent
                        ? Icons.send_rounded
                        : Icons.check_circle_outline_rounded,
                    text: _showSent
                        ? 'No tienes solicitudes enviadas.'
                        : 'Cuando alguien use tu código, aparecerá aquí.',
                  )
                else
                  ...visibleRequests.map(
                    (request) => _RequestTile(
                      request: request,
                      outgoing: _showSent,
                      onChanged: widget.onChanged,
                    ),
                  ),
              ],
            );
            if (widget.compact) return content;
            return _FriendsPanel(child: content);
          },
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onChanged;
  final bool outgoing;

  const _RequestTile({
    required this.request,
    required this.onChanged,
    this.outgoing = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = outgoing ? request.toName : request.fromName;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openRequestProfile(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.26),
        ),
        child: Row(
          children: [
            _InitialAvatar(name: displayName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    outgoing
                        ? 'Esperando que acepte tu solicitud.'
                        : 'Quiere agregarte como amigo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (outgoing) ...[
              _TinyProfileChip(
                icon: Icons.schedule_rounded,
                label: 'Pendiente',
                color: FocusPalette.amber,
              ),
              IconButton(
                tooltip: 'Ver perfil',
                onPressed: () => _openRequestProfile(context),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ] else ...[
              IconButton.filledTonal(
                tooltip: 'Aceptar',
                onPressed: () async {
                  try {
                    await FriendsService.acceptRequest(request);
                    onChanged();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: FocusActionSnackContent(
                          icon: Icons.people_alt_rounded,
                          message: '${request.fromName} ya es tu amigo.',
                          color: FocusPalette.mint,
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(RankingService.friendlyRankingError(error)),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded),
              ),
              IconButton(
                tooltip: 'Rechazar',
                onPressed: () async {
                  try {
                    await FriendsService.rejectRequest(request);
                    onChanged();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Solicitud rechazada.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(RankingService.friendlyRankingError(error)),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openRequestProfile(BuildContext context) async {
    final targetUid = outgoing ? request.toUid : request.fromUid;
    try {
      final profile = await RankingService.fetchProfileByUid(targetUid);
      if (!context.mounted) return;
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar ese perfil.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => FocusPublicProfileSheet(
          profile: profile,
          isFriend: false,
          statusLabel: outgoing ? 'Solicitud pendiente' : 'Solicitud recibida',
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(RankingService.friendlyRankingError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _RequestTabs extends StatelessWidget {
  final bool selectedSent;
  final int incomingCount;
  final int outgoingCount;
  final ValueChanged<bool> onChanged;

  const _RequestTabs({
    required this.selectedSent,
    required this.incomingCount,
    required this.outgoingCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.34),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RequestTabButton(
              label: 'Recibidas',
              count: incomingCount,
              selected: !selectedSent,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _RequestTabButton(
              label: 'Enviadas',
              count: outgoingCount,
              selected: selectedSent,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _RequestTabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? FocusPalette.primary : FocusPalette.muted;
    return Material(
      color: selected ? FocusPalette.primary.withValues(alpha: 0.12) : null,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final Future<List<RankingProfile>>? searchFuture;
  final List<RankingProfile> friends;
  final VoidCallback onSearch;
  final Future<void> Function(RankingProfile) onViewProfile;
  final Future<void> Function(RankingProfile, List<RankingProfile>)
      onPreviewProfile;

  const _SearchCard({
    required this.controller,
    required this.searchFuture,
    required this.friends,
    required this.onSearch,
    required this.onViewProfile,
    required this.onPreviewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Theme.of(context).cardColor,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Código o nombre',
                    hintText: 'FOC-ABC123 o Nelson',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              IconButton.filled(
                tooltip: 'Buscar',
                onPressed: onSearch,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
        if (searchFuture != null) ...[
          const SizedBox(height: 8),
          FutureBuilder<List<RankingProfile>>(
            future: searchFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const FocusSkeletonColumn(
                  heights: [64, 64],
                  spacing: 8,
                );
              }
              if (snapshot.hasError) {
                return _EmptyInline(
                  icon: Icons.warning_amber_rounded,
                  text: RankingService.friendlyRankingError(snapshot.error),
                );
              }
              final results = snapshot.data ?? const <RankingProfile>[];
              if (results.isEmpty) {
                return const _EmptyInline(
                  icon: Icons.person_search_rounded,
                  text: 'No encontramos ese perfil. Revisa el código.',
                );
              }
              return Column(
                children: results.asMap().entries.map((item) {
                  final profile = item.value;
                  final isFriend =
                      friends.any((friend) => friend.uid == profile.uid);
                  return _ProfileReveal(
                    index: item.key,
                    child: _ProfileTile(
                      profile: profile,
                      onTap: () => onPreviewProfile(profile, friends),
                      trailing: IconButton.filledTonal(
                        tooltip: isFriend ? 'Ver perfil' : 'Ver y agregar',
                        onPressed: () => isFriend
                            ? onViewProfile(profile)
                            : onPreviewProfile(profile, friends),
                        icon: Icon(
                          isFriend
                              ? Icons.chevron_right_rounded
                              : Icons.person_add_alt_1_rounded,
                        ),
                      ),
                      statusChip: isFriend
                          ? const _TinyProfileChip(
                              icon: Icons.check_circle_rounded,
                              label: 'Ya es amigo',
                              color: FocusPalette.mint,
                            )
                          : const _TinyProfileChip(
                              icon: Icons.visibility_rounded,
                              label: 'Ver perfil',
                              color: FocusPalette.cyan,
                            ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _FriendsList extends StatelessWidget {
  final List<RankingProfile> friends;
  final Future<void> Function(RankingProfile) onViewProfile;

  const _FriendsList({
    required this.friends,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const FocusProfileEmptyState(
        icon: Icons.person_add_alt_1_rounded,
        iconKind: FocusAppIconKind.friends,
        accent: FocusPalette.primary,
        title: 'Todavía no agregaste amigos',
        message: 'Busca por código o nombre.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis amigos',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: FocusPalette.muted,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        ...friends.asMap().entries.map(
              (item) => _ProfileReveal(
                index: item.key,
                child: _ProfileTile(
                  profile: item.value,
                  onTap: () => onViewProfile(item.value),
                  trailing: IconButton(
                    tooltip: 'Ver perfil',
                    onPressed: () => onViewProfile(item.value),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _TinyProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TinyProfileChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final background = color.withValues(alpha: 0.10);
    final border = color.withValues(alpha: 0.18);
    final foreground = color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final RankingProfile profile;
  final Widget trailing;
  final VoidCallback? onTap;
  final Widget? statusChip;

  const _ProfileTile({
    required this.profile,
    required this.trailing,
    this.onTap,
    this.statusChip,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Theme.of(context).cardColor,
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            _ProfileIconAvatar(profile: profile, size: 46),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.career,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FocusPalette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  statusChip ?? _InlineSocialStatus(profile: profile),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
