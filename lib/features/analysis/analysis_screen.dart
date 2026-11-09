import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/session_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/openf1_repository.dart';
import '../../shared/open_url.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, required this.repository, required this.active});

  final OpenF1Repository repository;
  final bool active;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  Future<CompletedSessionData?>? _analysis;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant AnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _load();
  }

  void _load({bool force = false}) {
    _analysis = widget.repository.fetchLatest(force: force);
  }

  Future<void> _refresh() async {
    final future = widget.repository.fetchLatest(force: true);
    setState(() => _analysis = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the source error and retry control.
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('YARIŞ ANALİZİ', style: TextStyle(color: AppColors.red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                    const SizedBox(height: 3),
                    Text('Analiz', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  ]),
                ),
                IconButton(onPressed: _refresh, tooltip: 'Verileri yenile', icon: const Icon(Icons.refresh_rounded)),
              ]),
              const SizedBox(height: 10),
              if (_analysis == null)
                const _StateCard(label: 'Son tamamlanan yarış verileri yükleniyor…', loading: true)
              else
                FutureBuilder<CompletedSessionData?>(
                  future: _analysis,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _StateCard(label: 'OpenF1’dan geçmiş yarış verileri alınıyor…', loading: true);
                    }
                    if (snapshot.hasError) {
                      return _StateCard(
                        label: 'Yarış verileri yüklenemedi: ${snapshot.error}',
                        icon: Icons.cloud_off_outlined,
                        onRetry: _refresh,
                      );
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return _StateCard(
                        label: 'Tamamlanmış yarış sonucu bulunamadı. OpenF1 verisi yarıştan sonra yayımlanabilir.',
                        icon: Icons.event_busy_outlined,
                        onRetry: _refresh,
                      );
                    }
                    return _AnalysisContent(data: data);
                  },
                ),
            ],
          ),
        ),
      );
}

class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) {
    final podium = data.podium;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _RaceHero(data: data),
      const SizedBox(height: 12),
      _ResultsSection(data: data),
      const SizedBox(height: 12),
      _LapSection(data: data),
      const SizedBox(height: 12),
      _GapSection(data: data),
      const SizedBox(height: 12),
      _TelemetrySection(data: data),
      const SizedBox(height: 12),
      _StrategySection(data: data),
      const SizedBox(height: 12),
      _WeatherSection(data: data),
      if (data.unavailableSections.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.info_outline_rounded,
          title: 'Eksik API bölümleri',
          subtitle: 'OpenF1 bazı alanları bu seans için döndürmedi. Eksikler örnek veriyle doldurulmadı.',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final item in data.unavailableSections) _Tag(item)],
          ),
        ),
      ],
      const SizedBox(height: 10),
      Row(children: [
        Icon(data.isCached ? Icons.offline_pin_outlined : Icons.cloud_done_outlined, size: 14, color: data.isCached ? AppColors.amber : AppColors.green),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            data.isCached
                ? 'OpenF1 önbelleği • ${_dateTime(data.updatedAt.toLocal())}'
                : 'Gerçek OpenF1 verisi • cihaz saatine göre ${_dateTime(data.updatedAt.toLocal())}',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ),
        Text('${podium.length} pilot telemetrisi', style: TextStyle(color: AppColors.muted, fontSize: 10)),
      ]),
    ]);
  }
}

class _RaceHero extends StatelessWidget {
  const _RaceHero({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) {
    final winner = data.podium.firstOrNull;
    final date = data.dateEnd.toLocal();
    final subtitle = [if (data.circuitName.isNotEmpty) data.circuitName, if (data.countryName.isNotEmpty) data.countryName].join(' • ');
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.themeId == 'light'
              ? [const Color(0xFFFFFFFF), const Color(0xFFFFF1EF), const Color(0xFFF0F3F7)]
              : [const Color(0xFF2A1A1B), const Color(0xFF16191F), const Color(0xFF101217)],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SON TAMAMLANAN YARIŞ', style: TextStyle(color: AppColors.red, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 5),
              Text(data.meetingName.isEmpty ? data.circuitName : data.meetingName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle.isEmpty ? data.sessionName : '$subtitle • ${data.sessionName}', style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ]),
          ),
          if (data.isCached) Icon(Icons.offline_pin_outlined, color: AppColors.amber),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.event_outlined, size: 14, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(_dateTime(date), style: TextStyle(color: AppColors.muted, fontSize: 10)),
          const Spacer(),
          if (data.standings.isNotEmpty) _Tag('${data.standings.first.laps} TUR'),
        ]),
        const SizedBox(height: 13),
        if (winner != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: .72), borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.red.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.emoji_events_rounded, color: AppColors.red, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('YARIŞ GALİBİ', style: TextStyle(color: AppColors.muted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text('${winner.driverName}  ·  ${winner.driverCode}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                Text(winner.teamName, style: TextStyle(color: AppColors.muted, fontSize: 10)),
              ])),
              Text(winner.resultSeconds == null ? winner.gapToLeader : _duration(winner.resultSeconds!), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
            ]),
          ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text('PİST GEOMETRİSİ', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
          Text('İlk tur GPS izi', style: TextStyle(color: AppColors.muted, fontSize: 9)),
        ]),
        const SizedBox(height: 7),
        Container(
          height: 156,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: .56), borderRadius: BorderRadius.circular(16)),
          child: _TrackMap(data: data),
        ),
        const SizedBox(height: 6),
        Text(
          _isInterlagos(data.circuitName) ? 'Pist şekli Formula1.com görselinden alınır; GPS izi yedek çizimdir.' : 'Pist şekli ilk üç pilotun ilk tur GPS izinden çizilir.',
          style: TextStyle(color: AppColors.muted, fontSize: 8),
        ),
        if (_isInterlagos(data.circuitName))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await openExternalUrl('https://www.formula1.com/en/racing/2026/brazil');
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 12),
              label: const Text('Formula1.com pist profili'),
            ),
          ),
      ]),
    );
  }
}

class _TrackMap extends StatelessWidget {
  const _TrackMap({required this.data});
  final CompletedSessionData data;

  static const _interlagosOfficialImage =
      'https://media.formula1.com/image/upload/c_fit%2Ch_704/q_auto/v1740000001/common/f1/2026/track/2026trackinterlagosdetailed.webp';

  @override
  Widget build(BuildContext context) {
    if (_isInterlagos(data.circuitName)) {
      return Image.network(
        _interlagosOfficialImage,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _gpsMap(),
      );
    }
    return _gpsMap();
  }

  Widget _gpsMap() {
    if (data.trackTraces.isEmpty) {
      return Center(child: Text('Bu yarış için pist konumu yayımlanmadı.', style: TextStyle(color: AppColors.muted, fontSize: 11)));
    }
    return CustomPaint(painter: _TrackPainter(data.trackTraces), child: const SizedBox.expand());
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) {
    final podium = data.podium;
    return _SectionCard(
      icon: Icons.emoji_events_outlined,
      title: 'Yarış sonucu',
      subtitle: 'Podyum, finiş farkı ve tam klasman',
      trailing: _Tag('${data.standings.length} pilot'),
      child: Column(children: [
        if (podium.isNotEmpty)
          Row(children: [
            for (final row in podium)
              Expanded(child: _PodiumTile(row: row, color: _driverColor(data, row.driverNumber))),
          ]),
        const SizedBox(height: 8),
        for (final row in data.standings.skip(3).take(7)) _ResultRow(row: row),
        if (data.standings.length > 10)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('Tüm sonuçlar (${data.standings.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              children: [for (final row in data.standings.skip(10)) _ResultRow(row: row)],
            ),
          ),
      ]),
    );
  }
}

class _PodiumTile extends StatelessWidget {
  const _PodiumTile({required this.row, required this.color});
  final SessionStanding row;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.fromLTRB(8, 9, 5, 9),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(13), border: Border(top: BorderSide(color: color, width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('P${row.position}', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(row.driverCode, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          Text(row.driverName.split(' ').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 9)),
          const SizedBox(height: 4),
          Text(row.position == 1 ? 'GALİP' : row.gapToLeader, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 8, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.row});
  final SessionStanding row;

  @override
  Widget build(BuildContext context) {
    final status = row.dns ? 'DNS' : row.dsq ? 'DSQ' : row.dnf ? 'DNF' : row.gapToLeader;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 28, child: Text(row.position > 0 ? '${row.position}' : '—', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10))),
        Expanded(child: Text('${row.driverCode}  ${row.driverName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
        SizedBox(width: 45, child: Text('${row.laps} tur', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 9))),
        SizedBox(width: 70, child: Text(status, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: row.dnf || row.dns || row.dsq ? AppColors.amber : AppColors.muted, fontSize: 9))),
      ]),
    );
  }
}

class _LapSection extends StatelessWidget {
  const _LapSection({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) {
    final podium = data.podium;
    final fastest = data.laps.where((lap) => lap.durationSeconds != null && !lap.pitOut).fold<LapRecord?>(null, (best, lap) {
      if (best == null || lap.durationSeconds! < best.durationSeconds!) return lap;
      return best;
    });
    final series = [
      for (final driver in podium)
        _ChartSeries(
          label: driver.driverCode,
          color: _driverColor(data, driver.driverNumber),
          values: data.lapsFor(driver.driverNumber).where((lap) => !lap.pitOut && lap.durationSeconds != null).map((lap) => lap.durationSeconds!).toList(),
        ),
    ];
    return _SectionCard(
      icon: Icons.timer_outlined,
      title: 'Tur kayıtları',
      subtitle: 'Podyum pilotlarının tur temposu ve sektör dereceleri',
      trailing: _Tag('${data.laps.length} kayıt'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (fastest != null) ...[
          _HighlightLine(
            label: 'En hızlı tur  ·  ${_driverCode(data, fastest.driverNumber)}  ·  Tur ${fastest.lapNumber}',
            value: _duration(fastest.durationSeconds!),
          ),
          const SizedBox(height: 12),
        ],
        if (series.any((item) => item.values.length > 1))
          _ComparisonChart(series: series, lowerIsBetter: true, leftLabel: 'daha hızlı', rightLabel: 'daha yavaş')
        else
          _EmptyInline(text: data.laps.isEmpty ? 'OpenF1 tur kaydı döndürmedi.' : 'Tur temposu grafiği için yeterli kayıt yok.'),
        const SizedBox(height: 10),
        for (final driver in podium.take(3))
          _DriverLapLine(data: data, driver: driver),
        if (data.laps.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('Tüm tur kayıtları (${data.laps.length})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              children: [for (final lap in data.laps) _LapRecordLine(data: data, lap: lap)],
            ),
          ),
      ]),
    );
  }
}

class _LapRecordLine extends StatelessWidget {
  const _LapRecordLine({required this.data, required this.lap});
  final CompletedSessionData data;
  final LapRecord lap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 54, child: Text('${_driverCode(data, lap.driverNumber)}  L${lap.lapNumber}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800))),
          Expanded(child: Text(_duration(lap.durationSeconds), style: const TextStyle(fontSize: 8))),
          Text('S1 ${_duration(lap.sector1)}  S2 ${_duration(lap.sector2)}  S3 ${_duration(lap.sector3)}', style: TextStyle(color: AppColors.muted, fontSize: 7)),
        ]),
      );
}

class _DriverLapLine extends StatelessWidget {
  const _DriverLapLine({required this.data, required this.driver});
  final CompletedSessionData data;
  final SessionStanding driver;

  @override
  Widget build(BuildContext context) {
    final laps = data.lapsFor(driver.driverNumber).where((lap) => !lap.pitOut && lap.durationSeconds != null).toList();
    if (laps.isEmpty) return const SizedBox.shrink();
    final best = laps.reduce((a, b) => a.durationSeconds! < b.durationSeconds! ? a : b);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(width: 4, height: 31, decoration: BoxDecoration(color: _driverColor(data, driver.driverNumber), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${driver.driverCode}  ·  en hızlı ${_duration(best.durationSeconds!)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          Text('S1 ${_duration(best.sector1)}   S2 ${_duration(best.sector2)}   S3 ${_duration(best.sector3)}', style: TextStyle(color: AppColors.muted, fontSize: 9)),
        ])),
        if (best.speedTrap != null) Text('${best.speedTrap!.round()} km/sa', style: TextStyle(color: AppColors.muted, fontSize: 9)),
      ]),
    );
  }
}

class _GapSection extends StatelessWidget {
  const _GapSection({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) {
    final series = [
      for (final driver in data.podium)
        _ChartSeries(
          label: driver.driverCode,
          color: _driverColor(data, driver.driverNumber),
          values: _gapValues(data.gapsFor(driver.driverNumber)),
        ),
    ];
    return _SectionCard(
      icon: Icons.compare_arrows_rounded,
      title: 'Aralıklar',
      subtitle: 'Yarış boyunca lider farkı ve finiş aralığı',
      trailing: _Tag('${data.gaps.length} kayıt'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (series.any((item) => item.values.length > 1))
          _ComparisonChart(series: series, lowerIsBetter: true, leftLabel: 'lider', rightLabel: 'daha geride')
        else
          const _EmptyInline(text: 'Podyum pilotları için yarış içi aralık serisi bulunamadı.'),
        const SizedBox(height: 8),
        for (final driver in data.podium)
          _KeyValueLine(label: '${driver.driverCode} · finiş farkı', value: driver.position == 1 ? 'Lider' : driver.gapToLeader),
      ]),
    );
  }
}

class _TelemetrySection extends StatelessWidget {
  const _TelemetrySection({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) {
    final series = [
      for (final driver in data.telemetry)
        _ChartSeries(label: driver.driverCode, color: Color(driver.teamColor), values: driver.speedSamples),
    ];
    return _SectionCard(
      icon: Icons.speed_rounded,
      title: 'İlk üç araç · telemetri',
      subtitle: 'Tam yarış örneklerinden hız, devir, gaz, fren ve DRS özeti',
      trailing: _Tag('${data.telemetry.fold<int>(0, (sum, item) => sum + item.sampleCount)} örnek'),
      child: data.telemetry.isEmpty
          ? const _EmptyInline(text: 'Podyum pilotlarına ait araç telemetrisi yayımlanmadı.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ComparisonChart(series: series, lowerIsBetter: false, leftLabel: 'tur başlangıcı', rightLabel: 'tur sonu'),
              const SizedBox(height: 9),
              for (final driver in data.telemetry) _TelemetryDriverLine(driver: driver),
            ]),
    );
  }
}

class _TelemetryDriverLine extends StatelessWidget {
  const _TelemetryDriverLine({required this.driver});
  final DriverTelemetry driver;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(width: 4, height: 38, decoration: BoxDecoration(color: Color(driver.teamColor), borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${driver.driverCode}  ·  ${driver.teamName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            Text('${driver.sampleCount} örnek  ·  ort. gaz ${_percent(driver.averageThrottle)}  ·  fren ${_percent(driver.brakingPercent)}  ·  DRS ${_percent(driver.drsPercent)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 8.5)),
          ])),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(driver.maxSpeed == null ? '—' : '${driver.maxSpeed!.round()} km/sa', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            Text('max • ${driver.maxRpm ?? '—'} rpm', style: TextStyle(color: AppColors.muted, fontSize: 8)),
          ]),
        ]),
      );
}

class _StrategySection extends StatelessWidget {
  const _StrategySection({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) => _SectionCard(
        icon: Icons.tire_repair_rounded,
        title: 'Pit ve lastik stratejisi',
        subtitle: 'Podyum pilotlarının duruşları ve stintleri',
        trailing: _Tag('${data.pitStops.length} pit · ${data.stints.length} stint'),
        child: data.pitStops.isEmpty && data.stints.isEmpty
            ? const _EmptyInline(text: 'Pit veya lastik stratejisi kaydı bulunamadı.')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final driver in data.podium) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 4),
                    child: Row(children: [
                      Container(width: 4, height: 22, decoration: BoxDecoration(color: _driverColor(data, driver.driverNumber), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 8),
                      Text('${driver.driverCode}  ${driver.driverName.split(' ').last}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                    ]),
                  ),
                  ...data.stintsFor(driver.driverNumber).map((stint) => _StintLine(stint: stint)),
                  ...data.pitStopsFor(driver.driverNumber).map((pit) => _PitLine(pit: pit)),
                ],
                if (data.stints.isNotEmpty)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text('Tüm lastik stintleri (${data.stints.length})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      children: [for (final stint in data.stints) _AllStintLine(data: data, stint: stint)],
                    ),
                  ),
                if (data.pitStops.isNotEmpty)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text('Tüm pit kayıtları (${data.pitStops.length})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      children: [for (final pit in data.pitStops) _AllPitLine(data: data, pit: pit)],
                    ),
                  ),
                if (data.podium.isEmpty) const _EmptyInline(text: 'Sürücü sıralaması bulunamadı.'),
              ]),
      );
}

class _AllStintLine extends StatelessWidget {
  const _AllStintLine({required this.data, required this.stint});
  final CompletedSessionData data;
  final TyreStint stint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 45, child: Text(_driverCode(data, stint.driverNumber), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900))),
          Icon(Icons.circle, size: 7, color: _compoundColor(stint.compound)),
          const SizedBox(width: 5),
          Expanded(child: Text('${stint.compound} · ${stint.lapStart}–${stint.lapEnd}. tur', style: const TextStyle(fontSize: 8))),
          Text('${stint.lapCount} tur', style: TextStyle(color: AppColors.muted, fontSize: 8)),
        ]),
      );
}

class _AllPitLine extends StatelessWidget {
  const _AllPitLine({required this.data, required this.pit});
  final CompletedSessionData data;
  final PitStop pit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 45, child: Text(_driverCode(data, pit.driverNumber), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900))),
          Expanded(child: Text('Tur ${pit.lapNumber}', style: const TextStyle(fontSize: 8))),
          Text(pit.stopSeconds != null ? 'Duruş ${pit.stopSeconds!.toStringAsFixed(1)} sn' : pit.laneSeconds != null ? 'Pit yolu ${pit.laneSeconds!.toStringAsFixed(1)} sn' : 'Süre yok', style: TextStyle(color: AppColors.muted, fontSize: 8)),
        ]),
      );
}

class _StintLine extends StatelessWidget {
  const _StintLine({required this.stint});
  final TyreStint stint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 12, top: 3, bottom: 3),
        child: Row(children: [
          Icon(Icons.circle, size: 8, color: _compoundColor(stint.compound)),
          const SizedBox(width: 7),
          Expanded(child: Text('${stint.compound}  ·  Tur ${stint.lapStart}–${stint.lapEnd}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
          Text('${stint.lapCount} tur  ·  yaş ${stint.tyreAgeAtStart}', style: TextStyle(color: AppColors.muted, fontSize: 8)),
        ]),
      );
}

class _PitLine extends StatelessWidget {
  const _PitLine({required this.pit});
  final PitStop pit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 12, top: 3, bottom: 3),
        child: _KeyValueLine(
          label: 'Pit · Tur ${pit.lapNumber}',
          value: pit.stopSeconds != null
              ? 'Duruş ${pit.stopSeconds!.toStringAsFixed(1)} sn'
              : pit.laneSeconds != null
                  ? 'Pit yolu ${pit.laneSeconds!.toStringAsFixed(1)} sn'
                  : 'Süre yok',
        ),
      );
}

class _WeatherSection extends StatelessWidget {
  const _WeatherSection({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) {
    final samples = data.weather;
    final air = samples.map((sample) => sample.airTemperature).whereType<double>().toList();
    final track = samples.map((sample) => sample.trackTemperature).whereType<double>().where((value) => value > 0).toList();
    final latest = samples.isEmpty ? null : samples.last;
    final rainSamples = samples.where((sample) => sample.rainfall == true).length;
    final tempSeries = [
      _ChartSeries(label: 'Hava', color: AppColors.green, values: air),
      _ChartSeries(label: 'Pist', color: AppColors.red, values: track),
    ];
    return _SectionCard(
      icon: Icons.cloud_outlined,
      title: 'Hava ve pist',
      subtitle: 'OpenF1’ın seans boyunca tuttuğu hava durumu kayıtları',
      trailing: _Tag('${samples.length} ölçüm'),
      child: samples.isEmpty
          ? const _EmptyInline(text: 'Bu yarış için hava durumu verisi yayımlanmadı.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Metric(label: 'HAVA', value: _range(air, '°C'), color: AppColors.green),
                _Metric(label: 'PİST', value: _range(track, '°C'), color: AppColors.red),
                _Metric(label: 'YAĞIŞ', value: '$rainSamples kayıt', color: AppColors.amber),
                _Metric(label: 'NEM', value: latest?.humidity == null ? '—' : '${latest!.humidity!.round()}%', color: AppColors.muted),
                _Metric(label: 'RÜZGÂR', value: latest?.windSpeed == null ? '—' : '${latest!.windSpeed!.toStringAsFixed(1)} m/sn', color: AppColors.muted),
              ]),
              const SizedBox(height: 12),
              if (air.length > 1 || track.length > 1) _ComparisonChart(series: tempSeries, lowerIsBetter: false, leftLabel: 'seans başı', rightLabel: 'seans sonu'),
              if (latest?.date != null)
                Align(alignment: Alignment.centerRight, child: Text('Son ölçüm ${_dateTime(latest!.date!.toLocal())}', style: TextStyle(color: AppColors.muted, fontSize: 8))),
            ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.child, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 31, height: 31, decoration: BoxDecoration(color: AppColors.red.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.red, size: 17)),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 9)),
            ])),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ]),
          const SizedBox(height: 13),
          child,
        ]),
      );
}

class _HighlightLine extends StatelessWidget {
  const _HighlightLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: .1), borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w700))),
          Text(value, style: TextStyle(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: AppColors.muted, fontSize: 9))),
          Text(value, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 75),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(11)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .7)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 8, fontWeight: FontWeight.w800)),
      );
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(text, style: TextStyle(color: AppColors.muted, fontSize: 10)));
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.label, this.icon = Icons.info_outline_rounded, this.loading = false, this.onRetry});
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          if (loading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(icon, color: AppColors.muted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: AppColors.muted, fontSize: 11))),
          if (onRetry != null) IconButton(onPressed: onRetry, tooltip: 'Yeniden dene', icon: const Icon(Icons.refresh_rounded)),
        ]),
      );
}

class _ChartSeries {
  const _ChartSeries({required this.label, required this.color, required this.values});
  final String label;
  final Color color;
  final List<double> values;
}

class _ComparisonChart extends StatelessWidget {
  const _ComparisonChart({required this.series, required this.lowerIsBetter, required this.leftLabel, required this.rightLabel});
  final List<_ChartSeries> series;
  final bool lowerIsBetter;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    final visible = series.where((item) => item.values.length > 1).toList();
    if (visible.isEmpty) return const _EmptyInline(text: 'Grafik için yeterli veri yok.');
    return Column(children: [
      SizedBox(height: 110, width: double.infinity, child: CustomPaint(painter: _LineChartPainter(visible, lowerIsBetter, AppColors.border))),
      const SizedBox(height: 2),
      Row(children: [
        Text(leftLabel, style: TextStyle(color: AppColors.muted, fontSize: 8)),
        const Spacer(),
        _Legend(items: [for (final item in visible) _LegendItem(item.label, item.color)]),
        const Spacer(),
        Text(rightLabel, style: TextStyle(color: AppColors.muted, fontSize: 8)),
      ]),
    ]);
  }
}

class _LegendItem {
  const _LegendItem(this.label, this.color);
  final String label;
  final Color color;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items});
  final List<_LegendItem> items;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 9,
        runSpacing: 4,
        children: [
          for (final item in items)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(item.label, style: TextStyle(color: AppColors.muted, fontSize: 8, fontWeight: FontWeight.w800)),
            ]),
        ],
      );
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.series, this.lowerIsBetter, this.gridColor);
  final List<_ChartSeries> series;
  final bool lowerIsBetter;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontal = 5.0;
    const vertical = 5.0;
    final chartWidth = size.width - horizontal * 2;
    final chartHeight = size.height - vertical * 2;
    final chart = Rect.fromLTWH(horizontal, vertical, chartWidth > 0 ? chartWidth : 0, chartHeight > 0 ? chartHeight : 0);
    final gridPaint = Paint()..color = gridColor.withValues(alpha: .7)..strokeWidth = .7;
    for (var row = 0; row < 4; row++) {
      final y = chart.top + chart.height * row / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final all = series.expand((item) => item.values).where((value) => value.isFinite).toList();
    if (all.isEmpty) return;
    var minValue = all.reduce((a, b) => a < b ? a : b);
    var maxValue = all.reduce((a, b) => a > b ? a : b);
    if ((maxValue - minValue).abs() < .001) {
      minValue -= 1;
      maxValue += 1;
    }
    for (final item in series) {
      if (item.values.length < 2) continue;
      final path = Path();
      for (var i = 0; i < item.values.length; i++) {
        final x = chart.left + chart.width * i / (item.values.length - 1);
        final normalized = (item.values[i] - minValue) / (maxValue - minValue);
        final progress = lowerIsBetter ? normalized : 1 - normalized;
        final y = chart.top + chart.height * progress;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, Paint()..color = item.color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.series != series || oldDelegate.lowerIsBetter != lowerIsBetter || oldDelegate.gridColor != gridColor;
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.traces);
  final List<TrackTrace> traces;

  @override
  void paint(Canvas canvas, Size size) {
    final valid = traces.where((trace) => trace.points.length > 2).toList();
    if (valid.isEmpty) return;
    final allPoints = valid.expand((trace) => trace.points).toList();
    final minX = allPoints.map((point) => point.x).reduce((a, b) => a < b ? a : b);
    final maxX = allPoints.map((point) => point.x).reduce((a, b) => a > b ? a : b);
    final minY = allPoints.map((point) => point.y).reduce((a, b) => a < b ? a : b);
    final maxY = allPoints.map((point) => point.y).reduce((a, b) => a > b ? a : b);
    final width = maxX > minX ? maxX - minX : 1.0;
    final height = maxY > minY ? maxY - minY : 1.0;
    const inset = 12.0;
    final scale = math.min((size.width - inset * 2) / width, (size.height - inset * 2) / height).toDouble();
    final drawWidth = width * scale;
    final drawHeight = height * scale;
    final left = (size.width - drawWidth) / 2;
    final top = (size.height - drawHeight) / 2;

    Offset map(TrackPoint point) => Offset(left + (point.x - minX) * scale, top + (maxY - point.y) * scale);

    for (final trace in valid) {
      final path = Path();
      for (var i = 0; i < trace.points.length; i++) {
        final offset = map(trace.points[i]);
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      final color = Color(trace.teamColor);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .18)..style = PaintingStyle.stroke..strokeWidth = 11..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      final start = map(trace.points.first);
      canvas.drawCircle(start, 4.3, Paint()..color = Colors.white);
      canvas.drawCircle(start, 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) => oldDelegate.traces != traces;
}

double? _number(String? text) {
  if (text == null || text.isEmpty || text.toUpperCase().contains('LAP') || text == 'Lider') return null;
  return double.tryParse(text.replaceAll('+', '').replaceAll(' sn', '').trim());
}

List<double> _gapValues(List<GapSample> gaps) {
  final values = [for (final gap in gaps) _number(gap.gapToLeader) ?? (gap.gapToLeader == null ? 0.0 : double.nan)];
  final valid = values.where((value) => value.isFinite).toList();
  if (valid.length <= 120) return valid;
  return [for (var i = 0; i < 120; i++) valid[(i * (valid.length - 1) / 119).round()]];
}

String _duration(double? seconds) {
  if (seconds == null || !seconds.isFinite) return '—';
  final millis = (seconds * 1000).round();
  final minutes = (millis ~/ 60000) % 60;
  final secs = (millis ~/ 1000) % 60;
  final ms = millis % 1000;
  final hours = millis ~/ 3600000;
  final clock = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  return hours > 0 ? '$hours:$clock' : clock;
}

String _dateTime(DateTime value) => '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}  ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _percent(double? value) => value == null ? '—' : '${value.round()}%';
bool _isInterlagos(String name) => name.toLowerCase().contains('interlagos') || name.toLowerCase().contains('sao paulo');

String _range(List<double> values, String suffix) {
  if (values.isEmpty) return '—';
  final low = values.reduce((a, b) => a < b ? a : b);
  final high = values.reduce((a, b) => a > b ? a : b);
  return '${low.round()}–${high.round()}$suffix';
}

String _driverCode(CompletedSessionData data, int number) {
  for (final driver in data.standings) {
    if (driver.driverNumber == number) return driver.driverCode;
  }
  return '$number';
}

Color _driverColor(CompletedSessionData data, int number) {
  for (final driver in data.telemetry) {
    if (driver.driverNumber == number) return Color(driver.teamColor);
  }
  for (final trace in data.trackTraces) {
    if (trace.driverNumber == number) return Color(trace.teamColor);
  }
  return switch (number) {
    1 => AppColors.red,
    2 => const Color(0xFF3671C6),
    _ => const Color(0xFF00D2BE),
  };
}

Color _compoundColor(String compound) => switch (compound.toUpperCase()) {
      'SOFT' => const Color(0xFFFF4C4C),
      'MEDIUM' => const Color(0xFFFFC800),
      'HARD' => const Color(0xFFF4F4F4),
      'INTERMEDIATE' => const Color(0xFF39B54A),
      'WET' => const Color(0xFF2C6FEA),
      _ => AppColors.muted,
    };

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
