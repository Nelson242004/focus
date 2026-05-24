import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_app_icon.dart';
import '../widgets/focus_design_system.dart';
import 'main_navigation_screen.dart';

const _permissionsCompletedKey = 'required_permissions_completed';

class RequiredPermissionsGate extends StatefulWidget {
  const RequiredPermissionsGate({super.key});

  static Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionsCompletedKey) ?? false;
  }

  static Future<bool> shouldSkipSetup() async {
    final completed = await isSetupCompleted();
    if (completed) return true;
    final accessibilityGranted =
        await FocusModeService.hasAccessibilityPermission();
    final overlayGranted = await FocusModeService.hasOverlayPermission();
    final allGranted = accessibilityGranted && overlayGranted;
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
  State<RequiredPermissionsGate> createState() =>
      _RequiredPermissionsGateState();
}

class _RequiredPermissionsGateState extends State<RequiredPermissionsGate> {
  late final Future<bool> _setupFuture;

  @override
  void initState() {
    super.initState();
    _setupFuture = RequiredPermissionsGate.shouldSkipSetup();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _setupFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const FocusSkeletonScaffold();
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

  bool get _allGranted => _accessibilityGranted && _overlayGranted;

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
      if (!_accessibilityGranted) await _requestAccessibility();
      if (!_overlayGranted) await _requestOverlay();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const FocusSkeletonScaffold();
    }

    if (_allGranted) {
      return const MainNavigationScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: FocusPageBackground(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const FocusAssetBadge(
                  kind: FocusAppIconKind.permissions,
                  fallback: Icons.security_rounded,
                  color: FocusPalette.primary,
                  size: 58,
                  iconSize: 38,
                ),
                const SizedBox(height: 14),
                Text(
                  'Permisos de Focus',
                  style: FocusTypography.screenTitle(context),
                ),
                const SizedBox(height: 10),
                Text(
                  'Puedes omitirlos ahora. Te los pediremos cuando actives recordatorios o bloqueo de apps.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _PermissionStatusCard(
                        icon: Icons.notifications_active_rounded,
                        title: 'Notificaciones',
                        subtitle: 'Pomodoro y recordatorios.',
                        granted: _notificationsGranted,
                        onTap: _requestNotifications,
                        required: false,
                      ),
                      const SizedBox(height: 12),
                      _PermissionStatusCard(
                        icon: Icons.accessibility_new_rounded,
                        title: 'Accesibilidad',
                        subtitle: 'Detecta apps bloqueadas.',
                        granted: _accessibilityGranted,
                        onTap: _requestAccessibility,
                      ),
                      const SizedBox(height: 12),
                      _PermissionStatusCard(
                        icon: Icons.layers_rounded,
                        title: 'Superposición',
                        subtitle: 'Muestra el bloqueo.',
                        granted: _overlayGranted,
                        onTap: _requestOverlay,
                      ),
                      const SizedBox(height: 12),
                      _PermissionStatusCard(
                        icon: Icons.manage_search_rounded,
                        title: 'Acceso de uso',
                        subtitle: 'Ayuda al diagnóstico.',
                        granted: _usageGranted,
                        onTap: _requestUsageAccess,
                        required: false,
                      ),
                      const SizedBox(height: 12),
                      _PermissionStatusCard(
                        icon: Icons.battery_charging_full_rounded,
                        title: 'Batería',
                        subtitle: 'Mejora la persistencia.',
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
                      _requesting ? 'Revisando permisos...' : 'Activar bloqueo',
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _requesting
                        ? null
                        : () async {
                            await RequiredPermissionsGate.markSetupCompleted();
                            if (!context.mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const MainNavigationScreen(),
                              ),
                            );
                          },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Omitir por ahora'),
                  ),
                ),
              ],
            ),
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
