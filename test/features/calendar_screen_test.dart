import 'package:f1_tracker/core/theme/app_theme.dart';
import 'package:f1_tracker/features/calendar/calendar_screen.dart';
import 'package:f1_tracker/features/calendar/race_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('takvimdeki yarışa dokununca o turun detay ekranı açılır', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeJolpica();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: CalendarScreen(repository: api.repository(), clock: () => testNow)),
    ));
    await settle(tester);

    expect(find.text('Sonuçlar ve puan durumu'), findsNWidgets(2)); // her kartta ipucu

    await tester.tap(find.text('Past Grand Prix'));
    await settle(tester);

    expect(find.byType(RaceDetailScreen), findsOneWidget);
    expect(api.paths, contains('/ergast/f1/2026/1/results.json')); // 1. tur için sorgu

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(RaceDetailScreen), findsNothing);
  });
}
