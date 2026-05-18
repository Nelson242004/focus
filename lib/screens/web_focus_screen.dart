import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../providers/app_provider.dart';
import '../utils/app_links.dart';
import '../utils/app_utils.dart';
import '../utils/focus_palette.dart';

class WebFocusScreen extends StatefulWidget {
  const WebFocusScreen({super.key});

  @override
  State<WebFocusScreen> createState() => _WebFocusScreenState();
}

class _WebFocusScreenState extends State<WebFocusScreen> {
  int _sectionIndex = 0;

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final sections = [
          _WebSectionData(
            label: 'Inicio',
            icon: Icons.dashboard_rounded,
            child: _WebHomeSection(
              onDownload: () => _openUrl(AppLinks.appDownload),
              onVisitSite: () => _openUrl(AppLinks.developerWebsite),
            ),
          ),
          const _WebSectionData(
            label: 'Materias',
            icon: Icons.menu_book_rounded,
            child: _WebSubjectsSection(),
          ),
          const _WebSectionData(
            label: 'Exámenes',
            icon: Icons.assignment_rounded,
            child: _WebExamsSection(),
          ),
          const _WebSectionData(
            label: 'Recursos',
            icon: Icons.link_rounded,
            child: _WebResourcesSection(),
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Focus Web'),
            actions: [
              IconButton(
                tooltip: 'Cambiar tema',
                icon: Icon(
                  provider.settings.themeMode == ThemeModeSetting.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
                onPressed: provider.toggleTheme,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: true,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _WebHeader(
                      subjectCount: provider.subjects.length,
                      examCount: provider.exams.length,
                      weeklyPomodoros: provider.weeklyPomodoros,
                      onDownload: () => _openUrl(AppLinks.appDownload),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(sections.length, (index) {
                          final item = sections[index];
                          final selected = index == _sectionIndex;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index == sections.length - 1 ? 0 : 10,
                            ),
                            child: ChoiceChip(
                              selected: selected,
                              avatar: Icon(
                                item.icon,
                                size: 18,
                                color: selected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              label: Text(item.label),
                              onSelected: (_) =>
                                  setState(() => _sectionIndex = index),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    sections[_sectionIndex].child,
                    const SizedBox(height: 16),
                    _WebPanel(
                      title: 'Más funciones en la app Android',
                      subtitle:
                          'La web se queda con lo principal. Para Pomodoro avanzado, PDF, backup, Politécnica y notificaciones, descarga la app.',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          const _FeatureChip(label: 'Pomodoro avanzado'),
                          const _FeatureChip(label: 'PDF e imagen'),
                          const _FeatureChip(label: 'Backup e importación'),
                          const _FeatureChip(label: 'Modo Politécnica'),
                          FilledButton.icon(
                            onPressed: () => _openUrl(AppLinks.appDownload),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Descargar app'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WebSectionData {
  final String label;
  final IconData icon;
  final Widget child;

  const _WebSectionData({
    required this.label,
    required this.icon,
    required this.child,
  });
}

class _WebHeader extends StatelessWidget {
  final int subjectCount;
  final int examCount;
  final int weeklyPomodoros;
  final VoidCallback onDownload;

  const _WebHeader({
    required this.subjectCount,
    required this.examCount,
    required this.weeklyPomodoros,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1D4ED8),
            Color(0xFF38BDF8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 820;
          return Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: stacked ? 0 : 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Focus en navegador',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tu semestre claro, rápido y sin ruido.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Consulta lo principal desde cualquier navegador. Si quieres todas las funciones de Focus, descárgala en Android.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Descargar app completa'),
                    ),
                  ],
                ),
              ),
              if (stacked)
                const SizedBox(height: 18)
              else
                const SizedBox(width: 18),
              Expanded(
                flex: stacked ? 0 : 2,
                child: Column(
                  children: [
                    _HeroMetric(label: 'Materias', value: '$subjectCount'),
                    const SizedBox(height: 12),
                    _HeroMetric(label: 'Exámenes', value: '$examCount'),
                    const SizedBox(height: 12),
                    _HeroMetric(
                      label: 'Pomodoros esta semana',
                      value: '$weeklyPomodoros',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WebHomeSection extends StatelessWidget {
  final VoidCallback onDownload;
  final VoidCallback onVisitSite;

  const _WebHomeSection({
    required this.onDownload,
    required this.onVisitSite,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final nextClass = provider.nextScheduleEntry;
        final nextExam = provider.nextUpcomingExam;
        final recentSchedules =
            provider.weeklySchedulesMonToSat.take(4).toList();

        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 880;
                return Flex(
                  direction: stacked ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _WebInfoCard(
                        title: 'Próxima clase',
                        icon: Icons.event_available_rounded,
                        accent: const Color(0xFF0EA5E9),
                        headline:
                            nextClass?.subject.name ?? 'Sin clase cercana',
                        detail: nextClass == null
                            ? 'Carga materias y horarios para verlos aquí.'
                            : '${weekdayLabel(nextClass.schedule.dayOfWeek)} · ${nextClass.schedule.startTime} a ${nextClass.schedule.endTime}',
                      ),
                    ),
                    if (stacked)
                      const SizedBox(height: 14)
                    else
                      const SizedBox(width: 14),
                    Expanded(
                      child: _WebInfoCard(
                        title: 'Próximo examen',
                        icon: Icons.assignment_late_rounded,
                        accent: FocusPalette.teal,
                        headline: nextExam == null
                            ? 'Sin examen próximo'
                            : provider.subjectNameForExam(nextExam),
                        detail: nextExam == null
                            ? 'Tus parciales y finales aparecerán aquí.'
                            : '${nextExam.displayType} · ${formatDate(nextExam.date)}',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _WebPanel(
              title: 'Resumen rápido',
              subtitle: 'Tu semana al alcance de un vistazo',
              child: recentSchedules.isEmpty
                  ? const _EmptyPanelText(
                      text: 'Todavía no tienes bloques cargados.',
                    )
                  : Column(
                      children: recentSchedules
                          .map(
                            (schedule) => _MiniScheduleTile(
                              subject: provider
                                      .getSubjectById(schedule.subjectId)
                                      ?.name ??
                                  'Materia',
                              detail:
                                  '${weekdayLabel(schedule.dayOfWeek)} · ${schedule.startTime} a ${schedule.endTime}',
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            _WebPanel(
              title: 'Sigue con Focus',
              subtitle: 'La app Android es donde está la experiencia completa.',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Descargar Android'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onVisitSite,
                    icon: const Icon(Icons.public_rounded),
                    label: const Text('Página oficial'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WebSubjectsSection extends StatelessWidget {
  const _WebSubjectsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final subjects = provider.subjects;
        return _WebPanel(
          title: 'Materias',
          subtitle: 'Consulta tus materias registradas y sus próximos bloques',
          child: subjects.isEmpty
              ? const _EmptyPanelText(
                  text: 'Todavía no tienes materias cargadas.',
                )
              : Column(
                  children: subjects.map((subject) {
                    final subjectSchedules = provider.schedules
                        .where((schedule) => schedule.subjectId == subject.id)
                        .toList()
                      ..sort((a, b) {
                        final dayComparison =
                            a.dayOfWeek.compareTo(b.dayOfWeek);
                        if (dayComparison != 0) return dayComparison;
                        return a.startTime.compareTo(b.startTime);
                      });
                    final nextBlock = subjectSchedules.isEmpty
                        ? 'Sin horarios'
                        : '${weekdayLabel(subjectSchedules.first.dayOfWeek)} · ${subjectSchedules.first.startTime} a ${subjectSchedules.first.endTime}';
                    return _ListCard(
                      leadingColor: colorFromHex(subject.color),
                      title: subject.name,
                      subtitle: nextBlock,
                      extra: subject.sectionCode?.trim().isNotEmpty == true
                          ? 'Sección ${subject.sectionCode}'
                          : null,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

class _WebExamsSection extends StatelessWidget {
  const _WebExamsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final exams = [...provider.exams]
          ..sort((a, b) => a.date.compareTo(b.date));
        return _WebPanel(
          title: 'Exámenes',
          subtitle: 'Tus parciales y finales ordenados por fecha',
          child: exams.isEmpty
              ? const _EmptyPanelText(
                  text: 'Todavía no tienes exámenes cargados.',
                )
              : Column(
                  children: exams.map((exam) {
                    final dateLabel = '${formatDate(exam.date)}'
                        '${exam.startTime.trim().isEmpty ? '' : ' · ${exam.startTime}'}';
                    return _ListCard(
                      leadingColor: exam.isFinal
                          ? FocusPalette.teal
                          : const Color(0xFF2563EB),
                      title: provider.subjectNameForExam(exam),
                      subtitle: '${exam.displayType} · $dateLabel',
                      extra: exam.classroom.trim().isEmpty
                          ? null
                          : 'Aula ${exam.classroom}',
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

class _WebResourcesSection extends StatelessWidget {
  const _WebResourcesSection();

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final items = [...provider.resourcesByCategory('course')];
        return _WebPanel(
          title: 'Recursos',
          subtitle: 'Abre enlaces útiles guardados dentro de Focus',
          child: items.isEmpty
              ? const _EmptyPanelText(
                  text: 'Todavía no tienes recursos disponibles en esta vista.',
                )
              : Column(
                  children: items.take(8).map((resource) {
                    final subject = resource.subjectId == null
                        ? null
                        : provider.getSubjectById(resource.subjectId!);
                    return _ResourceCard(
                      title: resource.title,
                      subtitle: subject?.name ?? 'Biblioteca general',
                      onTap: () => _openUrl(resource.url),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _WebInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String headline;
  final String detail;

  const _WebInfoCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.headline,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _WebPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MiniScheduleTile extends StatelessWidget {
  final String subject;
  final String detail;

  const _MiniScheduleTile({
    required this.subject,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.22),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final Color leadingColor;
  final String title;
  final String subtitle;
  final String? extra;

  const _ListCard({
    required this.leadingColor,
    required this.title,
    required this.subtitle,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.24),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 48,
            decoration: BoxDecoration(
              color: leadingColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (extra != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    extra!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ResourceCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.24),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: const Icon(Icons.open_in_new_rounded),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _EmptyPanelText extends StatelessWidget {
  final String text;

  const _EmptyPanelText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text),
    );
  }
}

