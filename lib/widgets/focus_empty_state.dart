import 'package:flutter/material.dart';

import '../services/ranking_service.dart';
import '../utils/profile_icon_access.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
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
                    radius: 16,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 17),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
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
