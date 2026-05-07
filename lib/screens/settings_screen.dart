import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../models/focus_mode_config.dart';
import '../models/focus_mode_status.dart';
import '../models/focus_shield_app.dart';
import '../providers/app_provider.dart';
import '../services/backup_service.dart';
import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../utils/app_links.dart';
import '../utils/app_utils.dart';
import 'app_tutorial_screen.dart';
import 'focus_mode_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _focusController;
  late TextEditingController _shortController;
  late TextEditingController _longController;
  late TextEditingController _goalController;
  String _selectedSound = 'chime';
  String _selectedStartScreen = 'dashboard';
  String _breakAfterFocus = 'auto';
  double _textScale = 1.0;
  bool _animationsEnabled = true;
  bool _notificationsEnabled = true;
  bool _checkingUpdate = false;
  late String _accentColor;
  FocusModeConfig _focusModeConfig = const FocusModeConfig();
  FocusModeStatus _focusModeStatus = const FocusModeStatus();
  bool _focusModePermissionGranted = false;

  static const List<String> _accentPalette = [
    '#1D4ED8',
    '#0EA5E9',
    '#10B981',
    '#F97316',
    '#7C3AED',
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _focusController =
        TextEditingController(text: provider.settings.focusTime.toString());
    _shortController = TextEditingController(
        text: provider.settings.shortBreakTime.toString());
    _longController =
        TextEditingController(text: provider.settings.longBreakTime.toString());
    _goalController =
        TextEditingController(text: provider.settings.weeklyGoal.toString());
    _selectedSound = provider.settings.sound;
    _selectedStartScreen = provider.settings.startScreen;
    _breakAfterFocus = provider.settings.breakAfterFocus;
    _textScale = provider.settings.textScale;
    _animationsEnabled = provider.settings.animationsEnabled;
    _notificationsEnabled = provider.settings.notificationsEnabled;
    _accentColor = provider.settings.accentColor;
    _loadFocusModeConfig();
  }

  Future<void> _loadFocusModeConfig() async {
    final config = await FocusModeService.loadConfig();
    final permissionGranted = await FocusModeService.hasUsageAccessPermission();
    final status = await FocusModeService.getStatus();
    if (!mounted) return;
    setState(() {
      _focusModeConfig = config;
      _focusModePermissionGranted = permissionGranted;
      _focusModeStatus = status;
    });
  }

  @override
  void dispose() {
    _focusController.dispose();
    _shortController.dispose();
    _longController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveSettings() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final focusTime = int.tryParse(_focusController.text);
    final shortBreak = int.tryParse(_shortController.text);
    final longBreak = int.tryParse(_longController.text);
    final goal = int.tryParse(_goalController.text);

    if ([focusTime, shortBreak, longBreak, goal].contains(null)) {
      _showMessage(
        'Revisa los números: usa solo valores enteros en minutos.',
      );
      return;
    }

    await provider.updateSettings(
      AppSettings(
        themeMode: provider.settings.themeMode,
        focusTime: focusTime!,
        shortBreakTime: shortBreak!,
        longBreakTime: longBreak!,
        weeklyGoal: goal!,
        sound: _selectedSound,
        selectedIdentity: provider.settings.selectedIdentity,
        startScreen: _selectedStartScreen,
        textScale: _textScale,
        animationsEnabled: _animationsEnabled,
        accentColor: _accentColor,
        notificationsEnabled: _notificationsEnabled,
        onboardingCompleted: provider.settings.onboardingCompleted,
        breakAfterFocus: _breakAfterFocus,
      ),
    );
    if (!mounted) return;
    _showMessage('Listo. Tu configuración quedó guardada.');
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

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final info = await UpdateService.checkForUpdates();
      if (!mounted) return;
      if (!info.available) {
        _showMessage('Ya tienes la última versión beta disponible.');
        return;
      }

      final openUpdate = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Nueva beta ${info.version}'),
          content: Text(
            '${info.notes}\n\nVersión instalada: ${AppLinks.currentVersion}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Después'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar'),
            ),
          ],
        ),
      );

      if (openUpdate == true) {
        await launchUrl(
          Uri.parse(info.apkUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'No pudimos revisar actualizaciones. Verifica tu conexión e intenta otra vez.',
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
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

  Future<void> _copyAppLink() async {
    try {
      await _openExternalUrl(AppLinks.appDownload);
      await Clipboard.setData(const ClipboardData(text: AppLinks.appDownload));
      if (!mounted) return;
      _showMessage('Página abierta. También copiamos el enlace.');
    } catch (error) {
      await Clipboard.setData(const ClipboardData(text: AppLinks.appDownload));
      if (!mounted) return;
      _showMessage(
        'No pudimos abrir la página, pero el enlace quedó copiado.',
      );
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw Exception('No se pudo abrir $url');
    }
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

  Future<void> _toggleFocusMode(bool value) async {
    final config = _focusModeConfig.copyWith(enabled: value);
    await FocusModeService.saveConfig(config);
    if (!mounted) return;
    setState(() => _focusModeConfig = config);
  }

  Future<void> _openFocusModePicker() async {
    final selectedApps = await Navigator.of(context).push<List<FocusShieldApp>>(
      MaterialPageRoute(
        builder: (_) => FocusModeSetupScreen(
          initiallySelected: _focusModeConfig.blockedApps,
        ),
      ),
    );
    if (selectedApps == null) return;
    final config = _focusModeConfig.copyWith(blockedApps: selectedApps);
    await FocusModeService.saveConfig(config);
    if (!mounted) return;
    setState(() => _focusModeConfig = config);
  }

  Future<void> _grantFocusModePermission() async {
    await FocusModeService.openUsageAccessSettings();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _loadFocusModeConfig();
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
                        value: 'statistics', child: Text('Estadísticas')),
                  ],
                  onChanged: (value) => setState(
                      () => _selectedStartScreen = value ?? 'dashboard'),
                ),
                const SizedBox(height: 14),
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
                  subtitle: const Text(
                      'Avisa el día anterior y, si hay hora, dos horas antes.'),
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
                OutlinedButton.icon(
                  onPressed: _testNotification,
                  icon: const Icon(Icons.notification_add_rounded),
                  label: const Text('Probar notificación'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Pomodoro',
              icon: Icons.timer_rounded,
              children: [
                const Text(
                  'Los tiempos de enfoque y descanso se ajustan desde la pantalla Pomodoro.',
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                    'Objetivo semanal (pomodoros)', _goalController),
                DropdownButtonFormField<String>(
                  initialValue: _breakAfterFocus,
                  decoration:
                      const InputDecoration(labelText: 'Después del enfoque'),
                  items: const [
                    DropdownMenuItem(
                        value: 'auto', child: Text('Automático cada 4 ciclos')),
                    DropdownMenuItem(
                        value: 'shortBreak',
                        child: Text('Siempre descanso corto')),
                    DropdownMenuItem(
                        value: 'longBreak',
                        child: Text('Siempre descanso largo')),
                  ],
                  onChanged: (value) =>
                      setState(() => _breakAfterFocus = value ?? 'auto'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSound,
                  decoration:
                      const InputDecoration(labelText: 'Sonido al terminar'),
                  items: const [
                    DropdownMenuItem(value: 'chime', child: Text('Campana')),
                    DropdownMenuItem(value: 'bell', child: Text('Timbre')),
                    DropdownMenuItem(value: 'none', child: Text('Ninguno')),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedSound = value ?? 'none'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Modo Enfoque Total',
              icon: Icons.shield_moon_rounded,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activar con Pomodoro'),
                  subtitle: const Text(
                    'Protege tus bloques de enfoque y vigila apps distractoras.',
                  ),
                  value: _focusModeConfig.enabled,
                  onChanged: _toggleFocusMode,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _focusModePermissionGranted
                        ? Icons.verified_user_rounded
                        : Icons.warning_amber_rounded,
                  ),
                  title: Text(
                    _focusModePermissionGranted
                        ? 'Permiso de vigilancia activo'
                        : 'Permiso pendiente',
                  ),
                  subtitle: Text(
                    _focusModePermissionGranted
                        ? 'Focus puede detectar qué app está al frente durante la sesión.'
                        : 'Necesitas activar el acceso de uso para vigilar apps distractoras.',
                  ),
                ),
                if (!_focusModePermissionGranted)
                  FilledButton.icon(
                    onPressed: _grantFocusModePermission,
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    label: const Text('Activar permiso'),
                  ),
                if (!_focusModePermissionGranted) const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openFocusModePicker,
                  icon: const Icon(Icons.apps_rounded),
                  label: Text(
                    _focusModeConfig.blockedApps.isEmpty
                        ? 'Elegir apps distractoras'
                        : 'Editar apps distractoras',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _focusModeConfig.blockedApps.isEmpty
                      ? 'Todavía no elegiste apps para frenar.'
                      : '${_focusModeConfig.blockedApps.length} apps elegidas. Intentos detectados: ${_focusModeStatus.blockedAttempts}.',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Datos y backup',
              icon: Icons.backup_rounded,
              children: [
                const Text(
                    'Exporta una copia completa o restaura un backup anterior.'),
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
              title: 'Actualizaciones beta',
              icon: Icons.system_update_alt_rounded,
              children: [
                const Text(
                  'Busca nuevas versiones sin salir de la app y descarga la beta más reciente cuando esté disponible.',
                ),
                const SizedBox(height: 10),
                Text(
                  'Versión instalada: ${AppLinks.currentVersion}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _checkingUpdate ? null : _checkForUpdates,
                  icon: _checkingUpdate
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _checkingUpdate ? 'Buscando...' : 'Buscar actualización',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Ayuda y app',
              icon: Icons.info_rounded,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_lesson_rounded),
                  title: const Text('Tutorial de funciones'),
                  subtitle: const Text('Repasa cómo usar cada sección.'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AppTutorialScreen()),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.ios_share_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Compartir Focus',
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
                        'Comparte la beta con un compañero para que pueda descargar la app desde la página oficial.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _copyAppLink,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Abrir y copiar link'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _openExternalUrl(AppLinks.developerWebsite),
                    child: const Row(
                      children: [
                        Icon(Icons.code_rounded, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Desarrollado por',
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 2),
                              Text(
                                AppLinks.developerName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Versión beta ${AppLinks.currentVersion}'),
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

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
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
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
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
                  '${provider.subjects.length} materias, ${provider.exams.length} exámenes y ${provider.resources.length} recursos.',
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
