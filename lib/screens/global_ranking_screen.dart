import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ranking_profile.dart';
import '../services/ranking_service.dart';
import '../widgets/focus_drawer.dart';

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

  Future<void> _signOut() => RankingService.signOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'ranking'),
      appBar: AppBar(
        title: const Text('Ranking global'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<RankingProfile?>(
        future: RankingService.fetchProfile(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = profileSnapshot.data;
          if (profile == null) {
            return const _MessagePanel(
              icon: Icons.person_pin_rounded,
              title: 'Completa tu perfil',
              message:
                  'Necesitas nombre y carrera para entrar al ranking semanal.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: _RankingBody(
              profile: profile,
              nextUpdate: _nextUpdate,
              leaderboardFuture: _leaderboardFuture,
              onSignOut: _signOut,
            ),
          );
        },
      ),
    );
  }
}

class _RankingBody extends StatelessWidget {
  final RankingProfile profile;
  final DateTime nextUpdate;
  final Future<List<RankingEntry>> leaderboardFuture;
  final Future<void> Function() onSignOut;

  const _RankingBody({
    required this.profile,
    required this.nextUpdate,
    required this.leaderboardFuture,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RankingEntry>>(
      future: leaderboardFuture,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <RankingEntry>[];
        final myIndex = entries.indexWhere((entry) => entry.uid == profile.uid);
        final myEntry = myIndex >= 0 ? entries[myIndex] : null;
        final nextUpdateLabel =
            '${nextUpdate.hour.toString().padLeft(2, '0')}:00';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _RankingHeader(
              nextUpdateLabel: nextUpdateLabel,
              resetDate: RankingService.nextWeeklyReset(),
              participantCount: entries.length,
            ),
            const SizedBox(height: 16),
            _MyRankCard(
              profile: profile,
              entry: myEntry,
              position: myIndex + 1,
            ),
            const SizedBox(height: 16),
            if (entries.length >= 3) ...[
              const _SectionLabel(
                icon: Icons.workspace_premium_rounded,
                title: 'Podio semanal',
              ),
              const SizedBox(height: 10),
              _Podium(entries: entries.take(3).toList()),
              const SizedBox(height: 18),
            ],
            const _SectionLabel(
              icon: Icons.format_list_numbered_rounded,
              title: 'Clasificación',
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }
}

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
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
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
          const SizedBox(height: 14),
          const Text(
            'Ranking semanal global',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Incluye a todos los usuarios, incluso con 0 puntos. Se reinicia cada domingo a las 00:00.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<RankingEntry> entries;

  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    final ordered = [
      if (entries.length > 1) entries[1],
      entries[0],
      if (entries.length > 2) entries[2],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: ordered.map((entry) {
          final position = entry.position;
          final height = position == 1 ? 176.0 : 138.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _PodiumPlace(
                entry: entry,
                height: height,
                medalAsset: _medalAsset(position),
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
  final String medalAsset;

  const _PodiumPlace({
    required this.entry,
    required this.height,
    required this.medalAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _podiumColor(entry.position).withValues(alpha: 0.18),
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
          Image.asset(medalAsset, width: 58, height: 58),
          const SizedBox(height: 8),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.points} pts',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage:
                profile.photoUrl.isEmpty ? null : NetworkImage(profile.photoUrl),
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
                  '${profile.career} · ${RankingService.rankForPoints(points)}',
                  overflow: TextOverflow.ellipsis,
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
              Text('$points pts'),
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
    final topMedal = position <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isMe
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).cardColor,
        border: Border.all(
          color: isMe
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.38)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: topMedal
            ? Image.asset(_medalAsset(position), width: 42, height: 42)
            : CircleAvatar(
                child: Text(
                  '#$position',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${entry.career} · ${entry.rank}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.points} pts',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text('${entry.pomodoros} pomodoros'),
          ],
        ),
      ),
    );
  }
}

Color _podiumColor(int position) {
  return switch (position) {
    1 => const Color(0xFFF59E0B),
    2 => const Color(0xFF94A3B8),
    3 => const Color(0xFFB45309),
    _ => const Color(0xFF2563EB),
  };
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
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
          ],
        ),
      ),
    );
  }
}

String _medalAsset(int position) {
  return switch (position) {
    1 => 'assets/medals/gold.png',
    2 => 'assets/medals/silver.png',
    3 => 'assets/medals/bronze.png',
    _ => 'assets/medals/bronze.png',
  };
}
