import 'dart:convert';
import 'dart:io';

import 'package:f1_tracker/core/models/replay_models.dart';
import 'package:f1_tracker/core/theme/app_theme.dart';
import 'package:f1_tracker/data/remote/replay_repository.dart';
import 'package:f1_tracker/features/replay/replay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeReplayRepository extends ReplayRepository {
  FakeReplayRepository({this.index, this.data, this.indexError}) : super(useIsolate: false);

  final ReplayIndex? index;
  final ReplayData? data;
  final Object? indexError;

  @override
  Future<ReplayIndex> fetchIndex() async {
    if (indexError != null) throw indexError!;
    return index!;
  }

  @override
  Future<ReplayData> fetchSession(ReplayIndexEntry entry) async => data!;
}

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

void main() {
  testWidgets('hazır seanslar listelenir ve oynatıcı açılır', (tester) async {
    await tester.pumpWidget(host(FakeReplayRepository(index: const ReplayIndex([entry]), data: loadData())));
    await tester.pumpAndSettle();

    expect(find.text('Test Grand Prix'), findsOneWidget);
    await tester.tap(find.text('Test Grand Prix'));
    await tester.pumpAndSettle();

    expect(find.text('Tur 1/3'), findsOneWidget);
    expect(find.text('Telemetri'), findsOneWidget);
    expect(find.textContaining('Test Driver A'), findsOneWidget); // varsayılan seçili: lider
  });

  testWidgets('oynat düğmesi duraklat düğmesine döner ve zaman ilerler', (tester) async {
    await tester.pumpWidget(host(FakeReplayRepository(index: const ReplayIndex([entry]), data: loadData())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Grand Prix'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('Tur 1/3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('pit stoplar sekmesi listeyi gösterir', (tester) async {
    await tester.pumpWidget(host(FakeReplayRepository(index: const ReplayIndex([entry]), data: loadData())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Grand Prix'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pit stoplar'));
    await tester.pumpAndSettle();
    expect(find.text('BBB · Tur 2'), findsOneWidget);
    expect(find.textContaining('Pit şeridi 5,0 sn'), findsOneWidget);
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
}
