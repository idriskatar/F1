import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:f1_tracker/core/models/replay_models.dart';
import 'package:f1_tracker/data/remote/replay_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory cacheDir;
  late Uint8List gzipped;
  late String indexJson;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('replay_repo_test');
    gzipped = Uint8List.fromList(gzip.encode(File('test/fixtures/replay_sample.json').readAsBytesSync()));
    indexJson = jsonEncode({
      'version': 1,
      'sessions': [
        {
          'year': 2099, 'round': 1, 'session': 'R', 'name': 'Test Grand Prix', 'country': 'Testland',
          'circuit': 'Ovalville', 'file': '2099/r01-R.json.gz', 'bytes': gzipped.length, 'duration': 60.0,
          'generatedAt': '2026-11-15T12:00:00Z',
        },
      ],
    });
  });

  tearDown(() => cacheDir.deleteSync(recursive: true));

  ReplayRepository build(http.Client client) => ReplayRepository(
        client: client,
        baseUrl: 'https://example.test/replay',
        cacheDirectory: () async => cacheDir,
        useIsolate: false,
      );

  MockClient server({List<String>? log, int sessionStatus = 200}) => MockClient((request) async {
        log?.add(request.url.path);
        if (request.url.path == '/replay/index.json') return http.Response(indexJson, 200);
        if (request.url.path == '/replay/2099/r01-R.json.gz') {
          return sessionStatus == 200 ? http.Response.bytes(gzipped, 200) : http.Response('yok', sessionStatus);
        }
        return http.Response('bulunamadı', 404);
      });

  MockClient offline() => MockClient((request) async => throw const SocketException('çevrimdışı'));

  test('liste ve gzip seans indirilip çözülür', () async {
    final repo = build(server());
    final index = await repo.fetchIndex();
    expect(index.sessions.single.name, 'Test Grand Prix');
    expect(index.isCached, isFalse);

    final data = await repo.fetchSession(index.sessions.single);
    expect(data.drivers.length, 4);
    expect(data.duration, 60);
  });

  test('indirilen seans diskte saklanır ve ağ olmadan açılır', () async {
    final index = await build(server()).fetchIndex();
    await build(server()).fetchSession(index.sessions.single);

    final data = await build(offline()).fetchSession(index.sessions.single);
    expect(data.event.name, 'Test Grand Prix');
  });

  test('ikinci açılışta ağa gidilmez', () async {
    final log = <String>[];
    final repo = build(server(log: log));
    final entry = (await repo.fetchIndex()).sessions.single;
    await repo.fetchSession(entry);
    log.clear();
    await repo.fetchSession(entry);
    expect(log, isEmpty);
  });

  test('ağ yokken liste yerel kopyadan gelir', () async {
    await build(server()).fetchIndex();
    final index = await build(offline()).fetchIndex();
    expect(index.isCached, isTrue);
    expect(index.sessions.length, 1);
  });

  test('ağ yok ve kopya da yoksa anlaşılır hata verilir', () async {
    expect(() => build(offline()).fetchIndex(), throwsA(isA<ReplayException>()));
  });

  test('HTTP hatası ReplayException olur', () async {
    final repo = build(server(sessionStatus: 404));
    final entry = (await repo.fetchIndex()).sessions.single;
    expect(() => repo.fetchSession(entry), throwsA(isA<ReplayException>()));
  });

  test('bozuk önbellek dosyası yeniden indirilir', () async {
    final repo = build(server());
    final entry = (await repo.fetchIndex()).sessions.single;
    File('${cacheDir.path}/${entry.cacheName}.json.gz').writeAsBytesSync([1, 2, 3, 4]);
    final data = await repo.fetchSession(entry);
    expect(data.drivers.length, 4);
  });

  test('düz (sıkıştırılmamış) JSON da okunur', () {
    final data = decodeReplayBytes(Uint8List.fromList(File('test/fixtures/replay_sample.json').readAsBytesSync()));
    expect(data.totalLaps, 3);
  });
}
