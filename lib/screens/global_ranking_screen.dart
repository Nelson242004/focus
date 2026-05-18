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
        future: RankingService.ensureProfile(),
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
        final participantCount = entries.length;
        final myIndex = entries.indexWhere((entry) => entry.uid == profile.uid);
        final myEntry = myIndex == -1 ? null : entries[myIndex];
        final myPosition = myIndex == -1 ? 0 : myIndex + 1;
        final topEntries = entries.take(3).toList();
        final tableEntries =
            entries.length >= 3 ? entries.skip(3).toList() : entries;
        final tableStartPosition = entries.length >= 3 ? 4 : 1;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _MyGlobalRankStrip(
              profile: profile,
              entry: myEntry,
              position: myPosition,
              participantCount: participantCount,
            ),
            const SizedBox(height: 12),
            const _AntiCheatNotice(),
            const SizedBox(height: 18),
            const _SectionLabel(
              icon: Icons.emoji_events_rounded,
              title: 'Podio semanal',
            ),
            const SizedBox(height: 12),
            if (topEntries.length >= 3) ...[
              _Podium(
                entries: topEntries,
                participantCount: participantCount,
              ),
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
                icon: Icons.cloud_off_rounded,
                title: 'El ranking está calentando motores',
                message:
                    'No pudimos traer la clasificación ahora. Revisa Firebase o inténtalo de nuevo en unos segundos.',
              )
            else if (entries.isEmpty)
              const _MessagePanel(
                icon: Icons.local_fire_department_rounded,
                title: 'El ranking está calentando motores',
                message:
                    'Cuando los primeros usuarios sumen puntos, la liga global aparecerá aquí.',
              )
            else if (tableEntries.isEmpty)
              const _MessagePanel(
                icon: Icons.auto_awesome_rounded,
                title: 'Solo hay podio por ahora',
                message: 'Cuando entren más usuarios aparecerá la tabla.',
              )
            else
              ...tableEntries.asMap().entries.map(
                    (item) => _StaggeredRankingTile(
                      index: item.key,
                      child: _RankingTile(
                        position: item.key + tableStartPosition,
                        entry: item.value,
                        isMe: item.value.uid == profile.uid,
                        participantCount: participantCount,
                      ),
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

    return TweenAnimationBuilder<double>(
      key: ValueKey('my-global-rank-$position-$points'),
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: isDark
                ? const [FocusPalette.ink, FocusPalette.primaryDeep]
                : const [FocusPalette.primaryDeep, FocusPalette.cyan],
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
        child: Row(
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
                      _GlassRankChip(label: '${points.clamp(0, 999999)} pts'),
                      _GlassRankChip(label: tier.name),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.26),
                    ),
                  ),
                ),
                Image.asset(
                  _tierMedalAsset(tier.name),
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
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

class _AntiCheatNotice extends StatelessWidget {
  const _AntiCheatNotice();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark
            ? Colors.white.withValues(alpha: 0.055)
            : FocusPalette.primary.withValues(alpha: 0.07),
        border: Border.all(
          color: FocusPalette.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  FocusPalette.primary.withValues(alpha: 0.22),
                  FocusPalette.teal.withValues(alpha: 0.18),
                ],
              ),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Solo cuentan pomodoros válidos de 25 min o más. Hábitos y sesiones tienen límites para evitar trampas.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
            ),
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

  const _RankingTile({
    required this.position,
    required this.entry,
    required this.isMe,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final tier = _distributedRankTierForPosition(position, participantCount);
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
                const SizedBox(height: 6),
                _RankTierChip(tier: tier, compact: true),
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
      return _TopMedalBadge(position: position, size: 46);
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tier.color.withValues(alpha: 0.10),
        border: Border.all(
          color: tier.color.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Image.asset(
          _tierMedalAsset(tier.name),
          fit: BoxFit.contain,
        ),
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

String _tierMedalAsset(String tierName) {
  return switch (tierName) {
    'Oro' => 'assets/medals/gold.png',
    'Plata' => 'assets/medals/silver.png',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      FocusPalette.ink,
                      FocusPalette.primaryDeep.withValues(alpha: 0.74),
                    ]
                  : [
                      FocusPalette.primary.withValues(alpha: 0.10),
                      Theme.of(context).cardColor,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: isDark ? 0.22 : 0.16,
                  ),
            ),
            boxShadow: [
              BoxShadow(
                color: FocusPalette.primaryDeep.withValues(alpha: 0.10),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      FocusPalette.primary.withValues(alpha: 0.22),
                      FocusPalette.teal.withValues(alpha: 0.18),
                    ],
                  ),
                ),
                child: Icon(
                  icon,
                  size: 38,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
