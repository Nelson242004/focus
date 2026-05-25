import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ranking_profile.dart';
import '../services/friends_service.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';
import '../utils/profile_icon_access.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_empty_state.dart';
import '../widgets/focus_feedback.dart';
import '../widgets/focus_metric_icon.dart';
import '../widgets/focus_public_profile_sheet.dart';
import '../widgets/focus_social_components.dart';
import 'auth_gate_screen.dart';

class GlobalRankingScreen extends StatefulWidget {
  final bool showAppBar;

  const GlobalRankingScreen({super.key, this.showAppBar = true});

  @override
  State<GlobalRankingScreen> createState() => _GlobalRankingScreenState();
}

class _GlobalRankingScreenState extends State<GlobalRankingScreen> {
  Timer? _refreshTimer;
  late Future<RankingProfile?> _profileFuture;
  late Future<List<RankingEntry>> _leaderboardFuture;
  DateTime _nextUpdate = RankingService.nextHourlyUpdate();

  @override
  void initState() {
    super.initState();
    _profileFuture = RankingService.ensureProfile();
    _leaderboardFuture = RankingService.fetchGlobalLeaderboard();
    _scheduleHourlyRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _scheduleHourlyRefresh() {
    _refreshTimer?.cancel();
    final now = DateTime.now();
    _nextUpdate = RankingService.nextHourlyUpdate();
    _refreshTimer = Timer(_nextUpdate.difference(now), () {
      if (!mounted) return;
      _refresh();
      _scheduleHourlyRefresh();
    });
  }

  void _refresh() {
    setState(() {
      _nextUpdate = RankingService.nextHourlyUpdate();
      _profileFuture = RankingService.ensureProfile();
      _leaderboardFuture = RankingService.fetchGlobalLeaderboard();
    });
  }

  Future<void> _openRankingProfile(
    RankingEntry entry,
    int participantCount,
  ) async {
    final currentUid = RankingService.currentUser?.uid;
    final isMe = entry.uid == currentUid;
    try {
      final profile = await RankingService.fetchProfileByUid(entry.uid);
      if (!mounted) return;
      if (profile == null) {
        showFocusFeedback(
          context,
          message: 'No se pudo cargar ese perfil.',
          type: FocusFeedbackType.warning,
          icon: Icons.person_off_rounded,
        );
        return;
      }
      final isFriend =
          isMe ? false : await FriendsService.areFriends(entry.uid);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => FocusPublicProfileSheet(
          profile: profile,
          isMe: isMe,
          isFriend: isFriend,
          points: entry.points,
          statusLabel: isMe
              ? 'Tu perfil'
              : isFriend
                  ? 'Perfil de amigo'
                  : null,
          onSendRequest: () async {
            await FriendsService.sendRequest(profile);
            if (!mounted) return false;
            showFocusFeedback(
              context,
              message: 'Solicitud enviada a ${profile.name}.',
              icon: Icons.person_add_alt_1_rounded,
            );
            return true;
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showFocusFeedback(
        context,
        message: RankingService.friendlyRankingError(error),
        type: FocusFeedbackType.error,
      );
    }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) _refresh();
  }

  void _showRankingInfo() {
    final nextUpdate = _formatDateTime(_nextUpdate);
    final nextReset = _formatDateTime(RankingService.nextWeeklyReset());
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
                'Info del ranking',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Lo principal del ranking global en un solo lugar.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FocusPalette.muted,
                    ),
              ),
              const SizedBox(height: 16),
              const _RankingInfoTile(
                icon: Icons.timer_rounded,
                title: 'Qué cuenta',
                text:
                    'Solo cuentan pomodoros válidos. Hábitos y sesiones tienen límites anti-trampa.',
              ),
              const SizedBox(height: 10),
              const _RankingInfoTile(
                icon: Icons.verified_user_rounded,
                title: 'Ranking justo',
                text:
                    'Pomodoros muy cortos o acciones repetidas no empujan la liga. Focus prioriza progreso real.',
              ),
              const SizedBox(height: 10),
              const _RankingInfoTile(
                icon: Icons.military_tech_rounded,
                title: 'Ligas',
                text: 'Oro: top 10%. Plata: top 35%. Bronce: el resto.',
              ),
              const SizedBox(height: 10),
              _RankingInfoTile(
                icon: Icons.schedule_rounded,
                title: 'Próxima actualización',
                text: nextUpdate,
              ),
              const SizedBox(height: 10),
              _RankingInfoTile(
                icon: Icons.restart_alt_rounded,
                title: 'Reinicio semanal',
                text: nextReset,
              ),
              const SizedBox(height: 10),
              const _RankingInfoTile(
                icon: Icons.emoji_events_rounded,
                title: 'Cómo subir',
                text:
                    'Necesitas más puntos semanales que la persona que está arriba de ti.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Ranking global'),
              actions: [
                IconButton(
                  onPressed: _showRankingInfo,
                  tooltip: 'Información',
                  icon: const Icon(Icons.help_outline_rounded),
                ),
              ],
            )
          : null,
      body: FutureBuilder<RankingProfile?>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (RankingService.currentUser == null) {
            return _MessagePanel(
              icon: Icons.login_rounded,
              title: 'Inicia sesión para competir',
              message:
                  'El ranking global usa tu cuenta. Puedes seguir usando materias, exámenes y Pomodoro sin iniciar sesión.',
              action: FilledButton.icon(
                onPressed: _openLogin,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Iniciar sesión'),
              ),
            );
          }
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const FocusSkeletonList(
              heights: [220, 92, 86, 86],
            );
          }
          if (profileSnapshot.hasError) {
            return _MessagePanel(
              icon: Icons.warning_amber_rounded,
              title: 'No se pudo cargar tu perfil',
              message: RankingService.friendlyRankingError(
                profileSnapshot.error,
              ),
              action: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            );
          }
          final profile = profileSnapshot.data;
          if (profile == null) {
            return _MessagePanel(
              icon: Icons.warning_amber_rounded,
              title: 'No se pudo preparar tu perfil',
              message: 'Reintenta para entrar al ranking semanal.',
              action: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            );
          }
          return FocusPageBackground(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: _RankingBody(
                profile: profile,
                leaderboardFuture: _leaderboardFuture,
                onRefresh: _refresh,
                onOpenProfile: _openRankingProfile,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RankingBody extends StatelessWidget {
  final RankingProfile profile;
  final Future<List<RankingEntry>> leaderboardFuture;
  final VoidCallback onRefresh;
  final Future<void> Function(RankingEntry entry, int participantCount)
      onOpenProfile;

  const _RankingBody({
    required this.profile,
    required this.leaderboardFuture,
    required this.onRefresh,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RankingEntry>>(
      future: leaderboardFuture,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <RankingEntry>[];
        final participantCount = entries.length;
        final myIndex = entries.indexWhere((entry) => entry.uid == profile.uid);
        final myEntry = myIndex == -1 ? null : entries[myIndex];
        final myPosition = myIndex == -1 ? 0 : myIndex + 1;
        final topEntries = entries.take(3).toList();
        final leaderboardEntries =
            entries.length >= 3 ? entries.skip(3).toList() : entries;
        final featuredEntries = leaderboardEntries;
        final nearbyEntries = const <RankingEntry>[];

        return ListView(
          padding: FocusInsets.pageCompact,
          children: [
            _MyGlobalRankStrip(
              profile: profile,
              entry: myEntry,
              position: myPosition,
              participantCount: participantCount,
            ),
            FocusGap.section,
            const _SectionLabel(
              icon: Icons.emoji_events_rounded,
              title: 'Podio semanal',
            ),
            FocusGap.sm,
            if (topEntries.isNotEmpty) ...[
              _Podium(
                entries: topEntries,
                participantCount: participantCount,
                onOpenProfile: (entry) =>
                    onOpenProfile(entry, participantCount),
              ),
              FocusGap.section,
            ],
            const _SectionLabel(
              icon: Icons.format_list_numbered_rounded,
              title: 'Tabla',
            ),
            FocusGap.sm,
            if (snapshot.connectionState == ConnectionState.waiting)
              const FocusSkeletonColumn(
                heights: [88, 72, 72],
                spacing: 10,
              )
            else if (snapshot.hasError)
              _MessagePanel(
                icon: Icons.cloud_off_rounded,
                title: 'El ranking está calentando motores',
                message:
                    'No pudimos traer la clasificación ahora. Revisa Firebase o inténtalo de nuevo en unos segundos.',
                action: FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              )
            else if (entries.isEmpty)
              _MessagePanel(
                icon: Icons.local_fire_department_rounded,
                title: 'El ranking está calentando motores',
                message:
                    'Cuando los primeros usuarios sumen puntos, la liga global aparecerá aquí.',
                action: FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              )
            else if (leaderboardEntries.isEmpty)
              _MessagePanel(
                icon: Icons.auto_awesome_rounded,
                title: 'Solo hay podio por ahora',
                message: 'Cuando entren más usuarios aparecerá la tabla.',
                action: FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              )
            else ...[
              ...featuredEntries.asMap().entries.map(
                    (item) => _StaggeredRankingTile(
                      index: item.key,
                      child: _RankingTile(
                        position: item.value.position,
                        entry: item.value,
                        isMe: item.value.uid == profile.uid,
                        participantCount: participantCount,
                        onOpenProfile: (entry) =>
                            onOpenProfile(entry, participantCount),
                      ),
                    ),
                  ),
              if (nearbyEntries.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _InlineSectionPill(
                  icon: Icons.my_location_rounded,
                  label: 'Tu zona',
                ),
                const SizedBox(height: 10),
                ...nearbyEntries.asMap().entries.map(
                      (item) => _StaggeredRankingTile(
                        index: featuredEntries.length + item.key,
                        child: _RankingTile(
                          position: item.value.position,
                          entry: item.value,
                          isMe: item.value.uid == profile.uid,
                          participantCount: participantCount,
                          onOpenProfile: (entry) =>
                              onOpenProfile(entry, participantCount),
                        ),
                      ),
                    ),
              ],
            ],
          ],
        );
      },
    );
  }
}

// ignore: unused_element
class _RankingHeader extends StatelessWidget {
  final String nextUpdateLabel;
  final DateTime resetDate;
  final int participantCount;

  const _RankingHeader({
    required this.nextUpdateLabel,
    required this.resetDate,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final resetLabel =
        '${resetDate.day.toString().padLeft(2, '0')}/${resetDate.month.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: FocusPalette.studyGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: FocusPalette.primaryDeep.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -24,
            child: Icon(
              Icons.emoji_events_rounded,
              size: 132,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.public_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const Spacer(),
                  _HeaderChip(
                    icon: Icons.people_alt_rounded,
                    label: '$participantCount usuarios',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Liga Focus',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ranking global',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Compite por puntos semanales. El tablero se refresca cada hora.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeaderChip(
                    icon: Icons.schedule_rounded,
                    label: 'Actualiza $nextUpdateLabel',
                  ),
                  _HeaderChip(
                    icon: Icons.restart_alt_rounded,
                    label: 'Reinicio $resetLabel',
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

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _RankingDetailsCard extends StatelessWidget {
  final RankingProfile profile;
  final RankingEntry? entry;
  final int position;
  final String nextUpdateLabel;
  final DateTime resetDate;
  final int participantCount;

  const _RankingDetailsCard({
    required this.profile,
    required this.entry,
    required this.position,
    required this.nextUpdateLabel,
    required this.resetDate,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final resetLabel =
        '${resetDate.day.toString().padLeft(2, '0')}/${resetDate.month.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        collapsedShape:
            const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        leading: Icon(
          Icons.info_outline_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text(
          'Detalles del ranking',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle:
            Text('$participantCount usuarios · actualiza $nextUpdateLabel'),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip(
                icon: Icons.schedule_rounded,
                label: 'Actualiza $nextUpdateLabel',
              ),
              _DetailChip(
                icon: Icons.restart_alt_rounded,
                label: 'Reinicio $resetLabel',
              ),
              _DetailChip(
                icon: Icons.people_alt_rounded,
                label: '$participantCount usuarios',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MyRankCard(
            profile: profile,
            entry: entry,
            position: position,
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MyGlobalRankStrip extends StatelessWidget {
  final RankingProfile profile;
  final RankingEntry? entry;
  final int position;
  final int participantCount;

  const _MyGlobalRankStrip({
    required this.profile,
    required this.entry,
    required this.position,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final points = entry?.points ?? profile.weeklyPoints;
    final tier = _distributedRankTierForPosition(position, participantCount);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final positionLabel = position <= 0 ? 'Sin puesto' : '#$position';
    final progress = _tierProgressValue(position, participantCount);
    final progressLabel = _tierProgressLabel(position, participantCount);

    return TweenAnimationBuilder<double>(
      key: ValueKey('my-global-rank-$position-$points'),
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    FocusPalette.darkCard,
                    Color.lerp(FocusPalette.darkCard, tier.color, 0.14)!,
                  ]
                : const [FocusPalette.primaryDeep, FocusPalette.cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? tier.color : FocusPalette.primaryDeep)
                  .withValues(alpha: isDark ? 0.10 : 0.18),
              blurRadius: isDark ? 18 : 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu liga global',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _GlassRankChip(label: positionLabel),
                      _GlassRankChip(label: tier.name),
                      _GlassRankChip(label: '${points.clamp(0, 999999)} pts'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    progressLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.26),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FocusLeagueIcon(
                      league: tier.name,
                      size: 54,
                      color: tier.color,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      positionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassRankChip extends StatelessWidget {
  final String label;

  const _GlassRankChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<RankingEntry> entries;
  final int participantCount;
  final Future<void> Function(RankingEntry entry) onOpenProfile;

  const _Podium({
    required this.entries,
    required this.participantCount,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [
      if (entries.length > 1) entries[1],
      if (entries.isNotEmpty) entries[0],
      if (entries.length > 2) entries[2],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.panel),
        color: Theme.of(context).cardColor,
        border: Border.all(
          color: FocusPalette.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: ordered.map((entry) {
          final position = entry.position;
          final height = position == 1 ? 232.0 : 206.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 520 + (position * 80)),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 18),
                      child: Transform.scale(
                        scale: 0.92 + (value * 0.08),
                        child: child,
                      ),
                    ),
                  );
                },
                child: _PodiumPlace(
                  entry: entry,
                  height: height,
                  participantCount: participantCount,
                  onOpenProfile: onOpenProfile,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final RankingEntry entry;
  final double height;
  final int participantCount;
  final Future<void> Function(RankingEntry entry) onOpenProfile;

  const _PodiumPlace({
    required this.entry,
    required this.height,
    required this.participantCount,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _podiumColor(entry.position);
    return InkWell(
      borderRadius: BorderRadius.circular(FocusRadii.card),
      onTap: () => onOpenProfile(entry),
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(9, 12, 9, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FocusRadii.card),
          color: accent.withValues(alpha: 0.08),
          border: Border.all(
            color: accent.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '#${entry.position}',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _RankingProfileIcon(
                  asset: _entryProfileIconAsset(entry),
                  size: entry.position == 1 ? 92 : 82,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: FocusLeagueIcon.position(
                    position: entry.position,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: entry.position == 1 ? 14 : 13.5,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _PointsPill(points: entry.points),
          ],
        ),
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final RankingProfile profile;
  final RankingEntry? entry;
  final int position;

  const _MyRankCard({
    required this.profile,
    required this.entry,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final points = entry?.points ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          _RankingProfileIcon(
            asset: _profileIconAsset(profile),
            size: 58,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu posición esta semana',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _careerLabel(profile.career),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                position <= 0 ? '-' : '#$position',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              _PointsPill(points: points, large: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionLabel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _InlineSectionPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InlineSectionPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _RankingInfoTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return FocusSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 20,
      accent: accent,
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accent.withValues(alpha: 0.10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: FocusPalette.muted,
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

class _PointsPill extends StatelessWidget {
  final int points;
  final bool large;

  const _PointsPill({
    required this.points,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: large ? 132 : 92),
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 9,
        vertical: large ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: FocusPalette.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FocusPalette.amber.withValues(alpha: 0.18)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FocusMetricIcon.points(
              size: large ? 18 : 13,
              color: FocusPalette.amber,
            ),
            SizedBox(width: large ? 5 : 3),
            _AnimatedPointsText(points: points, large: large),
          ],
        ),
      ),
    );
  }
}

class _AnimatedPointsText extends StatelessWidget {
  final int points;
  final bool large;

  const _AnimatedPointsText({
    required this.points,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      key: ValueKey(points),
      tween: IntTween(begin: 0, end: points),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          '$value pts',
          maxLines: 1,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: large ? 16 : 11,
            fontWeight: FontWeight.w900,
          ),
        );
      },
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int position;
  final RankingEntry entry;
  final bool isMe;
  final int participantCount;
  final Future<void> Function(RankingEntry entry) onOpenProfile;

  const _RankingTile({
    required this.position,
    required this.entry,
    required this.isMe,
    required this.participantCount,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(FocusRadii.card),
      onTap: () => onOpenProfile(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: FocusSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FocusRadii.card),
          color: isMe
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)
              : Theme.of(context).cardColor,
          border: Border.all(
            color: isMe
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.34)
                : Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.32),
          ),
          boxShadow: [
            if (isMe)
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _RankBadge(
              position: position,
              entry: entry,
              participantCount: participantCount,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isMe)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Tú',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _careerLabel(entry.career),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PointsPill(points: entry.points),
          ],
        ),
      ),
    );
  }
}

class _StaggeredRankingTile extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredRankingTile({
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8) * 55);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _RankingProfileIcon extends StatelessWidget {
  final String asset;
  final double size;

  const _RankingProfileIcon({
    required this.asset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: size * 0.24,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int position;
  final RankingEntry entry;
  final int participantCount;

  const _RankBadge({
    required this.position,
    required this.entry,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final tier = _distributedRankTierForPosition(position, participantCount);
    if (position <= 3) {
      return FocusLeagueIcon.position(position: position, size: 40);
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tier.color.withValues(alpha: 0.10),
        border: Border.all(
          color: tier.color.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: FocusLeagueIcon(
          league: tier.name,
          size: 32,
          color: tier.color,
          elevated: false,
        ),
      ),
    );
  }
}

class _RankTier {
  final String name;
  final Color color;
  final IconData icon;

  const _RankTier({
    required this.name,
    required this.color,
    required this.icon,
  });
}

Color _podiumColor(int position) {
  return switch (position) {
    1 => FocusPalette.amber,
    2 => const Color(0xFF94A3B8),
    3 => const Color(0xFFB45309),
    _ => FocusPalette.primary,
  };
}

_RankTier _distributedRankTierForPosition(int position, int participantCount) {
  final limits = _rankTierLimits(participantCount);
  if (position <= 0 || limits.total <= 0) {
    return const _RankTier(
      name: 'Bronce',
      color: Color(0xFFB45309),
      icon: Icons.shield_rounded,
    );
  }

  if (position <= limits.goldLimit) {
    return const _RankTier(
      name: 'Oro',
      color: FocusPalette.amber,
      icon: Icons.stars_rounded,
    );
  }
  if (position <= limits.silverLimit) {
    return const _RankTier(
      name: 'Plata',
      color: Color(0xFF64748B),
      icon: Icons.workspace_premium_rounded,
    );
  }
  return const _RankTier(
    name: 'Bronce',
    color: Color(0xFFB45309),
    icon: Icons.shield_rounded,
  );
}

double _tierProgressValue(int position, int participantCount) {
  final limits = _rankTierLimits(participantCount);
  if (limits.total <= 0 || position <= 0) return 0;
  if (position <= limits.goldLimit) return 1;
  if (position <= limits.silverLimit) {
    final span = (limits.silverLimit - limits.goldLimit).clamp(1, limits.total);
    final distance = (position - limits.goldLimit - 1).clamp(0, span);
    return (1 - (distance / span)).clamp(0.12, 1);
  }
  final span = (limits.total - limits.silverLimit).clamp(1, limits.total);
  final distance = (position - limits.silverLimit - 1).clamp(0, span);
  return (1 - (distance / span)).clamp(0.08, 1);
}

String _tierProgressLabel(int position, int participantCount) {
  final limits = _rankTierLimits(participantCount);
  if (limits.total <= 0 || position <= 0) {
    return 'Suma puntos para entrar a la liga semanal.';
  }
  if (position <= limits.goldLimit) return 'Estás dentro del top 10% de Focus.';
  if (position <= limits.silverLimit) {
    final needed = position - limits.goldLimit;
    return needed == 1
        ? 'Te falta 1 puesto para Oro.'
        : 'Te faltan $needed puestos para Oro.';
  }
  final needed = position - limits.silverLimit;
  return needed == 1
      ? 'Te falta 1 puesto para Plata.'
      : 'Te faltan $needed puestos para Plata.';
}

({int total, int goldLimit, int silverLimit}) _rankTierLimits(int total) {
  if (total <= 0) return (total: 0, goldLimit: 0, silverLimit: 0);
  final goldLimit = (total * 0.10).ceil().clamp(1, total);
  final silverLimit = (total * 0.35).ceil().clamp(goldLimit, total);
  return (
    total: total,
    goldLimit: goldLimit,
    silverLimit: silverLimit,
  );
}

String _careerLabel(String career) {
  final cleaned = career.trim();
  return cleaned.isEmpty ? 'Sin carrera' : cleaned;
}

String _entryProfileIconAsset(RankingEntry entry) {
  if (entry.profileIconAsset.trim().isNotEmpty) {
    return normalizeProfileIconAsset(
      entry.profileIconAsset,
      email: RankingService.currentUser?.email,
      enforceAccess: true,
    );
  }
  return profileIconAssetFromIndex(
    entry.socialMascotIndex,
    email: RankingService.currentUser?.email,
    enforceAccess: true,
  );
}

String _profileIconAsset(RankingProfile profile) {
  final rawAsset = '${profile.stats['profileIconAsset'] ?? ''}';
  if (rawAsset.trim().isNotEmpty) {
    return normalizeProfileIconAsset(
      rawAsset,
      email: RankingService.currentUser?.email,
      enforceAccess: true,
    );
  }
  return profileIconAssetFromIndex(
    profile.stats['socialMascotIndex'],
    email: RankingService.currentUser?.email,
    enforceAccess: true,
  );
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: FocusProfileEmptyState(
          icon: icon,
          iconKind: FocusAppIconKind.ranking,
          title: title,
          message: message,
          action: action,
        ),
      ),
    );
  }
}
