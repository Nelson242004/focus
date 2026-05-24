import 'package:flutter/material.dart';

import '../services/ranking_service.dart';
import '../utils/profile_icon_access.dart';
import 'focus_design_system.dart';

class FocusEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;
  final IconData icon;
  final Color? accent;
  final String? profileIconAsset;

  const FocusEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.center_focus_strong_rounded,
    this.accent,
    this.profileIconAsset,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return FocusCuteCard(
      padding: FocusInsets.panel,
      accent: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: color.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.13),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  profileIconAsset ?? defaultProfileIconAsset,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          FocusGap.md,
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
    );
  }
}

class FocusProfileEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;
  final IconData icon;
  final Color? accent;

  const FocusProfileEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.center_focus_strong_rounded,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (RankingService.currentUser == null) {
      return FocusEmptyState(
        title: title,
        message: message,
        action: action,
        icon: icon,
        accent: accent,
        profileIconAsset: defaultProfileIconAsset,
      );
    }

    return StreamBuilder(
      stream: RankingService.profileStream(),
      builder: (context, snapshot) {
        final asset = profileIconAssetFromIndex(
          snapshot.data?.stats['socialMascotIndex'],
          email: RankingService.currentUser?.email,
          enforceAccess: true,
        );
        return FocusEmptyState(
          title: title,
          message: message,
          action: action,
          icon: icon,
          accent: accent,
          profileIconAsset: asset,
        );
      },
    );
  }
}
