import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/focus_shield_app.dart';
import '../services/focus_mode_service.dart';
import '../widgets/focus_design_system.dart';
import '../widgets/focus_help_button.dart';

class FocusModeSetupScreen extends StatefulWidget {
  final List<FocusShieldApp> initiallySelected;

  const FocusModeSetupScreen({
    super.key,
    required this.initiallySelected,
  });

  @override
  State<FocusModeSetupScreen> createState() => _FocusModeSetupScreenState();
}

class _FocusModeSetupScreenState extends State<FocusModeSetupScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedPackages = <String>{};
  final Map<String, Uint8List> _iconCache = <String, Uint8List>{};
  final Set<String> _iconRequestsInFlight = <String>{};

  List<FocusShieldApp> _installedApps = const [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedPackages.addAll(
      widget.initiallySelected.map((app) => app.packageName),
    );
    _searchController.addListener(_onSearchChanged);
    _loadApps();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _query = _searchController.text.trim().toLowerCase());
    _primeVisibleIcons();
  }

  Future<void> _loadApps() async {
    final apps = await FocusModeService.getInstalledApps();
    if (!mounted) return;

    setState(() {
      _installedApps = apps;
      _isLoading = false;
    });
    _primeVisibleIcons();
  }

  void _primeVisibleIcons() {
    final filteredApps = _filteredApps();
    final visibleApps = <FocusShieldApp>[
      ...filteredApps
          .where((app) => _selectedPackages.contains(app.packageName)),
      ...filteredApps
          .where((app) => !_selectedPackages.contains(app.packageName))
          .take(16),
    ];

    for (final app in visibleApps) {
      if (_iconCache.containsKey(app.packageName) ||
          _iconRequestsInFlight.contains(app.packageName)) {
        continue;
      }
      _iconRequestsInFlight.add(app.packageName);
      unawaited(_loadIconForApp(app));
    }
  }

  Future<void> _loadIconForApp(FocusShieldApp app) async {
    final raw = await FocusModeService.getAppIcon(app.packageName);
    if (!mounted) return;

    Uint8List? bytes;
    if (raw.trim().isNotEmpty) {
      try {
        bytes = base64Decode(raw);
      } catch (_) {
        bytes = null;
      }
    }

    _iconRequestsInFlight.remove(app.packageName);
    if (bytes == null) return;

    setState(() {
      _iconCache[app.packageName] = bytes!;
    });
  }

  void _toggleApp(FocusShieldApp app) {
    setState(() {
      if (_selectedPackages.contains(app.packageName)) {
        _selectedPackages.remove(app.packageName);
      } else {
        _selectedPackages.add(app.packageName);
      }
    });
    _primeVisibleIcons();
  }

  void _toggleRecommendedSelection() {
    final recommendedPackages = _installedApps
        .where((app) => app.isRecommended)
        .map((app) => app.packageName)
        .toSet();
    final alreadySelected = recommendedPackages.isNotEmpty &&
        recommendedPackages.every(_selectedPackages.contains);

    setState(() {
      if (alreadySelected) {
        _selectedPackages.removeAll(recommendedPackages);
      } else {
        _selectedPackages.addAll(recommendedPackages);
      }
    });
    _primeVisibleIcons();
  }

  List<FocusShieldApp> _filteredApps() {
    return _installedApps.where((app) {
      if (_query.isEmpty) return true;
      final label = app.label.toLowerCase();
      final packageName = app.packageName.toLowerCase();
      return label.contains(_query) || packageName.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _filteredApps();
    final selectedApps = filteredApps
        .where((app) => _selectedPackages.contains(app.packageName))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    final moreApps = filteredApps
        .where((app) => !_selectedPackages.contains(app.packageName))
        .toList()
      ..sort(_sortAppsLikeMindful);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps distractoras'),
        actions: const [
          FocusHelpAction(
            title: 'Ayuda de apps distractoras',
            message:
                'Aquí eliges las apps que Focus va a considerar distractoras durante el modo de enfoque.',
            sections: [
              FocusHelpSection(
                title: 'Como usarlo',
                items: [
                  'Selecciona solo las apps que realmente te sacan del estudio.',
                  'Las recomendadas te ayudan a marcar rápido redes, video y mensajería.',
                  'El boton inferior guarda la lista elegida.',
                ],
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: child,
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            final selected = _installedApps
                .where((app) => _selectedPackages.contains(app.packageName))
                .map(
                  (app) => app.copyWith(
                    iconBase64: '',
                  ),
                )
                .toList();
            Navigator.of(context).pop(selected);
          },
          icon: const Icon(Icons.check_rounded),
          label: Text(
            _selectedPackages.isEmpty
                ? 'Guardar'
                : 'Guardar ${_selectedPackages.length}',
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isLoading
              ? const FocusSkeletonList(
                  heights: [72, 64, 64, 64, 64],
                  padding: EdgeInsets.fromLTRB(14, 16, 14, 104),
                )
              : ListView(
                  key: ValueKey<int>(
                    _selectedPackages.length + filteredApps.length,
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 104),
                  children: [
                    _RevealIn(
                      child: _SearchAndActions(
                        controller: _searchController,
                        hasQuery: _query.isNotEmpty,
                        onClearQuery: () {
                          _searchController.clear();
                          setState(() => _query = '');
                          _primeVisibleIcons();
                        },
                        onToggleRecommended: _toggleRecommendedSelection,
                        onClearSelected: () {
                          setState(_selectedPackages.clear);
                          _primeVisibleIcons();
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    _RevealIn(
                      delay: const Duration(milliseconds: 40),
                      child: _SectionTitle(
                        title: 'Tus aplicaciones que te distraen',
                        subtitle: _selectedPackages.isEmpty
                            ? 'Elige redes, videos o mensajería que quieras frenar.'
                            : '${_selectedPackages.length} seleccionadas',
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: selectedApps.isEmpty
                          ? const _InfoTile(
                              key: ValueKey('empty-selected'),
                              text:
                                  'Aún no elegiste apps. Toca una de la lista para añadirla.',
                            )
                          : Column(
                              key: const ValueKey('selected-list'),
                              children: [
                                for (var i = 0; i < selectedApps.length; i++)
                                  _RevealIn(
                                    delay:
                                        Duration(milliseconds: 50 + (i * 35)),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _MindfulAppTile(
                                        app: selectedApps[i],
                                        selected: true,
                                        iconBytes: _iconCache[
                                            selectedApps[i].packageName],
                                        onTap: () =>
                                            _toggleApp(selectedApps[i]),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    _RevealIn(
                      delay: const Duration(milliseconds: 70),
                      child: _SectionTitle(
                        title: 'Selecciona más apps',
                        subtitle: _query.isEmpty
                            ? 'Te mostramos primero las más típicas de distracción.'
                            : 'Resultados para tu búsqueda',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (moreApps.isEmpty)
                      const _InfoTile(
                        key: ValueKey('empty-more'),
                        text: 'No encontramos más apps con ese filtro.',
                      )
                    else
                      ...moreApps.asMap().entries.map((entry) {
                        final index = entry.key;
                        final app = entry.value;
                        final tile = Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MindfulAppTile(
                            app: app,
                            selected: false,
                            iconBytes: _iconCache[app.packageName],
                            onTap: () => _toggleApp(app),
                          ),
                        );
                        if (index < 18) {
                          return _RevealIn(
                            delay: Duration(milliseconds: 90 + (index * 16)),
                            child: tile,
                          );
                        }
                        return tile;
                      }),
                  ],
                ),
        ),
      ),
    );
  }

  int _sortAppsLikeMindful(FocusShieldApp a, FocusShieldApp b) {
    if (a.isRecommended && !b.isRecommended) return -1;
    if (!a.isRecommended && b.isRecommended) return 1;

    final order = FocusShieldApp.recommendedPackageOrder;
    final aIndex = order.indexOf(a.packageName.toLowerCase());
    final bIndex = order.indexOf(b.packageName.toLowerCase());
    if (aIndex == -1 && bIndex == -1) {
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    }
    if (aIndex == -1) return 1;
    if (bIndex == -1) return -1;
    return aIndex.compareTo(bIndex);
  }
}

class _SearchAndActions extends StatelessWidget {
  final TextEditingController controller;
  final bool hasQuery;
  final VoidCallback onClearQuery;
  final VoidCallback onToggleRecommended;
  final VoidCallback onClearSelected;

  const _SearchAndActions({
    required this.controller,
    required this.hasQuery,
    required this.onClearQuery,
    required this.onToggleRecommended,
    required this.onClearSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.3);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: tint,
            ),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Buscar aplicaciones...',
                prefixIcon: Icon(Icons.search_rounded),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ActionCircleButton(
          icon: Icons.auto_awesome_rounded,
          tooltip: 'Marcar sugeridas',
          onTap: onToggleRecommended,
        ),
        const SizedBox(width: 10),
        _ActionCircleButton(
          icon: hasQuery ? Icons.close_rounded : Icons.deselect_rounded,
          tooltip: hasQuery ? 'Limpiar búsqueda' : 'Quitar selección',
          onTap: hasQuery ? onClearQuery : onClearSelected,
        ),
      ],
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String text;

  const _InfoTile({
    super.key,
    required this.text,
  });

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
            .withValues(alpha: 0.25),
      ),
      child: Text(text),
    );
  }
}

class _MindfulAppTile extends StatelessWidget {
  final FocusShieldApp app;
  final bool selected;
  final Uint8List? iconBytes;
  final VoidCallback onTap;

  const _MindfulAppTile({
    required this.app,
    required this.selected,
    required this.iconBytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.22)
                  : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: selected ? 1.04 : 1,
                child: _AppIconBubble(app: app, iconBytes: iconBytes),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  app.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: selected
                      ? primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected ? primary : Theme.of(context).dividerColor,
                    width: 1.8,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: primary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIconBubble extends StatelessWidget {
  final FocusShieldApp app;
  final Uint8List? iconBytes;

  const _AppIconBubble({required this.app, required this.iconBytes});

  @override
  Widget build(BuildContext context) {
    final visual = _focusModeVisualForSetup(app);
    return CircleAvatar(
      radius: 18,
      backgroundColor: visual.color.withValues(alpha: 0.14),
      child: iconBytes != null
          ? ClipOval(
              child: Image.memory(
                iconBytes!,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  visual.icon,
                  color: visual.color,
                  size: 20,
                ),
              ),
            )
          : Icon(
              visual.icon,
              color: visual.color,
              size: 20,
            ),
    );
  }
}

_SetupAppVisual _focusModeVisualForSetup(FocusShieldApp app) {
  final pkg = app.packageName.toLowerCase();
  final label = app.label.toLowerCase();

  if (pkg.contains('instagram') || label.contains('instagram')) {
    return const _SetupAppVisual(Icons.camera_alt_rounded, Color(0xFFE1306C));
  }
  if (pkg.contains('musical') ||
      pkg.contains('tiktok') ||
      label.contains('tiktok')) {
    return const _SetupAppVisual(Icons.music_note_rounded, Color(0xFF111827));
  }
  if (pkg.contains('youtube') || label.contains('youtube')) {
    return const _SetupAppVisual(Icons.play_arrow_rounded, Color(0xFFEF4444));
  }
  if (pkg.contains('whatsapp') || label.contains('whatsapp')) {
    return const _SetupAppVisual(Icons.chat_rounded, Color(0xFF22C55E));
  }
  if (pkg.contains('telegram') || label.contains('telegram')) {
    return const _SetupAppVisual(Icons.send_rounded, Color(0xFF38BDF8));
  }
  if (pkg.contains('facebook') || label.contains('facebook')) {
    return const _SetupAppVisual(Icons.thumb_up_rounded, Color(0xFF2563EB));
  }
  if (pkg.contains('twitter') ||
      pkg.contains('x.') ||
      label == 'x' ||
      label.contains('twitter')) {
    return const _SetupAppVisual(
      Icons.alternate_email_rounded,
      Color(0xFF111827),
    );
  }
  if (pkg.contains('discord') || label.contains('discord')) {
    return const _SetupAppVisual(Icons.headset_mic_rounded, Color(0xFF6366F1));
  }
  if (pkg.contains('spotify') || label.contains('spotify')) {
    return const _SetupAppVisual(Icons.graphic_eq_rounded, Color(0xFF22C55E));
  }
  if (pkg.contains('netflix') || label.contains('netflix')) {
    return const _SetupAppVisual(
      Icons.movie_creation_rounded,
      Color(0xFFDC2626),
    );
  }
  if (pkg.contains('chrome') ||
      pkg.contains('browser') ||
      label.contains('chrome') ||
      label.contains('browser')) {
    return const _SetupAppVisual(Icons.public_rounded, Color(0xFF0EA5E9));
  }

  return const _SetupAppVisual(Icons.apps_rounded, Color(0xFF64748B));
}

class _SetupAppVisual {
  final IconData icon;
  final Color color;

  const _SetupAppVisual(this.icon, this.color);
}

class _RevealIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _RevealIn({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_RevealIn> createState() => _RevealInState();
}

class _RevealInState extends State<_RevealIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
