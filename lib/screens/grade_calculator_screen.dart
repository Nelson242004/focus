import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/focus_palette.dart';
import '../utils/polytechnic_grade_utils.dart';
import '../widgets/focus_drawer.dart';

class GradeCalculatorScreen extends StatefulWidget {
  const GradeCalculatorScreen({super.key});

  @override
  State<GradeCalculatorScreen> createState() => _GradeCalculatorScreenState();
}

class _GradeCalculatorScreenState extends State<GradeCalculatorScreen> {
  final _firstController = TextEditingController();
  final _secondController = TextEditingController();

  double? _firstPartial;
  double? _secondPartial;
  String? _firstError;
  String? _secondError;
  int _selectedTab = 0;

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selectedTab = index);
  }

  void _calculateCurrentTab() {
    final requireSecond = _selectedTab != 0;
    _validateAndStore(requireSecond: requireSecond);
  }

  bool _validateAndStore({required bool requireSecond}) {
    FocusManager.instance.primaryFocus?.unfocus();

    final firstText = _firstController.text.trim();
    final secondText = _secondController.text.trim();

    final firstError = _validateScoreText(
      firstText,
      label: 'Parcial 1',
      required: true,
    );
    final secondError = _validateScoreText(
      secondText,
      label: 'Parcial 2',
      required: requireSecond,
    );

    final firstValue = firstError == null && firstText.isNotEmpty
        ? parsePolytechnicScore(firstText)
        : null;
    final secondValue = secondError == null && secondText.isNotEmpty
        ? parsePolytechnicScore(secondText)
        : null;

    setState(() {
      _firstError = firstError;
      _secondError = secondError;
      _firstPartial = firstValue;
      _secondPartial = secondValue;
    });

    return firstError == null && secondError == null;
  }

  String? _validateScoreText(
    String value, {
    required String label,
    required bool required,
  }) {
    if (value.isEmpty) {
      return required ? 'Ingresa $label.' : null;
    }

    final normalized = value.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      return 'Usa solo números válidos.';
    }
    if (parsed < 0 || parsed > 100) {
      return 'Debe estar entre 0 y 100.';
    }
    return null;
  }

  String _signatureStatusLabel(int total) {
    if (total >= 119) return 'Firma completa';
    if (total >= 99) return 'Media firma';
    return 'Aún no firma';
  }

  Color _signatureStatusColor(int total) {
    if (total >= 119) return FocusPalette.teal;
    if (total >= 99) return const Color(0xFF0EA5E9);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
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
                  'Firma, final y detalles separados para ver solo lo importante.',
            ),
            const SizedBox(height: 14),
            _CalculatorTabSelector(
              selectedIndex: _selectedTab,
              onSelected: _selectTab,
            ),
            const SizedBox(height: 14),
            _InputsCard(
              firstController: _firstController,
              secondController: _secondController,
              firstError: _firstError,
              secondError: _secondError,
              showSecondField: _selectedTab != 0,
              requireSecond: _selectedTab != 0,
              buttonLabel: switch (_selectedTab) {
                0 => 'Calcular firma',
                1 => 'Calcular final',
                _ => 'Ver detalles',
              },
              helperText: switch (_selectedTab) {
                0 => 'Para firma solo necesitas el parcial 1.',
                1 => 'Para final necesitas parcial 1 y parcial 2.',
                _ => 'Detalles muestra ponderado y suma de parciales.',
              },
              onPressed: _calculateCurrentTab,
            ),
            const SizedBox(height: 14),
            if (_selectedTab == 0)
              _FirmaTab(
                firstPartial: _firstPartial,
              )
            else if (_selectedTab == 1)
              _FinalTab(
                firstPartial: _firstPartial,
                secondPartial: _secondPartial,
              )
            else
              _DetailsTab(
                firstPartial: _firstPartial,
                secondPartial: _secondPartial,
                statusLabel: _signatureStatusLabel,
                statusColor: _signatureStatusColor,
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

class _CalculatorTabSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _CalculatorTabSelector({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _TabPill(
            label: 'Firma',
            icon: Icons.verified_rounded,
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          _TabPill(
            label: 'Final',
            icon: Icons.flag_rounded,
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          _TabPill(
            label: 'Detalles',
            icon: Icons.insights_rounded,
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color:
              selected ? primary.withValues(alpha: 0.14) : Colors.transparent,
          border: Border.all(
            color: selected ? primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? primary : null),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? primary : null,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputsCard extends StatelessWidget {
  final TextEditingController firstController;
  final TextEditingController secondController;
  final String? firstError;
  final String? secondError;
  final bool showSecondField;
  final bool requireSecond;
  final String buttonLabel;
  final String helperText;
  final VoidCallback onPressed;

  const _InputsCard({
    required this.firstController,
    required this.secondController,
    required this.firstError,
    required this.secondError,
    required this.showSecondField,
    required this.requireSecond,
    required this.buttonLabel,
    required this.helperText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Carga tus parciales',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(helperText, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: firstController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onSubmitted: (_) => onPressed(),
                  decoration: InputDecoration(
                    labelText: 'Parcial 1',
                    hintText: '0 a 100',
                    errorText: firstError,
                    prefixIcon: const Icon(Icons.filter_1_rounded),
                  ),
                ),
              ),
              if (showSecondField) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: secondController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onSubmitted: (_) => onPressed(),
                    decoration: InputDecoration(
                      labelText:
                          requireSecond ? 'Parcial 2' : 'Parcial 2 (opcional)',
                      hintText: '0 a 100',
                      errorText: secondError,
                      prefixIcon: const Icon(Icons.filter_2_rounded),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.auto_graph_rounded),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirmaTab extends StatelessWidget {
  final double? firstPartial;

  const _FirmaTab({
    required this.firstPartial,
  });

  @override
  Widget build(BuildContext context) {
    if (firstPartial == null) {
      return const _EmptyResult(
        title: 'Empieza con tu primer parcial',
        text:
            'Ingresa tu parcial 1 para ver cuánto te faltaría para media firma y firma completa.',
      );
    }

    final mediaGoal =
        requiredSecondPartialForSignature(firstPartial!, SignatureGoal.media);
    final fullGoal =
        requiredSecondPartialForSignature(firstPartial!, SignatureGoal.full);

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Firma',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Lo esencial: cuánto necesitas en el parcial 2 para llegar a firma.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.34,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _GoalCard(
                goal: _GradeGoal(
                  'Media firma',
                  mediaGoal,
                  const Color(0xFF0EA5E9),
                ),
              ),
              _GoalCard(
                goal: _GradeGoal(
                  'Firma completa',
                  fullGoal,
                  FocusPalette.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinalTab extends StatelessWidget {
  final double? firstPartial;
  final double? secondPartial;

  const _FinalTab({
    required this.firstPartial,
    required this.secondPartial,
  });

  @override
  Widget build(BuildContext context) {
    if (firstPartial == null || secondPartial == null) {
      return const _EmptyResult(
        title: 'Faltan datos para el final',
        text:
            'Carga ambos parciales para ver cuánto necesitas en el examen final.',
      );
    }

    final pondered = calculatePonderedAverageFromPartials(
      firstPartial!,
      secondPartial!,
    );
    final enabled = habilitatesFinal(pondered);
    final goals = enabled
        ? [
            _GradeGoal('Nota 2', requiredFinalScore(pondered, 2), Colors.green),
            _GradeGoal('Nota 3', requiredFinalScore(pondered, 3), Colors.blue),
            _GradeGoal(
                'Nota 4', requiredFinalScore(pondered, 4), Colors.orange),
            _GradeGoal(
                'Nota 5', requiredFinalScore(pondered, 5), Colors.purple),
          ]
        : const <_GradeGoal>[];

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Final',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Lo esencial: si habilitas y qué necesitas en el final.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (!enabled)
            const _BlockedResult(
              title: 'No habilita final',
              text: 'Con ponderado menor a 50% no se habilita el examen final.',
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: goals.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.34,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) => _GoalCard(goal: goals[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final double? firstPartial;
  final double? secondPartial;
  final String Function(int total) statusLabel;
  final Color Function(int total) statusColor;

  const _DetailsTab({
    required this.firstPartial,
    required this.secondPartial,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    if (firstPartial == null || secondPartial == null) {
      return const _EmptyResult(
        title: 'Faltan datos para detalles',
        text:
            'Carga ambos parciales para ver ponderado actual, suma de parciales y estado de firma.',
      );
    }

    final pondered = calculatePonderedAverageFromPartials(
      firstPartial!,
      secondPartial!,
    );
    final sum = calculateSignaturePoints(firstPartial!, secondPartial!);
    final label = statusLabel(sum);
    final accent = statusColor(sum);

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalles',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Aquí va lo complementario.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _SummaryStrip(
            items: [
              _SummaryItem(
                label: 'Ponderado actual',
                value: pondered.toStringAsFixed(1),
                accent: const Color(0xFF2563EB),
              ),
              _SummaryItem(
                label: 'Suma de parciales',
                value: '$sum',
                accent: const Color(0xFF0EA5E9),
              ),
              _SummaryItem(
                label: 'Estado de firma',
                value: label,
                accent: accent,
              ),
            ],
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
              .asMap()
              .entries
              .map(
                (entry) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: entry.key == items.length - 1 ? 0 : 10,
                    ),
                    child: _SummaryCard(item: entry.value),
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
    return _SurfaceCard(
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

