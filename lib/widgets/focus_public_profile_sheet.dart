import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ranking_profile.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';
import '../utils/profile_icon_access.dart';
import 'focus_design_system.dart';
import 'focus_metric_icon.dart';
import 'focus_social_components.dart';

class FocusPublicProfileSheet extends StatefulWidget {
  final RankingProfile profile;
  final bool isMe;
  final bool isFriend;
  final int? points;
  final String? league;
  final String? statusLabel;
  final Future<bool> Function()? onSendRequest;
  final Future<void> Function()? onRemove;

  const FocusPublicProfileSheet({
    super.key,
    required this.profile,
    this.isMe = false,
    this.isFriend = true,
    this.points,
    this.league,
    this.statusLabel,
    this.onSendRequest,
    this.onRemove,
  });

  @override
  State<FocusPublicProfileSheet> createState() =>
      _FocusPublicProfileSheetState();
}

class _FocusPublicProfileSheetState extends State<FocusPublicProfileSheet> {
  bool _sending = false;
  bool _sent = false;
  bool _removing = false;

  Future<void> _sendRequest() async {
    final action = widget.onSendRequest;
    if (action == null || _sending || _sent) return;
    setState(() => _sending = true);
    try {
      final sent = await action();
      if (!mounted || !sent) return;
      HapticFeedback.mediumImpact();
      setState(() => _sent = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(RankingService.friendlyRankingError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmRemoveFriend() async {
    final action = widget.onRemove;
    if (action == null || _removing) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar amigo'),
        content: Text(
          '¿Quieres eliminar a ${widget.profile.name} de tus amigos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.person_remove_rounded),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _removing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final league = _leagueLabel(widget.league ?? profile.rank);
    final accent = _leagueColor(league);
    final isFriend = widget.isFriend;
    final isMe = widget.isMe;
    final actionTitle = widget.statusLabel ??
        (isMe
            ? 'Tu perfil'
            : isFriend
                ? 'Perfil de amigo'
                : _sent
                    ? 'Solicitud enviada'
                    : 'Perfil encontrado');
    final actionSubtitle = isMe
        ? 'Este es tu perfil público en Focus.'
        : isFriend
            ? 'Ya forma parte de tus amigos en Focus.'
            : _sent
                ? 'Ahora espera a que acepte tu solicitud.'
                : 'Revisa su perfil antes de enviar la solicitud.';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FocusSurfaceCard(
              padding: const EdgeInsets.all(20),
              radius: 30,
              accent: accent,
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.24),
                  Theme.of(context).cardColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _PublicProfileAvatar(profile: profile, size: 116),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).cardColor,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: FocusLeagueIcon(
                            league: league,
                            size: 38,
                            elevated: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 24,
                                    height: 1.03,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.45,
                                  ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _careerLabel(profile.career),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        _PublicProfileChip(
                          icon: isMe
                              ? Icons.person_rounded
                              : isFriend
                                  ? Icons.people_alt_rounded
                                  : _sent
                                      ? Icons.check_circle_rounded
                                      : Icons.person_search_rounded,
                          label: actionTitle,
                          color: accent,
                        ),
                        const SizedBox(height: 8),
                        _PublicSocialStatus(profile: profile),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              actionSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _PublicMetricCard(
                  icon: Icons.bolt_rounded,
                  metricIcon: FocusMetricIconKind.points,
                  label: 'Puntos',
                  value: '${widget.points ?? profile.totalPoints}',
                  color: FocusPalette.amber,
                ),
                const SizedBox(width: 10),
                _PublicMetricCard(
                  icon: Icons.emoji_events_rounded,
                  customIcon: FocusLeagueIcon(
                    league: league,
                    size: 24,
                    elevated: false,
                  ),
                  label: 'Liga',
                  value: league,
                  color: accent,
                ),
                const SizedBox(width: 10),
                _PublicMetricCard(
                  icon: Icons.local_fire_department_rounded,
                  metricIcon: FocusMetricIconKind.streak,
                  label: 'Racha',
                  value: '${_profileStreak(profile)}',
                  color: FocusPalette.amber,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isMe
                  ? OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.person_rounded),
                      label: const Text('Este eres tú'),
                    )
                  : isFriend
                      ? OutlinedButton.icon(
                          onPressed: widget.onRemove == null || _removing
                              ? null
                              : _confirmRemoveFriend,
                          icon: _removing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_remove_rounded),
                          label: Text(
                            widget.onRemove == null
                                ? 'Ya está en tus amigos'
                                : _removing
                                    ? 'Eliminando...'
                                    : 'Eliminar de amigos',
                          ),
                          style: widget.onRemove == null
                              ? null
                              : OutlinedButton.styleFrom(
                                  foregroundColor: FocusPalette.danger,
                                  side: BorderSide(
                                    color: FocusPalette.danger
                                        .withValues(alpha: 0.38),
                                  ),
                                ),
                        )
                      : widget.onSendRequest == null
                          ? OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.visibility_rounded),
                              label: const Text('Perfil visto'),
                            )
                          : FilledButton.icon(
                              onPressed:
                                  (_sending || _sent) ? null : _sendRequest,
                              icon: _sent
                                  ? const Icon(Icons.check_circle_rounded)
                                  : _sending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person_add_alt_1_rounded),
                              label: Text(
                                _sent
                                    ? 'Solicitud enviada'
                                    : _sending
                                        ? 'Enviando solicitud...'
                                        : 'Enviar solicitud',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _sent
                                    ? FocusPalette.mint
                                    : FocusPalette.primary,
                                disabledBackgroundColor: _sent
                                    ? FocusPalette.mint
                                    : FocusPalette.primary
                                        .withValues(alpha: 0.56),
                                disabledForegroundColor: Colors.white,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
            ),
            if (!isMe && !isFriend && widget.onSendRequest != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'La solicitud se enviará con tu perfil público.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PublicProfileAvatar extends StatelessWidget {
  final RankingProfile profile;
  final double size;

  const _PublicProfileAvatar({
    required this.profile,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final asset = _profileIconAsset(profile);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  FocusPalette.primary.withValues(alpha: 0.12),
                  FocusPalette.cyan.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _PublicProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PublicProfileChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicSocialStatus extends StatelessWidget {
  final RankingProfile profile;

  const _PublicSocialStatus({required this.profile});

  @override
  Widget build(BuildContext context) {
    final status = _socialStatus(profile);
    return _PublicProfileChip(
      icon: status.icon,
      label: status.label,
      color: status.color,
    );
  }
}

class _PublicMetricCard extends StatelessWidget {
  final IconData icon;
  final Widget? customIcon;
  final FocusMetricIconKind? metricIcon;
  final String label;
  final String value;
  final Color color;

  const _PublicMetricCard({
    required this.icon,
    this.customIcon,
    this.metricIcon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FocusSurfaceCard(
        padding: const EdgeInsets.all(12),
        radius: 20,
        accent: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customIcon != null)
              SizedBox(width: 24, height: 24, child: customIcon)
            else if (metricIcon != null)
              FocusMetricIcon(kind: metricIcon!, size: 22, color: color)
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialStatus {
  final String label;
  final IconData icon;
  final Color color;

  const _SocialStatus(this.label, this.icon, this.color);
}

_SocialStatus _socialStatus(RankingProfile profile) {
  final now = DateTime.now();
  final active = profile.lastActive;
  final event = profile.lastPointEvent.toLowerCase();
  final streak = _profileStreak(profile);
  if (active != null && now.difference(active).inMinutes <= 45) {
    if (event == 'pomodoro') {
      return const _SocialStatus(
        'Estudió hace poco',
        Icons.timer_rounded,
        FocusPalette.mint,
      );
    }
    if (event == 'habit') {
      return const _SocialStatus(
        'Completó un hábito',
        Icons.check_circle_rounded,
        FocusPalette.teal,
      );
    }
    return const _SocialStatus(
      'Activo recientemente',
      Icons.bolt_rounded,
      FocusPalette.cyan,
    );
  }
  if (active != null && _isSameDay(active, now)) {
    return const _SocialStatus(
      'Estudió hoy',
      Icons.school_rounded,
      FocusPalette.primary,
    );
  }
  if (streak > 0) {
    return const _SocialStatus(
      'Racha activa',
      Icons.local_fire_department_rounded,
      FocusPalette.amber,
    );
  }
  if (active != null) {
    final days = now.difference(active).inDays.clamp(1, 999);
    return _SocialStatus(
      'Última vez hace $days d',
      Icons.history_rounded,
      FocusPalette.muted,
    );
  }
  return const _SocialStatus(
    'Listo para enfocarse',
    Icons.auto_awesome_rounded,
    FocusPalette.muted,
  );
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int _profileStreak(RankingProfile profile) {
  return int.tryParse('${profile.stats['currentStreak'] ?? 0}') ?? 0;
}

String _leagueLabel(String rank) {
  return switch (rank.trim().toLowerCase()) {
    'oro' || 'diamante' || 'platino' => 'Oro',
    'plata' => 'Plata',
    _ => 'Bronce',
  };
}

Color _leagueColor(String rank) {
  return switch (_leagueLabel(rank)) {
    'Oro' => FocusPalette.amber,
    'Plata' => const Color(0xFF64748B),
    _ => const Color(0xFFB45309),
  };
}

String _careerLabel(String career) {
  final cleaned = career.trim();
  return cleaned.isEmpty ? 'Sin carrera' : cleaned;
}

@visibleForTesting
String focusPublicProfileIconAsset(RankingProfile profile) {
  final rawAsset = '${profile.stats['profileIconAsset'] ?? ''}';
  if (rawAsset.trim().isNotEmpty) {
    return normalizeProfileIconAsset(rawAsset);
  }
  return profileIconAssetFromIndex(profile.stats['socialMascotIndex']);
}

String _profileIconAsset(RankingProfile profile) {
  return focusPublicProfileIconAsset(profile);
}
