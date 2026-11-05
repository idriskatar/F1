import 'package:f1_tracker/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('uygulama açılır, ana sayfa gerçek veriyi gösterir ve sekmeler çalışır', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeJolpica();
    await tester.pumpWidget(F1TrackerApp(repository: api.repository(), clock: () => testNow));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.text('F1 TRACKER'), findsOneWidget);
    expect(find.text('SIRADAKİ YARIŞ'), findsOneWidget);

    final calendarTab = find.descendant(of: find.byType(NavigationBar), matching: find.text('Takvim'));
    await tester.tap(calendarTab);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Sezon programı • saatler cihazının yerel saatinde'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
