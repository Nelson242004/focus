import 'package:flutter/material.dart';

class FocusPalette {
  FocusPalette._();

  static const primary = Color(0xFF2563EB);
  static const primaryDeep = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFEFF6FF);
  static const cyan = Color(0xFF0EA5E9);
  static const teal = Color(0xFF0F766E);
  static const mint = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const coral = Color(0xFFFF7A59);
  static const danger = Color(0xFFEF4444);

  // Dirección visual Focus: académico + gamificado + calmado.
  // Azul: enfoque/acción. Teal: estudio/progreso. Mint: calma/éxito.
  // Amber: puntos/logros. Coral/danger: solo alerta o error.
  static const academic = primary;
  static const study = teal;
  static const calmGame = mint;
  static const reward = amber;

  static const action = primary;
  static const progress = teal;
  static const calm = mint;
  static const points = amber;
  static const achievement = amber;
  static const softAlert = coral;
  static const error = danger;

  static const success = mint;
  static const warning = amber;
  static const focusBlue = primary;
  static const studyTeal = teal;

  static const ink = Color(0xFF0F172A);
  static const ink2 = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFD6E0EC);
  static const surface = Color(0xFFF6F8FC);
  static const surfaceTop = Color(0xFFF8FAFC);
  static const surfaceMid = Color(0xFFF3F7FD);
  static const surfaceTint = Color(0xFFF4FBF9);
  static const card = Color(0xFFFFFFFF);

  static const darkInk = Color(0xFF000000);
  static const darkSurface = Color(0xFF000000);
  static const darkSurfaceTop = Color(0xFF000000);
  static const darkSurfaceMid = Color(0xFF030405);
  static const darkSurfaceTint = Color(0xFF05080A);
  static const darkCard = Color(0xFF090C10);
  static const darkCard2 = Color(0xFF10161D);
  static const darkBorder = Color(0xFF1B2430);

  static const focusGradient = [primaryDeep, primary, cyan];
  static const studyGradient = [ink, primaryDeep, primary];
  static const successGradient = [teal, mint];
  static const examGradient = [coral, primary];
  static const calmGradient = [primary, teal];
  static const warmGradient = [amber, mint];
  static const heroGradient = [primaryDeep, primary, teal];
  static const socialGradient = [primaryDeep, cyan, mint];
  static const rewardGradient = [amber, mint];
  static const lightBackgroundGradient = [
    surfaceTop,
    surfaceMid,
    surfaceTint,
  ];
  static const darkBackgroundGradient = [
    darkSurfaceTop,
    darkSurfaceMid,
    darkSurfaceTint,
  ];

  static const coreAccents = [
    primary,
    teal,
    mint,
    amber,
  ];

  static const accentOptions = [
    primaryDeep,
    primary,
    cyan,
    teal,
    mint,
  ];

  static const accentHexOptions = [
    '#1D4ED8',
    '#2563EB',
    '#0EA5E9',
    '#0F766E',
    '#10B981',
  ];
}
