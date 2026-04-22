import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_links.dart';
import '../widgets/focus_drawer.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: AppLinks.appDownload));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link de descarga copiado.')),
    );
  }

  Future<void> _openDeveloperSite() async {
    final uri = Uri.parse(AppLinks.developerWebsite);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF475569);

    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'about'),
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          color: surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 132,
                      height: 132,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Focus es una app pensada para estudiantes en general.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Su propósito es ayudarte a organizar materias, horarios, exámenes, pomodoro, hábitos y progreso académico en un solo lugar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 17,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'La importación desde Excel está pensada especialmente para estudiantes de la Facultad Politécnica de la UNA. La aplicación es externa a la facultad y fue desarrollada por iniciativa propia, de forma independiente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Soy estudiante de Ingeniería en Informática y creé Focus para resolver una necesidad real de organización académica. Si encuentras un fallo o tienes sugerencias de mejora, puedes contactarme: cada idea ayuda a seguir puliendo la app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              Card(
                color: cardColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _openDeveloperSite,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Desarrollado por',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppLinks.developerName,
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Icon(Icons.open_in_new_rounded,
                                color: secondaryText),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compartir la app',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        AppLinks.appDownload,
                        style: TextStyle(color: secondaryText, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _copyLink(context),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar link'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
