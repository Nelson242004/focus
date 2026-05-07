import 'package:flutter/material.dart';

import '../utils/polytechnic_grade_utils.dart';
import '../widgets/focus_drawer.dart';

class GradeCalculatorScreen extends StatefulWidget {
  const GradeCalculatorScreen({super.key});

  @override
  State<GradeCalculatorScreen> createState() => _GradeCalculatorScreenState();
}

class _GradeCalculatorScreenState extends State<GradeCalculatorScreen> {
  final _directFirstController = TextEditingController();
  final _directSecondController = TextEditingController();
  final _ponderedController = TextEditingController();
  final _firstPartialController = TextEditingController();

  int _selectedMode = 0;
  double? _directFirstPartial;
  double? _directSecondPartial;
  double? _ponderedAverage;
  double? _firstPartialScore;

  @override
  void dispose() {
    _directFirstController.dispose();
    _directSecondController.dispose();
    _ponderedController.dispose();
    _firstPartialController.dispose();
    super.dispose();
  }

  void _calculateDirect() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _directFirstPartial = _parseScore(_directFirstController.text);
      _directSecondPartial = _parseScore(_directSecondController.text);
    });
  }

  void _calculatePondered() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _ponderedAverage = _parseScore(_ponderedController.text));
  }

  void _calculateSignature() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(
      () => _firstPartialScore = _parseScore(_firstPartialController.text),
    );
  }

  double? _parseScore(String value) {
    return parsePolytechnicScore(value);
  }

  int _requiredFinal(double currentAverage, int targetGrade) {
    return requiredFinalScore(currentAverage, targetGrade);
  }

  int _requiredSecondPartial(double firstPartial, int targetTotal) {
    return requiredSecondPartialForSignature(
      firstPartial,
      targetTotal >= 119 ? SignatureGoal.full : SignatureGoal.media,
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = switch (_selectedMode) {
      0 => _DirectPanel(
          key: const ValueKey('direct'),
          firstController: _directFirstController,
          secondController: _directSecondController,
          firstPartial: _directFirstPartial,
          secondPartial: _directSecondPartial,
          onCalculate: _calculateDirect,
          requiredFinal: _requiredFinal,
          requiredSecondPartial: _requiredSecondPartial,
        ),
      1 => _PonderedPanel(
          key: const ValueKey('pondered'),
          controller: _ponderedController,
          average: _ponderedAverage,
          onCalculate: _calculatePondered,
          requiredFinal: _requiredFinal,
        ),
      _ => _SignaturePanel(
          key: const ValueKey('signature'),
          controller: _firstPartialController,
          firstPartial: _firstPartialScore,
          onCalculate: _calculateSignature,
          requiredSecondPartial: _requiredSecondPartial,
        ),
    };

    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'polytechnic'),
      appBar: AppBar(title: const Text('Calculadora Politécnica')),
      body: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _HeroPanel(
              title: 'Calcula rápido antes de rendir',
              subtitle:
                  'Carga tus parciales y Focus te muestra firma, ponderado actual y lo que necesitarías en el final.',
            ),
            const SizedBox(height: 14),
            _ModeSelector(
              selectedMode: _selectedMode,
              onChanged: (value) => setState(() => _selectedMode = value),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: panel,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeroPanel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF020617), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFD6E4FF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: primary.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.calculate_rounded, color: primary, size: 30),
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
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final int selectedMode;
  final ValueChanged<int> onChanged;

  const _ModeSelector({required this.selectedMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          icon: Icon(Icons.bolt_rounded),
          label: Text('Directo'),
        ),
        ButtonSegment(
          value: 1,
          icon: Icon(Icons.timeline_rounded),
          label: Text('Ponderado'),
        ),
        ButtonSegment(
          value: 2,
          icon: Icon(Icons.edit_note_rounded),
          label: Text('Firma'),
        ),
      ],
      selected: {selectedMode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _DirectPanel extends StatelessWidget {
  final TextEditingController firstController;
  final TextEditingController secondController;
  final double? firstPartial;
  final double? secondPartial;
  final VoidCallback onCalculate;
  final int Function(double currentAverage, int targetGrade) requiredFinal;
  final int Function(double firstPartial, int targetTotal)
      requiredSecondPartial;

  const _DirectPanel({
    super.key,
    required this.firstController,
    required this.secondController,
    required this.firstPartial,
    required this.secondPartial,
    required this.onCalculate,
    required this.requiredFinal,
    required this.requiredSecondPartial,
  });

  @override
  Widget build(BuildContext context) {
    final hasFirst = firstPartial != null;
    final hasBoth = firstPartial != null && secondPartial != null;
    final ponderedAverage = hasBoth
        ? calculatePonderedAverageFromPartials(firstPartial!, secondPartial!)
        : null;
    final signatureSum = hasBoth
        ? calculateSignaturePoints(firstPartial!, secondPartial!)
        : null;
    final blocked =
        ponderedAverage != null && !habilitatesFinal(ponderedAverage);
    final finalGoals = ponderedAverage == null || blocked
        ? const <_GradeGoal>[]
        : [
            _GradeGoal(
                'Nota 2', requiredFinal(ponderedAverage, 2), Colors.green),
            _GradeGoal(
                'Nota 3', requiredFinal(ponderedAverage, 3), Colors.blue),
            _GradeGoal(
                'Nota 4', requiredFinal(ponderedAverage, 4), Colors.orange),
            _GradeGoal(
                'Nota 5', requiredFinal(ponderedAverage, 5), Colors.purple),
          ];
    final signatureGoals = hasFirst
        ? [
            _GradeGoal(
              'Media firma',
              requiredSecondPartial(firstPartial!, 99),
              Colors.cyan,
            ),
            _GradeGoal(
              'Firma completa',
              requiredSecondPartial(firstPartial!, 119),
              Colors.indigo,
            ),
          ]
        : const <_GradeGoal>[];

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cálculo directo con parcial 1 y 2',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Carga tus dos parciales y te mostramos firma, ponderado actual y cuánto necesitas en el final.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: firstController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => onCalculate(),
                  decoration: const InputDecoration(
                    labelText: 'Parcial 1',
                    hintText: 'Ejemplo: 60',
                    prefixIcon: Icon(Icons.filter_1_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: secondController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => onCalculate(),
                  decoration: const InputDecoration(
                    labelText: 'Parcial 2',
                    hintText: 'Ejemplo: 72',
                    prefixIcon: Icon(Icons.filter_2_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCalculate,
              icon: const Icon(Icons.auto_graph_rounded),
              label: const Text('Calcular todo'),
            ),
          ),
          const SizedBox(height: 18),
          if (!hasFirst)
            const _EmptyResult(
              title: 'Empieza con tu primer parcial',
              text:
                  'Con el parcial 1 ya puedes ver cuánto te faltaría para media firma y firma completa. Si además cargas el parcial 2, sale todo el panorama del final.',
            )
          else ...[
            if (hasBoth)
              _SummaryStrip(
                items: [
                  _SummaryItem(
                    label: 'Ponderado actual',
                    value: ponderedAverage!.toStringAsFixed(1),
                    accent: const Color(0xFF2563EB),
                  ),
                  _SummaryItem(
                    label: 'Suma de parciales',
                    value: '$signatureSum',
                    accent: const Color(0xFF0EA5E9),
                  ),
                  _SummaryItem(
                    label: 'Firma',
                    value: signatureSum! >= 119
                        ? 'Completa'
                        : signatureSum >= 99
                            ? 'Media'
                            : 'Pendiente',
                    accent: const Color(0xFF7C3AED),
                  ),
                ],
              )
            else
              const _EmptyResult(
                title: 'Falta tu segundo parcial',
                text:
                    'Ya puedes ver cuánto necesitarías en el parcial 2 para firma. Cuando lo cargues, Focus calcula también tu ponderado y el final.',
              ),
            const SizedBox(height: 16),
            Text(
              'Objetivo de firma',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: signatureGoals.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.34,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                return _GoalCard(goal: signatureGoals[index]);
              },
            ),
            if (hasBoth) ...[
              const SizedBox(height: 18),
              if (blocked)
                const _BlockedResult(
                  title: 'No habilita final',
                  text:
                      'Con ponderado menor a 50% no se habilita el examen final.',
                )
              else ...[
                Text(
                  'Objetivos para el final',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: finalGoals.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.34,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    return _GoalCard(goal: finalGoals[index]);
                  },
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _PonderedPanel extends StatelessWidget {
  final TextEditingController controller;
  final double? average;
  final VoidCallback onCalculate;
  final int Function(double currentAverage, int targetGrade) requiredFinal;

  const _PonderedPanel({
    super.key,
    required this.controller,
    required this.average,
    required this.onCalculate,
    required this.requiredFinal,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = average != null && !habilitatesFinal(average!);
    final results = average == null
        ? const <_GradeGoal>[]
        : blocked
            ? const <_GradeGoal>[]
            : [
                _GradeGoal('Nota 2', requiredFinal(average!, 2), Colors.green),
                _GradeGoal('Nota 3', requiredFinal(average!, 3), Colors.blue),
                _GradeGoal('Nota 4', requiredFinal(average!, 4), Colors.orange),
                _GradeGoal('Nota 5', requiredFinal(average!, 5), Colors.purple),
              ];

    return _CalculatorPanel(
      title: 'Promedio ponderado',
      subtitle:
          'Si ya tienes tu ponderado calculado, aquí puedes ver rápidamente cuánto necesitarías en el final.',
      inputLabel: 'Promedio ponderado',
      hint: 'Ejemplo: 60',
      controller: controller,
      onCalculate: onCalculate,
      emptyTitle: 'Todavía no hay cálculo',
      emptyText: 'Carga tu ponderado para ver objetivos de nota 2, 3, 4 y 5.',
      blockedTitle: 'No habilita final',
      blockedText: 'Con ponderado menor a 50% no se habilita el examen final.',
      blocked: blocked,
      results: results,
    );
  }
}

class _SignaturePanel extends StatelessWidget {
  final TextEditingController controller;
  final double? firstPartial;
  final VoidCallback onCalculate;
  final int Function(double firstPartial, int targetTotal)
      requiredSecondPartial;

  const _SignaturePanel({
    super.key,
    required this.controller,
    required this.firstPartial,
    required this.onCalculate,
    required this.requiredSecondPartial,
  });

  @override
  Widget build(BuildContext context) {
    final results = firstPartial == null
        ? const <_GradeGoal>[]
        : [
            _GradeGoal(
              'Media firma',
              requiredSecondPartial(firstPartial!, 99),
              Colors.cyan,
            ),
            _GradeGoal(
              'Firma completa',
              requiredSecondPartial(firstPartial!, 119),
              Colors.indigo,
            ),
          ];

    return _CalculatorPanel(
      title: 'Firma',
      subtitle:
          'Si solo tienes el primer parcial, aquí puedes estimar lo necesario en el segundo.',
      inputLabel: 'Primer parcial',
      hint: 'Ejemplo: 60',
      controller: controller,
      onCalculate: onCalculate,
      emptyTitle: 'Esperando puntaje',
      emptyText:
          'Cuando cargues tu primer parcial verás media firma y firma completa.',
      blockedTitle: '',
      blockedText: '',
      blocked: false,
      results: results,
    );
  }
}

class _CalculatorPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String inputLabel;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onCalculate;
  final String emptyTitle;
  final String emptyText;
  final String blockedTitle;
  final String blockedText;
  final bool blocked;
  final List<_GradeGoal> results;

  const _CalculatorPanel({
    required this.title,
    required this.subtitle,
    required this.inputLabel,
    required this.hint,
    required this.controller,
    required this.onCalculate,
    required this.emptyTitle,
    required this.emptyText,
    required this.blockedTitle,
    required this.blockedText,
    required this.blocked,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => onCalculate(),
            decoration: InputDecoration(
              labelText: inputLabel,
              hintText: hint,
              prefixIcon: const Icon(Icons.numbers_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCalculate,
              icon: const Icon(Icons.auto_graph_rounded),
              label: const Text('Calcular'),
            ),
          ),
          const SizedBox(height: 18),
          if (blocked)
            _BlockedResult(title: blockedTitle, text: blockedText)
          else if (results.isEmpty)
            _EmptyResult(title: emptyTitle, text: emptyText)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.34,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final result = results[index];
                return _GoalCard(goal: result);
              },
            ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF222222) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final List<_SummaryItem> items;

  const _SummaryStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        if (compact) {
          return Column(
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SummaryCard(item: item),
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: items
              .map(
                (item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _SummaryCard(item: item),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: item.accent.withValues(alpha: 0.12),
        border: Border.all(color: item.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: TextStyle(
              color: item.accent,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final Color accent;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.accent,
  });
}

class _EmptyResult extends StatelessWidget {
  final String title;
  final String text;

  const _EmptyResult({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }
}

class _BlockedResult extends StatelessWidget {
  final String title;
  final String text;

  const _BlockedResult({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.red.withValues(alpha: 0.12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                      ),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final _GradeGoal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final impossible = goal.value > 100;
    final color = goal.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            goal.label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            impossible ? '+100' : '${goal.value}',
            style: TextStyle(
              color: color,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            impossible ? 'No alcanza con 100' : 'puntos necesarios',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GradeGoal {
  final String label;
  final int value;
  final Color color;

  const _GradeGoal(this.label, this.value, this.color);
}
