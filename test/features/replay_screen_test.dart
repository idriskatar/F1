import 'dart:convert';
import 'dart:io';

import 'package:f1_tracker/core/models/replay_models.dart';
import 'package:f1_tracker/core/theme/app_theme.dart';
import 'package:f1_tracker/data/remote/replay_repository.dart';
import 'package:f1_tracker/features/replay/replay_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fakes.dart';

ReplayData loadData() => ReplayData.fromJson(
      jsonDecode(File('test/fixtures/replay_sample.json').readAsStringSync()) as Map<String, dynamic>,
    );

const entry = ReplayIndexEntry(
  year: 2099,
  round: 1,
  session: 'R',
  name: 'Test Grand Prix',
  country: 'Testland',
  circuit: 'Ovalville',
  file: '2099/r01-R.json.gz',
  bytes: 1000,
  duration: 60,
  generatedAt: '2026-11-15T12:00:00Z',
);

Widget host(ReplayRepository repository) => MaterialApp(theme: AppTheme.dark, home: ReplayScreen(repository: repository));

/// Listeyi açar, ilk yarışa dokunup oynatıcıyı gösterir.
Future<void> openPlayer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(FakeReplayRepository(index: const ReplayIndex([entry]), data: loadData())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test Grand Prix'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hazır seanslar listelenir ve oynatıcı açılır', (tester) async {
    await openPlayer(tester);

    expect(find.text('Tur 1/3'), findsOneWidget);
    expect(find.text('SIRALAMA'), findsOneWidget);
    expect(find.text('ALPHA'), findsOneWidget); // varsayılan seçili: lider, soyadı büyük harfle
    expect(find.text('KM/SA'), findsOneWidget);
    expect(find.text('RPM'), findsOneWidget);
    for (final label in ['S1', 'S2', 'S3']) {
      expect(find.text(label), findsOneWidget);
    }
    // Lastik simgeleri: AAA (kart + liste) ve DDD SOFT, BBB MEDIUM, CCC HARD
    expect(find.text('S'), findsNWidgets(3));
    expect(find.text('M'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing); // henüz tur bitmedi: en hızlı tur sahibi yok
  });

  testWidgets('harita üstünde tek satırlık hava durumu şeridi görünür ve yağmur başlayınca değişir', (tester) async {
    await openPlayer(tester);

    expect(find.text('Kuru'), findsOneWidget);
    expect(find.text('24°'), findsOneWidget);
    expect(find.text('38°'), findsOneWidget);
    expect(find.text('%52'), findsOneWidget);
    expect(find.text('12 km/sa'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.forward_10_rounded));
    }
    await tester.pumpAndSettle(); // t = 30 sn: yağmur başlar, 1. turlar bitmiş
    expect(find.text('Yağmurlu'), findsOneWidget);
    expect(find.text('Kuru'), findsNothing);
    expect(find.text('39°'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget); // en hızlı tur sahibi simgesi
  });

  testWidgets('hava verisi olmayan dosyada şerit görünmez', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final json = (jsonDecode(File('test/fixtures/replay_sample.json').readAsStringSync()) as Map<String, dynamic>)
      ..remove('weather');
    await tester.pumpWidget(host(FakeReplayRepository(index: const ReplayIndex([entry]), data: ReplayData.fromJson(json))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Grand Prix'));
    await tester.pumpAndSettle();

    expect(find.text('Kuru'), findsNothing);
    expect(find.textContaining('Hava'), findsNothing);
  });

  testWidgets('sıralama listesi pilotları sırayla gösterir', (tester) async {
    await openPlayer(tester);

    for (final code in ['AAA', 'BBB', 'CCC', 'DDD']) {
      expect(find.text(code), findsOneWidget);
    }
  });

  testWidgets('listeden pilot seçmek kartı günceller', (tester) async {
    await openPlayer(tester);

    await tester.tap(find.text('CCC'));
    await tester.pumpAndSettle();
    expect(find.text('CHARLIE'), findsOneWidget);
    expect(find.text('ALPHA'), findsNothing);
  });

  testWidgets('X düğmesi kartı kapatır', (tester) async {
    await openPlayer(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Soldan bir pilot seç'), findsOneWidget);
    expect(find.text('ALPHA'), findsNothing);
  });

  testWidgets('sayfa noktaları hız grafiği ve pit stoplar sayfalarını açar', (tester) async {
    await openPlayer(tester);

    await tester.tap(find.byKey(const Key('replay-dot-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('son 60 sn hız'), findsOneWidget);

    await tester.tap(find.byKey(const Key('replay-dot-2')));
    await tester.pumpAndSettle();
    expect(find.text('BBB · Tur 2'), findsOneWidget);
    expect(find.textContaining('Pit şeridi 5,0 sn'), findsOneWidget);
  });

  testWidgets('oynat düğmesi duraklat düğmesine döner ve zaman ilerler', (tester) async {
    await openPlayer(tester);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('Tur 1/3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('liste boşsa açıklayıcı mesaj gösterilir', (tester) async {
    await tester.pumpWidget(host(FakeReplayRepository(index: const ReplayIndex([]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz hazır replay yok'), findsOneWidget);
  });

  testWidgets('liste alınamazsa hata ve tekrar dene düğmesi görünür', (tester) async {
    await tester.pumpWidget(host(FakeReplayRepository(indexError: const ReplayException('Bağlantı yok'))));
    await tester.pumpAndSettle();
    expect(find.text('Bağlantı yok'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('gömülü (sekme) modda kendi AppBar\'ını çizmez', (tester) async {
    final repo = FakeReplayRepository(index: const ReplayIndex([entry]));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: ReplayScreen(repository: repo, embedded: true)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Test Grand Prix'), findsOneWidget);
    expect(find.textContaining('Yarış 1'), findsOneWidget); // satır altı: "Yarış · 2099 · Yarış 1 · ..."
  });

  testWidgets('sekme açılana kadar (active: false) veri istenmez, açılınca yüklenir', (tester) async {
    final repo = FakeReplayRepository(index: const ReplayIndex([entry]));
    Widget app({required bool active}) => MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: ReplayScreen(repository: repo, embedded: true, active: active)),
        );

    await tester.pumpWidget(app(active: false));
    await tester.pump();
    expect(repo.indexCalls, 0);

    await tester.pumpWidget(app(active: true));
    await tester.pumpAndSettle();
    expect(repo.indexCalls, 1);
    expect(find.text('Test Grand Prix'), findsOneWidget);
  });

  testWidgets('boş listede "Yenile" listeyi yeniden ister', (tester) async {
    final repo = FakeReplayRepository(index: const ReplayIndex([]));
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();
    expect(repo.indexCalls, 1);

    await tester.tap(find.text('Yenile'));
    await tester.pumpAndSettle();
    expect(repo.indexCalls, 2);
  });
}
