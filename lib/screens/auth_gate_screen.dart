import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ranking_profile.dart';
import '../services/ranking_service.dart';

class AuthGateScreen extends StatefulWidget {
  final Widget child;
  final bool requireAccount;

  const AuthGateScreen({
    super.key,
    required this.child,
    this.requireAccount = true,
  });

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  int _profileRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: RankingService.authStateChanges,
      initialData: RankingService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return widget.requireAccount ? const LoginScreen() : widget.child;
        }
        return FutureBuilder<RankingProfile?>(
          key: ValueKey(_profileRefresh),
          future: RankingService.fetchProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!widget.requireAccount &&
                (profileSnapshot.hasError || profileSnapshot.data == null)) {
              return widget.child;
            }
            final profile = profileSnapshot.data;
            if (profile == null) {
              return ProfileSetupScreen(
                user: user,
                onSaved: () => setState(() => _profileRefresh++),
              );
            }
            RankingService.ensureCurrentWeekScore();
            return widget.child;
          },
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_creatingAccount) {
        await RankingService.createUserWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await RankingService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _loading = true);
    try {
      await RankingService.signInWithGoogle();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(RankingService.friendlyRankingError(error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF6F8FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1D4ED8),
                    Color(0xFF0F766E)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.center_focus_strong_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Entrar a Focus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu progreso, puntos y ranking semanal quedan asociados a tu cuenta.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _AuthPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _submitGoogle,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'o con correo',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            prefixIcon: Icon(Icons.mail_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (!text.contains('@')) {
                              return 'Escribe un correo.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.password_rounded),
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.length < 6) return 'Mínimo 6 caracteres.';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submitEmail,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_creatingAccount
                            ? Icons.person_add_rounded
                            : Icons.login_rounded),
                    label: Text(
                        _creatingAccount ? 'Crear cuenta' : 'Iniciar sesión'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(
                            () => _creatingAccount = !_creatingAccount),
                    child: Text(_creatingAccount
                        ? 'Ya tengo cuenta'
                        : 'Crear cuenta con correo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  final Widget child;

  const _AuthPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  final User user;
  final RankingProfile? profile;
  final VoidCallback? onSaved;

  const ProfileSetupScreen({
    super.key,
    required this.user,
    this.profile,
    this.onSaved,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _careerController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.profile?.name ?? widget.user.displayName ?? '',
    );
    _careerController = TextEditingController(
      text: widget.profile?.career == 'Sin carrera'
          ? ''
          : widget.profile?.career ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _careerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await RankingService.saveProfile(
        name: _nameController.text,
        career: _careerController.text,
      );
      widget.onSaved?.call();
      if (mounted && widget.profile != null) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RankingService.friendlyRankingError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.profile == null ? null : AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: widget.user.photoURL == null
                          ? null
                          : NetworkImage(widget.user.photoURL!),
                      child: widget.user.photoURL == null
                          ? const Icon(Icons.person_rounded)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.profile == null
                                ? 'Tu perfil público'
                                : 'Editar perfil',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nombre y carrera se muestran en rankings y amigos.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 32,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'Escribe tu nombre.';
                  return null;
                },
              ),
              const SizedBox(height: 10),
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
                    : const Icon(Icons.check_rounded),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
