import 'package:f1_tracker/core/theme/app_theme.dart';
import 'package:f1_tracker/features/news/news_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpNews(
  WidgetTester tester,
  FakeFeeds feeds, {
  Future<bool> Function(String url)? onOpenUrl,
}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: NewsScreen(repository: feeds.repository(), onOpenUrl: onOpenUrl)),
  ));
  await settle(tester);
}

void main() {
  testWidgets('tüm kaynaklardan haberleri, özetleri ve kaynak adlarını gösterir', (tester) async {
    await pumpNews(tester, FakeFeeds());

    expect(find.text('Motorsport Türkiye headline'), findsOneWidget);
    expect(find.text('TRF1 headline one'), findsOneWidget);
    expect(find.text('TRF1.NET'), findsNWidgets(2));
    expect(find.text('MOTORSPORT.COM TÜRKİYE'), findsOneWidget);
    expect(find.textContaining('RSS akışlarından alınır'), findsOneWidget);
  });

  testWidgets('kaynak filtresi yalnızca seçilen kaynağın haberlerini bırakır', (tester) async {
    await pumpNews(tester, FakeFeeds());

    await tester.tap(find.widgetWithText(ChoiceChip, 'TRF1.net'));
    await tester.pump();

    expect(find.text('TRF1 headline one'), findsOneWidget);
    expect(find.text('Motorsport Türkiye headline'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tümü'));
    await tester.pump();
    expect(find.text('Motorsport Türkiye headline'), findsOneWidget);
  });

  testWidgets('habere dokununca orijinal bağlantı açılır', (tester) async {
    final opened = <String>[];
    await pumpNews(tester, FakeFeeds(), onOpenUrl: (url) async {
      opened.add(url);
      return true;
    });

    await tester.tap(find.text('Motorsport Türkiye headline'));
    await tester.pump();

    expect(opened, ['https://tr.motorsport.com/f1/news/ornek-haber/']);
  });

  testWidgets('bağlantı açılamazsa uyarı gösterir', (tester) async {
    await pumpNews(tester, FakeFeeds(), onOpenUrl: (_) async => false);

    await tester.tap(find.text('Motorsport Türkiye headline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bağlantı açılamadı'), findsOneWidget);
  });

  testWidgets('bir kaynak çökerse diğer haberler gösterilir, uyarı o kaynağı adlandırır', (tester) async {
    await pumpNews(tester, FakeFeeds()..failingHosts.add('trf1.net'));

    expect(find.textContaining('TRF1.net güncellenemedi'), findsOneWidget);
    expect(find.text('Motorsport Türkiye headline'), findsOneWidget);
    expect(find.text('TRF1 headline one'), findsNothing);
  });

  testWidgets('tüm kaynaklar çökerse her biri için uyarı gösterir, çökmez', (tester) async {
    await pumpNews(tester, FakeFeeds()..offline = true);

    expect(find.textContaining('TRF1.net güncellenemedi'), findsOneWidget);
    expect(find.textContaining('Motorsport.com Türkiye güncellenemedi'), findsOneWidget);
  });
}
