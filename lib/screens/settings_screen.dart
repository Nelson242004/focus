import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../providers/app_provider.dart';
import '../services/backup_service.dart';
import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../services/ranking_service.dart';
import '../services/update_service.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import 'auth_gate_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _weeklyGoal = 8;
  String _selectedSound = 'chime';
  String _selectedStartScreen = 'dashboard';
  String _breakAfterFocus = 'auto';
  double _textScale = 1.0;
  bool _animationsEnabled = true;
  bool _notificationsEnabled = true;
  bool _examReminderDayBefore = true;
  bool _examReminderTwoHoursBefore = true;
  bool _examReminderThirtyMinutesBefore = false;
  late String _accentColor;

  static const List<String> _accentPalette = FocusPalette.accentHexOptions;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _weeklyGoal = provider.settings.weeklyGoal.clamp(1, 99);
    _selectedSound = provider.settings.sound;
    _selectedStartScreen = provider.settings.startScreen == 'statistics'
        ? 'dashboard'
        : provider.settings.startScreen;
    _breakAfterFocus = provider.settings.breakAfterFocus;
    _textScale = provider.settings.textScale;
    _animationsEnabled = provider.settings.animationsEnabled;
    _notificationsEnabled = provider.settings.notificationsEnabled;
    _examReminderDayBefore = provider.settings.examReminderDayBefore;
    _examReminderTwoHoursBefore = provider.settings.examReminderTwoHoursBefore;
    _examReminderThirtyMinutesBefore =
        provider.settings.examReminderThirtyMinutesBefore;
    _accentColor = provider.settings.accentColor;
  }

  @override
  void dispose() => super.dispose();

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveSettings() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final goal = _weeklyGoal.clamp(1, 99);

    await provider.updateSettings(
      AppSettings(
        themeMode: provider.settings.themeMode,
        focusTime: provider.settings.focusTime,
        shortBreakTime: provider.settings.shortBreakTime,
        longBreakTime: provider.settings.longBreakTime,
        weeklyGoal: goal,
        sound: _selectedSound,
        selectedIdentity: provider.settings.selectedIdentity,
        startScreen: _selectedStartScreen,
        textScale: _textScale,
        animationsEnabled: _animationsEnabled,
        accentColor: _accentColor,
        notificationsEnabled: _notificationsEnabled,
        examReminderDayBefore: _examReminderDayBefore,
        examReminderTwoHoursBefore: _examReminderTwoHoursBefore,
        examReminderThirtyMinutesBefore: _examReminderThirtyMinutesBefore,
        onboardingCompleted: provider.settings.onboardingCompleted,
        breakAfterFocus: _breakAfterFocus,
        userName: provider.settings.userName,
      ),
    );
    if (!mounted) return;
    _showMessage('Listo. Tu configuración quedó guardada.');
  }

  void _setWeeklyGoal(int value) {
    setState(() => _weeklyGoal = value.clamp(1, 99));
  }

  Future<void> _exportData() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await BackupService.exportBackup(provider);
      if (!mounted) return;
      _showMessage('Backup creado. Guárdalo en un lugar seguro.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'No se pudo exportar el backup. Revisa el espacio disponible e intenta otra vez.',
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Tus materias, exámenes y recursos quedan guardados en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await RankingService.signOut();
      if (!mounted) return;
      setState(() {});
      _showMessage('Sesión cerrada.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(RankingService.friendlyRankingError(error));
    }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) setState(() {});
  }

  String _notificationSummary() {
    if (!_notificationsEnabled) return 'Notificaciones desactivadas.';
    final enabled = <String>[
      if (_examReminderDayBefore) '1 día antes',
      if (_examReminderTwoHoursBefore) '2 horas antes',
      if (_examReminderThirtyMinutesBefore) '30 minutos antes',
    ];
    if (enabled.isEmpty) return 'Sin avisos de examen activos.';
    return 'Avisos: ${enabled.join(', ')}.';
  }

  Future<void> _chooseBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      final picked = result?.files.single;
      if (picked == null || picked.bytes == null) return;
      await _restoreBackupFromSelection(picked.bytes!, picked.name);
    } catch (error) {
      if (!mounted) return;
      _showMessage(BackupService.friendlyBackupError(error));
    }
  }

  Future<void> _importLatestBackup() async {
    try {
      final latestData = await BackupService.latestBackupData();
      if (latestData == null) {
        throw const FormatException(
          'No se encontró un backup reciente dentro de Focus.',
        );
      }

      await _restoreBackupFromData(
        latestData,
        'Último backup guardado en Focus',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(BackupService.friendlyBackupError(error));
    }
  }

  Future<void> _restoreBackupFromSelection(
    Uint8List bytes,
    String fileName,
  ) async {
    final data = await BackupService.readBackupBytes(bytes);
    await _restoreBackupFromData(data, fileName);
  }

  Future<void> _restoreBackupFromData(
    Map<String, dynamic> data,
    String sourceLabel,
  ) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: Text(
          'Se reemplazarán tus datos actuales por el backup:\n$sourceLabel',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    await BackupService.restoreBackupData(provider, data);

    if (!mounted) return;
    _showMessage('Backup restaurado. Tus datos ya están de vuelta.');
  }

  Future<void> _deleteAllData() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar toda la app'),
        content: const Text(
          'Esta acción elimina materias, exámenes, hábitos, recursos y sesiones. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await provider.clearAllData();
      if (!mounted) return;
      _showMessage('Datos borrados. Focus quedó limpio.');
    }
  }

  Future<void> _testNotification() async {
    try {
      final granted = await NotificationService.ensurePermissions();
      if (!granted) {
        if (!mounted) return;
        _showMessage(
          'Activa los permisos de notificaciones desde Android para probarlas.',
        );
        return;
      }

      await NotificationService.showTestNotification();
      if (!mounted) return;
      _showMessage('Notificación de prueba enviada. Revisa la barra superior.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'No pudimos lanzar la prueba. Revisa permisos de notificación y batería.',
      );
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showMessage('El enlace no es válido.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showMessage('No se pudo abrir el enlace.');
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final info = await UpdateService.checkForUpdates();
      if (!mounted) return;
      await _openExternalUrl(info.apkUrl);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'No se pudo abrir la actualización. Revisa tu conexión e intenta otra vez.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          IconButton(
            tooltip: 'Guardar',
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SettingsHero(provider: provider),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Cuenta',
              icon: Icons.person_rounded,
              children: [
                _AccountSettingsContent(
                  onLogin: _openLogin,
                  onSignOut: _signOut,
                  onProfileUpdated: () => setState(() {}),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Apariencia',
              icon: Icons.palette_rounded,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modo oscuro puro'),
                  subtitle: const Text(
                      'Usa una interfaz más cómoda para estudiar de noche.'),
                  value: provider.settings.themeMode == ThemeModeSetting.dark,
                  onChanged: (_) => provider.toggleTheme(),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStartScreen,
                  decoration:
                      const InputDecoration(labelText: 'Pantalla inicial'),
                  items: const [
                    DropdownMenuItem(
                        value: 'dashboard', child: Text('Dashboard')),
                    DropdownMenuItem(
                        value: 'pomodoro', child: Text('Pomodoro')),
                    DropdownMenuItem(
                        value: 'subjects', child: Text('Materias')),
                    DropdownMenuItem(value: 'habits', child: Text('Hábitos')),
                  ],
                  onChanged: (value) => setState(
                      () => _selectedStartScreen = value ?? 'dashboard'),
                ),
                const SizedBox(height: 10),
                Text('Tamaño del texto: ${_textScale.toStringAsFixed(2)}x'),
                Slider(
                  value: _textScale,
                  min: 0.9,
                  max: 1.2,
                  divisions: 6,
                  label: _textScale.toStringAsFixed(2),
                  onChanged: (value) => setState(() => _textScale = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Animaciones'),
                  subtitle:
                      const Text('Activa o reduce transiciones visuales.'),
                  value: _animationsEnabled,
                  onChanged: (value) =>
                      setState(() => _animationsEnabled = value),
                ),
                const SizedBox(height: 8),
                Text('Color principal',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _accentPalette.map((colorHex) {
                    final selected = _accentColor == colorHex;
                    return GestureDetector(
                      onTap: () => setState(() => _accentColor = colorHex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorFromHex(colorHex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Notificaciones',
              icon: Icons.notifications_active_rounded,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recordatorios de exámenes'),
                  subtitle: Text(_notificationSummary()),
                  value: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avisar 1 día antes'),
                  value: _examReminderDayBefore,
                  onChanged: _notificationsEnabled
                      ? (value) =>
                          setState(() => _examReminderDayBefore = value)
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avisar 2 horas antes'),
                  subtitle: const Text('Solo para exámenes con hora.'),
                  value: _examReminderTwoHoursBefore,
                  onChanged: _notificationsEnabled
                      ? (value) =>
                          setState(() => _examReminderTwoHoursBefore = value)
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avisar 30 minutos antes'),
                  subtitle: const Text('Solo para exámenes con hora.'),
                  value: _examReminderThirtyMinutesBefore,
                  onChanged: _notificationsEnabled
                      ? (value) => setState(
                            () => _examReminderThirtyMinutesBefore = value,
                          )
                      : null,
                ),
                FutureBuilder<int>(
                  future: NotificationService.pendingNotificationsCount(),
                  builder: (context, snapshot) {
                    final pendingCount = snapshot.data ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded),
                      title: const Text('Recordatorios pendientes'),
                      subtitle: Text(
                        pendingCount == 0
                            ? 'No hay avisos programados ahora.'
                            : '$pendingCount avisos programados.',
                      ),
                    );
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _testNotification,
                  icon: const Icon(Icons.notification_add_rounded),
                  label: const Text('Probar notificación'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Objetivo semanal',
              icon: Icons.flag_rounded,
              children: [
                const Text(
                  'Los tiempos, sonido y Modo Enfoque Total se ajustan desde la pantalla Pomodoro.',
                ),
                const SizedBox(height: 12),
                _WeeklyGoalControl(
                  value: _weeklyGoal,
                  onChanged: _setWeeklyGoal,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Guardar objetivo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Actualizaciones',
              icon: Icons.system_update_alt_rounded,
              children: [
                _UpdateCard(onCheck: _checkForUpdates),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Estudio local y backup',
              icon: Icons.backup_rounded,
              children: [
                _AcademicLocalNotice(provider: provider),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exportData,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Exportar copia'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _chooseBackupFile,
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Restaurar copia'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importLatestBackup,
                      icon: const Icon(Icons.restore_page_rounded),
                      label: const Text('Último backup'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Diagnóstico',
              icon: Icons.health_and_safety_rounded,
              children: [
                const Text(
                  'Revisa rápidamente si Focus está listo para estudiar.',
                ),
                const SizedBox(height: 12),
                _DiagnosticPanel(provider: provider),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Zona peligrosa',
              icon: Icons.warning_amber_rounded,
              danger: true,
              children: [
                const Text(
                    'Estas acciones no se pueden deshacer. Exporta un backup antes.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _deleteAllData,
                  icon: const Icon(Icons.delete_forever_rounded,
                      color: Colors.red),
                  label: const Text('Borrar todos los datos',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSettingsContent extends StatelessWidget {
  final Future<void> Function() onLogin;
  final Future<void> Function() onSignOut;
  final VoidCallback onProfileUpdated;

  const _AccountSettingsContent({
    required this.onLogin,
    required this.onSignOut,
    required this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: RankingService.authStateChanges,
      initialData: RankingService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_rounded),
              title: Text(user?.email ?? 'Sin cuenta'),
              subtitle: Text(
                user == null
                    ? 'Puedes usar materias, exámenes y Pomodoro sin iniciar sesión.'
                    : 'Tu ranking y progreso social usan esta cuenta.',
              ),
            ),
            if (user == null)
              FilledButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Iniciar sesión'),
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_rounded),
                title: const Text('Perfil público'),
                subtitle: const Text('Editar nombre y carrera del ranking.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final profile = await RankingService.fetchProfile();
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileSetupScreen(
                        user: user,
                        profile: profile,
                      ),
                    ),
                  );
                  if (context.mounted) onProfileUpdated();
                },
              ),
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WeeklyGoalControl extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _WeeklyGoalControl({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.flag_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pomodoros por semana',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '$value sesiones',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: value >= 99 ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final Future<void> Function() onCheck;

  const _UpdateCard({required this.onCheck});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onCheck,
        icon: const Icon(Icons.system_update_rounded),
        label: const Text('Actualizar ahora'),
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  final AppProvider provider;

  const _SettingsHero({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: FocusPalette.studyGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Centro de control',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${provider.subjects.length} materias, ${provider.exams.length} exámenes y ${provider.activeStudyTasks.length} tareas activas.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicLocalNotice extends StatelessWidget {
  final AppProvider provider;

  const _AcademicLocalNotice({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Datos académicos locales',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Materias, horarios, exámenes y recursos se guardan en este dispositivo. Exporta una copia antes de cambiar de celular o borrar la app.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DiagnosticChip(
                icon: Icons.book_rounded,
                label: '${provider.subjects.length} materias',
              ),
              _DiagnosticChip(
                icon: Icons.assignment_rounded,
                label: '${provider.exams.length} exámenes',
              ),
              _DiagnosticChip(
                icon: Icons.task_alt_rounded,
                label: '${provider.activeStudyTasks.length} tareas activas',
              ),
              _DiagnosticChip(
                icon: Icons.link_rounded,
                label: '${provider.resources.length} recursos',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusDiagnosticData {
  final bool accessibility;
  final bool overlay;
  final bool usageAccess;
  final bool batteryIgnored;
  final int blockedApps;
  final int blockedAttempts;
  final bool focusSessionActive;
  final int pendingNotifications;

  const _FocusDiagnosticData({
    required this.accessibility,
    required this.overlay,
    required this.usageAccess,
    required this.batteryIgnored,
    required this.blockedApps,
    required this.blockedAttempts,
    required this.focusSessionActive,
    required this.pendingNotifications,
  });

  bool get focusReady => accessibility && overlay && usageAccess;
}

class _DiagnosticPanel extends StatefulWidget {
  final AppProvider provider;

  const _DiagnosticPanel({required this.provider});

  @override
  State<_DiagnosticPanel> createState() => _DiagnosticPanelState();
}

class _DiagnosticPanelState extends State<_DiagnosticPanel> {
  late Future<_FocusDiagnosticData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FocusDiagnosticData> _load() async {
    final results = await Future.wait<Object>([
      FocusModeService.hasAccessibilityPermission(),
      FocusModeService.hasOverlayPermission(),
      FocusModeService.hasUsageAccessPermission(),
      FocusModeService.hasIgnoreBatteryOptimizationPermission(),
      FocusModeService.loadConfig(),
      FocusModeService.getStatus(),
      NotificationService.pendingNotificationsCount(),
    ]);
    final config = results[4] as dynamic;
    final status = results[5] as dynamic;
    return _FocusDiagnosticData(
      accessibility: results[0] as bool,
      overlay: results[1] as bool,
      usageAccess: results[2] as bool,
      batteryIgnored: results[3] as bool,
      blockedApps: config.blockedApps.length as int,
      blockedAttempts: status.blockedAttempts as int,
      focusSessionActive: status.active as bool,
      pendingNotifications: results[6] as int,
    );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FocusDiagnosticData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: (data?.focusReady == true
                              ? FocusPalette.mint
                              : FocusPalette.coral)
                          .withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      data?.focusReady == true
                          ? Icons.verified_rounded
                          : Icons.tune_rounded,
                      color: data?.focusReady == true
                          ? FocusPalette.mint
                          : FocusPalette.coral,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data?.focusReady == true
                              ? 'Focus listo'
                              : 'Revisar Focus',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          data == null
                              ? 'Comprobando permisos y servicios.'
                              : '${data.blockedApps} apps · ${data.blockedAttempts} bloqueos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar diagnóstico',
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : _refresh,
                    icon: snapshot.connectionState == ConnectionState.waiting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DiagnosticChip(
                    icon: widget.provider.lastLoadError == null
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    label: widget.provider.lastLoadError == null
                        ? 'Datos OK'
                        : 'Carga local con error',
                  ),
                  _DiagnosticChip(
                    icon: RankingService.currentUser == null
                        ? Icons.person_off_rounded
                        : Icons.verified_user_rounded,
                    label: RankingService.currentUser == null
                        ? 'Sin cuenta'
                        : 'Cuenta activa',
                  ),
                  _DiagnosticChip(
                    icon: widget.provider.settings.notificationsEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    label: widget.provider.settings.notificationsEnabled
                        ? '${data?.pendingNotifications ?? 0} avisos'
                        : 'Notificaciones apagadas',
                  ),
                  _DiagnosticChip(
                    icon: data?.focusReady == true
                        ? Icons.shield_rounded
                        : Icons.shield_outlined,
                    label: data == null
                        ? 'Revisando enfoque'
                        : data.focusReady
                            ? 'Enfoque listo'
                            : 'Permisos pendientes',
                  ),
                ],
              ),
              if (data != null) ...[
                const SizedBox(height: 14),
                _DiagnosticRow(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Accesibilidad',
                  ok: data.accessibility,
                  detail: data.accessibility
                      ? 'Focus puede detectar apps abiertas.'
                      : 'Actívala para bloquear distracciones.',
                  onFix: data.accessibility
                      ? null
                      : FocusModeService.openAccessibilitySettings,
                ),
                _DiagnosticRow(
                  icon: Icons.layers_rounded,
                  title: 'Mostrar sobre otras apps',
                  ok: data.overlay,
                  detail: data.overlay
                      ? 'La pantalla de bloqueo puede aparecer encima.'
                      : 'Actívalo para mostrar el bloqueo visual.',
                  onFix: data.overlay
                      ? null
                      : FocusModeService.openOverlaySettings,
                ),
                _DiagnosticRow(
                  icon: Icons.query_stats_rounded,
                  title: 'Uso de apps',
                  ok: data.usageAccess,
                  detail: data.usageAccess
                      ? 'Focus puede verificar apps recientes.'
                      : 'Actívalo para mejorar la detección.',
                  onFix: data.usageAccess
                      ? null
                      : FocusModeService.openUsageAccessSettings,
                ),
                _DiagnosticRow(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'Suspensión de batería',
                  ok: data.batteryIgnored,
                  detail: data.batteryIgnored
                      ? 'Android no debería dormir el bloqueo.'
                      : 'Recomendado para sesiones largas.',
                  onFix: data.batteryIgnored
                      ? null
                      : FocusModeService.openIgnoreBatteryOptimizationSettings,
                ),
                const SizedBox(height: 6),
                _DiagnosticChip(
                  icon: data.focusSessionActive
                      ? Icons.play_circle_fill_rounded
                      : Icons.pause_circle_rounded,
                  label:
                      'Enfoque ${data.focusSessionActive ? 'activo' : 'inactivo'}',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool ok;
  final String detail;
  final Future<void> Function()? onFix;

  const _DiagnosticRow({
    required this.icon,
    required this.title,
    required this.ok,
    required this.detail,
    this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? FocusPalette.mint : FocusPalette.coral;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        detail,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: onFix == null
          ? Icon(Icons.check_circle_rounded, color: color)
          : TextButton(
              onPressed: onFix,
              child: const Text('Abrir'),
            ),
    );
  }
}

class _DiagnosticChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DiagnosticChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool danger;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? Colors.red : Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('settings-$title'),
          initiallyExpanded: false,
          maintainState: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: accent),
          ),
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          children: children,
        ),
      ),
    );
  }
}
