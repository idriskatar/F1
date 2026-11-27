import 'dart:async';

import 'package:material_ui/material_ui.dart';
import '../../core/models/news_models.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/jolpica_repository.dart';
import '../../data/remote/news_repository.dart';
import '../../shared/open_url.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/responsive.dart';

/// Alt gezinme çubuğundaki sekme indeksleri (AppShell ile aynı sırada).
const _newsTab = 2;
const _resultsTab = 3;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, required this.newsRepository, this.clock, this.onOpenTab});

  final JolpicaRepository repository;
  final NewsRepository newsRepository;

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
  late Future<NewsFeedResult> _news;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _load() {
    final repo = widget.repository;
    _next = repo.nextRace(now: _now());
    _results = repo.latestResults();
    _drivers = repo.driverStandings();
    _teams = repo.teamStandings();
    _news = widget.newsRepository.fetchAll();
  }

  Future<void> _refresh() async {
    setState(_load);
    // Hatalar ilgili bölümde gösterilir; yenileme göstergesi yine de kapanmalı.
    await Future.wait<Object?>(
      [_next, _results, _drivers, _teams, _news].map((f) => f.then<Object?>((_) => null, onError: (_) => null)),
    );
  }

  void _open(int tab) => widget.onOpenTab?.call(tab);

  /// Ana sayfadaki haber doğrudan kaynağında açılır; Haberler sekmesine gidilmez.
  Future<void> _openNews(NewsItem item) async {
    var opened = false;
    try {
      opened = await openExternalUrl(item.url);
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: desktop
              ? const EdgeInsets.fromLTRB(24, 16, 24, 24)
              : const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: desktop ? _desktopChildren() : _mobileChildren(),
        ),
      ),
    );
  }

  List<Widget> _mobileChildren() => [
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
        _section<NewsFeedResult>(
          future: _news,
          errorTitle: 'Haberler yüklenemedi',
          builder: (data) => _NewsPreview(data: data, onTap: _openNews),
        ),
      ];

  /// Masaüstünde: küçük sıradaki yarış kartı, son yarış, yan yana puan
  /// durumları ve altta iki sütunlu haber önizlemesi.
  List<Widget> _desktopChildren() {
    final year = _now().year;
    return [
      SectionTitle('Yarışlar', action: 'Sonuçlar', onAction: () => _open(_resultsTab)),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _section<NextRaceData>(
            future: _next,
            errorTitle: 'Sıradaki yarış yüklenemedi',
            builder: (data) => _CompactNextRaceCard(data: data, clock: _now),
          )),
          const SizedBox(width: 14),
          Expanded(child: _section<JolpicaData<DriverResult>>(
            future: _results,
            errorTitle: 'Son yarış sonucu yüklenemedi',
            builder: (data) => _LatestRaceSideCard(data: data),
          )),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _section<JolpicaData<DriverStanding>>(
              future: _drivers,
              errorTitle: 'Pilotlar puan durumu yüklenemedi',
              builder: (data) => _StandingsTable(
                title: '$year Pilotlar Şampiyonası',
                columnLabel: 'PİLOT',
                showAllLabel: 'Tümünü göster',
                rows: [for (final r in data.items.take(10)) _StandingRowData(r.position, r.name, r.points, _teamColorForName(r.team))],
                onShowAll: () => _open(_resultsTab),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _section<JolpicaData<TeamStanding>>(
              future: _teams,
              errorTitle: 'Takımlar puan durumu yüklenemedi',
              builder: (data) => _StandingsTable(
                title: '$year Takımlar Şampiyonası',
                columnLabel: 'TAKIM',
                showAllLabel: 'Tümünü göster',
                rows: [for (final r in data.items.take(10)) _StandingRowData(r.position, r.name, r.points, _teamColorForName(r.name))],
                onShowAll: () => _open(_resultsTab),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      SectionTitle('Son haberler', action: 'Tüm haberler', onAction: () => _open(_newsTab)),
      const SizedBox(height: 12),
      _section<NewsFeedResult>(
        future: _news,
        errorTitle: 'Haberler yüklenemedi',
        builder: (data) => _NewsPreviewGrid(data: data, onTap: _openNews),
      ),
    ];
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
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: AppColors.themeId == 'light'
                  ? [const Color(0xFFFFFFFF), const Color(0xFFF5F6F9), const Color(0xFFFFF0EE)]
                  : [const Color(0xFF292D36), const Color(0xFF15181F), const Color(0xFF351412)],
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: race == null || start == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SIRADAKİ YARIŞ', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 10),
                    const Text('Sezon tamamlandı', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Yeni sezon takvimi yayımlandığında burada görünecek.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SIRADAKİ YARIŞ', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 10),
                    Text(race.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      '${[
                        if (race.location.isNotEmpty) race.location,
                        if (race.country.isNotEmpty) race.country,
                      ].join(', ')} • Tur ${race.round} • ${race.dateLabel}',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    _Countdown(target: start, clock: clock),
                    const SizedBox(height: 18),
                    Divider(color: AppColors.border),
                    Row(children: [
                      Icon(Icons.schedule, color: AppColors.red, size: 17),
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

/// Masaüstünde son yarış, sıradaki yarışın yanında daha dar bir kartta gösterilir.
class _LatestRaceSideCard extends StatelessWidget {
  const _LatestRaceSideCard({required this.data});
  final JolpicaData<DriverResult> data;

  @override
  Widget build(BuildContext context) {
    final podium = data.items.where((r) => r.position > 0).take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: podium.isEmpty
          ? const _InfoTile(
              icon: Icons.timer_outlined,
              title: 'Henüz yayımlanmış sonuç yok',
              subtitle: 'Jolpica yarış sonucunu yayımladığında burada görünecek.',
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SON YARIŞ', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.4)),
              const SizedBox(height: 6),
              Text(data.label ?? 'Son yarış', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              for (final r in podium)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    SizedBox(width: 28, child: Text('P${r.position}', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 11))),
                    Container(width: 3, height: 17, color: Color(r.color)),
                    const SizedBox(width: 7),
                    SizedBox(width: 40, child: Text(r.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                    Expanded(child: Text(r.team, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 11))),
                    Text(r.time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                  ]),
                ),
            ]),
    );
  }
}

/// Masaüstünde "Sıradaki yarış" kartı: aynı veriyi tek satırda, daha az yerle gösterir.
class _CompactNextRaceCard extends StatelessWidget {
  const _CompactNextRaceCard({required this.data, required this.clock});
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: race == null || start == null
              ? Row(children: [
                  Icon(Icons.flag_rounded, color: AppColors.red, size: 17),
                  const SizedBox(width: 10),
                  Text('SIRADAKİ YARIŞ', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.4)),
                  const Spacer(),
                  Text('Sezon tamamlandı', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.flag_rounded, color: AppColors.red, size: 15),
                    const SizedBox(width: 8),
                    Text('SIRADAKİ YARIŞ', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.4)),
                    const Spacer(),
                    Text(race.dateLabel, style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  ]),
                  const SizedBox(height: 6),
                  Text(race.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: Text(
                      '${[race.location, race.country].where((s) => s.isNotEmpty).join(', ')} • Tur ${race.round}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                      child: _Countdown(target: start, clock: clock, compact: true),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.schedule, color: AppColors.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      nextSession == null || nextSession.startUtc == null
                          ? 'Tüm seanslar başladı'
                          : 'Sıradaki seans: ${nextSession.name} • ${MaterialLocalizationsDate.dayTime(nextSession.startUtc!.toLocal())}',
                      style: const TextStyle(fontSize: 11),
                    )),
                  ]),
                ]),
        ),
        const SizedBox(height: 6),
        _SourceLine(cached: data.isCached, updatedAt: data.updatedAt),
      ],
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.target, required this.clock, this.compact = false});
  final DateTime target;
  final DateTime Function() clock;

  /// Masaüstünde daha küçük yazı ve sıkı aralık kullanılır.
  final bool compact;

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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CountdownUnit(value: two(left.inDays), label: 'GÜN', compact: widget.compact),
            _CountdownUnit(value: two(left.inHours % 24), label: 'SAAT', compact: widget.compact),
            _CountdownUnit(value: two(left.inMinutes % 60), label: 'DK', compact: widget.compact),
            _CountdownUnit(value: two(left.inSeconds % 60), label: 'SN', compact: widget.compact),
          ],
        ),
        if (remaining.isNegative)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Yarış başladı', style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({required this.value, required this.label, this.compact = false});
  final String value;
  final String label;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: compact ? 15 : 26, fontWeight: FontWeight.w900)),
    Text(label, style: TextStyle(fontSize: compact ? 8 : 9, color: AppColors.muted, letterSpacing: compact ? 0.8 : 1.2)),
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
      style: TextStyle(color: AppColors.muted, fontSize: 11),
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
              SizedBox(width: 30, child: Text('P${r.position}', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900))),
              Container(width: 3, height: 18, color: Color(r.color)),
              const SizedBox(width: 8),
              SizedBox(width: 44, child: Text(r.code, style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(child: Text(r.team, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 11))),
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

/// Takım adından puan durumu tablosunda kullanılacak marka rengini çıkarır.
Color _teamColorForName(String name) {
  final n = name.toLowerCase();
  if (n.contains('mercedes')) return const Color(0xFF27F4D2);
  if (n.contains('ferrari')) return const Color(0xFFE8002D);
  if (n.contains('red bull')) return const Color(0xFF3671C6);
  if (n.contains('mclaren')) return const Color(0xFFFF8000);
  if (n.contains('aston martin')) return const Color(0xFF229971);
  if (n.contains('alpine')) return const Color(0xFFFF87BC);
  if (n.contains('williams')) return const Color(0xFF64C4FF);
  if (n.contains('racing bulls') || n.contains('rb')) return const Color(0xFF6692FF);
  if (n.contains('haas')) return const Color(0xFFB6BABD);
  if (n.contains('audi') || n.contains('sauber')) return const Color(0xFF52E252);
  return const Color(0xFF9AA0AA);
}

class _StandingRowData {
  const _StandingRowData(this.position, this.name, this.points, this.color);
  final int position;
  final String name;
  final String points;
  final Color color;
}

/// Masaüstündeki puan durumu tablosu: POS / pilot-takım / puan / EVO.
class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.title, required this.columnLabel, required this.rows, required this.showAllLabel, this.onShowAll});

  final String title;
  final String columnLabel;
  final List<_StandingRowData> rows;
  final String showAllLabel;
  final VoidCallback? onShowAll;

  TextStyle get _headerStyle => TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1);

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              SizedBox(width: 32, child: Text('SIRA', style: _headerStyle)),
              Expanded(child: Text(columnLabel, style: _headerStyle)),
              SizedBox(width: 46, child: Text('PUAN', style: _headerStyle, textAlign: TextAlign.right)),
              const SizedBox(width: 6),
              SizedBox(width: 48, child: Text('DEĞİŞİM', style: _headerStyle.copyWith(fontSize: 8.5, letterSpacing: 0), textAlign: TextAlign.right)),
            ]),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Bu sezon için puan durumu henüz oluşmadı.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            )
          else
            for (final row in rows) _StandingsRow(row: row),
          InkWell(
            onTap: onShowAll,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Text(showAllLabel, style: TextStyle(color: onShowAll == null ? AppColors.muted : AppColors.red, fontWeight: FontWeight.w800, fontSize: 12)),
                const Spacer(),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: (onShowAll == null ? AppColors.muted : AppColors.red).withValues(alpha: .45))),
                  child: Icon(Icons.arrow_forward, size: 12, color: onShowAll == null ? AppColors.muted : AppColors.red),
                ),
              ]),
            ),
          ),
        ]),
      );
}

class _StandingsRow extends StatelessWidget {
  const _StandingsRow({required this.row});
  final _StandingRowData row;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: .6)))),
        child: Row(children: [
          SizedBox(width: 32, child: Text('${row.position}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          Container(width: 3, height: 17, color: row.color),
          const SizedBox(width: 8),
          Expanded(child: Text(row.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          const SizedBox(width: 6),
          SizedBox(width: 46, child: Text(row.points, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          const SizedBox(width: 6),
          SizedBox(width: 48, child: Text('—', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 11))),
        ]),
      );
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
              SizedBox(width: 26, child: Text('${r.position}', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (r.team.isNotEmpty) Text(r.team, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 11)),
                ]),
              ),
              Text(r.points, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 4),
              Text('puan', style: TextStyle(color: AppColors.muted, fontSize: 10)),
            ]),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Son haberler
// ---------------------------------------------------------------------------

class _NewsPreview extends StatelessWidget {
  const _NewsPreview({required this.data, required this.onTap});
  final NewsFeedResult data;
  final void Function(NewsItem) onTap;

  @override
  Widget build(BuildContext context) {
    final items = data.items.take(3).toList();
    if (items.isEmpty) {
      return _InfoTile(
        icon: Icons.newspaper,
        title: 'Haber bulunamadı',
        subtitle: data.errors.isEmpty ? 'Kaynaklar şu an haber döndürmedi.' : data.errors.values.first,
      );
    }
    return _Panel(
      title: 'EN YENİ HABERLER',
      children: [for (final item in items) _NewsPreviewItem(item: item, onTap: onTap)],
    );
  }
}

/// Ana sayfadaki tek haber satırı; mobil panel ve masaüstü 2 sütunlu ızgara aynı öğeyi kullanır.
class _NewsPreviewItem extends StatelessWidget {
  const _NewsPreviewItem({required this.item, required this.onTap});
  final NewsItem item;
  final void Function(NewsItem) onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onTap(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              item.publishedAt == null
                  ? item.sourceName
                  : '${item.sourceName} • ${MaterialLocalizationsDate.dayTime(item.publishedAt!.toLocal())}',
              style: TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
          ]),
        ),
      );
}

/// Masaüstünde haber önizlemesi: en yeni 4 haber iki sütuna bölünür.
class _NewsPreviewGrid extends StatelessWidget {
  const _NewsPreviewGrid({required this.data, required this.onTap});
  final NewsFeedResult data;
  final void Function(NewsItem) onTap;

  @override
  Widget build(BuildContext context) {
    final items = data.items.take(4).toList();
    if (items.isEmpty) {
      return _InfoTile(
        icon: Icons.newspaper,
        title: 'Haber bulunamadı',
        subtitle: data.errors.isEmpty ? 'Kaynaklar şu an haber döndürmedi.' : data.errors.values.first,
      );
    }
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final card = Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: _NewsPreviewItem(item: items[i], onTap: onTap),
      );
      (i.isEven ? left : right).add(card);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: left)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: right)),
    ]);
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
      Text(title, style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      const SizedBox(height: 4),
      ...children,
      if (footer != null)
        Padding(padding: const EdgeInsets.only(top: 2, bottom: 6), child: Text(footer!, style: TextStyle(color: AppColors.amber, fontSize: 10))),
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
        Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 11)),
      ])),
    ]),
  );
}
