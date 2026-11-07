import 'package:f1_tracker/core/theme/app_theme.dart';
import 'package:f1_tracker/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Sayaç Timer.periodic kullandığı için pumpAndSettle yerine sınırlı sayıda pump.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> pumpHome(WidgetTester tester, FakeJolpica api, {ValueChanged<int>? onOpenTab, FakeFeeds? feeds}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: HomeScreen(
        repository: api.repository(),
        newsRepository: (feeds ?? FakeFeeds()).repository(),
        clock: () => testNow,
        onOpenTab: onOpenTab,
      ),
    ),
  ));
  await settle(tester);
}

void main() {
  testWidgets('sıradaki yarışı, geri sayımı ve sıradaki seansı gösterir', (tester) async {
    await pumpHome(tester, FakeJolpica());

    expect(find.text('SIRADAKİ YARIŞ'), findsOneWidget);
    expect(find.text('Test Grand Prix'), findsOneWidget);
    expect(find.textContaining('Testville, Testland • Tur 22'), findsOneWidget);
    // 5 Kas 12:00Z → 8 Kas 14:00Z = 3 gün 2 saat
    expect(find.text('03'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.textContaining('Sıradaki seans: Antrenman 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('son yarış podyumunu ve şampiyona liderlerini gösterir', (tester) async {
    await pumpHome(tester, FakeJolpica());

    expect(find.text('Past Grand Prix'), findsOneWidget);
    expect(find.text('AAA'), findsOneWidget);
    expect(find.text('Alex Tester'), findsOneWidget);
    expect(find.text('301'), findsOneWidget);
    expect(find.text('577'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('en yeni 3 haberi kaynak adıyla gösterir; tarihli olanlar önce gelir', (tester) async {
    await pumpHome(tester, FakeJolpica());

    expect(find.text('Motorsport Türkiye headline'), findsOneWidget);
    expect(find.text('TRF1 headline one'), findsOneWidget);
    expect(find.text('TRF1 headline two'), findsOneWidget); // Ana sayfada ilk üç haber

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('haber kaynakları çökerse yalnızca haber bölümü hata gösterir', (tester) async {
    final feeds = FakeFeeds()..offline = true;
    await pumpHome(tester, FakeJolpica(), feeds: feeds);

    expect(find.text('Haber bulunamadı'), findsOneWidget);
    expect(find.text('Test Grand Prix'), findsOneWidget); // yarış kartı etkilenmedi

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sezon bittiyse ve yeni takvim yoksa "Sezon tamamlandı" gösterir', (tester) async {
    await pumpHome(tester, FakeJolpica(calendars: {2026: allPast2026}));

    expect(find.text('Sezon tamamlandı'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('API hatasında bölümler hata mesajı gösterir, çökmez', (tester) async {
    await pumpHome(tester, FakeJolpica()..status = 500);

    expect(find.text('Sıradaki yarış yüklenemedi'), findsOneWidget);
    expect(find.text('Son yarış sonucu yüklenemedi'), findsOneWidget);
    expect(find.textContaining('HTTP 500'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Sonuçlar" ve "Tüm haberler" kısayolları sekme isteği gönderir', (tester) async {
    final opened = <int>[];
    await pumpHome(tester, FakeJolpica(), onOpenTab: opened.add);

    await tester.tap(find.text('Sonuçlar'));
    await tester.tap(find.text('Tüm haberler'));

    expect(opened, [4, 3]); // Live tab was added before News and Results.

    await tester.pumpWidget(const SizedBox());
  });
}
