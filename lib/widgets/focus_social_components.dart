import 'package:flutter/material.dart';

import '../models/ranking_profile.dart';
import '../utils/focus_icon_assets.dart';
import 'focus_design_system.dart';

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
          Image.asset(
            FocusIconAssets.league(info.name),
            width: size,
            height: size,
            fit: BoxFit.contain,
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
