import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/resource_link.dart';
import '../providers/app_provider.dart';
import '../utils/focus_palette.dart';
import '../widgets/focus_drawer.dart';
import '../widgets/focus_help_button.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _searchController = TextEditingController();
  String _category = 'playlist';
  String _selectedFilter = 'all';
  int? _selectedSubjectId;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    _titleController.clear();
    _urlController.clear();
    _category = 'playlist';
    _selectedSubjectId = null;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Agregar recurso'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escribe un título.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(labelText: 'Link'),
                    validator: (value) {
                      final text = _normalizeUrl(value?.trim() ?? '');
                      final uri = Uri.tryParse(text);
                      if (text.isEmpty) return 'Escribe un link.';
                      if (uri == null ||
                          !uri.hasScheme ||
                          (uri.scheme != 'http' && uri.scheme != 'https')) {
                        return 'Usa un enlace válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: const [
                      DropdownMenuItem(
                          value: 'playlist', child: Text('Playlist')),
                      DropdownMenuItem(value: 'course', child: Text('Curso')),
                      DropdownMenuItem(
                          value: 'social', child: Text('Red social')),
                      DropdownMenuItem(
                          value: 'tool', child: Text('Herramienta')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => _category = value ?? 'playlist'),
                  ),
                  const SizedBox(height: 12),
                  Consumer<AppProvider>(
                    builder: (context, provider, _) {
                      final items = [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'General',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...provider.subjects.map(
                          (subject) => DropdownMenuItem<int?>(
                            value: subject.id,
                            child: Text(
                              subject.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ];

                      return DropdownButtonFormField<int?>(
                        initialValue: _selectedSubjectId,
                        isExpanded: true,
                        menuMaxHeight: 360,
                        decoration: const InputDecoration(
                          labelText: 'Materia asociada',
                          helperText:
                              'Opcional. Sirve para organizar recursos por materia.',
                        ),
                        selectedItemBuilder: (context) => items
                            .map(
                              (item) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  item.value == null
                                      ? 'General'
                                      : provider
                                              .getSubjectById(item.value)
                                              ?.name ??
                                          'General',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            )
                            .toList(),
                        items: items,
                        onChanged: (value) =>
                            setDialogState(() => _selectedSubjectId = value),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await Provider.of<AppProvider>(context, listen: false)
                    .addResource(
                  ResourceLink(
                    title: _titleController.text.trim(),
                    url: _normalizeUrl(_urlController.text.trim()),
                    category: _category,
                    subjectId: _selectedSubjectId,
                  ),
                );
                if (!mounted || !dialogContext.mounted) return;
                setState(() => _selectedFilter = 'all');
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recurso guardado.')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    final lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return text;
    }
    return 'https://$text';
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  Future<void> _suggestResource() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'gabrielnelson242004@gmail.com',
      queryParameters: {
        'subject': 'Sugerencia de recurso para Focus',
        'body':
            'Hola, quiero sugerir este recurso para Focus:\n\nNombre:\nLink:\nCategoría:\nMateria relacionada:\n',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir tu app de correo.')),
      );
    }
  }

  Future<void> _deleteResource(ResourceLink resource) async {
    if (resource.id == null || resource.isDefault) return;
    await Provider.of<AppProvider>(context, listen: false)
        .deleteResource(resource.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recurso eliminado.')),
    );
  }

  bool _matchesSearch(ResourceLink resource) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return resource.title.toLowerCase().contains(query) ||
        resource.url.toLowerCase().contains(query);
  }

  bool _matchesFilter(ResourceLink resource) {
    if (_selectedFilter == 'all') return true;
    if (_selectedFilter == 'subject') return resource.subjectId != null;
    return resource.category == _selectedFilter;
  }

  List<ResourceLink> _sortResourcesForDisplay(List<ResourceLink> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      final byCategory = _categoryRank(a.category).compareTo(
        _categoryRank(b.category),
      );
      if (byCategory != 0) return byCategory;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return sorted;
  }

  int _categoryRank(String category) {
    return switch (category) {
      'playlist' => 0,
      'course' => 1,
      'tool' => 2,
      'social' => 3,
      _ => 4,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'resources'),
      appBar: AppBar(
        title: const Text('Recursos'),
        actions: const [
          FocusHelpAction(
            title: 'Ayuda de recursos',
            message:
                'Guarda solo enlaces utiles para estudiar y deja el resto fuera para que la biblioteca se mantenga limpia.',
            sections: [
              FocusHelpSection(
                title: 'Que puedes guardar',
                items: [
                  'Playlists, cursos, herramientas y perfiles o redes utiles.',
                  'Puedes dejar un recurso como general o vincularlo a una materia.',
                ],
              ),
              FocusHelpSection(
                title: 'Organizacion',
                items: [
                  'Usa buscar y filtros para no llenar la pantalla con texto secundario.',
                  'El boton inferior sirve para agregar recursos nuevos.',
                  'Si quieres sugerir recursos para Focus, usa el boton Sugerir recurso.',
                ],
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final filteredResources = _sortResourcesForDisplay([
              ...provider.resourcesByCategory('playlist'),
              ...provider.resourcesByCategory('course'),
              ...provider.resourcesByCategory('social'),
              ...provider.resourcesByCategory('tool'),
            ]
                .where((item) => _matchesSearch(item) && _matchesFilter(item))
                .toList());
            final showGroupedBySubject =
                _selectedFilter == 'all' || _selectedFilter == 'subject';
            final generalResources = _sortResourcesForDisplay(filteredResources
                .where((item) => item.subjectId == null)
                .toList());
            final subjectResourceIds = {
              for (final item
                  in filteredResources.where((item) => item.subjectId != null))
                item.subjectId!: true
            };
            final singleSectionTitle = switch (_selectedFilter) {
              'playlist' => 'Playlists',
              'course' => 'Cursos',
              'tool' => 'Herramientas',
              'social' => 'Redes y perfiles',
              'subject' => 'Recursos por materia',
              _ => 'Biblioteca general',
            };

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
              children: [
                _ResourceIntroCard(totalResources: filteredResources.length),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buscar',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Buscar recurso',
                            hintText: 'Curso, playlist, herramienta...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar',
                            prefixIcon: Icon(Icons.tune_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('Todos')),
                            DropdownMenuItem(
                              value: 'subject',
                              child: Text('Por materia'),
                            ),
                            DropdownMenuItem(
                              value: 'playlist',
                              child: Text('Playlists'),
                            ),
                            DropdownMenuItem(
                                value: 'course', child: Text('Cursos')),
                            DropdownMenuItem(
                              value: 'tool',
                              child: Text('Herramientas'),
                            ),
                            DropdownMenuItem(
                                value: 'social', child: Text('Redes')),
                          ],
                          onChanged: (value) => setState(
                            () => _selectedFilter = value ?? 'all',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _suggestResource,
                            icon: const Icon(Icons.lightbulb_outline_rounded),
                            label: const Text('Sugerir recurso'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (filteredResources.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.library_books_rounded, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'No hay recursos para este filtro',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Prueba otro filtro o agrega tu primer recurso para empezar a construir tu biblioteca.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (!showGroupedBySubject)
                    _ResourceSection(
                      title: singleSectionTitle,
                      icon: _sectionIcon(_selectedFilter),
                      items: filteredResources,
                      onOpen: _openLink,
                      onDelete: _deleteResource,
                      accent: _sectionAccent(_selectedFilter),
                    )
                  else ...[
                    if (generalResources.isNotEmpty) ...[
                      _ResourceSection(
                        title: 'Biblioteca general',
                        icon: Icons.collections_bookmark_rounded,
                        items: generalResources,
                        onOpen: _openLink,
                        onDelete: _deleteResource,
                        accent: FocusPalette.primary,
                      ),
                      const SizedBox(height: 16),
                    ],
                    ...provider.subjects.where((subject) {
                      final subjectId = subject.id;
                      return subjectId != null &&
                          subjectResourceIds.containsKey(subjectId);
                    }).map((subject) {
                      final subjectItems = _sortResourcesForDisplay(
                          filteredResources
                              .where((item) => item.subjectId == subject.id)
                              .toList());
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ResourceSection(
                          title: subject.name,
                          icon: Icons.menu_book_rounded,
                          items: subjectItems,
                          onOpen: _openLink,
                          onDelete: _deleteResource,
                          accent: FocusPalette.primaryDeep,
                        ),
                      );
                    }),
                  ],
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  IconData _sectionIcon(String filter) {
    return switch (filter) {
      'playlist' => Icons.library_music_rounded,
      'course' => Icons.school_rounded,
      'tool' => Icons.build_circle_rounded,
      'social' => Icons.public_rounded,
      _ => Icons.collections_bookmark_rounded,
    };
  }

  Color _sectionAccent(String filter) {
    return switch (filter) {
      'playlist' => FocusPalette.primary,
      'course' => FocusPalette.teal,
      'tool' => FocusPalette.coral,
      'social' => FocusPalette.cyan,
      _ => FocusPalette.primary,
    };
  }
}

class _ResourceIntroCard extends StatelessWidget {
  final int totalResources;

  const _ResourceIntroCard({required this.totalResources});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: FocusPalette.focusGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recursos Focus',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enlaces clave para estudiar mejor.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: Text(
              '$totalResources recursos visibles',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<ResourceLink> items;
  final Future<void> Function(String url) onOpen;
  final Future<void> Function(ResourceLink resource) onDelete;
  final Color accent;

  const _ResourceSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.onOpen,
    required this.onDelete,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 240 + (index * 70)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onOpen(item.url),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: item.isDefault
                                  ? accent.withValues(alpha: 0.16)
                                  : Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.18),
                              child: Icon(
                                item.isDefault
                                    ? Icons.push_pin_rounded
                                    : _resourceIcon(item.category),
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.url,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!item.isDefault)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => onDelete(item),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _resourceIcon(String category) {
    return switch (category) {
      'playlist' => Icons.library_music_rounded,
      'course' => Icons.school_rounded,
      'social' => Icons.public_rounded,
      _ => Icons.build_circle_rounded,
    };
  }
}
