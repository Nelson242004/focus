import 'package:flutter/material.dart';

import '../utils/focus_palette.dart';

class FocusRadii {
  FocusRadii._();

  static const double chip = 999;
  static const double control = 16;
  static const double card = 24;
  static const double panel = 28;
}

class FocusSpacing {
  FocusSpacing._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

class FocusInsets {
  FocusInsets._();

  static const EdgeInsets page = EdgeInsets.fromLTRB(16, 16, 16, 32);
  static const EdgeInsets pageCompact = EdgeInsets.fromLTRB(16, 12, 16, 28);
  static const EdgeInsets card = EdgeInsets.all(16);
  static const EdgeInsets cardRelaxed = EdgeInsets.all(18);
  static const EdgeInsets panel = EdgeInsets.all(20);
}

class FocusGap {
  FocusGap._();

  static const Widget xs = SizedBox(height: FocusSpacing.xs);
  static const Widget sm = SizedBox(height: FocusSpacing.sm);
  static const Widget md = SizedBox(height: FocusSpacing.md);
  static const Widget lg = SizedBox(height: FocusSpacing.lg);
  static const Widget section = SizedBox(height: 16);
}

class FocusSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double radius;
  final bool elevated;
  final Gradient? gradient;

  const FocusSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FocusSpacing.lg),
    this.accent,
    this.radius = FocusRadii.panel,
    this.elevated = true,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? theme.cardColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.18 : 0.13),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: (isDark ? Colors.black : FocusPalette.ink)
                      .withValues(alpha: isDark ? 0.22 : 0.06),
                  blurRadius: isDark ? 18 : 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class FocusSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? accent;
  final double iconSize;

  const FocusSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.action,
    this.accent,
    this.iconSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(iconSize * 0.36),
            color: color.withValues(alpha: 0.11),
          ),
          child: Icon(icon, color: color, size: iconSize * 0.52),
        ),
        const SizedBox(width: FocusSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: FocusSpacing.sm),
          action!,
        ],
      ],
    );
  }
}

class FocusInlineState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? accent;

  const FocusInlineState({
    super.key,
    required this.icon,
    required this.text,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FocusSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: FocusSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class FocusPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;
  final bool selected;

  const FocusPill({
    super.key,
    this.icon,
    required this.label,
    this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: selected ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(FocusRadii.chip),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
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

class FocusStaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;
  final bool enabled;

  const FocusStaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 55).clamp(0, 260)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final eased = Curves.easeOutCubic.transform(value);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class FocusMicroPop extends StatelessWidget {
  final Object trigger;
  final Widget child;
  final Duration duration;
  final double fromScale;
  final double toScale;
  final bool fade;

  const FocusMicroPop({
    super.key,
    required this.trigger,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.fromScale = 0.94,
    this.toScale = 1,
    this.fade = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final scale = fromScale + ((toScale - fromScale) * value);
        final transformed = Transform.scale(scale: scale, child: child);
        if (!fade) return transformed;
        return Opacity(opacity: value.clamp(0, 1), child: transformed);
      },
      child: child,
    );
  }
}

class FocusActionSnackContent extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const FocusActionSnackContent({
    super.key,
    required this.icon,
    required this.message,
    this.color = FocusPalette.mint,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.92 + (value * 0.08),
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class FocusSkeletonCard extends StatefulWidget {
  final double height;
  final EdgeInsetsGeometry margin;

  const FocusSkeletonCard({
    super.key,
    this.height = 140,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<FocusSkeletonCard> createState() => _FocusSkeletonCardState();
}

class FocusSkeletonList extends StatelessWidget {
  final List<double> heights;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const FocusSkeletonList({
    super.key,
    this.heights = const [210, 88, 88, 88],
    this.padding = FocusInsets.pageCompact,
    this.spacing = FocusSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: heights.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (context, index) => FocusSkeletonCard(
        height: heights[index],
      ),
    );
  }
}

class FocusSkeletonScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final List<double> heights;
  final EdgeInsetsGeometry padding;

  const FocusSkeletonScaffold({
    super.key,
    this.appBar,
    this.heights = const [210, 88, 88, 88],
    this.padding = FocusInsets.pageCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: FocusSkeletonList(
        heights: heights,
        padding: padding,
      ),
    );
  }
}

class _FocusSkeletonCardState extends State<FocusSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? FocusPalette.darkCard : FocusPalette.card;
    final shine = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : FocusPalette.primary.withValues(alpha: 0.08);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = _controller.value;
        return Container(
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FocusRadii.panel),
            gradient: LinearGradient(
              begin: Alignment(-1 + x * 2, -1),
              end: Alignment(-0.2 + x * 2, 1),
              colors: [base, shine, base],
              stops: const [0.18, 0.5, 0.82],
            ),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
            ),
          ),
        );
      },
    );
  }
}
