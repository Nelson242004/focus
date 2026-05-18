import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_utils.dart';
import '../widgets/focus_help_button.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  String _selectedSubject = 'Todas';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: const [
          FocusHelpAction(
            title: 'Ayuda de historial',
            message:
                'Aqui revisas pomodoros pasados y filtras por materia cuando quieres ver progreso real.',
            sections: [
              FocusHelpSection(
                title: 'Como leerlo',
                items: [
                  'Buscar y filtrar sirven para encontrar sesiones sin saturar la lista.',
                  'Cada fila muestra materia, fecha y duracion de la sesion.',
                ],
              ),
              FocusHelpSection(
                title: 'Gestion',
                items: [
                  'Si deslizas una sesion, la eliminas del historial local.',
                ],
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final subjects = [
            'Todas',
            ...provider.subjects.map((subject) => subject.name)
          ];
          final filteredSessions = provider.pomodoros.where((session) {
            final matchesSubject = _selectedSubject == 'Todas' ||
                session.subject == _selectedSubject;
            final matchesQuery = _query.isEmpty ||
                session.subject.toLowerCase().contains(_query.toLowerCase());
            return matchesSubject && matchesQuery;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por materia',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: subjects.contains(_selectedSubject)
                          ? _selectedSubject
                          : 'Todas',
                      decoration: const InputDecoration(
                          labelText: 'Filtrar por materia'),
                      items: subjects
                          .map((subject) => DropdownMenuItem(
                              value: subject, child: Text(subject)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedSubject = value ?? 'Todas'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredSessions.isEmpty
                    ? const Center(
                        child: Text(
                            'No hay sesiones que coincidan con el filtro.'))
                    : ListView.builder(
                        itemCount: filteredSessions.length,
                        itemBuilder: (context, index) {
                          final session = filteredSessions[index];
                          final date = DateTime.parse(session.date);
                          return Dismissible(
                            key: ValueKey(session.id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              Provider.of<AppProvider>(context, listen: false)
                                  .deletePomodoro(session.id!);
                            },
                            child: ListTile(
                              leading: const Icon(Icons.timer),
                              title: Text(session.subject),
                              subtitle: Text(formatDateTime(date)),
                              trailing: Text('${session.duration} min'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
