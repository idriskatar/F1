import 'package:f1_tracker/core/models/race_models.dart';
import 'package:f1_tracker/core/theme/app_theme.dart';
import 'package:f1_tracker/features/calendar/race_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 1. tur: Fake API'de "yapılmış" tur. Sprint seansı olan hafta sonu.
RaceWeekend pastWeekend({bool sprint = true}) => RaceWeekend.fromJson(raceJson(
      round: 1,
      name: 'Past Grand Prix',
      date: '2026-03-15',
      sessions: {
        if (sprint) 'Sprint': '2026-03-14 11:00:00Z',
        'Qualifying': '2026-03-14 15:00:00Z',
      },
    ));

/// 22. tur: [testNow]'dan sonra, sonuçları henüz yok.
RaceWeekend upcomingWeekend() => RaceWeekend.fromJson(raceJson(
      round: 22,
      name: 'Test Grand Prix',
      date: '2026-11-08',
      sessions: {'FirstPractice': '2026-11-06 11:30:00Z', 'Qualifying': '2026-11-07 15:00:00Z'},
    ));

Future<void> pumpDetail(WidgetTester tester, FakeJolpica api, RaceWeekend weekend) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: RaceDetailScreen(weekend: weekend, repository: api.repository(), clock: () => testNow),
  ));
  await settle(tester);
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text(label)));
  await settle(tester);
}

void main() {
  testWidgets('tamamlanan yarış: üst bilgi, sınıflandırma, grid/tur ve en hızlı tur', (tester) async {
    await pumpDetail(tester, FakeJolpica(), pastWeekend());

    expect(find.text('Past Grand Prix'), findsOneWidget); // AppBar
    expect(find.text('TUR 1'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(find.textContaining('Test Circuit, Testville, Testland'), findsOneWidget);

    expect(find.text('Alex Tester'), findsOneWidget);
    expect(find.text('1:30:00.000'), findsOneWidget);
    expect(find.text('+25 puan'), findsOneWidget);
    expect(find.text('Test Team One • Grid 2 • 57 tur'), findsOneWidget);
    expect(find.text('En hızlı tur 1:23.456'), findsOneWidget);
    expect(find.text('+1 Lap'), findsOneWidget); // süresi olmayan pilot durumu

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Sıralama sekmesi Q1/Q2/Q3 derecelerini gösterir', (tester) async {
    await pumpDetail(tester, FakeJolpica(), pastWeekend());
    await openTab(tester, 'Sıralama');

    expect(find.text('Cara Qualifier'), findsOneWidget);
    expect(find.text('Q1 1:25.100 • Q2 1:24.500 • Q3 1:23.900'), findsOneWidget);
    expect(find.text('1:23.900'), findsOneWidget); // en iyi derece
    expect(find.text('Dan Poleman'), findsOneWidget);
    expect(find.text('1:24.800'), findsOneWidget); // Q3'e kalamayan pilotun en iyisi (Q2)

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sprint hafta sonunda Sprint sekmesi sonuçları gösterir', (tester) async {
    await pumpDetail(tester, FakeJolpica(), pastWeekend());
    await openTab(tester, 'Sprint');

    expect(find.text('Eli Sprinter'), findsOneWidget);
    expect(find.text('+8 puan'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sprint olmayan hafta sonunda Sprint sekmesi yoktur', (tester) async {
    await pumpDetail(tester, FakeJolpica(), pastWeekend(sprint: false));

    expect(find.descendant(of: find.byType(TabBar), matching: find.text('Sprint')), findsNothing);
    expect(find.descendant(of: find.byType(TabBar), matching: find.text('Puan durumu')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Puan durumu sekmesi bu yarıştan sonraki pilot ve takım sıralamasını gösterir', (tester) async {
    final api = FakeJolpica();
    await pumpDetail(tester, api, pastWeekend());
    await openTab(tester, 'Puan durumu');

    expect(api.paths, contains('/ergast/f1/2026/1/driverStandings.json'));
    expect(api.paths, contains('/ergast/f1/2026/1/constructorStandings.json'));
    expect(find.text('301'), findsOneWidget);
    expect(find.text('577'), findsOneWidget);
    expect(find.text('PİLOTLAR — BU YARIŞTAN SONRA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('henüz yapılmamış yarış: sonuç yok mesajı, hafta sonu programı ve kalan gün', (tester) async {
    await pumpDetail(tester, FakeJolpica(), upcomingWeekend());

    expect(find.text('3 gün kaldı'), findsOneWidget);
    expect(find.text('Yarış sonuçları henüz yayımlanmadı'), findsOneWidget);
    expect(find.text('HAFTA SONU PROGRAMI'), findsOneWidget);
    expect(find.text('Antrenman 1'), findsOneWidget);
    expect(find.text('Yarış'), findsNWidgets(2)); // sekme etiketi + program satırı

    await openTab(tester, 'Sıralama');
    expect(find.text('Sıralama sonuçları henüz yayımlanmadı'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('API hatasında sekme hata kartı ve yeniden dene düğmesi gösterir', (tester) async {
    final api = FakeJolpica()..status = 500;
    await pumpDetail(tester, api, pastWeekend());

    expect(find.text('Veriler yüklenemedi'), findsOneWidget);
    expect(find.textContaining('HTTP 500'), findsOneWidget);

    api.status = 200;
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester);

    expect(find.text('Alex Tester'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
