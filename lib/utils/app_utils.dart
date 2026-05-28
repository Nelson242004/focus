import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/exam.dart';

Color colorFromHex(String hex, {Color fallback = Colors.blue}) {
  final normalized = hex.replaceFirst('#', '');
  if (normalized.length != 6) return fallback;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;
  return Color(value + 0xFF000000);
}

String colorToHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

String formatDateTime(DateTime date) =>
    DateFormat('dd/MM/yyyy HH:mm').format(date);

DateTime combineDateAndTime(DateTime date, String time) {
  final minutes = timeToMinutes(time);
  if (minutes < 0) {
    return DateTime(date.year, date.month, date.day);
  }
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

DateTime combineExamDateAndTime(Exam exam) {
  return combineDateAndTime(exam.date, exam.startTime);
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int calendarDaysUntil(DateTime date, {DateTime? from}) {
  final start = dateOnly(from ?? DateTime.now());
  final target = dateOnly(date);
  return target.difference(start).inDays;
}

bool isExamUpcoming(Exam exam, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (exam.startTime.trim().isEmpty || !isValidTime(exam.startTime)) {
    return !dateOnly(exam.date).isBefore(dateOnly(current));
  }
  return !combineExamDateAndTime(exam).isBefore(current);
}

DateTime examSortMoment(Exam exam) {
  if (exam.startTime.trim().isEmpty || !isValidTime(exam.startTime)) {
    return DateTime(exam.date.year, exam.date.month, exam.date.day, 23, 59);
  }
  return combineExamDateAndTime(exam);
}

TimeOfDay? parseTimeOfDay(String value) {
  final minutes = timeToMinutes(value);
  if (minutes < 0) return null;
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

String timeOfDayToString(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int timeToMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return -1;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return -1;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return -1;
  return hour * 60 + minute;
}

bool isValidTime(String value) => timeToMinutes(value) >= 0;

String weekdayLabel(int dayOfWeek) {
  const days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  if (dayOfWeek < 0 || dayOfWeek >= days.length) return 'Día desconocido';
  return days[dayOfWeek];
}
