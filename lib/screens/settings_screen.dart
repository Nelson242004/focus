import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../models/ranking_profile.dart';
import '../providers/app_provider.dart';
import '../services/backup_service.dart';
import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../services/ranking_service.dart';
import '../services/update_service.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';
import '../utils/profile_icon_access.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_feedback.dart';
import '../widgets/focus_metric_icon.dart';
import 'auth_gate_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _weeklyGoal = 8;
  int _weeklyFocusMinutesGoal = 300;
  int _dailyHabitGoal = 3;
  int _streakGoal = 7;
  AppLanguage _selectedLanguage = AppLanguage.system;
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
    _weeklyFocusMinutesGoal =
        provider.settings.weeklyFocusMinutesGoal.clamp(25, 3000);
    _dailyHabitGoal = provider.settings.dailyHabitGoal.clamp(1, 20);
    _streakGoal = provider.settings.streakGoal.clamp(1, 365);
    _selectedLanguage = provider.settings.language;
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
    showFocusFeedback(context, message: message, type: FocusFeedbackType.info);
  }

  Future<void> _saveSettings() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final goal = _weeklyGoal.clamp(1, 99);
    var notificationsEnabled = _notificationsEnabled;
    if (notificationsEnabled) {
      final granted = await NotificationService.ensurePermissions();
      if (!granted) {
        notificationsEnabled = false;
        if (mounted) {
          setState(() => _notificationsEnabled = false);
          _showMessage(
            'Notificaciones desactivadas. Puedes activarlas cuando quieras.',
          );
        }
      }
    }

    await provider.updateSettings(
      AppSettings(
        themeMode: provider.settings.themeMode,
        language: _selectedLanguage,
        focusTime: provider.settings.focusTime,
        shortBreakTime: provider.settings.shortBreakTime,
        longBreakTime: provider.settings.longBreakTime,
        weeklyGoal: goal,
        weeklyFocusMinutesGoal: _weeklyFocusMinutesGoal.clamp(25, 3000),
        dailyHabitGoal: _dailyHabitGoal.clamp(1, 20),
        streakGoal: _streakGoal.clamp(1, 365),
        sound: _selectedSound,
        selectedIdentity: provider.settings.selectedIdentity,
        startScreen: _selectedStartScreen,
        textScale: _textScale,
        animationsEnabled: _animationsEnabled,
        accentColor: _accentColor,
        notificationsEnabled: notificationsEnabled,
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

  void _setWeeklyFocusMinutesGoal(int value) {
    setState(() => _weeklyFocusMinutesGoal = value.clamp(25, 3000));
  }

  void _setDailyHabitGoal(int value) {
    setState(() => _dailyHabitGoal = value.clamp(1, 20));
  }

  void _setStreakGoal(int value) {
    setState(() => _streakGoal = value.clamp(1, 365));
  }

  Future<void> _resetPreferences() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restablecer configuración'),
        content: const Text(
          'Volverán a sus valores iniciales la apariencia, notificaciones, inicio y metas. Tus datos de estudio no se borran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final defaults = AppSettings(
      onboardingCompleted: provider.settings.onboardingCompleted,
      userName: provider.settings.userName,
    );
    await provider.updateSettings(defaults);
    if (!mounted) return;
    setState(() {
      _weeklyGoal = defaults.weeklyGoal;
      _weeklyFocusMinutesGoal = defaults.weeklyFocusMinutesGoal;
      _dailyHabitGoal = defaults.dailyHabitGoal;
      _streakGoal = defaults.streakGoal;
      _selectedLanguage = defaults.language;
      _selectedSound = defaults.sound;
      _selectedStartScreen = defaults.startScreen;
      _breakAfterFocus = defaults.breakAfterFocus;
      _textScale = defaults.textScale;
      _animationsEnabled = defaults.animationsEnabled;
      _notificationsEnabled = defaults.notificationsEnabled;
      _examReminderDayBefore = defaults.examReminderDayBefore;
      _examReminderTwoHoursBefore = defaults.examReminderTwoHoursBefore;
      _examReminderThirtyMinutesBefore =
          defaults.examReminderThirtyMinutesBefore;
      _accentColor = defaults.accentColor;
    });
    _showMessage('Configuración restablecida. Tus datos siguen intactos.');
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

  String _languageLabel(AppLanguage language) {
    return switch (language) {
      AppLanguage.system => 'Usar idioma del dispositivo',
      AppLanguage.spanish => 'Español',
      AppLanguage.english => 'English',
      AppLanguage.portuguese => 'Português',
    };
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

  void _showSettingsSheet({
    required String title,
    required IconData icon,
    required List<Widget> Function(StateSetter setSheetState) childrenBuilder,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SettingsSheet(
              title: title,
              icon: icon,
              children: childrenBuilder(setSheetState),
            );
          },
        );
      },
    );
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
        child: FocusPageBackground(
          child: ListView(
            padding: FocusInsets.page,
            children: [
              _SettingsHero(provider: provider),
              FocusGap.md,
            _SettingsSection(
              title: 'Cuenta',
              subtitle: RankingService.currentUser == null
                  ? 'Sesión y perfil público'
                  : RankingService.currentUser?.email ?? 'Cuenta activa',
              icon: Icons.person_rounded,
              children: [
                _AccountSettingsContent(
                  onLogin: _openLogin,
                  onSignOut: _signOut,
                  onProfileUpdated: () => setState(() {}),
                ),
              ],
            ),
            FocusGap.md,
            _SettingsSection(
              title: 'Apariencia',
              subtitle: 'Tema, idioma, texto y color',
              icon: Icons.palette_rounded,
              children: [
                _ThemePreview(
                  accentColor: _accentColor,
                  darkMode:
                      provider.settings.themeMode == ThemeModeSetting.dark,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modo oscuro'),
                  value: provider.settings.themeMode == ThemeModeSetting.dark,
                  onChanged: (_) => provider.toggleTheme(),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AppLanguage>(
                  initialValue: _selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Idioma',
                    prefixIcon: Icon(Icons.language_rounded),
                  ),
                  items: AppLanguage.values
                      .map(
                        (language) => DropdownMenuItem(
                          value: language,
                          child: Text(_languageLabel(language)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _selectedLanguage = value ?? AppLanguage.system,
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => _accentColor = AppSettings().accentColor,
                    ),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restablecer apariencia'),
                  ),
                ),
              ],
            ),
            FocusGap.md,
            _SettingsSection(
              title: 'Pomodoro',
              subtitle: 'Tiempo y metas',
              icon: Icons.timer_rounded,
              children: [
                _StartScreenSelector(
                  value: _selectedStartScreen,
                  onChanged: (value) =>
                      setState(() => _selectedStartScreen = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _breakAfterFocus,
                  decoration: const InputDecoration(
                    labelText: 'Al terminar',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'auto',
                      child: Text('Automático'),
                    ),
                    DropdownMenuItem(
                      value: 'short',
                      child: Text('Ir a descanso corto'),
                    ),
                    DropdownMenuItem(
                      value: 'long',
                      child: Text('Ir a descanso largo'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _breakAfterFocus = value ?? 'auto'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_rounded),
                  title: const Text('Tiempos'),
                  subtitle: const Text('Desde Pomodoro'),
                ),
                const SizedBox(height: 12),
                _GoalControl(
                  icon: Icons.flag_rounded,
                  title: 'Pomodoros por semana',
                  valueLabel: '$_weeklyGoal sesiones',
                  value: _weeklyGoal,
                  min: 1,
                  max: 99,
                  onChanged: _setWeeklyGoal,
                ),
                const SizedBox(height: 12),
                _GoalControl(
                  icon: Icons.schedule_rounded,
                  title: 'Minutos semanales',
                  valueLabel: '$_weeklyFocusMinutesGoal min',
                  value: _weeklyFocusMinutesGoal,
                  min: 25,
                  max: 3000,
                  step: 25,
                  onChanged: _setWeeklyFocusMinutesGoal,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showSettingsSheet(
                    title: 'Metas y progreso',
                    icon: Icons.flag_rounded,
                    childrenBuilder: (setSheetState) => [
                      _GoalControl(
                        icon: Icons.check_circle_rounded,
                        title: 'Hábitos diarios esperados',
                        valueLabel: '$_dailyHabitGoal Hábitos',
                        value: _dailyHabitGoal,
                        min: 1,
                        max: 20,
                        onChanged: (value) {
                          _setDailyHabitGoal(value);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      _GoalControl(
                        icon: Icons.local_fire_department_rounded,
                        title: 'Días de racha objetivo',
                        valueLabel: '$_streakGoal días',
                        value: _streakGoal,
                        min: 1,
                        max: 365,
                        onChanged: (value) {
                          _setStreakGoal(value);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      _GoalsProgressPanel(
                        provider: provider,
                        weeklyFocusMinutesGoal: _weeklyFocusMinutesGoal,
                        dailyHabitGoal: _dailyHabitGoal,
                        streakGoal: _streakGoal,
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Metas avanzadas'),
                ),
              ],
            ),
            FocusGap.md,
            _SettingsSection(
              title: 'Notificaciones',
              subtitle: 'Notificaciones y avisos',
              icon: Icons.notifications_active_rounded,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notificaciones'),
                  value: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showSettingsSheet(
                    title: 'Avisos de exámenes',
                    icon: Icons.assignment_rounded,
                    childrenBuilder: (setSheetState) => [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Avisar 1 día antes'),
                        value: _examReminderDayBefore,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(() => _examReminderDayBefore = value);
                                setSheetState(() {});
                              }
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Avisar 2 horas antes'),
                        subtitle: const Text('Solo para exámenes con hora.'),
                        value: _examReminderTwoHoursBefore,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(
                                  () => _examReminderTwoHoursBefore = value,
                                );
                                setSheetState(() {});
                              }
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Avisar 30 minutos antes'),
                        subtitle: const Text('Solo para exámenes con hora.'),
                        value: _examReminderThirtyMinutesBefore,
                        onChanged: _notificationsEnabled
                            ? (value) {
                                setState(
                                  () =>
                                      _examReminderThirtyMinutesBefore = value,
                                );
                                setSheetState(() {});
                              }
                            : null,
                      ),
                      const SizedBox(height: 8),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.task_alt_rounded),
                        title: Text('Hábitos'),
                        subtitle: Text('Próximamente'),
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Configurar avisos'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _testNotification,
                  icon: const Icon(Icons.notification_add_rounded),
                  label: const Text('Probar notificación'),
                ),
              ],
            ),
            FocusGap.md,
            _SettingsSection(
              title: 'Backup',
              subtitle: '${provider.subjects.length} materias locales',
              icon: Icons.backup_rounded,
              children: [
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
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showSettingsSheet(
                    title: 'Datos guardados',
                    icon: Icons.storage_rounded,
                    childrenBuilder: (_) => [
                      const _PrivacyDataNotice(),
                      const SizedBox(height: 12),
                      _AcademicLocalNotice(provider: provider),
                    ],
                  ),
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Ver detalle de datos'),
                ),
              ],
            ),
            FocusGap.md,
            FocusSurfaceCard(
              padding: EdgeInsets.zero,
              elevated: false,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Avanzado'),
                subtitle: const Text('Actualizaciones y acciones delicadas'),
                children: [
                  _SettingsSection(
                    title: 'Sistema',
                    icon: Icons.health_and_safety_rounded,
                    children: [
                      _UpdateCard(onCheck: _checkForUpdates),
                      const SizedBox(height: 12),
                      _DiagnosticPanel(provider: provider),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _resetPreferences,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Restablecer configuración'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: 'Zona peligrosa',
                    icon: Icons.warning_amber_rounded,
                    danger: true,
                    children: [
                      const Text('Acciones permanentes.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _deleteAllData,
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: FocusPalette.danger,
                        ),
                        label: const Text(
                          'Borrar todos los datos',
                          style: TextStyle(color: FocusPalette.danger),
                        ),
                      ),
                    ],
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

class _GoalControl extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueLabel;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _GoalControl({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
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
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  valueLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: value <= min ? null : () => onChanged(value - step),
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: value >= max ? null : () => onChanged(value + step),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _GoalsProgressPanel extends StatelessWidget {
  final AppProvider provider;
  final int weeklyFocusMinutesGoal;
  final int dailyHabitGoal;
  final int streakGoal;

  const _GoalsProgressPanel({
    required this.provider,
    required this.weeklyFocusMinutesGoal,
    required this.dailyHabitGoal,
    required this.streakGoal,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayHabits =
        provider.habits.where((habit) => habit.history.contains(today)).length;
    final weeklyFocusMinutes = (provider.weeklyFocusHours * 60).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.32),
      ),
      child: Column(
        children: [
          _GoalProgressRow(
            icon: Icons.timer_rounded,
            label: 'Enfoque semanal',
            current: weeklyFocusMinutes,
            goal: weeklyFocusMinutesGoal,
            suffix: 'min',
          ),
          _GoalProgressRow(
            icon: Icons.task_alt_rounded,
            label: 'Hábitos de hoy',
            current: todayHabits,
            goal: dailyHabitGoal,
            suffix: '',
          ),
          _GoalProgressRow(
            icon: Icons.local_fire_department_rounded,
            metricIcon: FocusMetricIconKind.streak,
            label: 'Racha',
            current: provider.currentStreak,
            goal: streakGoal,
            suffix: 'días',
          ),
        ],
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  final IconData icon;
  final FocusMetricIconKind? metricIcon;
  final String label;
  final int current;
  final int goal;
  final String suffix;

  const _GoalProgressRow({
    required this.icon,
    this.metricIcon,
    required this.label,
    required this.current,
    required this.goal,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (current / goal).clamp(0.0, 1.0);
    final valueText =
        suffix.isEmpty ? '$current / $goal' : '$current / $goal $suffix';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (metricIcon != null)
            FocusMetricIcon(
              kind: metricIcon!,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            )
          else
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(valueText),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(value: progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final String accentColor;
  final bool darkMode;

  const _ThemePreview({
    required this.accentColor,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    final accent = colorFromHex(accentColor);
    final background = darkMode ? const Color(0xFF101820) : Colors.white;
    final foreground = darkMode ? Colors.white : FocusPalette.ink;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: background,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.palette_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  darkMode ? 'Vista oscura' : 'Vista clara',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: 0.68,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartScreenSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _StartScreenSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = const [
      _StartScreenOption('dashboard', 'Dashboard', Icons.dashboard_rounded),
      _StartScreenOption('pomodoro', 'Pomodoro', Icons.timer_rounded),
      _StartScreenOption('subjects', 'Materias', Icons.book_rounded),
      _StartScreenOption('habits', 'Hábitos', Icons.task_alt_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pantalla inicial',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            final selected = value == item.value;
            return ChoiceChip(
              selected: selected,
              avatar: Icon(item.icon, size: 18),
              label: Text(item.label),
              onSelected: (_) => onChanged(item.value),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StartScreenOption {
  final String value;
  final String label;
  final IconData icon;

  const _StartScreenOption(this.value, this.label, this.icon);
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
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: FocusInsets.cardRelaxed,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(FocusRadii.panel),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SettingsProfileAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuración',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${provider.subjects.length} materias, ${provider.exams.length} exámenes y ${provider.activeStudyTasks.length} tareas activas.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: FocusPalette.muted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          FocusGap.md,
          FutureBuilder<List<Object?>>(
            future: Future.wait<Object?>([
              NotificationService.pendingNotificationsCount(),
              BackupService.latestBackupData(),
            ]),
            builder: (context, snapshot) {
              final data = snapshot.data;
              final pending =
                  data == null || data.isEmpty ? 0 : (data[0] as int? ?? 0);
              final hasBackup =
                  data != null && data.length > 1 && data[1] != null;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroStatusChip(
                    icon: RankingService.currentUser == null
                        ? Icons.person_off_rounded
                        : Icons.verified_user_rounded,
                    label: RankingService.currentUser == null
                        ? 'Sin cuenta'
                        : 'Cuenta activa',
                  ),
                  _HeroStatusChip(
                    icon: hasBackup
                        ? Icons.cloud_done_rounded
                        : Icons.backup_rounded,
                    label: hasBackup ? 'Backup reciente' : 'Sin backup local',
                  ),
                  _HeroStatusChip(
                    icon: provider.settings.notificationsEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    label: provider.settings.notificationsEnabled
                        ? '$pending avisos'
                        : 'Avisos apagados',
                  ),
                  _HeroStatusChip(
                    icon: Icons.flag_rounded,
                    label:
                        '${provider.weeklyPomodoros}/${provider.settings.weeklyGoal} semanal',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsProfileAvatar extends StatelessWidget {
  const _SettingsProfileAvatar();

  @override
  Widget build(BuildContext context) {
    if (RankingService.currentUser == null) {
      return const _SettingsAvatarFrame(asset: defaultProfileIconAsset);
    }
    return StreamBuilder<RankingProfile?>(
      stream: RankingService.profileStream(),
      builder: (context, snapshot) {
        final asset = profileIconAssetFromIndex(
          snapshot.data?.stats['socialMascotIndex'],
          email: RankingService.currentUser?.email,
          enforceAccess: true,
        );
        return _SettingsAvatarFrame(asset: asset);
      },
    );
  }
}

class _SettingsAvatarFrame extends StatelessWidget {
  final String asset;

  const _SettingsAvatarFrame({required this.asset});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _HeroStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroStatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.chip),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSheet({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FocusSectionHeader(
              icon: icon,
              title: title,
              accent: accent,
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
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
      padding: FocusInsets.card,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
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

class _PrivacyDataNotice extends StatelessWidget {
  const _PrivacyDataNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: FocusInsets.card,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FocusRadii.card),
        color: FocusPalette.mint.withValues(alpha: 0.08),
        border: Border.all(color: FocusPalette.mint.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.privacy_tip_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Privacidad y datos',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tus materias, horarios, exámenes, recursos y sesiones se guardan en este dispositivo. Si inicias sesión, tu perfil público, puntos y ranking usan tu cuenta.',
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

  bool get focusReady => accessibility && overlay;
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
          padding: FocusInsets.card,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FocusRadii.card),
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
                      borderRadius: BorderRadius.circular(FocusRadii.control),
                      color: (data?.focusReady == true
                              ? FocusPalette.mint
                              : FocusPalette.softAlert)
                          .withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      data?.focusReady == true
                          ? Icons.verified_rounded
                          : Icons.tune_rounded,
                      color: data?.focusReady == true
                          ? FocusPalette.mint
                          : FocusPalette.softAlert,
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
                      ? 'Diagnóstico adicional activo.'
                      : 'Opcional para diagnóstico avanzado.',
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
    final color = ok ? FocusPalette.mint : FocusPalette.softAlert;
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
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool danger;

  const _SettingsSection({
    required this.title,
    this.subtitle = '',
    required this.icon,
    required this.children,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        danger ? FocusPalette.danger : Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FocusRadii.card),
      ),
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
              borderRadius: BorderRadius.circular(FocusRadii.control),
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
          subtitle: subtitle.trim().isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          children: children,
        ),
      ),
    );
  }
}
