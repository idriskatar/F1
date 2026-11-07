import 'package:flutter_test/flutter_test.dart';
import 'package:f1_tracker/core/models/live_timing_model.dart';

void main() {
  test('parses the F1 Live Pulse timingData driver shape', () {
    final driver = LiveTimingDriver.fromJson({
      'position': '1',
      'racingNumber': '4',
      'driver': {
        'FullName': 'Lando NORRIS',
        'Tla': 'NOR',
        'TeamName': 'McLaren',
        'TeamColour': 'FF8000',
      },
      'inPit': false,
      'retired': false,
      'stopped': false,
      'compound': 'HARD',
      'bestLapTime': '1:27.438',
    });

    expect(driver.position, 1);
    expect(driver.racingNumber, '4');
    expect(driver.code, 'NOR');
    expect(driver.name, 'Lando NORRIS');
    expect(driver.team, 'McLaren');
    expect(driver.teamColor, 0xFFFF8000);
    expect(driver.compound, 'HARD');
    expect(driver.bestLapTime, '1:27.438');
  });
}
