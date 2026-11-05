import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/jolpica_repository.dart';
import '../../shared/widgets/section_title.dart';

/// Alt gezinme çubuğundaki sekme indeksleri (AppShell ile aynı sırada).
const _newsTab = 2;
const _resultsTab = 3;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, this.clock, this.onOpenTab});

  final JolpicaRepository repository;

  /// Testlerde sabit saat vermek için; boşsa `DateTime.now`.
  final DateTime Function()? clock;
  final ValueChanged<int>? onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<NextRaceData> _next;
  late Future<JolpicaData<DriverResult>> _results;
  late Future<JolpicaData<DriverStanding>> _drivers;
  late Future<JolpicaData<TeamStanding>> _teams;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = widget.repository;
    _next = repo.nextRace(now: _now());
    _results = repo.latestResults();
    _drivers = repo.driverStandings();
    _teams = repo.teamStandings();
  }

  Future<void> _refresh() async {
    setState(_load);
    // Hatalar ilgili bölümde gösterilir; yenileme göstergesi yine de kapanmalı.
    await Future.wait<Object?>(
      [_next, _results, _drivers, _teams].map((f) => f.then<Object?>((_) => null, onError: (_) => null)),
    );
  }

  void _open(int tab) => widget.onOpenTab?.call(tab);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 30,
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.flag_rounded, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text('F1 TRACKER', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                const Spacer(),
                IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
              ],
            ),
            const SizedBox(height: 18),
            _section<NextRaceData>(
              future: _next,
              errorTitle: 'Sıradaki yarış yüklenemedi',
              builder: (data) => _NextRaceCard(data: data, clock: _now),
            ),
            const SizedBox(height: 24),
            SectionTitle('Son yarış', action: 'Sonuçlar', onAction: () => _open(_resultsTab)),
            const SizedBox(height: 12),
            _section<JolpicaData<DriverResult>>(
              future: _results,
              errorTitle: 'Son yarış sonucu yüklenemedi',
              builder: (data) => _LatestRaceCard(data: data),
            ),
            const SizedBox(height: 22),
            SectionTitle('Şampiyona', action: 'Tümü', onAction: () => _open(_resultsTab)),
            const SizedBox(height: 12),
            _section<JolpicaData<DriverStanding>>(
              future: _drivers,
              errorTitle: 'Pilotlar puan durumu yüklenemedi',
              builder: (data) => _StandingsPanel(
                title: 'PİLOTLAR',
                emptyMessage: 'Bu sezon için puan durumu henüz oluşmadı.',
                rows: [for (final r in data.items.take(3)) _StandingLine(r.position, r.name, r.team, r.points)],
              ),
            ),
            const SizedBox(height: 12),
            _section<JolpicaData<TeamStanding>>(
              future: _teams,
              errorTitle: 'Takımlar puan durumu yüklenemedi',
              builder: (data) => _StandingsPanel(
                title: 'TAKIMLAR',
                emptyMessage: 'Bu sezon için takım puan durumu henüz oluşmadı.',
                rows: [for (final r in data.items.take(3)) _StandingLine(r.position, r.name, '', r.points)],
              ),
            ),
            const SizedBox(height: 22),
            SectionTitle('Son haberler', action: 'Tüm haberler', onAction: () => _open(_newsTab)),
            const SizedBox(height: 12),
            const _InfoTile(
              icon: Icons.newspaper,
              title: 'Haber akışı hazırlanıyor',
              subtitle: 'Ücretsiz RSS kaynakları bağlandığında haberler listelenecek.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _section<T>({
    required Future<T> future,
    required String errorTitle,
    required Widget Function(T data) builder,
  }) =>
      FutureBuilder<T>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const _LoadingTile();
          if (snapshot.hasError) {
            return _InfoTile(icon: Icons.cloud_off_outlined, title: errorTitle, subtitle: '${snapshot.error}');
          }
          return builder(snapshot.data as T);
        },
      );
}

// ---------------------------------------------------------------------------
// Sıradaki yarış
// ---------------------------------------------------------------------------

class _NextRaceCard extends StatelessWidget {
  const _NextRaceCard({required this.data, required this.clock});
  final NextRaceData data;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final race = data.race;
    final start = race?.raceStart;
    final nextSession = race?.nextSession(clock());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF292D36), Color(0xFF15181F), Color(0xFF351412)],
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: race == null || start == null
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SIRADAKİ YARIŞ', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    SizedBox(height: 10),
                    Text('Sezon tamamlandı', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('Yeni sezon takvimi yayımlandığında burada görünecek.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SIRADAKİ YARIŞ', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 10),
                    Text(race.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      '${[
                        if (race.location.isNotEmpty) race.location,
                        if (race.country.isNotEmpty) race.country,
                      ].join(', ')} • Tur ${race.round} • ${race.dateLabel}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    _Countdown(target: start, clock: clock),
                    const SizedBox(height: 18),
                    const Divider(color: AppColors.border),
                    Row(children: [
                      const Icon(Icons.schedule, color: AppColors.red, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nextSession == null || nextSession.startUtc == null
                              ? 'Tüm seanslar başladı'
                              : 'Sıradaki seans: ${nextSession.name} • ${MaterialLocalizationsDate.dayTime(nextSession.startUtc!.toLocal())}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ]),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        _SourceLine(cached: data.isCached, updatedAt: data.updatedAt),
      ],
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.target, required this.clock});
  final DateTime target;
  final DateTime Function() clock;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.target.difference(widget.clock().toUtc());
    final left = remaining.isNegative ? Duration.zero : remaining;
    String two(int v) => v.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CountdownUnit(value: two(left.inDays), label: 'GÜN'),
            _CountdownUnit(value: two(left.inHours % 24), label: 'SAAT'),
            _CountdownUnit(value: two(left.inMinutes % 60), label: 'DK'),
            _CountdownUnit(value: two(left.inSeconds % 60), label: 'SN'),
          ],
        ),
        if (remaining.isNegative)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Yarış başladı', style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(fontSize: 9, color: AppColors.muted, letterSpacing: 1.2)),
  ]);
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
      cached
          ? 'Jolpica önbelleği • ${MaterialLocalizationsDate.dayTime(updatedAt.toLocal())}'
          : 'Jolpica • ${MaterialLocalizationsDate.dayTime(updatedAt.toLocal())}',
      style: const TextStyle(color: AppColors.muted, fontSize: 11),
    ),
  ]);
}

// ---------------------------------------------------------------------------
// Son yarış
// ---------------------------------------------------------------------------

class _LatestRaceCard extends StatelessWidget {
  const _LatestRaceCard({required this.data});
  final JolpicaData<DriverResult> data;

  @override
  Widget build(BuildContext context) {
    final podium = data.items.where((r) => r.position > 0).take(3).toList();
    if (podium.isEmpty) {
      return const _InfoTile(
        icon: Icons.timer_outlined,
        title: 'Henüz yayımlanmış sonuç yok',
        subtitle: 'Jolpica yarış sonucunu yayımladığında burada görünecek.',
      );
    }
    return _Panel(
      title: data.label ?? 'Son yarış',
      footer: data.isCached ? 'Önbellekten gösteriliyor' : null,
      children: [
        for (final r in podium)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(width: 30, child: Text('P${r.position}', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900))),
              Container(width: 3, height: 18, color: Color(r.color)),
              const SizedBox(width: 8),
              SizedBox(width: 44, child: Text(r.code, style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(child: Text(r.team, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 11))),
              Text(r.time, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Şampiyona
// ---------------------------------------------------------------------------

class _StandingLine {
  const _StandingLine(this.position, this.name, this.team, this.points);
  final int position;
  final String name;
  final String team;
  final String points;
}

class _StandingsPanel extends StatelessWidget {
  const _StandingsPanel({required this.title, required this.rows, required this.emptyMessage});
  final String title;
  final List<_StandingLine> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _InfoTile(icon: Icons.emoji_events_outlined, title: title, subtitle: emptyMessage);
    }
    return _Panel(
      title: title,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(width: 26, child: Text('${r.position}', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (r.team.isNotEmpty) Text(r.team, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                ]),
              ),
              Text(r.points, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 4),
              const Text('puan', style: TextStyle(color: AppColors.muted, fontSize: 10)),
            ]),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ortak parçalar
// ---------------------------------------------------------------------------

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children, this.footer});
  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      const SizedBox(height: 4),
      ...children,
      if (footer != null)
        Padding(padding: const EdgeInsets.only(top: 2, bottom: 6), child: Text(footer!, style: const TextStyle(color: AppColors.amber, fontSize: 10))),
    ]),
  );
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();
  @override
  Widget build(BuildContext context) => Container(
    height: 90,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.red)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ])),
    ]),
  );
}
