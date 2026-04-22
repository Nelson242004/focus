import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../models/exam.dart';
import '../models/habit.dart';
import '../models/pomodoro.dart';
import '../models/resource_link.dart';
import '../models/schedule.dart';
import '../models/subject.dart';
import '../providers/app_provider.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../utils/app_links.dart';
import '../utils/app_utils.dart';
import 'app_tutorial_screen.dart';

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
  }

  @override
  void dispose() {
    _focusController.dispose();
    _shortController.dispose();
    _longController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final focusTime = int.tryParse(_focusController.text);
    final shortBreak = int.tryParse(_shortController.text);
    final longBreak = int.tryParse(_longController.text);
    final goal = int.tryParse(_goalController.text);

    if ([focusTime, shortBreak, longBreak, goal].contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los valores numéricos.')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración guardada.')),
    );
  }

  Future<void> _exportData() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final data = {
        'app': 'focus_app',
        'formatVersion': 5,
        'exportDate': DateTime.now().toIso8601String(),
        'settings': _repairJsonText(provider.settings.toMap()),
        'pomodoros': provider.pomodoros
            .map((item) => _repairJsonText(item.toMap()))
            .toList(),
        'habits': provider.habits
            .map((item) => _repairJsonText(item.toMap()))
            .toList(),
        'subjects': provider.subjects
            .map((item) => _repairJsonText(item.toMap()))
            .toList(),
        'schedules': provider.schedules
            .map((item) => _repairJsonText(item.toMap()))
            .toList(),
        'exams': provider.exams
            .map((item) => _repairJsonText(item.toMap()))
            .toList(),
        'resources': provider.resources
            .map((item) => _repairJsonText(item.toMap()))
            .toList(),
      };

      final targetDirectory = await _backupDirectory();
      final date = DateTime.now().toIso8601String().split('T')[0];
      final file = File(
        '${targetDirectory.path}${Platform.pathSeparator}focus_backup_$date.focusbackup.json',
      );
      final encodedBackup = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(encodedBackup, encoding: utf8, flush: true);

      final latestFile = File(
        '${targetDirectory.path}${Platform.pathSeparator}focus_backup_ultimo.json',
      );
      await latestFile.writeAsString(encodedBackup,
          encoding: utf8, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Backup de Focus',
        text:
            'Backup completo de Focus. Guarda este archivo para restaurarlo después.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Backup creado. Puedes guardarlo o compartirlo.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el backup: $error')),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final info = await UpdateService.checkForUpdates();
      if (!mounted) return;
      if (!info.available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya tienes la última versión beta.')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo buscar actualización. Revisa tu conexión o el enlace beta.',
          ),
        ),
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
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null) return;
      await _restoreBackupFromFile(File(path));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo importar el backup. Verifica que sea un archivo exportado por Focus. Detalle: $error',
          ),
        ),
      );
    }
  }

  Future<void> _importLatestBackup() async {
    try {
      final targetDirectory = await _backupDirectory();

      final latestFile = File(
        '${targetDirectory.path}${Platform.pathSeparator}focus_backup_ultimo.json',
      );
      if (!await latestFile.exists()) {
        throw const FileSystemException(
          'No se encontró focus_backup_ultimo.json en Descargas.',
        );
      }

      await _restoreBackupFromFile(latestFile);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No se pudo restaurar el último backup: $error')),
      );
    }
  }

  Future<Directory> _backupDirectory() async {
    final baseDirectory = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}FocusBackups',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _restoreBackupFromFile(File file) async {
    final raw = (await file.readAsString()).replaceFirst('\uFEFF', '');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('El backup no tiene formato de objeto.');
    }
    final data = Map<String, dynamic>.from(_repairJsonText(decoded) as Map);
    if (data['app'] != 'focus_app') {
      throw Exception('El archivo seleccionado no pertenece a Focus.');
    }
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: Text(
          'Se reemplazarán tus datos actuales por el backup:\n${file.path}',
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

    await _restoreBackupData(data);
  }

  Future<void> _restoreBackupData(Map<String, dynamic> data) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.clearAllData(reseed: false);

    final importedSubjects = (data['subjects'] as List? ?? [])
        .map((item) => Subject.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedSchedules = (data['schedules'] as List? ?? [])
        .map((item) => Schedule.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedExams = (data['exams'] as List? ?? [])
        .map((item) => Exam.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedPomodoros = (data['pomodoros'] as List? ?? [])
        .map((item) => Pomodoro.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedHabits = (data['habits'] as List? ?? [])
        .map((item) => Habit.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedResources = (data['resources'] as List? ?? [])
        .map((item) =>
            ResourceLink.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    final oldToNewSubjectId = <int, int>{};
    final subjectScheduleMap = <int, List<Schedule>>{};
    for (final schedule in importedSchedules) {
      subjectScheduleMap
          .putIfAbsent(schedule.subjectId, () => [])
          .add(schedule);
    }

    for (final subject in importedSubjects) {
      final seedSchedules = subject.id != null
          ? (subjectScheduleMap[subject.id!] ?? [])
          : <Schedule>[];
      if (seedSchedules.isEmpty) {
        await provider.addSubject(Subject(
          name: subject.name,
          color: subject.color,
          icon: subject.icon,
          defaultClassroom: subject.defaultClassroom,
          professorName: subject.professorName,
          sectionCode: subject.sectionCode,
        ));
        final created = provider.getSubjectByName(subject.name);
        if (subject.id != null && created?.id != null) {
          oldToNewSubjectId[subject.id!] = created!.id!;
        }
        continue;
      }

      final created = await provider.addSubjectWithInitialSchedule(
        Subject(
          name: subject.name,
          color: subject.color,
          icon: subject.icon,
          defaultClassroom: subject.defaultClassroom,
          professorName: subject.professorName,
          sectionCode: subject.sectionCode,
        ),
        Schedule(
          subjectId: -1,
          dayOfWeek: seedSchedules.first.dayOfWeek,
          startTime: seedSchedules.first.startTime,
          endTime: seedSchedules.first.endTime,
          classroom: seedSchedules.first.classroom,
        ),
      );
      if (subject.id != null && created.id != null) {
        oldToNewSubjectId[subject.id!] = created.id!;
      }
      for (final extra in seedSchedules.skip(1)) {
        await provider.addSchedule(Schedule(
          subjectId: created.id!,
          dayOfWeek: extra.dayOfWeek,
          startTime: extra.startTime,
          endTime: extra.endTime,
          classroom: extra.classroom,
        ));
      }
    }

    for (final pomodoro in importedPomodoros) {
      await provider.addPomodoro(pomodoro);
    }
    for (final habit in importedHabits) {
      await provider.addHabit(Habit(
        name: habit.name,
        identity: habit.identity,
        history: habit.history,
        streak: habit.streak,
      ));
    }
    for (final exam in importedExams) {
      final subjectId = oldToNewSubjectId[exam.subjectId] ??
          provider.getSubjectByName(exam.subject)?.id;
      await provider.addExam(Exam(
        subject: exam.subject,
        subjectId: subjectId,
        examType: exam.examType,
        examLabel: exam.examLabel,
        date: exam.date,
        startTime: exam.startTime,
        classroom: exam.classroom,
      ));
    }
    for (final resource in importedResources) {
      await provider.addResource(ResourceLink(
        title: resource.title,
        url: resource.url,
        category: resource.category,
        subjectId: oldToNewSubjectId[resource.subjectId] ?? resource.subjectId,
      ));
    }

    final importedSettings = data['settings'] != null
        ? AppSettings.fromMap(
            Map<String, dynamic>.from(data['settings'] as Map))
        : provider.settings;
    importedSettings.onboardingCompleted = true;
    await provider.updateSettings(importedSettings);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restaurado correctamente.')),
    );
  }

  dynamic _repairJsonText(dynamic value) {
    if (value is String) return _repairText(value);
    if (value is List) return value.map(_repairJsonText).toList();
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _repairJsonText(entry.value),
      };
    }
    return value;
  }

  String _repairText(String value) {
    const mojibakeMarker = '\u00C3';
    const latin1Marker = '\u00C2';
    const replacementMarker = '\uFFFD';
    if (!value.contains(mojibakeMarker) &&
        !value.contains(latin1Marker) &&
        !value.contains(replacementMarker)) {
      return value;
    }
    try {
      return utf8.decode(latin1.encode(value), allowMalformed: false);
    } catch (_) {
      return value
          .replaceAll('\u00C3\u00A1', 'á')
          .replaceAll('\u00C3\u00A9', 'é')
          .replaceAll('\u00C3\u00AD', 'í')
          .replaceAll('\u00C3\u00B3', 'ó')
          .replaceAll('\u00C3\u00BA', 'ú')
          .replaceAll('\u00C3\u00B1', 'ñ')
          .replaceAll('\u00C3\u0081', 'Á')
          .replaceAll('\u00C3\u0089', 'É')
          .replaceAll('\u00C3\u008D', 'Í')
          .replaceAll('\u00C3\u0093', 'Ó')
          .replaceAll('\u00C3\u009A', 'Ú')
          .replaceAll('\u00C3\u0091', 'Ñ')
          .replaceAll('\u00C2\u00BF', '¿')
          .replaceAll('\u00C2\u00A1', '¡')
          .replaceAll('\u00C2\u00B7', '·')
          .replaceAll(latin1Marker, '');
    }
  }

  Future<void> _copyAppLink() async {
    try {
      await _openExternalUrl(AppLinks.appDownload);
      await Clipboard.setData(const ClipboardData(text: AppLinks.appDownload));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Página abierta y link copiado.')),
      );
    } catch (error) {
      await Clipboard.setData(const ClipboardData(text: AppLinks.appDownload));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir. Link copiado: $error')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos borrados.')),
      );
    }
  }

  Future<void> _testNotification() async {
    try {
      final granted = await NotificationService.ensurePermissions();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Activa los permisos de notificaciones.')),
        );
        return;
      }

      await NotificationService.showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificación de prueba enviada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo lanzar la prueba: $error')),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Compartir app'),
                  subtitle: const SelectableText(AppLinks.appDownload),
                  onTap: _copyAppLink,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('Desarrollado por PoliCode'),
                  subtitle: const Text(AppLinks.developerWebsite),
                  onTap: () => _openExternalUrl(AppLinks.developerWebsite),
                ),
                const SizedBox(height: 8),
                const Text('Versión beta ${AppLinks.currentVersion}'),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
