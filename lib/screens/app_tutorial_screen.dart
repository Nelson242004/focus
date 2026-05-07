import 'package:flutter/material.dart';

class AppTutorialScreen extends StatefulWidget {
  const AppTutorialScreen({super.key});

  @override
  State<AppTutorialScreen> createState() => _AppTutorialScreenState();
}

class _AppTutorialScreenState extends State<AppTutorialScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      icon: Icons.dashboard_customize_rounded,
      title: 'Dashboard',
      text:
          'Tu vista rápida para saber cómo va tu estudio sin revisar toda la app.',
      bullets: ['Puntos y nivel', 'Racha y horas', 'Lo más importante del día'],
      colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
    ),
    (
      icon: Icons.book_rounded,
      title: 'Materias',
      text:
          'Carga materias manualmente y revisa tu horario semanal como vista principal.',
      bullets: [
        'Horario semanal',
        'Profesor y sección',
        'Recursos por materia'
      ],
      colors: [Color(0xFF0F766E), Color(0xFF34D399)],
    ),
    (
      icon: Icons.school_rounded,
      title: 'Politécnica',
      text:
          'Usa herramientas específicas para la facultad: calculadora de firma y ponderado, más importación automática del Excel oficial.',
      bullets: [
        'Calculadora académica',
        'Importar Excel',
        'Carrera, materias y secciones'
      ],
      colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    ),
    (
      icon: Icons.assignment_rounded,
      title: 'Exámenes',
      text:
          'Sigue parciales y finales con fecha, hora, aula y recordatorios automáticos antes del examen.',
      bullets: ['Parcial 1 y 2', 'Final 1 y 2', 'Ordenados por cercanía'],
      colors: [Color(0xFFF97316), Color(0xFFFACC15)],
    ),
    (
      icon: Icons.timer_rounded,
      title: 'Pomodoro',
      text:
          'Estudia por ciclos de enfoque y descanso, con modo horizontal y continuidad automática entre bloques.',
      bullets: [
        'Modo horizontal',
        'Ciclos automáticos',
        'Estadísticas de enfoque'
      ],
      colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
    ),
    (
      icon: Icons.auto_graph_rounded,
      title: 'Hábitos y logros',
      text:
          'Marca hábitos, suma puntos, sube de nivel y completa misiones semanales de estudio.',
      bullets: [
        'Sistemas diarios',
        'Racha de constancia',
        'Logros e insignias'
      ],
      colors: [Color(0xFFDB2777), Color(0xFFF472B6)],
    ),
    (
      icon: Icons.link_rounded,
      title: 'Recursos y configuración',
      text:
          'Guarda enlaces clave, organiza recursos por materia y ajusta la experiencia de la app a tu estilo.',
      bullets: [
        'Biblioteca personal',
        'Recursos por materia',
        'Tema y accesibilidad'
      ],
      colors: [Color(0xFF0F172A), Color(0xFF334155)],
    ),
    (
      icon: Icons.verified_user_rounded,
      title: 'Beta segura',
      text:
          'Antes de probar una versión nueva, exporta un backup. Si algo falla, puedes restaurar tus datos y avisar a PoliCode con una captura.',
      bullets: ['Exportar copia', 'Buscar actualización', 'Compartir la app'],
      colors: [Color(0xFF0891B2), Color(0xFF22D3EE)],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _pages[_page];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial de Focus'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final item = _pages[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            colors: item.colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(item.icon,
                                  color: Colors.white, size: 30),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Qué puedes hacer aquí',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ...item.bullets.map(
                        (bullet) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.35),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: current.colors.first,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(bullet)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _page ? 26 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: index == _page
                            ? current.colors.first
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (_page == _pages.length - 1) {
                        Navigator.of(context).pop();
                        return;
                      }
                      await _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Text(
                        _page == _pages.length - 1 ? 'Listo' : 'Siguiente'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

