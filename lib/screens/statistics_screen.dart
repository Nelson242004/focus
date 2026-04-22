import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final pomodoros = provider.pomodoros;
        final subjects = provider.subjects;
        if (pomodoros.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.query_stats_rounded, size: 52),
                  const SizedBox(height: 12),
                  Text(
                    'Todavía no hay datos suficientes',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completa algunas sesiones de estudio y aquí verás una lectura mucho más clara de tu progreso.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final hoursBySubject = <String, double>{
          for (final subject in subjects) subject.name: 0
        };
        for (final pomodoro in pomodoros) {
          hoursBySubject[pomodoro.subject] =
              (hoursBySubject[pomodoro.subject] ?? 0) + pomodoro.duration / 60;
        }

        final last7Days = List.generate(
            7, (index) => DateTime.now().subtract(Duration(days: 6 - index)));
        final dailyCount = last7Days.map((date) {
          final dateStr = date.toIso8601String().split('T')[0];
          return pomodoros
              .where((pomodoro) => pomodoro.date.startsWith(dateStr))
              .length
              .toDouble();
        }).toList();

        final totalHours = pomodoros.fold<double>(
            0, (sum, pomodoro) => sum + pomodoro.duration / 60);
        final subjectHours = hoursBySubject.entries
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final uniqueDays = pomodoros
            .map((pomodoro) => pomodoro.date.split('T')[0])
            .toSet()
            .length;
        final averagePerDay =
            uniqueDays == 0 ? 0 : pomodoros.length / uniqueDays;
        final bestDay = dailyCount.reduce((a, b) => a > b ? a : b);
        final strongestSubject =
            hoursBySubject.entries.reduce((a, b) => a.value >= b.value ? a : b);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Estadísticas',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
            ),
            const SizedBox(height: 4),
            const Text(
                'Tu rendimiento concentrado en una lectura visual más clara.'),
            const SizedBox(height: 16),
            _StatsHero(
              totalHours: totalHours,
              strongestSubject: strongestSubject.key,
              bestDay: bestDay.toInt(),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width < 420 ? 2 : 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.12,
              children: [
                _MetricTile(
                    label: 'Horas totales',
                    value: '${totalHours.toStringAsFixed(1)}h',
                    icon: Icons.timer_rounded),
                _MetricTile(
                    label: 'Mejor día',
                    value: '${bestDay.toInt()}',
                    icon: Icons.local_fire_department_rounded),
                _MetricTile(
                    label: 'Promedio',
                    value: averagePerDay.toStringAsFixed(1),
                    icon: Icons.show_chart_rounded),
                _MetricTile(
                    label: 'Materia top',
                    value: strongestSubject.key,
                    icon: Icons.auto_graph_rounded),
              ],
            ),
            const SizedBox(height: 16),
            _ChartShell(
              title: 'Horas por materia',
              subtitle:
                  'Compara rápidamente dónde se está yendo tu energía de estudio.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 260,
                    child: BarChart(
                      BarChartData(
                        maxY: (subjectHours.isEmpty
                                ? 1
                                : subjectHours
                                    .map((entry) => entry.value)
                                    .reduce((a, b) => a > b ? a : b)) +
                            1,
                        barGroups: subjectHours.asMap().entries.map((entry) {
                          final palette = [
                            const Color(0xFF2563EB),
                            const Color(0xFF0EA5E9),
                            const Color(0xFF14B8A6),
                            const Color(0xFF7C3AED),
                            const Color(0xFFF97316),
                          ];
                          final color = palette[entry.key % palette.length];
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.value,
                                color: color,
                                width: 18,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subjectHours.asMap().entries.map((entry) {
                      final palette = [
                        const Color(0xFF2563EB),
                        const Color(0xFF0EA5E9),
                        const Color(0xFF14B8A6),
                        const Color(0xFF7C3AED),
                        const Color(0xFFF97316),
                      ];
                      final color = palette[entry.key % palette.length];
                      return _SubjectLegendChip(
                        color: color,
                        label: entry.value.key,
                        hours: entry.value.value,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ChartShell(
              title: 'Actividad de los últimos 7 días',
              subtitle:
                  'Observa el ritmo de sesiones y detecta días fuertes o flojos.',
              child: SizedBox(
                height: 280,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                            dailyCount.length,
                            (index) =>
                                FlSpot(index.toDouble(), dailyCount[index])),
                        isCurved: true,
                        color: const Color(0xFF2563EB),
                        barWidth: 5,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              const Color(0xFF2563EB).withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= last7Days.length) {
                              return const SizedBox.shrink();
                            }
                            final day = last7Days[index];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('${day.day}/${day.month}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData:
                        const FlGridData(show: true, drawVerticalLine: false),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubjectLegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final double hours;

  const _SubjectLegendChip({
    required this.color,
    required this.label,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label · ${hours.toStringAsFixed(1)}h',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHero extends StatelessWidget {
  final double totalHours;
  final String strongestSubject;
  final int bestDay;

  const _StatsHero({
    required this.totalHours,
    required this.strongestSubject,
    required this.bestDay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lectura general del rendimiento',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            '${totalHours.toStringAsFixed(1)} horas acumuladas',
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Tu mejor día llegó a $bestDay pomodoros y tu materia con más horas es $strongestSubject.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ChartShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartShell({
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
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
