import 'dart:async';

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
          future: widget.requireAccount
              ? RankingService.ensureProfile()
              : RankingService.fetchProfile(),
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
              return widget.child;
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
  bool _obscurePassword = true;

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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showMessage('Escribe tu correo primero para enviarte el enlace.');
      return;
    }
    setState(() => _loading = true);
    try {
      await RankingService.sendPasswordResetEmail(email);
      _showMessage('Te enviamos un enlace para recuperar tu contraseña.');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    _showMessage(RankingService.friendlyRankingError(error));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF6F8FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _loading || !Navigator.of(context).canPop()
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () => setState(
                            () => _creatingAccount = !_creatingAccount,
                          ),
                  icon: Icon(
                    _creatingAccount
                        ? Icons.login_rounded
                        : Icons.person_add_alt_1_rounded,
                  ),
                  label: Text(_creatingAccount ? 'Entrar' : 'Crear cuenta'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _LoginHero(creatingAccount: _creatingAccount),
            const SizedBox(height: 16),
            _AuthPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.login_rounded),
                        label: Text('Entrar'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.person_add_rounded),
                        label: Text('Crear'),
                      ),
                    ],
                    selected: {_creatingAccount},
                    onSelectionChanged: _loading
                        ? null
                        : (selection) => setState(
                              () => _creatingAccount = selection.first,
                            ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _submitGoogle,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                    label: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 14),
                  _DividerLabel(
                    label: _creatingAccount
                        ? 'o crea una cuenta con correo'
                        : 'o entra con correo',
                  ),
                  const SizedBox(height: 14),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            hintText: 'tu@email.com',
                            prefixIcon: Icon(Icons.mail_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Escribe tu correo.';
                            }
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(text)) {
                              return 'Ese correo no parece válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) {
                            if (!_loading) unawaited(_submitEmail());
                          },
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            hintText: _creatingAccount
                                ? 'Mínimo 6 caracteres'
                                : 'Tu contraseña',
                            prefixIcon: const Icon(Icons.password_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded),
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                            ),
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.isEmpty) {
                              return 'Escribe tu contraseña.';
                            }
                            if (text.length < 6) {
                              return 'Mínimo 6 caracteres.';
                            }
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
                    label: Text(_creatingAccount
                        ? 'Crear cuenta y continuar'
                        : 'Iniciar sesión'),
                  ),
                  if (!_creatingAccount) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        child: const Text('Olvidé mi contraseña'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _AuthHint(
                    icon: _creatingAccount
                        ? Icons.auto_awesome_rounded
                        : Icons.verified_user_rounded,
                    color: primary,
                    text: _creatingAccount
                        ? 'No te pediremos nombre ahora. Focus creará tu perfil automáticamente.'
                        : 'Tu cuenta sincroniza ranking, amigos e insignias. Tus materias siguen disponibles sin tocar nada.',
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(
                              () => _creatingAccount = !_creatingAccount,
                            ),
                    child: Text(_creatingAccount
                        ? 'Ya tengo una cuenta'
                        : 'Soy nuevo, quiero crear cuenta'),
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

class _LoginHero extends StatelessWidget {
  final bool creatingAccount;

  const _LoginHero({required this.creatingAccount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF0F766E)],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creatingAccount ? 'Crea tu cuenta' : 'Bienvenido de vuelta',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  creatingAccount
                      ? 'Guarda tu progreso social sin configurar un perfil manual.'
                      : 'Entra para recuperar ranking, amigos e insignias.',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String label;

  const _DividerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _AuthHint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _AuthHint({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
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
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
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
