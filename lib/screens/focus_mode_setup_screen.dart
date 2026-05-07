import 'package:flutter/material.dart';

import '../models/focus_shield_app.dart';
import '../services/focus_mode_service.dart';

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
  List<FocusShieldApp> _installedApps = const [];
  final Set<String> _selectedPackages = <String>{};
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedPackages.addAll(
      widget.initiallySelected.map((app) => app.packageName),
    );
    _loadApps();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final installedApps = await FocusModeService.getInstalledApps();
    if (!mounted) return;
    setState(() {
      _installedApps = installedApps;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _installedApps.where((app) {
      if (_query.isEmpty) return true;
      final label = app.label.toLowerCase();
      final packageName = app.packageName.toLowerCase();
      return label.contains(_query) || packageName.contains(_query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps distractoras'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar app',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                ),
                child: Text(
                  'Selecciona las apps que quieres frenar durante una sesión. Focus vigilará si intentas abrirlas mientras estudias.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredApps.isEmpty
                      ? const Center(
                          child: Text('No encontramos apps con ese nombre.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = filteredApps[index];
                            final selected =
                                _selectedPackages.contains(app.packageName);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: CheckboxListTile(
                                value: selected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedPackages.add(app.packageName);
                                    } else {
                                      _selectedPackages.remove(app.packageName);
                                    }
                                  });
                                },
                                title: Text(app.label),
                                subtitle: Text(
                                  app.packageName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: FilledButton.icon(
                onPressed: () {
                  final selectedApps = _installedApps
                      .where(
                        (app) => _selectedPackages.contains(app.packageName),
                      )
                      .toList();
                  Navigator.of(context).pop(selectedApps);
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  _selectedPackages.isEmpty
                      ? 'Guardar sin apps'
                      : 'Guardar ${_selectedPackages.length} apps',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
