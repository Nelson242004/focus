import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/ranking_profile.dart';
import 'focus_design_system.dart';

class FocusLeagueIcon extends StatelessWidget {
  final String league;
  final int? position;
  final double size;
  final Color? color;
  final bool elevated;

  const FocusLeagueIcon({
    super.key,
    required this.league,
    this.position,
    this.size = 34,
    this.color,
    this.elevated = true,
  });

  const FocusLeagueIcon.position({
    super.key,
    required int this.position,
    this.size = 34,
    this.color,
    this.elevated = true,
  }) : league = '';

  @override
  Widget build(BuildContext context) {
    final info = position == null
        ? LeagueInfo.fromName(league)
        : _leagueInfoForPosition(position!);
    final accent = color ?? info.color;
    final icon = _iconForLeague(info.name, position);
    final iconSize = size * 0.56;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.95),
            Color.lerp(accent, Colors.black, 0.18)!,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.44),
          width: (size * 0.035).clamp(1.0, 2.0),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: size * 0.26,
                  offset: Offset(0, size * 0.10),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  static LeagueInfo _leagueInfoForPosition(int position) {
    return switch (position) {
      1 => LeagueInfo.fromName('Oro'),
      2 => LeagueInfo.fromName('Plata'),
      3 => LeagueInfo.fromName('Bronce'),
      _ => LeagueInfo.fromName('Bronce'),
    };
  }

  static IconData _iconForLeague(String league, int? position) {
    if (position == 1) return LucideIcons.crown;
    if (position == 2) return LucideIcons.medal;
    if (position == 3) return LucideIcons.shield;
    return switch (league) {
      'Oro' => LucideIcons.crown,
      'Plata' => LucideIcons.medal,
      _ => LucideIcons.shield,
    };
  }
}

class FocusLeagueBadge extends StatelessWidget {
  final String league;
  final double size;
  final bool showLabel;

  const FocusLeagueBadge({
    super.key,
    required this.league,
    this.size = 34,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final info = LeagueInfo.fromName(league);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 10 : 6,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(FocusRadii.chip),
        border: Border.all(color: info.color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusLeagueIcon(
            league: info.name,
            size: size,
            color: info.color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 7),
            Text(
              info.name,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: info.color,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class FocusSocialStatItem {
  final Widget icon;
  final String label;
  final String value;
  final Color color;

  const FocusSocialStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class FocusSocialStatsGrid extends StatelessWidget {
  final List<FocusSocialStatItem> items;

  const FocusSocialStatsGrid({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: _FocusSocialStatCard(item: items[i])),
          if (i != items.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class FocusFriendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String leadingLabel;
  final String trailingLabel;
  final Color accent;
  final bool highlighted;
  final VoidCallback? onTap;

  const FocusFriendCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leadingLabel,
    required this.trailingLabel,
    required this.accent,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = highlighted ? primary : accent;
    return InkWell(
      borderRadius: BorderRadius.circular(FocusRadii.card),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FocusRadii.card),
          color: highlighted
              ? primary.withValues(alpha: 0.10)
              : color.withValues(alpha: 0.06),
          border: Border.all(
            color: highlighted
                ? primary.withValues(alpha: 0.24)
                : color.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
              ),
              child: Center(
                child: Text(
                  leadingLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailingLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusSocialStatCard extends StatelessWidget {
  final FocusSocialStatItem item;

  const _FocusSocialStatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return FocusSurfaceCard(
      padding: const EdgeInsets.all(12),
      radius: 22,
      accent: item.color,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 28, height: 28, child: Center(child: item.icon)),
          const SizedBox(height: 10),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
