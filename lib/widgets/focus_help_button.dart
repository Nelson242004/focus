import 'package:flutter/material.dart';

class FocusHelpSection {
  final String title;
  final List<String> items;

  const FocusHelpSection({
    required this.title,
    required this.items,
  });
}

class FocusHelpAction extends StatelessWidget {
  final String title;
  final String? message;
  final List<FocusHelpSection> sections;
  final String tooltip;

  const FocusHelpAction({
    super.key,
    required this.title,
    required this.sections,
    this.message,
    this.tooltip = 'Informacion',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => showFocusHelpSheet(
        context,
        title: title,
        message: message,
        sections: sections,
      ),
      icon: const Icon(Icons.help_outline_rounded),
    );
  }
}

Future<void> showFocusHelpSheet(
  BuildContext context, {
  required String title,
  String? message,
  required List<FocusHelpSection> sections,
}) {
  final theme = Theme.of(context);
  final helperMessage = message?.trim();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (helperMessage != null && helperMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                helperMessage,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            for (final section in sections) ...[
              const SizedBox(height: 18),
              Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...section.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
