import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ranking_profile.dart';
import '../services/ranking_service.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_feedback.dart';

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
        if (!widget.requireAccount) {
          unawaited(RankingService.ensureCurrentWeekScore());
          return widget.child;
        }
        return FutureBuilder<RankingProfile?>(
          future: RankingService.ensureProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const FocusSkeletonScaffold();
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
  State<LoginScreen> createState() => _DuoLoginScreenState();
}

class _DuoLoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _showEmailForm = false;

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
    showFocusFeedback(context, message: message, type: FocusFeedbackType.info);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _FocusLoginBackdrop(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _showEmailForm
                ? _EmailLoginStep(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    creatingAccount: _creatingAccount,
                    loading: _loading,
                    obscurePassword: _obscurePassword,
                    onBack: () => setState(() => _showEmailForm = false),
                    onToggleMode: () => setState(
                      () => _creatingAccount = !_creatingAccount,
                    ),
                    onTogglePassword: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    onSubmitEmail: _submitEmail,
                    onSubmitGoogle: _submitGoogle,
                    onResetPassword: _resetPassword,
                  )
                : _LoginChoiceStep(
                    loading: _loading,
                    canPop: Navigator.of(context).canPop(),
                    onBack: () => Navigator.of(context).pop(),
                    onSignIn: () => setState(() {
                      _creatingAccount = false;
                      _showEmailForm = true;
                    }),
                  ),
          ),
        ),
      ),
    );
  }
}

const _loginStroke = Color(0xFF28435F);
const _loginPrimary = FocusPalette.primary;
const _loginMint = FocusPalette.mint;
const _loginTextMuted = Color(0xFF9FB4CC);

bool _loginIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _loginBackground(BuildContext context) => _loginIsDark(context)
    ? FocusPalette.darkSurfaceTop
    : FocusPalette.surfaceTop;

Color _loginCard(BuildContext context) =>
    _loginIsDark(context) ? FocusPalette.darkCard : Theme.of(context).cardColor;

Color _loginBorder(BuildContext context) => _loginIsDark(context)
    ? FocusPalette.darkBorder
    : FocusPalette.border.withValues(alpha: 0.95);

Color _loginText(BuildContext context) =>
    _loginIsDark(context) ? Colors.white : FocusPalette.ink;

Color _loginMuted(BuildContext context) =>
    _loginIsDark(context) ? _loginTextMuted : FocusPalette.muted;

Color _loginSoftFill(BuildContext context) => _loginIsDark(context)
    ? Colors.white.withValues(alpha: 0.06)
    : FocusPalette.primarySoft.withValues(alpha: 0.74);

class _FocusLoginBackdrop extends StatelessWidget {
  final Widget child;

  const _FocusLoginBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = _loginIsDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _loginBackground(context),
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  FocusPalette.darkSurfaceTop,
                  FocusPalette.darkCard,
                  FocusPalette.darkSurfaceTint,
                ]
              : const [
                  FocusPalette.surfaceTop,
                  FocusPalette.surfaceMid,
                  FocusPalette.surfaceTint,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

class _LoginSurfaceCard extends StatelessWidget {
  final Widget child;

  const _LoginSurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _loginCard(context),
        border: Border.all(color: _loginBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: _loginIsDark(context) ? 0.18 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LoginChoiceStep extends StatelessWidget {
  final bool loading;
  final bool canPop;
  final VoidCallback onBack;
  final VoidCallback onSignIn;

  const _LoginChoiceStep({
    required this.loading,
    required this.canPop,
    required this.onBack,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('choice-step'),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
      children: [
        _LoginTopBar(enabled: !loading && canPop, onBack: onBack),
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        _LoginSurfaceCard(
          child: Column(
            children: [
              const _FocusWelcomeMark(),
              const SizedBox(height: 18),
              Text(
                'Bienvenido a Focus',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _loginText(context),
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Inicia sesión para usar perfil, ranking y progreso social.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _loginMuted(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              const _FocusLoginFeatureStrip(),
              const SizedBox(height: 20),
              _DuoPrimaryButton(
                label: 'Iniciar sesión',
                loading: false,
                onPressed: loading ? null : onSignIn,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FocusLoginFeatureStrip extends StatelessWidget {
  const _FocusLoginFeatureStrip();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: const [
        _FocusMiniBenefit(
          icon: Icons.emoji_events_rounded,
          label: 'Ranking',
        ),
        _FocusMiniBenefit(
          icon: Icons.groups_rounded,
          label: 'Perfil',
        ),
        _FocusMiniBenefit(
          icon: Icons.shield_rounded,
          label: 'Enfoque',
        ),
      ],
    );
  }
}

class _FocusMiniBenefit extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FocusMiniBenefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _loginSoftFill(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _loginBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _loginPrimary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _loginText(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailLoginStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool creatingAccount;
  final bool loading;
  final bool obscurePassword;
  final VoidCallback onBack;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmitEmail;
  final VoidCallback onSubmitGoogle;
  final VoidCallback onResetPassword;

  const _EmailLoginStep({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.creatingAccount,
    required this.loading,
    required this.obscurePassword,
    required this.onBack,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.onSubmitEmail,
    required this.onSubmitGoogle,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('email-step'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
          child: _LoginTopBar(
            enabled: !loading,
            onBack: onBack,
            title: creatingAccount ? 'Crear cuenta' : 'Iniciar sesión',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 24),
            children: [
              _FocusLoginHeroCard(creatingAccount: creatingAccount),
              const SizedBox(height: 22),
              _FocusAuthDataCard(
                formKey: formKey,
                emailController: emailController,
                passwordController: passwordController,
                creatingAccount: creatingAccount,
                obscurePassword: obscurePassword,
                loading: loading,
                onTogglePassword: onTogglePassword,
                onSubmit: onSubmitEmail,
              ),
              const SizedBox(height: 28),
              _DuoPrimaryButton(
                label: creatingAccount ? 'CREAR CUENTA' : 'INGRESAR',
                loading: loading,
                onPressed: loading ? null : onSubmitEmail,
              ),
              if (!creatingAccount) ...[
                const SizedBox(height: 26),
                Center(
                  child: TextButton(
                    onPressed: loading ? null : onResetPassword,
                    child: const Text(
                      'RESTABLECER CONTRASEÑA',
                      style: TextStyle(
                        color: _loginPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DuoSocialButton(
                      label: 'GOOGLE',
                      icon: Icons.g_mobiledata_rounded,
                      color: const Color(0xFF4285F4),
                      onPressed: loading ? null : onSubmitGoogle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _DuoSocialButton(
                      label: creatingAccount ? 'ENTRAR' : 'CREAR',
                      icon: creatingAccount
                          ? Icons.login_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: _loginMint,
                      onPressed: loading ? null : onToggleMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                creatingAccount
                    ? 'Tu cuenta guarda ranking, amigos e insignias.'
                    : 'Focus sincroniza tu progreso sin tocar tus materias.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _loginMuted(context).withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginTopBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onBack;
  final String? title;

  const _LoginTopBar({
    required this.enabled,
    required this.onBack,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _loginSoftFill(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _loginBorder(context),
                ),
              ),
              child: IconButton(
                onPressed: enabled ? onBack : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 27),
                color: _loginText(context).withValues(
                  alpha: enabled ? 0.86 : 0.32,
                ),
                tooltip: 'Volver',
              ),
            ),
          ),
          if (title != null)
            Text(
              title!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _loginText(context),
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _FocusMascotIntro extends StatelessWidget {
  const _FocusMascotIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _loginStroke, width: 2.4),
          ),
          child: const Text(
            '¡Hola! Yo soy Focus.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: FocusPalette.studyGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: FocusPalette.cyan.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(
            Icons.center_focus_strong_rounded,
            color: Colors.white,
            size: 58,
          ),
        ),
      ],
    );
  }
}

class _FocusWelcomeMark extends StatelessWidget {
  const _FocusWelcomeMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
          border: Border.all(color: _loginBorder(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _loginIsDark(context) ? 0.16 : 0.06,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Image.asset(
          'assets/icon.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _FocusLoginBrief extends StatelessWidget {
  final bool creatingAccount;

  const _FocusLoginBrief({required this.creatingAccount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            FocusPalette.primaryDeep.withValues(alpha: 0.96),
            FocusPalette.cyan.withValues(alpha: 0.78),
            FocusPalette.teal.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: FocusPalette.cyan.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creatingAccount ? 'Tu perfil Focus' : 'Tu progreso te espera',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  creatingAccount
                      ? 'Crea una cuenta para competir, sumar insignias y estudiar con amigos.'
                      : 'Ingresa para recuperar ranking, rachas e insignias.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusLoginHeroCard extends StatelessWidget {
  final bool creatingAccount;

  const _FocusLoginHeroCard({required this.creatingAccount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _loginCard(context),
        border: Border.all(color: _loginBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
            ),
            child: Image.asset('assets/icon.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creatingAccount ? 'Crear cuenta' : 'Iniciar sesión',
                  style: TextStyle(
                    color: _loginText(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  creatingAccount
                      ? 'Guarda tu perfil, puntos y ranking.'
                      : 'Entra para recuperar tu perfil y ranking.',
                  style: TextStyle(
                    color: _loginMuted(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusAuthDataCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool creatingAccount;
  final bool obscurePassword;
  final bool loading;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const _FocusAuthDataCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.creatingAccount,
    required this.obscurePassword,
    required this.loading,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: _loginCard(context),
          border: Border.all(color: _loginBorder(context)),
        ),
        child: Column(
          children: [
            _FocusTextField(
              controller: emailController,
              hint: 'Correo de Focus',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Escribe tu correo.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Ese correo no parece válido.';
                }
                return null;
              },
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: _loginBorder(context),
            ),
            _FocusTextField(
              controller: passwordController,
              hint: creatingAccount ? 'Mínimo 6 caracteres' : 'Contraseña',
              icon: Icons.lock_rounded,
              obscureText: obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!loading) onSubmit();
              },
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: _loginPrimary,
                  size: 24,
                ),
                tooltip: obscurePassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return 'Escribe tu contraseña.';
                if (text.length < 6) return 'Mínimo 6 caracteres.';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _FocusTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(
        color: _loginText(context),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _loginMuted(context).withValues(alpha: 0.72),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Icon(
          icon,
          color: _loginPrimary,
          size: 22,
        ),
        suffixIcon: suffixIcon,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        errorStyle: const TextStyle(
          color: Color(0xFFFFB4B4),
          fontWeight: FontWeight.w800,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }
}

// ignore: unused_element
class _AuthDataCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool creatingAccount;
  final bool obscurePassword;
  final bool loading;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const _AuthDataCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.creatingAccount,
    required this.obscurePassword,
    required this.loading,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _loginStroke, width: 2.4),
        ),
        child: Column(
          children: [
            _DuoTextField(
              controller: emailController,
              hint: 'Usuario o correo',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Escribe tu correo.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Ese correo no parece válido.';
                }
                return null;
              },
            ),
            Divider(height: 1, thickness: 2, color: _loginStroke),
            _DuoTextField(
              controller: passwordController,
              hint: creatingAccount ? 'Mínimo 6 caracteres' : 'Contraseña',
              obscureText: obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!loading) onSubmit();
              },
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: _loginPrimary,
                  size: 34,
                ),
                tooltip: obscurePassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return 'Escribe tu contraseña.';
                if (text.length < 6) return 'Mínimo 6 caracteres.';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DuoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _DuoTextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 23,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.32),
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
        suffixIcon: suffixIcon,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      ),
    );
  }
}

class _DuoPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _DuoPrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: enabled ? _loginPrimary : _loginBorder(context),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _loginPrimary.withValues(alpha: 0.18),
                      offset: const Offset(0, 8),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _DuoOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _DuoOutlineButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(66),
        side: const BorderSide(color: _loginStroke, width: 2.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        foregroundColor: _loginMint,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.1,
        ),
      ),
    );
  }
}

class _DuoSocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _DuoSocialButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: _loginSoftFill(context),
        side: BorderSide(
          color: _loginBorder(context),
          width: 1.4,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        foregroundColor: _loginText(context),
      ),
      icon: Icon(icon, color: color, size: 24),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _LegacyLoginScreen extends StatefulWidget {
  const _LegacyLoginScreen();

  @override
  State<_LegacyLoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LegacyLoginScreen> {
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
    showFocusFeedback(context, message: message, type: FocusFeedbackType.info);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor:
          isDark ? FocusPalette.darkSurfaceTop : FocusPalette.surfaceTop,
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
      showFocusFeedback(
        context,
        message: RankingService.friendlyRankingError(error),
        type: FocusFeedbackType.error,
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
