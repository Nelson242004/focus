import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ranking_profile.dart';
import '../services/friends_service.dart';
import '../services/ranking_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/badge_assets.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_drawer.dart';
import '../widgets/focus_layered_avatar.dart';
import '../widgets/focus_profile_mascot.dart';
import 'auth_gate_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  Future<List<RankingProfile>>? _searchFuture;
  late Future<RankingProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = RankingService.ensureProfile();
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

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) {
      setState(() => _profileFuture = RankingService.ensureProfile());
    }
  }

  Future<void> _copyFriendCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'CÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo $code copiado.')),
    );
  }

  Future<void> _shareFriendInvite(RankingProfile profile) async {
    final code = RankingService.friendCodeForUid(profile.uid);
    final message =
        'AgrÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©game en Focus con mi cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo de amigo:\n\n$code\n\nEntra a Perfil > Buscar y pega este cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo.';
    try {
      await Share.share(
        message,
        subject:
            'InvitaciÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n de Focus',
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'InvitaciÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n copiada al portapapeles.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'friends'),
      appBar: AppBar(title: const Text('Perfil')),
      body: RankingService.currentUser == null
          ? _LoginRequiredPanel(onLogin: _openLogin)
          : FutureBuilder<RankingProfile?>(
              future: _profileFuture,
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                return StreamBuilder<List<RankingProfile>>(
                  stream: FriendsService.friendsStream(),
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
                          _DuolingoFriendsHeader(
                            profile: profile!,
                            friendsCount: friends.length,
                            onCopy: _copyFriendCode,
                            onShare: () => _shareFriendInvite(profile),
                          ),
                          const SizedBox(height: 14),
                          _SocialSummaryCard(
                            friendsCount: friends.length,
                            profile: profile,
                          ),
                          const SizedBox(height: 14),
                          _FriendsHubDuo(
                            friends: friends,
                            search: _SearchCard(
                              controller: _searchController,
                              searchFuture: _searchFuture,
                              onSearch: _search,
                              onSendRequest: _sendRequest,
                            ),
                            requests: _RequestsCard(
                              onChanged: () => setState(() {}),
                            ),
                            list: _FriendsList(
                              friends: friends,
                              onRemove: _removeFriend,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FriendStreaks(
                            profile: profile,
                            friends: friends,
                          ),
                          const SizedBox(height: 18),
                          _AllBadgesGrid(profile: profile),
                          /*
                          _CollapsibleFriendsSection(
                            icon: Icons.person_add_alt_1_rounded,
                            title: 'Agregar amigo',
                            subtitle: 'CÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo, nombre o correo',
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

  Future<void> _sendRequest(RankingProfile profile) async {
    try {
      await FriendsService.sendRequest(profile);
      if (!mounted) return;
      setState(() => _searchFuture = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud enviada a ${profile.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RankingService.friendlyRankingError(error))),
      );
    }
  }

  Future<void> _removeFriend(RankingProfile friend) async {
    try {
      await FriendsService.removeFriend(friend.uid);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${friend.name} saliÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³ de tu cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­rculo.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RankingService.friendlyRankingError(error))),
      );
    }
  }
}

class _LoginRequiredPanel extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoginRequiredPanel({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.people_alt_rounded,
      title:
          'Inicia sesiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n para usar tu perfil',
      message:
          'Crea tu perfil para competir con compaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±eros y aparecer en rankings.',
      action: FilledButton.icon(
        onPressed: onLogin,
        icon: const Icon(Icons.login_rounded),
        label: const Text(
            'Iniciar sesiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n'),
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
    final accent = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).cardColor,
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: accent.withValues(alpha: 0.10),
                ),
                child: Icon(icon, size: 30, color: accent),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FocusPalette.muted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 18),
              action,
            ],
          ),
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
    _profileIconIndex = _safeIndex(
      widget.profile.stats['socialMascotIndex'],
      _profileIcons.length,
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
                    _ColorFanButton(
                      selected: _themeIndex,
                      onSelected: (index) async {
                        final previous = _themeIndex;
                        setState(() => _themeIndex = index);
                        try {
                          await RankingService.updateSocialStyle(
                            themeIndex: index,
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          setState(() => _themeIndex = previous);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                RankingService.friendlyRankingError(error),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        foregroundColor: FocusPalette.ink,
                        fixedSize: const Size(38, 38),
                      ),
                      onPressed: widget.onShare,
                      tooltip:
                          'Compartir cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo',
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
                'Elige cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³mo quieres aparecer en Perfil.',
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
                itemCount: _profileIcons.length,
                itemBuilder: (context, index) {
                  final option = _profileIcons[index];
                  return _ProfileIconChoice(
                    option: option,
                    selected: index == _profileIconIndex,
                    onTap: () async {
                      Navigator.pop(context);
                      if (index == _profileIconIndex) return;
                      final previous = _profileIconIndex;
                      setState(() => _profileIconIndex = index);
                      try {
                        await RankingService.updateSocialStyle(
                          mascotIndex: index,
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
  late FocusAvatarConfig _avatarConfig;

  @override
  void initState() {
    super.initState();
    _themeIndex = _safeIndex(
      widget.profile.stats['socialThemeIndex'],
      _socialThemes.length,
    );
    _profileIconIndex = _safeIndex(
      widget.profile.stats['socialMascotIndex'],
      _profileIcons.length,
    );
    _avatarConfig = _avatarConfigFromProfile(widget.profile, _profileIconIndex);
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
        height: 236,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
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
              padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
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
                        const SizedBox(height: 8),
                        _HeaderTinyPill(
                          icon: Icons.auto_awesome_rounded,
                          text: '${profile.totalPoints} pts',
                        ),
                      ],
                    ),
                  ),
                  _ColorFanButton(
                    selected: _themeIndex,
                    onSelected: (index) async {
                      final previous = _themeIndex;
                      setState(() => _themeIndex = index);
                      try {
                        await RankingService.updateSocialStyle(
                          themeIndex: index,
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        setState(() => _themeIndex = previous);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              RankingService.friendlyRankingError(error),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      foregroundColor: Colors.white.withValues(alpha: 0.92),
                      fixedSize: const Size(38, 38),
                      minimumSize: const Size(38, 38),
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    onPressed: widget.onShare,
                    tooltip: 'Compartir código',
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Align(
              alignment: const Alignment(0.08, 0.24),
              child: _ProfileIconBadge(
                option: _profileIcons[_profileIconIndex],
                config: _avatarConfig,
                colors: theme.colors,
                size: 194,
                onTap: () => _showAvatarBuilder(context),
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
                  const Spacer(),
                  _HeaderTinyPill(
                    icon: Icons.groups_rounded,
                    text: '${widget.friendsCount}',
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
        onSelected: (index) async {
          final previousIndex = _profileIconIndex;
          final previousConfig = _avatarConfig;
          final config = FocusAvatarConfig.fromProfileIndex(index);
          setState(() {
            _profileIconIndex = index;
            _avatarConfig = config;
          });
          try {
            await RankingService.updateSocialStyle(mascotIndex: index);
            await RankingService.updateSocialAvatar(config.toMap());
            await WidgetSyncService.syncProfileIconAsset(
              _profileIcons[index].asset,
            );
          } catch (error) {
            if (!mounted) return;
            setState(() {
              _profileIconIndex = previousIndex;
              _avatarConfig = previousConfig;
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

class _HeaderTinyPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeaderTinyPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
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
    final scheme = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : FocusPalette.ink;
    final muted = textColor.withValues(alpha: isDark ? 0.48 : 0.56);
    final surfaceColor = isDark
        ? const Color(0xFF10212A)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : FocusPalette.primary.withValues(alpha: 0.10);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF10212A), Color(0xFF132B33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isDark ? null : surfaceColor,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.045),
            blurRadius: isDark ? 18 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMEN',
            style: TextStyle(
              color: muted,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: isDark
                      ? Colors.white.withValues(alpha: 0.46)
                      : FocusPalette.coral,
                  value: '${_profileStreak(profile)} días',
                  valueColor: textColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.people_alt_rounded,
                  iconColor: FocusPalette.cyan,
                  value: '$friendsCount',
                  valueColor: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.emoji_events_rounded,
                  assetIcon: _rankMedalAsset(profile.rank),
                  iconColor: FocusPalette.cyan,
                  value: profile.rank,
                  valueColor: textColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.bolt_rounded,
                  iconColor: FocusPalette.amber,
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

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String? assetIcon;
  final Color iconColor;
  final String value;
  final Color valueColor;

  const _SummaryMetric({
    required this.icon,
    this.assetIcon,
    required this.iconColor,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (assetIcon == null)
          Icon(icon, color: iconColor, size: 34)
        else
          Image.asset(
            assetIcon!,
            width: 34,
            height: 34,
            fit: BoxFit.contain,
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _ColorFanButton extends StatelessWidget {
  final int selected;
  final Future<void> Function(int index) onSelected;

  const _ColorFanButton({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTheme = _socialThemes[selected];
    return Tooltip(
      message: 'Cambiar fondo',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showColorFan(context),
        child: Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  ...selectedTheme.colors,
                  FocusPalette.amber,
                  FocusPalette.mint,
                  selectedTheme.colors.first,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showColorFan(BuildContext context) {
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
                'Color de fondo',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  _socialThemes.length,
                  (index) => InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      Navigator.pop(context);
                      if (index != selected) await onSelected(index);
                    },
                    child: _ThemeChoicePill(
                      theme: _socialThemes[index],
                      selected: index == selected,
                    ),
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

class _ProfileIconBadge extends StatelessWidget {
  final _ProfileIconOption option;
  final FocusAvatarConfig? config;
  final List<Color> colors;
  final double size;
  final VoidCallback onTap;

  const _ProfileIconBadge({
    required this.option,
    this.config,
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
                  child: FocusProfileMascot(
                    size: size,
                    fallbackConfig: config ??
                        FocusAvatarConfig.fromProfileIndex(
                          _profileIcons.indexOf(option),
                        ),
                    state: FocusMascotState.idle,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 18,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: colors.first,
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
  final VoidCallback onTap;

  const _ProfileIconChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
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
        ),
        child: Column(
          children: [
            Expanded(
              child: FocusProfileMascot(
                size: 72,
                animate: false,
                fallbackConfig: FocusAvatarConfig.fromProfileIndex(
                  _profileIcons.indexOf(option),
                ),
                state: selected
                    ? FocusMascotState.celebrating
                    : FocusMascotState.idle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              option.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: selected ? FocusPalette.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIconPickerSheet extends StatefulWidget {
  final int selectedIndex;
  final Future<void> Function(int index) onSelected;

  const _ProfileIconPickerSheet({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<_ProfileIconPickerSheet> createState() =>
      _ProfileIconPickerSheetState();
}

class _ProfileIconPickerSheetState extends State<_ProfileIconPickerSheet> {
  late final PageController _pageController;
  late int _selectedIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _pageController = PageController(
      initialPage: widget.selectedIndex,
      viewportFraction: 0.48,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _profileIcons[_selectedIndex];
    final config = FocusAvatarConfig.fromProfileIndex(_selectedIndex);
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
                          if (_selectedIndex == widget.selectedIndex) {
                            Navigator.pop(context);
                            return;
                          }
                          setState(() => _saving = true);
                          await widget.onSelected(_selectedIndex);
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
              height: 232,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [
                    FocusPalette.primary.withValues(alpha: 0.12),
                    FocusPalette.cyan.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: RadialGradient(
                          center: const Alignment(0.20, -0.18),
                          colors: [
                            FocusPalette.cyan.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: FocusProfileMascot(
                      size: 196,
                      fallbackConfig: config,
                      state: FocusMascotState.celebrating,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 126,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _profileIcons.length,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                itemBuilder: (context, index) {
                  final option = _profileIcons[index];
                  final active = index == _selectedIndex;
                  return AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: active ? 1 : 0.88,
                    curve: Curves.easeOutBack,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: _ProfileIconChoice(
                        option: option,
                        selected: active,
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                          setState(() => _selectedIndex = index);
                        },
                      ),
                    ),
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
  _SocialTheme('Amanecer', [FocusPalette.coral, FocusPalette.amber]),
  _SocialTheme('Noche', [FocusPalette.ink, FocusPalette.primaryDeep]),
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
];

// ignore: unused_element
const _socialMascots = [
  _MascotOption(
      'BÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âºho',
      Icons.psychology_alt_rounded,
      FocusPalette.primary),
  _MascotOption('Cohete', Icons.rocket_launch_rounded, FocusPalette.coral),
  _MascotOption('Hoja', Icons.eco_rounded, FocusPalette.mint),
  _MascotOption('Rayo', Icons.bolt_rounded, FocusPalette.amber),
];

int _safeIndex(Object? value, int length) {
  final parsed = int.tryParse('$value') ?? 0;
  if (length <= 0) return 0;
  return parsed.clamp(0, length - 1).toInt();
}

FocusAvatarConfig _avatarConfigFromProfile(
  RankingProfile profile,
  int fallbackIndex,
) {
  final raw = profile.stats['socialAvatar'];
  if (raw is Map) {
    return FocusAvatarConfig.fromMap(Map<String, dynamic>.from(raw));
  }
  return FocusAvatarConfig.fromProfileIndex(fallbackIndex);
}

int _profileStreak(RankingProfile profile) {
  return int.tryParse('${profile.stats['currentStreak'] ?? 0}') ?? 0;
}

int _profileBestStreak(RankingProfile profile) {
  return int.tryParse('${profile.stats['bestStreak'] ?? 0}') ??
      _profileStreak(profile);
}

String _rankMedalAsset(String rank) {
  return switch (rank.trim().toLowerCase()) {
    'oro' => 'assets/medals/gold.png',
    'plata' => 'assets/medals/silver.png',
    _ => 'assets/medals/bronze.png',
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
                    tooltip: 'Copiar cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo',
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
            tooltip:
                'Copiar cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo',
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
                          'CÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­rculo Focus',
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
                              ? 'Invita compaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±eros y compara puntos.'
                              : '$friendsCount amigos activos en tu cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­rculo.',
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
                            'Tu cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo de amigo',
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
                    label:
                        'Solicitudes rÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡pidas',
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).cardColor,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                        ? 'Busca por cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo o nombre'
                        : '${friends.length} en tu cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­rculo',
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
                ? 'Busca y agrega compaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±eros'
                : '${friends.length} en tu cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­rculo',
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
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
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
    final config = _avatarConfigFromProfile(profile, index);
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
          FocusLayeredAvatar(
            size: size,
            config: config,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
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
            color: FocusPalette.coral,
            value:
                '$streak dÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­as',
          ),
          _SummaryItem(
            icon: Icons.stars_rounded,
            color: FocusPalette.amber,
            value: '${profile.totalPoints} pts',
          ),
          _SummaryItem(
            icon: Icons.emoji_events_rounded,
            assetIcon: _rankMedalAsset(profile.rank),
            color: FocusPalette.cyan,
            value: profile.rank,
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
                    'AÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âºn no tienes rachas privadas. Toca + para invitar a un amigo.',
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
      title:
          'ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ltimas insignias',
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
                'Completa pomodoros, rachas y hÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡bitos para ganar insignias.',
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
                'Completa sesiones y hÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡bitos para desbloquear logros.',
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

  const _AllBadgesGrid({required this.profile});

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
                  'Completa sesiones y hÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡bitos para desbloquear insignias.',
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
                return _BadgeBubble(badgeId: badges[index]);
              },
            ),
    );
  }
}

class _BadgeBubble extends StatelessWidget {
  final String badgeId;

  const _BadgeBubble({required this.badgeId});

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
              boxShadow: [
                BoxShadow(
                  color: info.color.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Image.asset(
              badgeAssetPath(badgeId),
              fit: BoxFit.contain,
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
            'VacÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­o',
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
        color: FocusPalette.coral,
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
  final Color color;
  final int current;
  final int goal;
  final bool unlocked;

  const _MonthlyMedal({
    required this.label,
    required this.icon,
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
  final Color color;
  final String value;

  const _SummaryItem({
    required this.icon,
    this.assetIcon,
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
          if (assetIcon == null)
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
                      color: active ? FocusPalette.coral : FocusPalette.muted,
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
      content: Text(
          'ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¿Quieres quitar la racha con ${streak.friend.name}?'),
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
      SnackBar(content: Text(RankingService.friendlyRankingError(error))),
    );
  }
}

void _showStartStreakSheet(
  BuildContext context,
  List<RankingProfile> friends,
  List<FriendStreak> streaks,
) {
  final rootContext = context;
  final activeIds = streaks.map((streak) => streak.friend.uid).toSet();
  final candidates =
      friends.where((friend) => !activeIds.contains(friend.uid)).toList();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
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
              style: Theme.of(sheetContext).textTheme.bodySmall,
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
                        onPressed: () async {
                          try {
                            Navigator.of(sheetContext).pop();
                            await FriendsService.sendStreakRequest(friend);
                            if (!rootContext.mounted) return;
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'InvitaciÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n de racha enviada a ${friend.name}.',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (!rootContext.mounted) return;
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  RankingService.friendlyRankingError(error),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.local_fire_department_rounded),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    ),
  );
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
        color: FocusPalette.coral.withValues(alpha: 0.08),
        border: Border.all(color: FocusPalette.coral.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: FocusPalette.coral,
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
              child: Icon(
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
            'CÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³mo funciona',
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
                  'Compara tus puntos solo con tu cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­rculo. Ahora tienes $friendsCount amigos agregados.',
            ),
            _InfoTile(
              icon: Icons.local_fire_department_rounded,
              title: 'Rachas entre amigos',
              text:
                  'Muestra quiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©n mantiene mÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡s dÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­as de estudio seguidos. Tu racha actual es ${_profileStreak(profile)} dÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­as.',
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
                ? 'Apareces tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âº hasta que agregues compaÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±eros.'
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
                return const LinearProgressIndicator();
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
                  isCurrentUser
                      ? 'Vas liderando'
                      : 'LÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­der semanal',
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : accent.withValues(alpha: entry.position <= 3 ? 0.1 : 0.05),
        border: Border.all(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.24)
              : accent.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
            ),
            child: Center(
              child: Text(
                '#${entry.position}',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser
                      ? '${entry.name} (tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âº)'
                      : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.career,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.points} pts',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RequestsCard extends StatelessWidget {
  final VoidCallback onChanged;

  const _RequestsCard({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: FriendsService.incomingRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FriendsPanel(
            child: _EmptyInline(
              icon: Icons.warning_amber_rounded,
              text: RankingService.friendlyRankingError(snapshot.error),
            ),
          );
        }
        final requests = snapshot.data ?? const <FriendRequest>[];
        if (requests.isEmpty) return const SizedBox.shrink();
        return _FriendsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.mark_email_unread_rounded,
                title: 'Solicitudes',
                subtitle: requests.isEmpty
                    ? 'Sin pendientes por ahora.'
                    : '${requests.length} esperando respuesta.',
              ),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                const _EmptyInline(
                  icon: Icons.check_circle_outline_rounded,
                  text:
                      'Cuando alguien use tu cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo, aparecerÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ aquÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­.',
                )
              else
                ...requests.map(
                  (request) => _RequestTile(
                    request: request,
                    onChanged: onChanged,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onChanged;

  const _RequestTile({
    required this.request,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _InitialAvatar(name: request.fromName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quiere entrar a tu cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­rculo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Aceptar',
            onPressed: () async {
              try {
                await FriendsService.acceptRequest(request);
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
                await FriendsService.rejectRequest(request);
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

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final Future<List<RankingProfile>>? searchFuture;
  final VoidCallback onSearch;
  final Future<void> Function(RankingProfile) onSendRequest;

  const _SearchCard({
    required this.controller,
    required this.searchFuture,
    required this.onSearch,
    required this.onSendRequest,
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
                    labelText:
                        'CÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo o nombre',
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
                return const LinearProgressIndicator();
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
                  text:
                      'No encontramos ese perfil. Revisa el cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³digo.',
                );
              }
              return Column(
                children: results
                    .map(
                      (profile) => _ProfileTile(
                        profile: profile,
                        trailing: IconButton.filledTonal(
                          tooltip: 'Enviar solicitud',
                          onPressed: () => onSendRequest(profile),
                          icon: const Icon(Icons.person_add_rounded),
                        ),
                      ),
                    )
                    .toList(),
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
  final Future<void> Function(RankingProfile) onRemove;

  const _FriendsList({
    required this.friends,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mi cÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­rculo',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: FocusPalette.muted,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        ...friends.map(
          (friend) => _ProfileTile(
            profile: friend,
            trailing: IconButton(
              tooltip: 'Eliminar amigo',
              onPressed: () => onRemove(friend),
              icon: const Icon(Icons.person_remove_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final RankingProfile profile;
  final Widget trailing;

  const _ProfileTile({
    required this.profile,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardColor,
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
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
