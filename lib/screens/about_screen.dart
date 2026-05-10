import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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

  Future<void> _shareApp() async {
    await Share.share(
      'Probá Focus, una app para organizar materias, exámenes, hábitos y Pomodoro:\n${AppLinks.appDownload}',
      subject: 'Focus app',
    );
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
      appBar: AppBar(title: const Text('Acerca de Focus')),
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
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _openDeveloperSite,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: const Icon(
                            Icons.code_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Desarrollado por',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                AppLinks.developerName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tecnología y herramientas para estudiantes.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.ios_share_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Compartir Focus',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Invita a otros estudiantes a probar la beta y organizar mejor su rutina académica.',
                        style: TextStyle(color: secondaryText, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      SelectableText(
                        AppLinks.appDownload,
                        style: TextStyle(color: secondaryText, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _shareApp,
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Compartir'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyLink(context),
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copiar link'),
                          ),
                        ],
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
