import 'dart:convert';

import 'package:f1_tracker/data/remote/f1_live_pulse_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('finds timing rows nested under data, timingData, and numbered Lines', () async {
    final client = F1LivePulseClient(
      client: MockClient((request) async {
        expect(request.headers['X-RapidAPI-Key'], 'test-key');
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'timingData': {
                'Lines': {
                  '4': {
                    'Position': 1,
                    'Driver': {
                      'FullName': 'Lando NORRIS',
                      'Tla': 'NOR',
                      'TeamName': 'McLaren',
                      'TeamColour': 'FF8000',
                    },
                    'LastLapTime': '1:27.438',
                  },
                },
              },
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);

    final drivers = await client.fetch('test-key');

    expect(drivers, hasLength(1));
    expect(drivers.single.number, '4');
    expect(drivers.single.code, 'NOR');
    expect(drivers.single.team, 'McLaren');
    expect(drivers.single.lapTime, '1:27.438');
  });

  test('explains an unrecognized provider payload without printing the API key', () async {
    final client = F1LivePulseClient(
      client: MockClient((_) async => http.Response('{"status":"idle"}', 200)),
    );
    addTearDown(client.close);

    await expectLater(
      client.fetch('private-test-key'),
      throwsA(isA<F1LivePulseException>().having((error) => error.message, 'message', contains('status'))),
    );
  });
}
