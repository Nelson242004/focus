import 'package:flutter/material.dart';

import '../utils/focus_palette.dart';
import '../widgets/focus_design_system.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: SafeArea(
        top: false,
        bottom: true,
        child: FocusPageBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [
                            FocusPalette.darkCard2,
                            FocusPalette.darkSurfaceTint,
                          ]
                        : const [
                            FocusPalette.card,
                            FocusPalette.surfaceTint,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color:
                        isDark ? FocusPalette.darkBorder : FocusPalette.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withValues(alpha: isDark ? 0.14 : 0.7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        color: isDark ? Colors.white : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Guía rápida de Focus',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Si algo no se entiende en menos de un minuto, esta pantalla tiene que ayudarte. Empieza por lo básico y luego explora lo avanzado.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HelpChecklist(),
              const SizedBox(height: 16),
              const _HelpTopic(
                icon: Icons.rocket_launch_rounded,
                title: 'Primera configuración recomendada',
                body:
                    '1. Carga tus materias o importa el Excel desde Politécnica. 2. Agrega tus exámenes importantes. 3. Activa recordatorios. 4. Exporta un backup cuando tengas todo listo.',
              ),
              const _HelpTopic(
                icon: Icons.school_rounded,
                title: 'Politécnica',
                body:
                    'Entra a Politécnica para usar la calculadora de firma y ponderado o para importar el Excel oficial. La importación va paso a paso: carrera, materias y secciones. Si una materia no tiene examen en el Excel, la app igual importa lo que encuentre.',
              ),
              const _HelpTopic(
                icon: Icons.calculate_rounded,
                title: 'Calculadora académica',
                body:
                    'Ponderado te dice cuánto necesitas en el final para nota 2, 3, 4 o 5. Si tu ponderado es menor a 50%, la app muestra que no habilita final. Firma te ayuda a estimar media firma o firma completa.',
              ),
              const _HelpTopic(
                icon: Icons.calendar_month_rounded,
                title: 'Horario semanal',
                body:
                    'En Materias, el horario semanal es la vista principal: puedes deslizar entre días, revisar tus bloques por jornada y compartir tu horario como imagen.',
              ),
              const _HelpTopic(
                icon: Icons.assignment_rounded,
                title: 'Exámenes y recordatorios',
                body:
                    'Agrega parciales y finales con lo mínimo: materia y fecha. Si tienes hora o aula, también puedes guardarlas. Activa las notificaciones desde Configuración para recibir avisos antes del examen.',
              ),
              const _HelpTopic(
                icon: Icons.timer_rounded,
                title: 'Pomodoro',
                body:
                    'Configura enfoque, descanso corto, descanso largo y qué descanso sigue al terminar. Si sales de la app, Focus intenta mantener el estado y mostrar el temporizador en notificaciones.',
              ),
              const _HelpTopic(
                icon: Icons.backup_rounded,
                title: 'Backup e importación',
                body:
                    'Exporta una copia antes de probar una beta nueva, cambiar de celular o borrar datos. Al restaurar, Focus te pide confirmación porque el backup reemplaza tus datos actuales.',
              ),
              const _HelpTopic(
                icon: Icons.warning_amber_rounded,
                title: 'Si algo falla en la beta',
                body:
                    'Prueba cerrar y abrir la app. Si el problema sigue, guarda una captura, anota qué estabas haciendo y compártelo con PoliCode. Eso ayuda muchísimo a mejorar Focus para todos.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpChecklist extends StatelessWidget {
  const _HelpChecklist();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    const items = [
      'Carga horario o Excel',
      'Agrega exámenes',
      'Activa recordatorios',
      'Exporta backup',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checklist beta',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
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
            child: Text(
              body,
              style: const TextStyle(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
