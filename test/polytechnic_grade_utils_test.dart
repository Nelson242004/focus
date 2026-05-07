import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/utils/polytechnic_grade_utils.dart';

void main() {
  group('Calculadora Politécnica', () {
    test('menor a 50 de ponderado no habilita final', () {
      expect(habilitatesFinal(49.99), isFalse);
      expect(habilitatesFinal(50), isTrue);
    });

    test('ponderado calcula mínimos de final para notas 2 a 5', () {
      expect(requiredFinalScore(60, 2), 60);
      expect(requiredFinalScore(60, 3), 78);
      expect(requiredFinalScore(60, 4), 95);
      expect(requiredFinalScore(60, 5), 111);
    });

    test('ponderado nunca pide menos de 50 en el final', () {
      expect(requiredFinalScore(90, 2), 50);
      expect(requiredFinalScore(100, 3), 51);
    });

    test('firma calcula media firma y firma completa', () {
      expect(requiredSecondPartialForSignature(60, SignatureGoal.media), 39);
      expect(requiredSecondPartialForSignature(60, SignatureGoal.full), 59);
      expect(requiredSecondPartialForSignature(120, SignatureGoal.full), 0);
    });

    test('dos parciales calculan el ponderado actual', () {
      expect(calculatePonderedAverageFromPartials(60, 80), 70);
      expect(calculatePonderedAverageFromPartials(55, 55), 55);
    });

    test('dos parciales calculan puntos de firma acumulados', () {
      expect(calculateSignaturePoints(60, 45), 105);
      expect(calculateSignaturePoints(59.9, 59.9), 119);
    });
  });
}
