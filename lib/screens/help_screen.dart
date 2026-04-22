import 'package:flutter/material.dart';

import '../widgets/focus_drawer.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'help'),
      appBar: AppBar(title: const Text('Ayuda')),
      body: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF020617), Color(0xFF0F766E)]
                      : const [Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    color: isDark ? Colors.white : const Color(0xFF1D4ED8),
                    size: 38,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Guía rápida de Focus',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todo lo importante para importar datos, organizar tu semana y proteger tu progreso.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _HelpTopic(
              icon: Icons.upload_file_rounded,
              title: 'Importar Excel de Politécnica',
              body:
                  'En Materias toca el botón Excel, elige el archivo oficial y avanza paso a paso: carrera, materias y secciones. La importación carga materias, horarios, aulas, profesores, parciales y finales cuando estén disponibles.',
            ),
            const _HelpTopic(
              icon: Icons.emoji_events_rounded,
              title: 'Puntos, niveles y logros',
              body:
                  'Los puntos suben con hábitos completados, pomodoros terminados y constancia semanal. El nivel llega hasta 5 y la insignia central cambia para que tu progreso se sienta visible.',
            ),
            const _HelpTopic(
              icon: Icons.timer_rounded,
              title: 'Pomodoro',
              body:
                  'Configura enfoque, descanso corto, descanso largo y qué descanso sigue al terminar. Si sales de la app, revisa las notificaciones para mantener el ritmo.',
            ),
            const _HelpTopic(
              icon: Icons.backup_rounded,
              title: 'Backup e importación',
              body:
                  'Exporta una copia antes de reinstalar, cambiar de celular o probar una beta nueva. Al restaurar, la app te pide confirmación porque puede reemplazar tus datos actuales.',
            ),
            const _HelpTopic(
              icon: Icons.picture_as_pdf_rounded,
              title: 'PDF y recursos',
              body:
                  'Puedes exportar horarios y exámenes en PDF. En Recursos guarda playlists, cursos, herramientas y enlaces por materia para tener todo a mano.',
            ),
            const _HelpTopic(
              icon: Icons.system_update_alt_rounded,
              title: 'Actualizaciones beta',
              body:
                  'Desde Configuración puedes buscar nuevas versiones. Si hay una beta disponible, la app abre el enlace de descarga para instalarla manualmente.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpTopic extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(body),
          ),
        ],
      ),
    );
  }
}
