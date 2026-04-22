import 'package:flutter/material.dart';
import '../utils/app_utils.dart';

class TimePickerField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const TimePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pickTime(BuildContext context) async {
    final initial =
        parseTimeOfDay(value) ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: label,
    );
    if (picked == null) return;
    onChanged(timeOfDayToString(picked));
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseTimeOfDay(value);
    final display = parsed == null
        ? (value.trim().isEmpty ? 'Sin hora definida' : value)
        : MaterialLocalizations.of(context)
            .formatTimeOfDay(parsed, alwaysUse24HourFormat: true);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _pickTime(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time_rounded),
        ),
        child: Text(
          display,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
