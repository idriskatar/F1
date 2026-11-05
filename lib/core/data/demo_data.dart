import '../models/race_models.dart';

/// UI fixtures only. These are NOT verified 2026 race data or official results.
const demoWeekend = RaceWeekend(
  name: 'Grand Prix Weekend',
  location: 'Race location',
  country: 'Race country',
  dateLabel: 'Schedule will load from Jolpica',
  round: 0,
  sessions: [
    RaceSession(name: 'Practice 1', localTime: '--:--', status: SessionStatus.upcoming),
    RaceSession(name: 'Practice 2', localTime: '--:--', status: SessionStatus.upcoming),
    RaceSession(name: 'Practice 3', localTime: '--:--', status: SessionStatus.upcoming),
    RaceSession(name: 'Qualifying', localTime: '--:--', status: SessionStatus.upcoming),
    RaceSession(name: 'Race', localTime: '--:--', status: SessionStatus.upcoming),
  ],
);

const demoResults = [
  DriverResult(position: 1, code: 'VER', team: 'Example Team', time: '—', color: 0xFF3671C6),
  DriverResult(position: 2, code: 'NOR', team: 'Example Team', time: '—', color: 0xFFFF8000),
  DriverResult(position: 3, code: 'LEC', team: 'Example Team', time: '—', color: 0xFFE8002D),
  DriverResult(position: 4, code: 'PIA', team: 'Example Team', time: '—', color: 0xFFFF8000),
  DriverResult(position: 5, code: 'HAM', team: 'Example Team', time: '—', color: 0xFFE8002D),
];

const demoNewsTitles = [
  'Race weekend briefing',
  'Technical updates to watch',
  'The latest paddock headlines',
];
