import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/schedule.dart';
import '../models/subject.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../widgets/time_picker_field.dart';

class SubjectScheduleScreen extends StatefulWidget {
  final Subject subject;

  const SubjectScheduleScreen({super.key, required this.subject});

  @override
  State<SubjectScheduleScreen> createState() => _SubjectScheduleScreenState();
}

class _SubjectScheduleScreenState extends State<SubjectScheduleScreen> {
  List<Schedule> _schedules = [];
  final _formKey = GlobalKey<FormState>();
  final _classroomController = TextEditingController();
  int _selectedDay = 0;
  String _startTime = '08:00';
  String _endTime = '09:00';
  Schedule? _editingSchedule;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void dispose() {
    _classroomController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _schedules = await provider.getSchedulesForSubject(widget.subject.id!);
    if (mounted) setState(() {});
  }

  Future<void> _showScheduleDialog({Schedule? schedule}) async {
    _editingSchedule = schedule;
    _selectedDay = schedule?.dayOfWeek ?? 0;
    _startTime = schedule?.startTime ?? '08:00';
    _endTime = schedule?.endTime ?? '09:00';
    _classroomController.text =
        schedule?.classroom ?? widget.subject.defaultClassroom ?? '';
    final provider = Provider.of<AppProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(schedule == null ? 'Agregar horario' : 'Editar horario'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedDay,
                  decoration: const InputDecoration(labelText: 'Día'),
                  items: List.generate(
                    6,
                    (index) => DropdownMenuItem(
                        value: index, child: Text(weekdayLabel(index))),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => _selectedDay = value ?? 0),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TimePickerField(
                          label: 'Inicio',
                          value: _startTime,
                          onChanged: (value) =>
                              setDialogState(() => _startTime = value)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TimePickerField(
                          label: 'Fin',
                          value: _endTime,
                          onChanged: (value) =>
                              setDialogState(() => _endTime = value)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _classroomController,
                  decoration:
                      const InputDecoration(labelText: 'Aula (opcional)'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Se permiten horarios superpuestos entre materias.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                if (!isValidTime(_startTime) || !isValidTime(_endTime)) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Usa formato de hora HH:MM.')));
                  return;
                }
                if (timeToMinutes(_endTime) <= timeToMinutes(_startTime)) {
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text(
                            'La hora de fin debe ser mayor que la de inicio.')),
                  );
                  return;
                }
                final scheduleToSave = Schedule(
                  id: _editingSchedule?.id,
                  subjectId: widget.subject.id!,
                  dayOfWeek: _selectedDay,
                  startTime: _startTime,
                  endTime: _endTime,
                  classroom: _classroomController.text.trim(),
                );
                try {
                  if (_editingSchedule == null) {
                    await provider.addSchedule(scheduleToSave);
                  } else {
                    await provider.updateSchedule(scheduleToSave);
                  }
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  await _loadSchedules();
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(
                            error.toString().replaceFirst('Bad state: ', ''))),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSchedule(int id) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar horario'),
        content: const Text('Este bloque horario se eliminara de la materia.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await provider.deleteSchedule(id);
      await _loadSchedules();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Horarios de ${widget.subject.name}'),
        actions: [
          IconButton(
              onPressed: () => _showScheduleDialog(),
              icon: const Icon(Icons.add)),
        ],
      ),
      body: _schedules.isEmpty
          ? const Center(
              child: Text('Esta materia no tiene horarios adicionales.'))
          : ListView.builder(
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(
                        '${weekdayLabel(schedule.dayOfWeek)} - ${schedule.startTime} - ${schedule.endTime}'),
                    subtitle: Text('Aula: ${schedule.classroom}'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showScheduleDialog(schedule: schedule)),
                        IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteSchedule(schedule.id!)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
