import 'dart:math' as math;

double? parsePolytechnicScore(String value) {
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  return parsed?.clamp(0, 100).toDouble();
}

double calculatePonderedAverageFromPartials(
  double firstPartial,
  double secondPartial,
) {
  return ((firstPartial + secondPartial) / 2).clamp(0, 100).toDouble();
}

int calculateSignaturePoints(double firstPartial, double secondPartial) {
  return (firstPartial + secondPartial).floor();
}

bool habilitatesFinal(double ponderedAverage) => ponderedAverage >= 50;

int requiredFinalScore(double ponderedAverage, int targetGrade) {
  final targetThreshold = switch (targetGrade) {
    2 => 60.0,
    3 => 71.0,
    4 => 81.0,
    5 => 91.0,
    _ => throw ArgumentError.value(targetGrade, 'targetGrade'),
  };

  // La nota final ponderada se redondea al entero más cercano.
  final roundedThreshold = targetThreshold - 0.5;
  final required = (roundedThreshold - (ponderedAverage * 0.4)) / 0.6;
  return math.max(50, required.ceil());
}

int requiredSecondPartialForSignature(
  double firstPartial,
  SignatureGoal goal,
) {
  final targetTotal = switch (goal) {
    SignatureGoal.media => 99,
    SignatureGoal.full => 119,
  };
  return math.max(0, targetTotal - firstPartial.floor());
}

enum SignatureGoal { media, full }
