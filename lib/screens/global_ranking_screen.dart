import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ranking_profile.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_drawer.dart';
import 'auth_gate_screen.dart';

class GlobalRankingScreen extends StatefulWidget {
  const GlobalRankingScreen({super.key});

  @override
  State<GlobalRankingScreen> createState() => _GlobalRankingScreenState();
}

class _GlobalRankingScreenState extends State<GlobalRankingScreen> {
  Timer? _refreshTimer;
  late Future<List<RankingEntry>> _leaderboardFuture;
  DateTime _nextUpdate = RankingService.nextHourlyUpdate();

  @override
  void initState() {
    super.initState();
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
      _leaderboardFuture = RankingService.fetchGlobalLeaderboard();
    });
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'ranking'),
      appBar: AppBar(
        title: const Text('Ranking global'),
      ),
      body: FutureBuilder<RankingProfile?>(
        future: RankingService.fetchProfile(),
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
            return const Center(child: CircularProgressIndicator());
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
            final user = RankingService.currentUser;
            return _MessagePanel(
              icon: Icons.person_pin_rounded,
              title: 'Completa tu perfil',
              message:
                  'Necesitas nombre y carrera para entrar al ranking semanal.',
              action: user == null
                  ? null
                  : FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileSetupScreen(
                              user: user,
                              onSaved: _refresh,
                            ),
                          ),
                        );
                        if (mounted) _refresh();
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Completar perfil'),
                    ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: _RankingBody(
              profile: profile,
              leaderboardFuture: _leaderboardFuture,
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

  const _RankingBody({
    required this.profile,
    required this.leaderboardFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RankingEntry>>(
      future: leaderboardFuture,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <RankingEntry>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel(
              icon: Icons.workspace_premium_rounded,
              title: 'Top puntos',
            ),
            const SizedBox(height: 10),
            if (entries.length >= 3) ...[
              _Podium(
                entries: entries.take(3).toList(),
                participantCount: entries.length,
              ),
              const SizedBox(height: 18),
            ],
            const _SectionLabel(
              icon: Icons.format_list_numbered_rounded,
              title: 'Tabla por puntos',
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _MessagePanel(
                icon: Icons.warning_amber_rounded,
                title: 'No se pudo cargar',
                message: RankingService.friendlyRankingError(snapshot.error),
              )
            else if (entries.isEmpty)
              const _MessagePanel(
                icon: Icons.emoji_events_outlined,
                title: 'Sin participantes',
                message: 'Cuando haya usuarios registrados aparecerán aquí.',
              )
            else
              ...entries.asMap().entries.map(
                    (item) => _RankingTile(
                      position: item.key + 1,
                      entry: item.value,
                      isMe: item.value.uid == profile.uid,
                    ),
                  ),
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

class _Podium extends StatelessWidget {
  final List<RankingEntry> entries;
  final int participantCount;

  const _Podium({
    required this.entries,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [
      if (entries.length > 1) entries[1],
      entries[0],
      if (entries.length > 2) entries[2],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            FocusPalette.primary.withValues(alpha: 0.10),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: FocusPalette.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: ordered.map((entry) {
          final position = entry.position;
          final height = position == 1 ? 208.0 : 176.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _PodiumPlace(
                entry: entry,
                height: height,
                participantCount: participantCount,
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

  const _PodiumPlace({
    required this.entry,
    required this.height,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            _podiumColor(entry.position).withValues(alpha: 0.24),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: _podiumColor(entry.position).withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _TopMedalBadge(position: entry.position, size: 58),
          const SizedBox(height: 7),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          _RankTierChip(
            tier: _distributedRankTierForPosition(
              entry.position,
              participantCount,
            ),
            compact: true,
          ),
          const SizedBox(height: 6),
          _PointsPill(points: entry.points),
        ],
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
          CircleAvatar(
            radius: 28,
            backgroundImage: profile.photoUrl.isEmpty
                ? null
                : NetworkImage(profile.photoUrl),
            child: profile.photoUrl.isEmpty
                ? Text(profile.name.trim().isEmpty
                    ? 'F'
                    : profile.name.trim()[0].toUpperCase())
                : null,
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
      constraints: BoxConstraints(maxWidth: large ? 132 : 78),
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 8,
        vertical: large ? 8 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FocusPalette.amber.withValues(alpha: 0.24),
            FocusPalette.coral.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FocusPalette.amber.withValues(alpha: 0.28)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars_rounded,
              size: large ? 18 : 13,
              color: FocusPalette.amber,
            ),
            SizedBox(width: large ? 5 : 3),
            Text(
              '$points pts',
              maxLines: 1,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: large ? 16 : 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int position;
  final RankingEntry entry;
  final bool isMe;

  const _RankingTile({
    required this.position,
    required this.entry,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isMe
              ? [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                  Theme.of(context).cardColor,
                ]
              : [
                  Theme.of(context).cardColor,
                  Theme.of(context).cardColor.withValues(alpha: 0.92),
                ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: isMe
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.42)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          _RankBadge(position: position, entry: entry),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: 4),
                Text(
                  _careerLabel(entry.career),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _PointsPill(points: entry.points),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int position;
  final RankingEntry entry;

  const _RankBadge({
    required this.position,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    if (position <= 3) {
      return _TopMedalBadge(position: position, size: 46);
    }
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: FocusPalette.amber.withValues(alpha: 0.10),
        border: Border.all(
          color: FocusPalette.amber.withValues(alpha: 0.20),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/medals/bronze.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: 3,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Theme.of(context).cardColor.withValues(alpha: 0.92),
              ),
              child: Text(
                '#$position',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMedalBadge extends StatelessWidget {
  final int position;
  final double size;

  const _TopMedalBadge({
    required this.position,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _podiumColor(position).withValues(alpha: 0.30),
            blurRadius: size * 0.24,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Image.asset(
        _medalAsset(position),
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _RankTierChip extends StatelessWidget {
  final _RankTier tier;
  final bool compact;

  const _RankTierChip({
    required this.tier,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tier.color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: compact ? 13 : 15, color: tier.color),
          const SizedBox(width: 4),
          Text(
            tier.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tier.color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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

String _medalAsset(int position) {
  return switch (position) {
    1 => 'assets/medals/gold.png',
    2 => 'assets/medals/silver.png',
    3 => 'assets/medals/bronze.png',
    _ => 'assets/medals/bronze.png',
  };
}

_RankTier _distributedRankTierForPosition(int position, int participantCount) {
  if (participantCount <= 0 || position <= 0) {
    return const _RankTier(
      name: 'Bronce',
      color: Color(0xFFB45309),
      icon: Icons.shield_rounded,
    );
  }

  final goldLimit = (participantCount * 0.10).ceil().clamp(1, participantCount);
  final silverLimit =
      (participantCount * 0.35).ceil().clamp(goldLimit, participantCount);

  if (position <= goldLimit) {
    return const _RankTier(
      name: 'Oro',
      color: FocusPalette.amber,
      icon: Icons.stars_rounded,
    );
  }
  if (position <= silverLimit) {
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

// ignore: unused_element
_RankTier _rankTierForPosition(int position, int participantCount) {
  if (participantCount <= 0 || position <= 0) {
    return const _RankTier(
      name: 'Sin rango',
      color: FocusPalette.muted,
      icon: Icons.remove_rounded,
    );
  }
  if (position == 1) {
    return const _RankTier(
      name: 'Campeón',
      color: FocusPalette.amber,
      icon: Icons.emoji_events_rounded,
    );
  }
  final percentile = position / participantCount;
  if (percentile <= 0.10) {
    return const _RankTier(
      name: 'Diamante',
      color: Color(0xFF0891B2),
      icon: Icons.diamond_rounded,
    );
  }
  if (percentile <= 0.25) {
    return const _RankTier(
      name: 'Oro',
      color: FocusPalette.amber,
      icon: Icons.stars_rounded,
    );
  }
  if (percentile <= 0.50) {
    return const _RankTier(
      name: 'Plata',
      color: Color(0xFF64748B),
      icon: Icons.workspace_premium_rounded,
    );
  }
  if (percentile <= 0.75) {
    return const _RankTier(
      name: 'Bronce',
      color: Color(0xFFB45309),
      icon: Icons.shield_rounded,
    );
  }
  return const _RankTier(
    name: 'Inicial',
    color: FocusPalette.primary,
    icon: Icons.flag_rounded,
  );
}

String _careerLabel(String career) {
  final cleaned = career.trim();
  return cleaned.isEmpty ? 'Sin carrera' : cleaned;
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
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
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
