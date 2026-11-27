import 'package:f1_tracker/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpDesktopApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(F1TrackerApp(
    repository: FakeJolpica().repository(),
    newsRepository: FakeFeeds().repository(),
    clock: () => testNow,
  ));
  await settle(tester);
}

void main() {
  testWidgets('geniş pencerede alt çubuk yerine yan gezinme rayı gösterilir', (tester) async {
    await pumpDesktopApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('SIRADAKİ YARIŞ'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(NavigationRail),
      matching: find.byIcon(Icons.calendar_month_outlined),
    ));
    await settle(tester);

    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 1);
    expect(find.text('Sezon programı • saatler cihazının yerel saatinde'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ctrl+2 klavye kısayolu Takvim sekmesine geçer', (tester) async {
    await pumpDesktopApp(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);

    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('masaüstü ana sayfası puan durumlarını yan yana, haberleri iki sütunda gösterir', (tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('2026 Driver Standings'), findsOneWidget);
    expect(find.text('2026 Constructor Standings'), findsOneWidget);
    expect(find.text('Full 2026 Driver Standings'), findsOneWidget);
    expect(find.text('POS.'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox());
  });
}
