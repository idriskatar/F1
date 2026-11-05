import 'package:flutter/material.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/jolpica_repository.dart';

/// Takvimden seçilen yarış hafta sonunun sonuçları ve puan durumu.
class RaceDetailScreen extends StatelessWidget {
  const RaceDetailScreen({super.key, required this.weekend, required this.repository, this.clock});

  final RaceWeekend weekend;
  final JolpicaRepository repository;

  /// Testlerde sabit saat vermek için; boşsa `DateTime.now`.
  final DateTime Function()? clock;

  DateTime _now() => (clock ?? DateTime.now)();

  @override
  Widget build(BuildContext context) {
    final season = weekend.season;
    final round = weekend.round;
    final tabs = <(String, Widget)>[
      (
        'Yarış',
        _AsyncTab<JolpicaData<DriverResult>>(
          load: () => repository.raceResults(season, round),
          builder: (context, data) => [
            _SourceLine(cached: data.isCached, updatedAt: data.updatedAt),
            const SizedBox(height: 12),
            if (data.items.isEmpty) ...[
              const _EmptyCard(
                icon: Icons.hourglass_empty,
                title: 'Yarış sonuçları henüz yayımlanmadı',
                subtitle: 'Yarış tamamlandıktan sonra sınıflandırma burada görünür.',
              ),
              const SizedBox(height: 14),
              _SessionsCard(weekend: weekend, now: _now()),
            ] else ...[
              const _Heading('YARIŞ SINIFLANDIRMASI'),
              _Panel(children: [for (final r in data.items) _ResultRow(r)]),
            ],
          ],
        ),
      ),
      (
        'Sıralama',
        _AsyncTab<JolpicaData<QualifyingResult>>(
          load: () => repository.qualifying(season, round),
          builder: (context, data) => [
            _SourceLine(cached: data.isCached, updatedAt: data.updatedAt),
            const SizedBox(height: 12),
            if (data.items.isEmpty)
              const _EmptyCard(
                icon: Icons.hourglass_empty,
                title: 'Sıralama sonuçları henüz yayımlanmadı',
                subtitle: 'Sıralama turları bittikten sonra Q1/Q2/Q3 dereceleri burada görünür.',
              )
            else ...[
              const _Heading('SIRALAMA TURLARI'),
              _Panel(children: [for (final r in data.items) _QualifyingRow(r)]),
            ],
          ],
        ),
      ),
      if (weekend.hasSprint)
        (
          'Sprint',
          _AsyncTab<JolpicaData<DriverResult>>(
            load: () => repository.sprintResults(season, round),
            builder: (context, data) => [
              _SourceLine(cached: data.isCached, updatedAt: data.updatedAt),
              const SizedBox(height: 12),
              if (data.items.isEmpty)
                const _EmptyCard(
                  icon: Icons.hourglass_empty,
                  title: 'Sprint sonuçları henüz yayımlanmadı',
                  subtitle: 'Sprint tamamlandıktan sonra sınıflandırma burada görünür.',
                )
              else ...[
                const _Heading('SPRINT SINIFLANDIRMASI'),
                _Panel(children: [for (final r in data.items) _ResultRow(r)]),
              ],
            ],
          ),
        ),
      (
        'Puan durumu',
        _AsyncTab<(JolpicaData<DriverStanding>, JolpicaData<TeamStanding>)>(
          load: () async {
            final values = await Future.wait<Object>([
              repository.driverStandingsAfter(season, round),
              repository.teamStandingsAfter(season, round),
            ]);
            return (values[0] as JolpicaData<DriverStanding>, values[1] as JolpicaData<TeamStanding>);
          },
          builder: (context, data) {
            final (drivers, teams) = data;
            return [
              _SourceLine(cached: drivers.isCached || teams.isCached, updatedAt: drivers.updatedAt),
              const SizedBox(height: 12),
              if (drivers.items.isEmpty && teams.items.isEmpty)
                const _EmptyCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Bu yarış sonrası puan durumu henüz yok',
                  subtitle: 'Yarış sonuçlandıktan sonra şampiyona sıralaması burada görünür.',
                )
              else ...[
                const _Heading('PİLOTLAR — BU YARIŞTAN SONRA'),
                _Panel(children: [
                  for (final d in drivers.items) _StandingRow(d.position, d.name, d.team, '${d.wins} gal.', d.points),
                ]),
                const SizedBox(height: 20),
                const _Heading('TAKIMLAR — BU YARIŞTAN SONRA'),
                _Panel(children: [
                  for (final t in teams.items) _StandingRow(t.position, t.name, '', '${t.wins} gal.', t.points),
                ]),
              ],
            ];
          },
        ),
      ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(weekend.name, overflow: TextOverflow.ellipsis),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t.$1)],
          ),
        ),
        body: Column(children: [
          _Header(weekend: weekend, now: _now()),
          Expanded(child: TabBarView(children: [for (final t in tabs) t.$2])),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Üst bilgi
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.weekend, required this.now});
  final RaceWeekend weekend;
  final DateTime now;

  ({String text, Color color}) get _status {
    final start = weekend.raceStart;
    if (start == null) return (text: '', color: AppColors.muted);
    final diff = start.difference(now.toUtc());
    if (diff.isNegative) {
      return diff.inHours.abs() < 3 ? (text: 'Yarış sürüyor', color: AppColors.amber) : (text: 'Tamamlandı', color: AppColors.green);
    }
    return (text: diff.inDays >= 1 ? '${diff.inDays} gün kaldı' : 'Bugün', color: AppColors.red);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final place = [
      if (weekend.circuitName.isNotEmpty) weekend.circuitName,
      if (weekend.location.isNotEmpty) weekend.location,
      if (weekend.country.isNotEmpty) weekend.country,
    ].join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TUR ${weekend.round}', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)),
            const SizedBox(height: 3),
            Text(place, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(weekend.dateLabel, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
        if (status.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: status.color.withValues(alpha: 0.5)),
            ),
            child: Text(status.text, style: TextStyle(color: status.color, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Sekme yükleyici (her sekme kendi verisini bir kez çeker, hata/yenileme sunar)
// ---------------------------------------------------------------------------

class _AsyncTab<T> extends StatefulWidget {
  const _AsyncTab({required this.load, required this.builder});
  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data) builder;

  @override
  State<_AsyncTab<T>> createState() => _AsyncTabState<T>();
}

class _AsyncTabState<T> extends State<_AsyncTab<T>> with AutomaticKeepAliveClientMixin {
  late Future<T> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.load());
    try {
      await _future;
    } catch (_) {
      // Hata FutureBuilder tarafından gösterilir.
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<T>(
        future: _future,
        builder: (context, snapshot) {
          final List<Widget> children;
          if (snapshot.connectionState != ConnectionState.done) {
            children = const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))];
          } else if (snapshot.hasError) {
            children = [_ErrorCard(message: '${snapshot.error}', onRetry: _reload)];
          } else {
            children = widget.builder(context, snapshot.data as T);
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: children,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Satırlar
// ---------------------------------------------------------------------------

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.result);
  final DriverResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final subtitle = [
      r.team,
      if (r.grid > 0) 'Grid ${r.grid}',
      if (r.laps > 0) '${r.laps} tur',
    ].join(' • ');
    final showPoints = r.points.isNotEmpty && r.points != '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        SizedBox(width: 28, child: Text(r.position > 0 ? '${r.position}' : '—', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900))),
        Container(width: 3, height: 32, color: Color(r.color)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name.isEmpty ? r.code : r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
            if (r.fastestLapRank == 1 && r.fastestLapTime != null)
              Row(children: [
                const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFB36BFF)),
                const SizedBox(width: 3),
                Text('En hızlı tur ${r.fastestLapTime}', style: const TextStyle(color: Color(0xFFB36BFF), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ]),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(r.time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          if (showPoints) Text('+${r.points} puan', style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _QualifyingRow extends StatelessWidget {
  const _QualifyingRow(this.result);
  final QualifyingResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final stages = [
      if (r.q1.isNotEmpty) 'Q1 ${r.q1}',
      if (r.q2.isNotEmpty) 'Q2 ${r.q2}',
      if (r.q3.isNotEmpty) 'Q3 ${r.q3}',
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        SizedBox(width: 28, child: Text(r.position > 0 ? '${r.position}' : '—', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900))),
        Container(width: 3, height: 32, color: Color(r.color)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name.isEmpty ? r.code : r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(r.team, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
            if (stages.isNotEmpty) Text(stages, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(r.best, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow(this.position, this.name, this.team, this.wins, this.points);
  final int position;
  final String name;
  final String team;
  final String wins;
  final String points;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(children: [
      SizedBox(width: 28, child: Text('$position', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900))),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (team.isNotEmpty) Text(team, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
        ]),
      ),
      Text(wins, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const SizedBox(width: 12),
      SizedBox(width: 42, child: Text(points, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w900))),
    ]),
  );
}

// ---------------------------------------------------------------------------
// Ortak parçalar
// ---------------------------------------------------------------------------

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: children),
  );
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.cached, required this.updatedAt});
  final bool cached;
  final DateTime updatedAt;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(cached ? Icons.offline_pin_outlined : Icons.cloud_done_outlined, size: 14, color: cached ? AppColors.amber : AppColors.green),
    const SizedBox(width: 6),
    Text(
      '${cached ? 'Jolpica önbelleği' : 'Jolpica'} • ${MaterialLocalizationsDate.dayTime(updatedAt.toLocal())}',
      style: const TextStyle(color: AppColors.muted, fontSize: 11),
    ),
  ]);
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Icon(icon, color: AppColors.red),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ])),
    ]),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Veriler yüklenemedi', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(message, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Yeniden dene'))),
    ]),
  );
}

/// Yarış henüz yapılmadıysa hafta sonu programını gösterir.
class _SessionsCard extends StatelessWidget {
  const _SessionsCard({required this.weekend, required this.now});
  final RaceWeekend weekend;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final nowUtc = now.toUtc();
    final sessions = weekend.sessions.where((s) => s.startUtc != null).toList();
    if (sessions.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Heading('HAFTA SONU PROGRAMI'),
      _Panel(children: [
        for (final s in sessions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Icon(
                s.startUtc!.isBefore(nowUtc) ? Icons.check_circle_outline : Icons.schedule,
                size: 16,
                color: s.startUtc!.isBefore(nowUtc) ? AppColors.muted : AppColors.red,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(MaterialLocalizationsDate.dayTime(s.startUtc!.toLocal()), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    ]);
  }
}
