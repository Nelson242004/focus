import 'package:flutter/material.dart';

import 'focus_app_icon.dart';
import 'focus_design_system.dart';

class FocusEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;
  final IconData icon;
  final FocusAppIconKind? iconKind;
  final Color? accent;

  const FocusEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.center_focus_strong_rounded,
    this.iconKind,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: FocusCuteCard(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          accent: color,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: 156,
                  height: 126,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 8,
                        top: 18,
                        child: _EmptyBubble(
                          size: 28,
                          color: color.withValues(alpha: 0.16),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 4,
                        child: _EmptyBubble(
                          size: 22,
                          color: color.withValues(alpha: 0.20),
                        ),
                      ),
                      Positioned(
                        right: 22,
                        bottom: 13,
                        child: _EmptyBubble(
                          size: 32,
                          color: color.withValues(alpha: 0.12),
                        ),
                      ),
                      Positioned(
                        left: 30,
                        bottom: 8,
                        child: _EmptySpark(color: color),
                      ),
                      Positioned(
                        right: 34,
                        top: 32,
                        child:
                            _EmptySpark(color: color.withValues(alpha: 0.72)),
                      ),
                      Center(
                        child: _EmptySectionIcon(
                          icon: icon,
                          iconKind: iconKind,
                          color: color,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FocusGap.sm,
              Text(
                title,
                textAlign: TextAlign.center,
                style: FocusTypography.sectionTitle(context),
              ),
              FocusGap.xs,
              Text(
                message,
                textAlign: TextAlign.center,
                style: FocusTypography.helper(context),
              ),
              if (action != null) ...[
                FocusGap.md,
                SizedBox(
                  width: double.infinity,
                  child: FilledButtonTheme(
                    data: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    child: action!,
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

class FocusCenteredEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;
  final IconData icon;
  final FocusAppIconKind? iconKind;
  final Color? accent;
  final double? height;
  final EdgeInsetsGeometry padding;

  const FocusCenteredEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.center_focus_strong_rounded,
    this.iconKind,
    this.accent,
    this.height,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: padding,
      child: FocusEmptyState(
        title: title,
        message: message,
        action: action,
        icon: icon,
        iconKind: iconKind,
        accent: accent,
      ),
    );
    const alignment = Alignment(0, -0.08);

    if (height == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedHeight) {
            return Align(alignment: alignment, child: child);
          }
          final fallbackHeight = MediaQuery.sizeOf(context).height * 0.54;
          return SizedBox(
            height: fallbackHeight.clamp(340.0, 480.0),
            child: Align(alignment: alignment, child: child),
          );
        },
      );
    }

    return SizedBox(
      height: height,
      child: Align(alignment: alignment, child: child),
    );
  }
}

class _EmptySectionIcon extends StatelessWidget {
  final IconData icon;
  final FocusAppIconKind? iconKind;
  final Color color;
  final bool isDark;

  const _EmptySectionIcon({
    required this.icon,
    required this.iconKind,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(
        color: color,
        shadows: [
          Shadow(
            color: color.withValues(alpha: isDark ? 0.28 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: iconKind == null
          ? Icon(icon, size: 78)
          : FocusAppIcon(
              kind: iconKind!,
              size: 78,
              fallback: icon,
              fallbackColor: color,
            ),
    );
  }
}

class _EmptySpark extends StatelessWidget {
  final Color color;

  const _EmptySpark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome_rounded,
      size: 18,
      color: color,
    );
  }
}

class _EmptyBubble extends StatelessWidget {
  final double size;
  final Color color;

  const _EmptyBubble({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class FocusProfileEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;
  final IconData icon;
  final FocusAppIconKind? iconKind;
  final Color? accent;

  const FocusProfileEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.center_focus_strong_rounded,
    this.iconKind,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return FocusEmptyState(
      title: title,
      message: message,
      action: action,
      icon: icon,
      iconKind: iconKind,
      accent: accent,
    );
  }
}
