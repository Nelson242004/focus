import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/models/ranking_profile.dart';
import 'package:focus_app/utils/profile_icon_access.dart';
import 'package:focus_app/widgets/focus_public_profile_sheet.dart';

RankingProfile _profile({
  Map<String, dynamic> stats = const {},
}) {
  return RankingProfile(
    uid: 'user-1',
    name: 'Daiga',
    career: 'Ingeniería',
    rank: 'Oro',
    totalPoints: 1200,
    joinedAt: DateTime(2026),
    stats: stats,
  );
}

void main() {
  test('perfil público respeta iconos exclusivos de otros usuarios', () {
    final profile = _profile(
      stats: const {'profileIconAsset': darkFemaleProfileIconAsset},
    );

    expect(focusPublicProfileIconAsset(profile), darkFemaleProfileIconAsset);
  });

  test('perfil público usa default si el asset guardado no existe', () {
    final profile = _profile(
      stats: const {'profileIconAsset': 'assets/profile_icons/nope.png'},
    );

    expect(focusPublicProfileIconAsset(profile), defaultProfileIconAsset);
  });

  testWidgets('muestra feedback si falla enviar solicitud', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusPublicProfileSheet(
            profile: _profile(),
            isFriend: false,
            onSendRequest: () async {
              throw StateError('sin permisos');
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enviar solicitud'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('sin permisos'), findsOneWidget);
  });
}
