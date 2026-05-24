import 'package:flutter/material.dart';

import '../utils/focus_palette.dart';
import 'focus_design_system.dart';

enum FocusFeedbackType { success, info, warning, error }

void showFocusFeedback(
  BuildContext context, {
  required String message,
  FocusFeedbackType type = FocusFeedbackType.success,
  IconData? icon,
  bool celebration = false,
}) {
  final config = switch (type) {
    FocusFeedbackType.success => (
        color: FocusPalette.mint,
        icon: Icons.check_circle_rounded,
      ),
    FocusFeedbackType.info => (
        color: FocusPalette.primary,
        icon: Icons.info_rounded,
      ),
    FocusFeedbackType.warning => (
        color: FocusPalette.amber,
        icon: Icons.tips_and_updates_rounded,
      ),
    FocusFeedbackType.error => (
        color: FocusPalette.danger,
        icon: Icons.error_rounded,
      ),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: FocusActionSnackContent(
          icon: icon ?? config.icon,
          message: celebration ? '✨ $message' : message,
          color: config.color,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
    );
}
