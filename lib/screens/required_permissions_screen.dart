import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import 'main_navigation_screen.dart';

const _permissionsCompletedKey = 'required_permissions_completed';

class RequiredPermissionsGate extends StatelessWidget {
  const RequiredPermissionsGate({super.key});

  static Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionsCompletedKey) ?? false;
  }

  static Future<bool> shouldSkipSetup() async {
    final notificationsGranted = await NotificationService.hasPermissions();
    final accessibilityGranted =
        await FocusModeService.hasAccessibilityPermission();
    final overlayGranted = await FocusModeService.hasOverlayPermission();
    final usageGranted = await FocusModeService.hasUsageAccessPermission();
    final allGranted = notificationsGranted &&
        accessibilityGranted &&
        overlayGranted &&
        usageGranted;
    final completed = await isSetupCompleted();
    if (completed && allGranted) return true;
    if (allGranted) {
      await markSetupCompleted();
    }
    return allGranted;
  }

  static Future<void> markSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsCompletedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: shouldSkipSetup(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! == true
            ? const MainNavigationScreen()
            : const RequiredPermissionsScreen();
      },
    );
  }
}

class RequiredPermissionsScreen extends StatefulWidget {
  const RequiredPermissionsScreen({super.key});

  @override
  State<RequiredPermissionsScreen> createState() =>
      _RequiredPermissionsScreenState();
}

class _RequiredPermissionsScreenState extends State<RequiredPermissionsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _requesting = false;
  bool _notificationsGranted = false;
  bool _accessibilityGranted = false;
  bool _overlayGranted = false;
  bool _usageGranted = false;
  bool _batteryGranted = false;

  bool get _allGranted =>
      _notificationsGranted &&
      _accessibilityGranted &&
      _overlayGranted &&
      _usageGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final notificationsGranted = await NotificationService.hasPermissions();
    final accessibilityGranted =
        await FocusModeService.hasAccessibilityPermission();
    final overlayGranted = await FocusModeService.hasOverlayPermission();
    final usageGranted = await FocusModeService.hasUsageAccessPermission();
    final batteryGranted =
        await FocusModeService.hasIgnoreBatteryOptimizationPermission();

    if (!mounted) return;
    setState(() {
      _notificationsGranted = notificationsGranted;
      _accessibilityGranted = accessibilityGranted;
      _overlayGranted = overlayGranted;
      _usageGranted = usageGranted;
      _batteryGranted = batteryGranted;
      _loading = false;
    });

    if (_allGranted) {
      await RequiredPermissionsGate.markSetupCompleted();
    }
  }

  Future<void> _requestNotifications() async {
    await NotificationService.ensurePermissions();
    await _refreshStatus();
  }

  Future<void> _requestAccessibility() async {
    await FocusModeService.openAccessibilitySettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshStatus();
  }

  Future<void> _requestOverlay() async {
    await FocusModeService.openOverlaySettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshStatus();
  }

  Future<void> _requestUsageAccess() async {
    await FocusModeService.openUsageAccessSettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshStatus();
  }

  Future<void> _requestBattery() async {
    await FocusModeService.openIgnoreBatteryOptimizationSettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshStatus();
  }

  Future<void> _requestAll() async {
    setState(() => _requesting = true);
    try {
      if (!_notificationsGranted) await _requestNotifications();
      if (!_accessibilityGranted) await _requestAccessibility();
      if (!_overlayGranted) await _requestOverlay();
      if (!_usageGranted) await _requestUsageAccess();
      if (!_batteryGranted) await _requestBattery();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_allGranted) {
      return const MainNavigationScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'Permisos esenciales',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                'Activa lo esencial antes de entrar. Así Focus podrá mantener vivo el Pomodoro y bloquear distracciones al instante.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _PermissionStatusCard(
                      icon: Icons.notifications_active_rounded,
                      title: 'Enviar notificaciones',
                      subtitle:
                          'Temporizador activo, recordatorios y avisos del enfoque.',
                      granted: _notificationsGranted,
                      onTap: _requestNotifications,
                    ),
                    const SizedBox(height: 12),
                    _PermissionStatusCard(
                      icon: Icons.accessibility_new_rounded,
                      title: 'Accesibilidad',
                      subtitle:
                          'Detecta al instante cuando entras a una app bloqueada.',
                      granted: _accessibilityGranted,
                      onTap: _requestAccessibility,
                    ),
                    const SizedBox(height: 12),
                    _PermissionStatusCard(
                      icon: Icons.layers_rounded,
                      title: 'Mostrar sobre otras apps',
                      subtitle:
                          'Muestra la pantalla de bloqueo encima de la distracción.',
                      granted: _overlayGranted,
                      onTap: _requestOverlay,
                    ),
                    const SizedBox(height: 12),
                    _PermissionStatusCard(
                      icon: Icons.manage_search_rounded,
                      title: 'Acceso de uso',
                      subtitle:
                          'Permite saber qué app está abierta para bloquearla al instante.',
                      granted: _usageGranted,
                      onTap: _requestUsageAccess,
                    ),
                    const SizedBox(height: 12),
                    _PermissionStatusCard(
                      icon: Icons.battery_charging_full_rounded,
                      title: 'Ignorar optimización de batería',
                      subtitle:
                          'Opcional, pero ayuda a que el bloqueo dure mejor fuera de la app.',
                      granted: _batteryGranted,
                      onTap: _requestBattery,
                      required: false,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _requesting ? null : _requestAll,
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.security_rounded),
                  label: Text(
                    _requesting
                        ? 'Revisando permisos...'
                        : 'Completar configuración',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _requesting ? null : _refreshStatus,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Volver a comprobar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onTap;
  final bool required;

  const _PermissionStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = granted
        ? const Color(0xFF34D399)
        : Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Theme.of(context).cardColor,
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: accent.withValues(alpha: 0.16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: granted
                                ? accent.withValues(alpha: 0.16)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: granted
                                  ? accent
                                  : Theme.of(context).dividerColor,
                              width: 1.6,
                            ),
                          ),
                          child: Icon(
                            granted ? Icons.check_rounded : Icons.add_rounded,
                            color:
                                granted ? accent : Theme.of(context).hintColor,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle),
                    const SizedBox(height: 10),
                    Text(
                      granted
                          ? 'Listo'
                          : required
                              ? 'Toca para activarlo'
                              : 'Opcional, pero recomendado',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
