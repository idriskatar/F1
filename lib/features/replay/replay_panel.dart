import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../core/models/replay_models.dart';
import '../../core/theme/app_theme.dart';

const _purple = Color(0xFFB138DD);
const _yellow = Color(0xFFFACC15);
const _blue = Color(0xFF2F6BFF);

/// 5400 -> "1:30:00", 95 -> "1:35"
String formatReplayClock(double seconds) {
  final total = seconds.isNaN || seconds < 0 ? 0 : seconds.floor();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final ss = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

Color _sectorColor(SectorStatus status) => switch (status) {
      SectorStatus.overallBest => _purple,
      SectorStatus.personalBest => AppColors.green,
      SectorStatus.slower => _yellow,
      SectorStatus.active => Colors.white,
      SectorStatus.upcoming || SectorStatus.unknown => AppColors.border,
    };

Color _compoundColor(String letter) => switch (letter) {
      'S' => const Color(0xFFEF4444),
      'M' => _yellow,
      'H' => const Color(0xFFE5E7EB),
      'I' => AppColors.green,
      'W' => const Color(0xFF3B82F6),
      _ => AppColors.muted,
    };

/// Lastik harfi (S/M/H/I/W) için renk; strateji ekranı da kullanır.
Color replayCompoundColor(String letter) => _compoundColor(letter);

/// Yarış yönetimi olayının rengi (zaman çubuğu, rozet, liste).
Color replayEventColor(ReplayEventKind kind) => switch (kind) {
      ReplayEventKind.safetyCar || ReplayEventKind.virtualSafetyCar => _yellow,
      ReplayEventKind.redFlag => const Color(0xFFEF4444),
      ReplayEventKind.penalty => const Color(0xFFFB923C),
    };

/// Oynatıcının alt bölümü: solda sıralama listesi, sağda sayfalı pilot kartı
/// (Telemetri · Hız grafiği · Pit stoplar · Tur süreleri · Olaylar · Karşılaştır).
class ReplayLowerPanel extends StatefulWidget {
  const ReplayLowerPanel({
    super.key,
    required this.data,
    required this.time,
    required this.slowTime,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    required this.onOpenPit,
    this.onOpenEvent,
  });

  final ReplayData data;

  /// Her karede güncellenen zaman (gösterge, hız grafiği).
  final ValueListenable<double> time;

  /// Yaklaşık 0,5 sn'de bir güncellenen zaman (sıralama, tur, sektör, pit vurgusu).
  final ValueListenable<double> slowTime;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;
  final ValueChanged<ReplayPit> onOpenPit;
  final ValueChanged<ReplayEvent>? onOpenEvent;

  @override
  State<ReplayLowerPanel> createState() => _ReplayLowerPanelState();
}

class _ReplayLowerPanelState extends State<ReplayLowerPanel> {
  final PageController _pages = PageController();
  int _page = 0;

  /// Karşılaştırma sayfasında kullanıcının seçtiği rakip; null ise otomatik (öndeki pilot).
  String? _compareCode;

  bool get _hasLaps => widget.data.drivers.any((d) => d.laps.isNotEmpty);

  // Eski dosyalarda tur/olay verisi olmayabilir; o sayfalar hiç gösterilmez.
  List<String> get _titles => [
        'Telemetri',
        'Hız grafiği',
        'Pit stoplar',
        if (_hasLaps) 'Tur süreleri',
        if (widget.data.events.isNotEmpty) 'Olaylar',
        if (_canCompare) 'Karşılaştır',
      ];

  bool get _canCompare => widget.data.drivers.where((d) => d.hasTelemetry).length >= 2;

  /// Karşılaştırılacak rakip: seçilmişse o, değilse hemen öndeki pilot (liderse ikinci).
  ReplayDriver? _rival(ReplayDriver? primary) {
    if (primary == null) return null;
    final data = widget.data;
    final chosen = data.driverByCode(_compareCode);
    if (chosen != null && chosen.code != primary.code && chosen.hasTelemetry) return chosen;
    final order = [
      for (final d in data.orderAt(widget.slowTime.value))
        if (d.hasTelemetry) d,
    ];
    if (order.isEmpty) return null;
    final index = order.indexWhere((d) => d.code == primary.code);
    if (index < 0) return order.first;
    if (index > 0) return order[index - 1];
    return order.length > 1 ? order[1] : null;
  }

  Future<void> _pickRival(ReplayDriver? current) async {
    final data = widget.data;
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Rakip seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          for (final d in data.orderAt(widget.slowTime.value))
            if (d.hasTelemetry && d.code != widget.selected)
              ListTile(
                key: Key('replay-rival-${d.code}'),
                dense: true,
                selected: d.code == current?.code,
                leading: Container(width: 4, height: 24, decoration: BoxDecoration(color: Color(d.colorValue), borderRadius: BorderRadius.circular(2))),
                title: Text('${d.code} · ${d.surname}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: d.team.isEmpty ? null : Text(d.team),
                onTap: () => Navigator.of(context).pop(d.code),
              ),
        ]),
      ),
    );
    if (code != null && mounted) setState(() => _compareCode = code);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pages.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final driver = data.driverByCode(widget.selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 120,
          child: _PositionList(data: data, time: widget.slowTime, selected: widget.selected, onSelect: widget.onSelect),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(children: [
            _PageDots(titles: _titles, index: math.min(_page, _titles.length - 1), onTap: _goTo),
            const SizedBox(height: 2),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _DriverCard(data: data, driver: driver, time: widget.time, slowTime: widget.slowTime, onClose: widget.onClose),
                  _SpeedPage(data: data, driver: driver, time: widget.time),
                  _PitTab(data: data, time: widget.slowTime, onOpen: widget.onOpenPit),
                  if (_hasLaps) _LapTimesPage(data: data, driver: driver, time: widget.slowTime),
                  if (data.events.isNotEmpty) _EventsPage(data: data, time: widget.slowTime, onOpen: widget.onOpenEvent),
                  if (_canCompare)
                    _ComparePage(
                      data: data,
                      driver: driver,
                      rival: _rival(driver),
                      time: widget.time,
                      slowTime: widget.slowTime,
                      onPickRival: () => _pickRival(_rival(driver)),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.titles, required this.index, required this.onTap});

  final List<String> titles;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < titles.length; i++)
          GestureDetector(
            key: Key('replay-dot-$i'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: i == index ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index ? AppColors.red : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        const Spacer(),
        Text(titles[index], style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
      ]);
}

// ---------------------------------------------------------------------------- Sıralama

class _PositionList extends StatefulWidget {
  const _PositionList({required this.data, required this.time, required this.selected, required this.onSelect});

  final ReplayData data;
  final ValueListenable<double> time;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  State<_PositionList> createState() => _PositionListState();
}

class _PositionListState extends State<_PositionList> {
  final ScrollController _scroll = ScrollController();

  /// true: lidere fark, false: hemen öndekine fark.
  bool _toLeader = true;

  /// Fark yalnız canlı sıralama varken anlamlıdır (bitiş sırası farkla çelişirdi).
  bool get _showGaps => widget.data.hasGaps && widget.data.hasLivePositions;

  /// Fark satırı için satır biraz yüksek olur.
  double get _rowHeight => _showGaps ? 40.0 : 32.0;

  @override
  void didUpdateWidget(covariant _PositionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Seçilen pilotun satırını görünür alana getirir (pistten seçildiğinde).
  void _reveal() {
    if (!mounted || !_scroll.hasClients) return;
    final order = widget.data.orderAt(widget.time.value);
    final index = order.indexWhere((d) => d.code == widget.selected);
    if (index < 0) return;
    final target = index * _rowHeight - _scroll.position.viewportDimension / 2 + _rowHeight / 2;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.data.hasLivePositions;
    final headerStyle = TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 0, 4),
        child: Row(children: [
          Expanded(child: Text(live ? 'SIRALAMA' : 'BİTİŞ SIRASI', maxLines: 1, overflow: TextOverflow.ellipsis, style: headerStyle)),
          if (_showGaps)
            InkWell(
              key: const Key('replay-gap-mode'),
              borderRadius: BorderRadius.circular(4),
              onTap: () => setState(() => _toLeader = !_toLeader),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  _toLeader ? 'LİDERE' : 'ÖNDEKİNE',
                  style: headerStyle.copyWith(color: AppColors.amber, letterSpacing: 0.2, fontSize: 9),
                ),
              ),
            ),
        ]),
      ),
      Expanded(
        child: ValueListenableBuilder<double>(
          valueListenable: widget.time,
          builder: (context, t, _) {
            final order = widget.data.orderAt(t);
            final fastest = widget.data.fastestLapHolderAt(t);
            return ListView.builder(
              controller: _scroll,
              itemExtent: _rowHeight,
              itemCount: order.length,
              itemBuilder: (context, i) {
                final driver = order[i];
                final rank = live ? driver.rankAt(t) : driver.position;
                // Lider için "Lider"; diğerleri için seçili moda göre fark, örnek yoksa/bayatsa "–".
                final gap = !_showGaps
                    ? null
                    : i == 0
                        ? 'Lider'
                        : driver.gapAt(t)?.text(toLeader: _toLeader) ?? '–';
                return _PositionRow(
                  rank: rank == null ? '–' : '$rank',
                  gap: gap,
                  driver: driver,
                  selected: driver.code == widget.selected,
                  inPit: widget.data.inPit(driver.code, t),
                  tyre: driver.stintAt(t),
                  hasFastestLap: driver.code == fastest,
                  onTap: () => widget.onSelect(driver.code),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({
    required this.rank,
    required this.driver,
    required this.selected,
    required this.inPit,
    required this.tyre,
    required this.hasFastestLap,
    required this.onTap,
    this.gap,
  });

  final String rank;

  /// Pilot kodunun altında küçük yazılan fark metni; veri yoksa null (satır tek satır kalır).
  final String? gap;
  final ReplayDriver driver;
  final bool selected;
  final bool inPit;

  /// O an takılı lastik; bilinmiyorsa null (simge gösterilmez).
  final ReplayStint? tyre;

  /// O ana kadarki en hızlı turun sahibi mi?
  final bool hasFastestLap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface2 : null,
            borderRadius: BorderRadius.circular(6),
            border: selected ? Border.all(color: AppColors.red, width: 1.2) : null,
          ),
          child: Row(children: [
            // Sabit genişlik: "10" ve sonrası da tek satırda kalır, kod sütunu tüm satırlarda aynı hizadan başlar.
            SizedBox(
              width: 24,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  rank,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ),
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(color: Color(driver.colorValue), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 5),
            // Expanded: yer daralırsa (büyük yazı boyutu vb.) kod kısalır, satır taşmaz.
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  driver.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 1.1, color: inPit ? AppColors.amber : null),
                ),
                if (gap != null)
                  Text(gap!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 10, height: 1.1)),
              ]),
            ),
            if (hasFastestLap) ...[
              const Icon(Icons.timer_outlined, size: 15, color: _purple),
              const SizedBox(width: 3),
            ],
            if (tyre != null) _TyreDot(letter: tyre!.letter),
          ]),
        ),
      );
}

class _TyreDot extends StatelessWidget {
  const _TyreDot({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) => Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _compoundColor(letter), width: 2.5)),
        child: Text(letter, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, height: 1)),
      );
}

// ---------------------------------------------------------------------------- Pilot kartı

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.data, required this.driver, required this.time, required this.slowTime, required this.onClose});

  final ReplayData data;
  final ReplayDriver? driver;
  final ValueListenable<double> time;
  final ValueListenable<double> slowTime;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    if (d == null) {
      return Center(
        child: Text(
          'Soldan bir pilot seç ya da pistteki araca dokun.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(color: Color(d.colorValue), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              d.surname.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, height: 1.1),
            ),
            if (d.team.isNotEmpty)
              Text(d.team, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
        IconButton(tooltip: 'Kapat', visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close_rounded)),
      ]),
      ValueListenableBuilder<double>(
        valueListenable: slowTime,
        builder: (context, t, _) => _LapTyreRow(data: data, driver: d, t: t),
      ),
      Expanded(
        child: d.hasTelemetry
            ? _Gauge(data: data, driver: d, time: time)
            : Center(child: Text('Bu pilot için telemetri verisi yok.', style: TextStyle(color: AppColors.muted))),
      ),
      ValueListenableBuilder<double>(
        valueListenable: slowTime,
        builder: (context, t, _) => _SectorBars(states: data.sectorStatesAt(d, t)),
      ),
    ]);
  }
}

class _LapTyreRow extends StatelessWidget {
  const _LapTyreRow({required this.data, required this.driver, required this.t});

  final ReplayData data;
  final ReplayDriver driver;
  final double t;

  @override
  Widget build(BuildContext context) {
    final last = driver.lastCompletedLapAt(t);
    final current = driver.currentLapAt(t);
    final lapNumber = current?.number ?? last?.number;
    final stint = lapNumber == null ? null : driver.stintAtLap(lapNumber);
    final duration = last?.duration;

    Widget lapTime = Text('—', style: TextStyle(color: AppColors.muted));
    if (duration != null) {
      final status = data.bestsAt(t, driver).classifyLap(duration);
      final highlighted = status != SectorStatus.slower;
      lapTime = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: highlighted ? _sectorColor(status) : AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          formatLapTime(duration),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: highlighted ? Colors.white : null),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('SON TUR  ', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w800)),
        lapTime,
        const Spacer(),
        if (stint != null && lapNumber != null) _TyreBadge(stint: stint, age: stint.ageAt(lapNumber)),
      ]),
    );
  }
}

class _TyreBadge extends StatelessWidget {
  const _TyreBadge({required this.stint, required this.age});

  final ReplayStint stint;
  final int age;

  @override
  Widget build(BuildContext context) {
    final color = _compoundColor(stint.letter);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$age tur  ', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
      Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5)),
        child: Text(stint.letter, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------- Gösterge

class _Gauge extends StatelessWidget {
  const _Gauge({required this.data, required this.driver, required this.time, this.compact = false});

  final ReplayData data;
  final ReplayDriver driver;
  final ValueListenable<double> time;

  /// Minyatür: birim ve GAZ/FREN yazıları gizlenir, yalnız halka, hız, rpm ve vites kalır.
  final bool compact;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: time,
        builder: (context, t, _) {
          final speed = driver.speedAt(t, data.hz);
          final throttle = driver.throttleAt(t, data.hz);
          final braking = driver.brakeAt(t, data.hz) ?? false;
          final gear = driver.gearAt(t, data.hz);
          final rpm = driver.rpmAt(t, data.hz);
          final drs = driver.drsAt(t, data.hz) ?? false;
          return LayoutBuilder(builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            if (!side.isFinite || side <= 0) return const SizedBox.shrink();
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: Stack(alignment: Alignment.center, children: [
                  CustomPaint(
                    size: Size.square(side),
                    painter: _GaugePainter(
                      speed: ((speed ?? 0) / 360).clamp(0.0, 1.0).toDouble(),
                      throttle: ((throttle ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
                      brake: braking ? 1.0 : 0.0,
                      trackColor: AppColors.border,
                      speedColor: _blue,
                      throttleColor: AppColors.green,
                      brakeColor: AppColors.red,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(side * 0.24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(speed == null ? '—' : '${speed.round()}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
                        if (!compact) Text('KM/SA', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(rpm == null ? '—' : '${rpm.round()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.1)),
                        if (!compact) Text('RPM', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.94),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(gear == null ? '' : 'V$gear', style: TextStyle(fontSize: compact ? 10 : 12, fontWeight: FontWeight.w900)),
                      if (drs)
                        Text(compact ? ' D' : '  DRS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.green)),
                    ]),
                  ),
                  if (!compact) ...[
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Text('GAZ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.green)),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text('FREN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.red)),
                    ),
                  ],
                ]),
              ),
            );
          });
        },
      );
}

/// Dış halka: hız (0–360 km/sa). İç yaylar: gaz 180° (sol alttan sağ üste), fren 90° (sağ üstten sağ alta). Alt kısımda 90° boşluk.
class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.speed,
    required this.throttle,
    required this.brake,
    required this.trackColor,
    required this.speedColor,
    required this.throttleColor,
    required this.brakeColor,
  });

  final double speed;
  final double throttle;
  final double brake;
  final Color trackColor;
  final Color speedColor;
  final Color throttleColor;
  final Color brakeColor;

  static const _start = 3 * math.pi / 4; // 135°: sol alt
  static const _sweep = 3 * math.pi / 2; // 270°
  static const _throttleSpan = math.pi; // gaz yayı 180°
  static const _brakeSpan = math.pi / 2; // fren yayı 90° (gaz:fren = 2:1)

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerWidth = size.width * 0.105; // hız halkası
    final innerWidth = size.width * 0.05;
    final outerRadius = size.width / 2 - outerWidth / 2;
    final innerRadius = outerRadius - outerWidth / 2 - innerWidth / 2 - size.width * 0.03;
    final outer = Rect.fromCircle(center: center, radius: outerRadius);
    final inner = Rect.fromCircle(center: center, radius: innerRadius);

    Paint stroke(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = color;

    canvas.drawArc(outer, _start, _sweep, false, stroke(outerWidth, trackColor));
    if (speed > 0) canvas.drawArc(outer, _start, _sweep * speed, false, stroke(outerWidth, speedColor));

    canvas.drawArc(inner, _start, _throttleSpan, false, stroke(innerWidth, trackColor));
    canvas.drawArc(inner, _start + _throttleSpan, _brakeSpan, false, stroke(innerWidth, trackColor));
    if (throttle > 0) canvas.drawArc(inner, _start, _throttleSpan * throttle, false, stroke(innerWidth, throttleColor));
    if (brake > 0) {
      // Fren yayı sağ alttan (405°) yukarı doğru dolar.
      final fill = _brakeSpan * brake;
      canvas.drawArc(inner, _start + _throttleSpan + _brakeSpan - fill, fill, false, stroke(innerWidth, brakeColor));
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.speed != speed ||
      old.throttle != throttle ||
      old.brake != brake ||
      old.trackColor != trackColor ||
      old.speedColor != speedColor ||
      old.throttleColor != throttleColor ||
      old.brakeColor != brakeColor;
}

class _SectorBars extends StatelessWidget {
  const _SectorBars({required this.states});

  final List<SectorStatus> states;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          for (var i = 0; i < states.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(color: _sectorColor(states[i]), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(height: 3),
                  Text('S${i + 1}', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      );
}

// ---------------------------------------------------------------------------- Hız grafiği ve pit listesi

class _SpeedPage extends StatelessWidget {
  const _SpeedPage({required this.data, required this.driver, required this.time});

  final ReplayData data;
  final ReplayDriver? driver;
  final ValueListenable<double> time;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    if (d == null || !d.hasTelemetry) {
      return Center(
        child: Text(
          d == null ? 'Bir pilot seç.' : 'Bu pilot için telemetri verisi yok.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${d.code} · son 60 sn hız (km/sa)', style: TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 6),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _SpeedPainter(
              series: d.speedSeries(math.max(0.0, t - 60), t, data.hz),
              lineColor: Color(d.colorValue),
              gridColor: AppColors.border,
            ),
          ),
        ),
      ]),
    );
  }
}

class _SpeedPainter extends CustomPainter {
  _SpeedPainter({required this.series, required this.lineColor, required this.gridColor});

  final List<double?> series;
  final Color lineColor;
  final Color gridColor;

  static const _maxSpeed = 360.0;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), grid);
    canvas.drawLine(Offset.zero, Offset(size.width, 0), grid);
    if (series.length < 2) return;
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    var penDown = false;
    for (var i = 0; i < series.length; i++) {
      final value = series[i];
      if (value == null) {
        penDown = false;
        continue;
      }
      final dx = size.width * i / (series.length - 1);
      final dy = size.height * (1 - (value / _maxSpeed).clamp(0.0, 1.0));
      if (penDown) {
        path.lineTo(dx, dy);
      } else {
        path.moveTo(dx, dy);
        penDown = true;
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter old) => true;
}

class _PitTab extends StatelessWidget {
  const _PitTab({required this.data, required this.time, required this.onOpen});

  final ReplayData data;
  final ValueListenable<double> time;
  final ValueChanged<ReplayPit> onOpen;

  @override
  Widget build(BuildContext context) {
    if (data.pits.isEmpty) {
      return Center(child: Text('Bu seansta pit stop kaydı yok.', style: TextStyle(color: AppColors.muted)));
    }
    return ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, _) => ListView.builder(
        padding: const EdgeInsets.only(top: 2, bottom: 12),
        itemCount: data.pits.length,
        itemBuilder: (context, i) {
          final pit = data.pits[i];
          final driver = data.driverByCode(pit.driver);
          final active = pit.containsTime(t);
          final lane = pit.pitLaneSeconds;
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: CircleAvatar(radius: 6, backgroundColor: Color(driver?.colorValue ?? 0xFF9AA0A6)),
            title: Text(
              '${pit.driver} · Tur ${pit.lap}',
              style: TextStyle(fontWeight: FontWeight.w800, color: active ? AppColors.amber : null),
            ),
            subtitle: Text('Giriş ${formatReplayClock(pit.inTime)}', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            trailing: Text(
              lane == null ? '—' : 'Pit şeridi ${lane.toStringAsFixed(1).replaceAll('.', ',')} sn',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            onTap: () => onOpen(pit),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------- Tur süreleri ve olaylar

class _LapBand {
  const _LapBand(this.firstLap, this.lastLap, this.color);

  final int firstLap;
  final int lastLap;
  final Color color;
}

class _LapTimesPage extends StatelessWidget {
  const _LapTimesPage({required this.data, required this.driver, required this.time});

  final ReplayData data;
  final ReplayDriver? driver;
  final ValueListenable<double> time;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    if (d == null) {
      return Center(child: Text('Bir pilot seç.', style: TextStyle(color: AppColors.muted)));
    }
    final laps = [
      for (final lap in d.laps)
        if (lap.duration != null) lap,
    ];
    if (laps.length < 2) {
      return Center(child: Text('Bu pilot için tur süresi verisi yok.', style: TextStyle(color: AppColors.muted)));
    }
    final sorted = [for (final lap in laps) lap.duration!]..sort();
    final fastest = sorted.first;
    final median = sorted[sorted.length ~/ 2];
    // Pit ve safety car turları ölçeği bozmasın: median'ın %8 üstü tavan, üstü kenarda halka.
    final top = math.max(fastest + 1.0, median * 1.08);
    final bottom = fastest - 0.3;
    final maxLap = math.max(data.totalLaps, laps.last.number);
    final bands = [
      for (final period in data.periods)
        _LapBand(
          data.lapAt(period.time),
          data.lapAt(period.end ?? period.time),
          replayEventColor(period.kind).withValues(alpha: period.kind == ReplayEventKind.virtualSafetyCar ? .10 : .18),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        '${d.code} · tur süreleri · en iyi ${formatLapTime(fastest)}',
        style: TextStyle(color: AppColors.muted, fontSize: 11),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: ValueListenableBuilder<double>(
          valueListenable: time,
          builder: (context, t, _) => CustomPaint(
            size: Size.infinite,
            painter: _LapTimesPainter(
              laps: laps,
              fastest: fastest,
              bottom: bottom,
              top: top,
              maxLap: maxLap,
              currentLap: data.lapAt(t),
              bands: bands,
              colorFor: (lap) => _compoundColor(d.stintAtLap(lap)?.letter ?? '?'),
              gridColor: AppColors.border,
              markerColor: AppColors.red,
            ),
          ),
        ),
      ),
    ]);
  }
}

class _LapTimesPainter extends CustomPainter {
  _LapTimesPainter({
    required this.laps,
    required this.fastest,
    required this.bottom,
    required this.top,
    required this.maxLap,
    required this.currentLap,
    required this.bands,
    required this.colorFor,
    required this.gridColor,
    required this.markerColor,
  });

  final List<ReplayLap> laps;
  final double fastest;
  final double bottom;
  final double top;
  final int maxLap;
  final int currentLap;
  final List<_LapBand> bands;
  final Color Function(int lap) colorFor;
  final Color gridColor;
  final Color markerColor;

  static const _pad = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    double xOf(int lap) => maxLap <= 1 ? _pad : _pad + (lap - 1) / (maxLap - 1) * (size.width - _pad * 2);
    double yOf(double seconds) {
      final ratio = ((seconds - bottom) / (top - bottom)).clamp(0.0, 1.0);
      return size.height - _pad - ratio * (size.height - _pad * 2);
    }

    final step = maxLap <= 1 ? size.width : (size.width - _pad * 2) / (maxLap - 1);
    for (final band in bands) {
      final rect = Rect.fromLTRB(xOf(band.firstLap) - step / 2, 0, xOf(band.lastLap) + step / 2, size.height);
      canvas.drawRect(rect, Paint()..color = band.color);
    }
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), grid);
    canvas.drawLine(Offset.zero, Offset(size.width, 0), grid);

    // Süren tur çizgisi
    canvas.drawLine(
      Offset(xOf(currentLap), 0),
      Offset(xOf(currentLap), size.height),
      Paint()
        ..color = markerColor.withValues(alpha: .7)
        ..strokeWidth = 1.5,
    );

    final link = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    ReplayLap? previous;
    for (final lap in laps) {
      final seconds = lap.duration!;
      final center = Offset(xOf(lap.number), yOf(seconds));
      final clipped = seconds > top;
      final before = previous;
      if (before != null && !clipped && before.duration! <= top && before.number == lap.number - 1) {
        canvas.drawLine(Offset(xOf(before.number), yOf(before.duration!)), center, link);
      }
      previous = lap;
      final color = colorFor(lap.number);
      if (clipped) {
        canvas.drawCircle(
          center,
          3,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        canvas.drawCircle(center, 3, Paint()..color = color);
      }
      if ((seconds - fastest).abs() < 0.0005) {
        canvas.drawCircle(
          center,
          6,
          Paint()
            ..color = _purple
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LapTimesPainter old) => true;
}

class _EventsPage extends StatelessWidget {
  const _EventsPage({required this.data, required this.time, this.onOpen});

  final ReplayData data;
  final ValueListenable<double> time;
  final ValueChanged<ReplayEvent>? onOpen;

  static IconData _icon(ReplayEventKind kind) => switch (kind) {
        ReplayEventKind.safetyCar => Icons.warning_amber_rounded,
        ReplayEventKind.virtualSafetyCar => Icons.speed_rounded,
        ReplayEventKind.redFlag => Icons.flag_rounded,
        ReplayEventKind.penalty => Icons.gavel_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final open = onOpen;
    return ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, _) => ListView.builder(
        padding: const EdgeInsets.only(top: 2, bottom: 12),
        itemCount: data.events.length,
        itemBuilder: (context, i) {
          final event = data.events[i];
          final active = event.containsTime(t);
          return ListTile(
            key: Key('replay-event-$i'),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(_icon(event.kind), size: 20, color: replayEventColor(event.kind)),
            title: Text(
              '${event.label}${event.lap == null ? '' : ' · Tur ${event.lap}'}',
              style: TextStyle(fontWeight: FontWeight.w800, color: active ? AppColors.amber : null),
            ),
            subtitle: event.message.isEmpty
                ? null
                : Text(event.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            trailing: Text(formatReplayClock(event.time), style: TextStyle(color: AppColors.muted, fontSize: 12)),
            onTap: open == null ? null : () => open(event),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------- Pilot karşılaştırma

/// İki renk birbirine çok yakınsa (takım arkadaşları) rakip için ayırt edilebilir bir renk seçer.
Color _rivalColor(Color primary, Color rival) {
  double distance(Color a, Color b) {
    final dr = a.r - b.r;
    final dg = a.g - b.g;
    final db = a.b - b.b;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  for (final candidate in [rival, _yellow, _blue, const Color(0xFFFFFFFF)]) {
    if (distance(primary, candidate) >= 0.3) return candidate;
  }
  return rival;
}

class _ComparePage extends StatelessWidget {
  const _ComparePage({
    required this.data,
    required this.driver,
    required this.rival,
    required this.time,
    required this.slowTime,
    required this.onPickRival,
  });

  final ReplayData data;
  final ReplayDriver? driver;
  final ReplayDriver? rival;
  final ValueListenable<double> time;
  final ValueListenable<double> slowTime;
  final VoidCallback onPickRival;

  @override
  Widget build(BuildContext context) {
    final a = driver;
    final b = rival;
    if (a == null) {
      return Center(child: Text('Bir pilot seç.', style: TextStyle(color: AppColors.muted)));
    }
    if (!a.hasTelemetry || b == null) {
      return Center(
        child: Text('Karşılaştırma için iki pilotun telemetrisi gerekli.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      );
    }
    final colorA = Color(a.colorValue);
    final colorB = _rivalColor(colorA, Color(b.colorValue));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _CompareChip(code: a.code, color: colorA),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('–', style: TextStyle(color: AppColors.muted))),
        InkWell(
          key: const Key('replay-compare-pick'),
          borderRadius: BorderRadius.circular(6),
          onTap: onPickRival,
          child: _CompareChip(code: b.code, color: colorB, dropdown: true),
        ),
        const Spacer(),
        ValueListenableBuilder<double>(
          valueListenable: slowTime,
          builder: (context, t, _) {
            final gap = data.gapBetween(a, b, t);
            return gap == null
                ? const SizedBox.shrink()
                : Text('Δ ${gap.toStringAsFixed(1)} sn', key: const Key('replay-compare-gap'), style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700));
          },
        ),
      ]),
      const SizedBox(height: 6),
      // Sayfa kısa panelde sıkışmasın diye kaydırılır: önce iki grafik, en sonda iki pilotun mini göstergesi.
      Expanded(
        child: SingleChildScrollView(
          child: ValueListenableBuilder<double>(
            valueListenable: time,
            builder: (context, t, _) {
              final from = math.max(0.0, t - 60);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Hız (km/sa) · son 60 sn', style: TextStyle(color: AppColors.muted, fontSize: 10)),
                const SizedBox(height: 2),
                SizedBox(
                  height: 96,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _LinesPainter(
                      lines: [
                        _Line(a.speedSeries(from, t, data.hz), colorA),
                        _Line(b.speedSeries(from, t, data.hz), colorB),
                      ],
                      maxValue: 360,
                      gridColor: AppColors.border,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Gaz (%)', style: TextStyle(color: AppColors.muted, fontSize: 10)),
                const SizedBox(height: 2),
                SizedBox(
                  height: 60,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _LinesPainter(
                      lines: [
                        _Line(a.throttleSeries(from, t, data.hz), colorA),
                        _Line(b.throttleSeries(from, t, data.hz), colorB),
                      ],
                      maxValue: 100,
                      gridColor: AppColors.border,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _CompareGauge(data: data, driver: a, color: colorA, time: time)),
                  const SizedBox(width: 8),
                  Expanded(child: _CompareGauge(data: data, driver: b, color: colorB, time: time)),
                ]),
                const SizedBox(height: 8),
              ]);
            },
          ),
        ),
      ),
    ]);
  }
}

class _CompareChip extends StatelessWidget {
  const _CompareChip({required this.code, required this.color, this.dropdown = false});

  final String code;
  final Color color;
  final bool dropdown;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          if (dropdown) Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.muted),
        ]),
      );
}

/// Pilotun ana ekrandaki göstergesinin (hız, gaz, fren, rpm, vites) minyatürü; üstünde çizgi renginde kod.
class _CompareGauge extends StatelessWidget {
  const _CompareGauge({required this.data, required this.driver, required this.color, required this.time});

  final ReplayData data;
  final ReplayDriver driver;
  final Color color;
  final ValueListenable<double> time;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(driver.code, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        SizedBox(
          key: Key('replay-compare-gauge-${driver.code}'),
          height: 92,
          child: _Gauge(data: data, driver: driver, time: time, compact: true),
        ),
      ]);
}

class _Line {
  const _Line(this.series, this.color);

  final List<double?> series;
  final Color color;
}

/// Aynı ölçekte birden çok çizgi: boş (null) örneklerde kalem kalkar.
class _LinesPainter extends CustomPainter {
  _LinesPainter({required this.lines, required this.maxValue, required this.gridColor});

  final List<_Line> lines;
  final double maxValue;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), grid);
    canvas.drawLine(Offset.zero, Offset(size.width, 0), grid);
    for (final line in lines) {
      final series = line.series;
      if (series.length < 2) continue;
      final path = Path();
      var penDown = false;
      for (var i = 0; i < series.length; i++) {
        final value = series[i];
        if (value == null) {
          penDown = false;
          continue;
        }
        final dx = size.width * i / (series.length - 1);
        final dy = size.height * (1 - (value / maxValue).clamp(0.0, 1.0));
        if (penDown) {
          path.lineTo(dx, dy);
        } else {
          path.moveTo(dx, dy);
          penDown = true;
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) => true;
}

// ---------------------------------------------------------------------------- Hava durumu şeridi

/// Harita kartının üstünde duran tek satırlık pist hava durumu. Ölçüm yoksa görünmez.
class ReplayWeatherStrip extends StatelessWidget {
  const ReplayWeatherStrip({super.key, required this.data, required this.time});

  final ReplayData data;
  final ValueListenable<double> time;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: time,
        builder: (context, t, _) {
          final weather = data.weatherAt(t);
          if (weather == null) return const SizedBox.shrink();
          final raining = weather.raining;
          final air = weather.air;
          final track = weather.track;
          final humidity = weather.humidity;
          final wind = weather.wind;
          final items = <Widget>[
            if (raining != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(raining ? Icons.water_drop_outlined : Icons.wb_sunny_outlined, size: 15, color: raining ? _blue : AppColors.amber),
                const SizedBox(width: 4),
                Text(raining ? 'Yağmurlu' : 'Kuru', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
              ]),
            if (air != null) _WeatherValue(label: 'Hava', value: '${air.round()}°'),
            if (track != null) _WeatherValue(label: 'Pist', value: '${track.round()}°'),
            if (humidity != null) _WeatherValue(label: 'Nem', value: '%$humidity'),
            if (wind != null) _WeatherValue(label: 'Rüzgâr', value: '${wind.round()} km/sa'),
          ];
          if (items.isEmpty) return const SizedBox.shrink();
          return Container(
            height: 28,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  items[i],
                ],
              ]),
            ),
          );
        },
      );
}

class _WeatherValue extends StatelessWidget {
  const _WeatherValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ', style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
        Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
      ]);
}

// ---------------------------------------------------------------------------- Masaüstü kartları için açık sarmalayıcılar
// Mobil PageView akışı değişmeden kalır; yalnızca masaüstü düzeni bu parçaları yeniden kullanır.

class ReplayPositionListCard extends StatelessWidget {
  const ReplayPositionListCard({super.key, required this.data, required this.time, required this.selected, required this.onSelect});

  final ReplayData data;
  final ValueListenable<double> time;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => _PositionList(data: data, time: time, selected: selected, onSelect: onSelect);
}

class ReplayTelemetryDesktop extends StatelessWidget {
  const ReplayTelemetryDesktop({super.key, required this.data, required this.driver, required this.time, required this.slowTime});

  final ReplayData data;
  final ReplayDriver driver;
  final ValueListenable<double> time;
  final ValueListenable<double> slowTime;

  @override
  Widget build(BuildContext context) {
    if (!driver.hasTelemetry) {
      return Center(child: Text('Bu pilot için telemetri verisi yok.', style: TextStyle(color: AppColors.muted, fontSize: 11)));
    }
    return Row(children: [
      SizedBox(width: 176, height: 176, child: _Gauge(data: data, driver: driver, time: time)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(driver.surname.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        if (driver.team.isNotEmpty)
          Text(driver.team, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 10)),
        ValueListenableBuilder<double>(
          valueListenable: slowTime,
          builder: (context, t, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LapTyreRow(data: data, driver: driver, t: t),
            _SectorBars(states: data.sectorStatesAt(driver, t)),
          ]),
        ),
      ])),
    ]);
  }
}

class ReplaySpeedGraphCard extends StatelessWidget {
  const ReplaySpeedGraphCard({super.key, required this.data, required this.driver, required this.time});
  final ReplayData data;
  final ReplayDriver driver;
  final ValueListenable<double> time;
  @override
  Widget build(BuildContext context) => _SpeedPage(data: data, driver: driver, time: time);
}

class ReplayLapTimesCard extends StatelessWidget {
  const ReplayLapTimesCard({super.key, required this.data, required this.driver, required this.time});
  final ReplayData data;
  final ReplayDriver driver;
  final ValueListenable<double> time;
  @override
  Widget build(BuildContext context) => _LapTimesPage(data: data, driver: driver, time: time);
}

class ReplayPitStopsCard extends StatelessWidget {
  const ReplayPitStopsCard({super.key, required this.data, required this.time, required this.onOpen});
  final ReplayData data;
  final ValueListenable<double> time;
  final ValueChanged<ReplayPit> onOpen;
  @override
  Widget build(BuildContext context) => _PitTab(data: data, time: time, onOpen: onOpen);
}

class ReplayEventsCard extends StatelessWidget {
  const ReplayEventsCard({super.key, required this.data, required this.time, required this.onOpen});
  final ReplayData data;
  final ValueListenable<double> time;
  final ValueChanged<ReplayEvent> onOpen;
  @override
  Widget build(BuildContext context) => _EventsPage(data: data, time: time, onOpen: onOpen);
}

class ReplayCompareCard extends StatelessWidget {
  const ReplayCompareCard({super.key, required this.data, required this.driver, required this.rival, required this.time, required this.slowTime, required this.onPickRival});
  final ReplayData data;
  final ReplayDriver? driver;
  final ReplayDriver? rival;
  final ValueListenable<double> time;
  final ValueListenable<double> slowTime;
  final VoidCallback onPickRival;
  @override
  Widget build(BuildContext context) => _ComparePage(
        data: data,
        driver: driver,
        rival: rival,
        time: time,
        slowTime: slowTime,
        onPickRival: onPickRival,
      );
}
