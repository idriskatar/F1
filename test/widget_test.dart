import 'package:f1_tracker/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('uygulama açılır, ana sayfa gerçek veriyi gösterir ve sekmeler çalışır', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(F1TrackerApp(
      repository: FakeJolpica().repository(),
      newsRepository: FakeFeeds().repository(),
      clock: () => testNow,
    ));
    await settle(tester);

    expect(find.text('F1 TRACKER'), findsOneWidget);
    expect(find.text('SIRADAKİ YARIŞ'), findsOneWidget);

    final nav = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('Takvim')));
    await settle(tester);
    expect(find.text('Sezon programı • saatler cihazının yerel saatinde'), findsOneWidget);

    await tester.tap(find.descendant(of: nav, matching: find.text('Haberler')));
    await settle(tester);
    expect(find.widgetWithText(ChoiceChip, 'TRF1.net'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
