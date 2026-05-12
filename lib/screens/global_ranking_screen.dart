import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/ranking_profile.dart';
import '../services/ranking_service.dart';
import '../widgets/focus_drawer.dart';

class GlobalRankingScreen extends StatefulWidget {
  const GlobalRankingScreen({super.key});

  @override
  State<GlobalRankingScreen> createState() => _GlobalRankingScreenState();
}

class _GlobalRankingScreenState extends State<GlobalRankingScreen> {
  Timer? _hourlyTimer;
  DateTime _nextUpdate = RankingService.nextHourlyUpdate();
  Future<List<RankingEntry>>? _leaderboardFuture;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _hourlyTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = RankingService.nextHourlyUpdate();
      if (mounted && next != _nextUpdate && RankingService.currentUser != null) {
        setState(() {
          _nextUpdate = next;
          _leaderboardFuture = RankingService.fetchGlobalLeaderboard();
        });
      }
    });
  }

  @override
  void dispose() {
    _hourlyTimer?.cancel();
    super.dispose();
  }

  Future<List<RankingEntry>> _leaderboard() {
    return _leaderboardFuture ??= RankingService.fetchGlobalLeaderboard();
  }

  void _refreshLeaderboard() {
    setState(() {
      _leaderboardFuture = RankingService.fetchGlobalLeaderboard();
    });
  }

  Future<void> _signOut() async {
    await RankingService.signOut();
    if (mounted) {
      setState(() => _leaderboardFuture = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'ranking'),
      appBar: AppBar(title: const Text('Ranking global')),
      body: StreamBuilder<User?>(
        stream: RankingService.authStateChanges,
        initialData: RankingService.currentUser,
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;
          if (user == null) return _SignInPanel(onSignIn: _signIn);
          return StreamBuilder<RankingProfile?>(
            stream: RankingService.profileStream(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.hasError) {
                return _RankingErrorPanel(
                  title: 'No se pudo cargar tu perfil',
                  error: profileSnapshot.error,
                  onRetry: () => setState(() {}),
                  onSignOut: _signOut,
                );
              }
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final profile = profileSnapshot.data;
              if (profile == null) {
                return _ProfileSetupPanel(
                  user: user,
                  onSaved: _refreshLeaderboard,
                );
              }
              return _RankingBody(
                profile: profile,
                nextUpdate: _nextUpdate,
                leaderboardFuture: _leaderboard(),
                onRefresh: _refreshLeaderboard,
                onSignOut: _signOut,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      await RankingService.signInWithGoogle();
    } catch (error) {
      if (!mounted) return;
      debugPrint('[FocusRanking] Error login: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyRankingError(error)),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }
}

class _SignInPanel extends StatelessWidget {
  final Future<void> Function() onSignIn;

  const _SignInPanel({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_GlobalRankingScreenState>();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _HeroCard(
          title: 'Compite con estudiantes de Focus',
          subtitle:
              'El ranking global semanal se actualiza por hora y muestra puntos, carrera y rango.',
          icon: Icons.public_rounded,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: state?._signingIn == true ? null : onSignIn,
          icon: state?._signingIn == true
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_rounded),
          label: const Text('Entrar con Google'),
        ),
        const SizedBox(height: 12),
        Text(
          'Tu email no se muestra en el ranking. Solo se publica nombre, carrera, rango y puntos.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ProfileSetupPanel extends StatefulWidget {
  final User user;
  final VoidCallback onSaved;

  const _ProfileSetupPanel({
    required this.user,
    required this.onSaved,
  });

  @override
  State<_ProfileSetupPanel> createState() => _ProfileSetupPanelState();
}

class _ProfileSetupPanelState extends State<_ProfileSetupPanel> {
  late final TextEditingController _nameController;
  final _careerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _careerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _HeroCard(
            title: 'Prepara tu perfil público',
            subtitle: 'Esto será visible en el ranking global de Focus.',
            icon: Icons.person_pin_rounded,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 32,
            decoration: const InputDecoration(
              labelText: 'Nombre público',
              prefixIcon: Icon(Icons.badge_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.length < 2) return 'Escribe al menos 2 caracteres.';
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _careerController,
            textCapitalization: TextCapitalization.words,
            maxLength: 42,
            decoration: const InputDecoration(
              labelText: 'Carrera',
              hintText: 'Ej. Ingeniería Informática',
              prefixIcon: Icon(Icons.school_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.length < 2) return 'Escribe tu carrera.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch_rounded),
            label: const Text('Entrar al ranking'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await RankingService.saveProfile(
        name: _nameController.text,
        career: _careerController.text,
      );
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      debugPrint('[FocusRanking] Error guardando perfil: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyRankingError(error)),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RankingBody extends StatelessWidget {
  final RankingProfile profile;
  final DateTime nextUpdate;
  final Future<List<RankingEntry>> leaderboardFuture;
  final VoidCallback onRefresh;
  final Future<void> Function() onSignOut;

  const _RankingBody({
    required this.profile,
    required this.nextUpdate,
    required this.leaderboardFuture,
    required this.onRefresh,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RankingEntry>>(
      future: leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _RankingErrorPanel(
            title: 'No se pudo cargar el ranking',
            error: snapshot.error,
            onRetry: onRefresh,
            onSignOut: onSignOut,
          );
        }

        final entries = snapshot.data ?? const <RankingEntry>[];
        final myIndex = entries.indexWhere((entry) => entry.uid == profile.uid);
        final updateLabel = '${nextUpdate.hour.toString().padLeft(2, '0')}:00';

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _HeroCard(
              title: 'Liga global · ${RankingService.currentWeekId()}',
              subtitle:
                  'Próxima actualización visible: $updateLabel. Rango actual: ${profile.rank}.',
              icon: Icons.emoji_events_rounded,
            ),
            const SizedBox(height: 14),
            _MyRankCard(profile: profile, position: myIndex + 1),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (entries.isEmpty)
              const _EmptyRanking()
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
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar ahora'),
            ),
            const SizedBox(height: 8),
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

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF2563EB), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final RankingProfile profile;
  final int position;

  const _MyRankCard({required this.profile, required this.position});

  @override
  Widget build(BuildContext context) {
    final initial = profile.name.trim().isEmpty ? 'F' : profile.name.trim()[0];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              profile.photoUrl.isEmpty ? null : NetworkImage(profile.photoUrl),
          child: profile.photoUrl.isEmpty ? Text(initial) : null,
        ),
        title: Text(profile.name),
        subtitle: Text('${profile.career} · ${profile.rank}'),
        trailing: Text(
          position <= 0 ? 'Sin posición' : '#$position',
          style: const TextStyle(fontWeight: FontWeight.w900),
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
    final medal = switch (position) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '#$position',
    };
    return Card(
      color: isMe ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(child: Text(medal)),
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${entry.career} · ${entry.rank}'),
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

class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Todavía no hay puntos esta semana. Completa un Pomodoro para aparecer en el ranking.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _RankingErrorPanel extends StatelessWidget {
  final String title;
  final Object? error;
  final VoidCallback onRetry;
  final Future<void> Function()? onSignOut;

  const _RankingErrorPanel({
    required this.title,
    required this.error,
    required this.onRetry,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final message = _friendlyRankingError(error);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _HeroCard(
          title: title,
          subtitle: message,
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              '${error ?? 'Sin detalle técnico'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Probar de nuevo'),
        ),
        if (onSignOut != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ],
    );
  }
}

String _friendlyRankingError(Object? error) {
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Google canceló el inicio. Si elegiste una cuenta y volvió aquí, normalmente falta revisar SHA-1/SHA-256 o el cliente web OAuth.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google Sign-In está mal configurado. Revisa SHA-1/SHA-256, paquete com.example.focus_app y vuelve a descargar google-services.json.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'El proveedor de Google no está disponible o está mal configurado en el dispositivo.',
      _ => 'Google Sign-In falló: ${error.description ?? error.code.name}.',
    };
  }
  if (error is FirebaseAuthException) {
    return 'Firebase Auth falló (${error.code}): ${error.message ?? 'sin mensaje'}.';
  }
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Firestore rechazó la operación. Revisa las reglas de seguridad de la base de datos.';
    }
    if (error.code == 'failed-precondition') {
      return 'Firestore necesita un índice para esta consulta. Abre el enlace que aparece en logs o crea el índice sugerido.';
    }
    return 'Firebase falló (${error.plugin}/${error.code}): ${error.message ?? 'sin mensaje'}.';
  }
  return 'Algo falló en Ranking: ${error ?? 'sin detalle'}.';
}
