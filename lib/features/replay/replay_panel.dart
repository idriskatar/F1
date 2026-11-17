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

/// Oynatıcının alt bölümü: solda sıralama listesi, sağda sayfalı pilot kartı
/// (Telemetri · Hız grafiği · Pit stoplar).
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

  @override
  State<ReplayLowerPanel> createState() => _ReplayLowerPanelState();
}

class _ReplayLowerPanelState extends State<ReplayLowerPanel> {
  static const _titles = ['Telemetri', 'Hız grafiği', 'Pit stoplar'];

  final PageController _pages = PageController();
  int _page = 0;

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
          width: 112,
          child: _PositionList(data: data, time: widget.slowTime, selected: widget.selected, onSelect: widget.onSelect),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(children: [
            _PageDots(titles: _titles, index: _page, onTap: _goTo),
            const SizedBox(height: 2),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _DriverCard(data: data, driver: driver, time: widget.time, slowTime: widget.slowTime, onClose: widget.onClose),
                  _SpeedPage(data: data, driver: driver, time: widget.time),
                  _PitTab(data: data, time: widget.slowTime, onOpen: widget.onOpenPit),
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
  static const _rowHeight = 32.0;
  final ScrollController _scroll = ScrollController();

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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 0, 4),
        child: Text(
          live ? 'SIRALAMA' : 'BİTİŞ SIRASI',
          style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
      ),
      Expanded(
        child: ValueListenableBuilder<double>(
          valueListenable: widget.time,
          builder: (context, t, _) {
            final order = widget.data.orderAt(t);
            return ListView.builder(
              controller: _scroll,
              itemExtent: _rowHeight,
              itemCount: order.length,
              itemBuilder: (context, i) {
                final driver = order[i];
                final rank = live ? driver.rankAt(t) : driver.position;
                return _PositionRow(
                  rank: rank == null ? '–' : '$rank',
                  driver: driver,
                  selected: driver.code == widget.selected,
                  inPit: widget.data.inPit(driver.code, t),
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
  const _PositionRow({required this.rank, required this.driver, required this.selected, required this.inPit, required this.onTap});

  final String rank;
  final ReplayDriver driver;
  final bool selected;
  final bool inPit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface2 : null,
            borderRadius: BorderRadius.circular(6),
            border: selected ? Border.all(color: AppColors.red, width: 1.2) : null,
          ),
          child: Row(children: [
            SizedBox(width: 22, child: Text(rank, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(color: Color(driver.colorValue), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(
              driver.code,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: inPit ? AppColors.amber : null),
            ),
          ]),
        ),
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
  const _Gauge({required this.data, required this.driver, required this.time});

  final ReplayData data;
  final ReplayDriver driver;
  final ValueListenable<double> time;

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
                        Text('KM/SA', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(rpm == null ? '—' : '${rpm.round()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.1)),
                        Text('RPM', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.94),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(gear == null ? '' : 'V$gear', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                      if (drs)
                        Text('  DRS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.green)),
                    ]),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Text('GAZ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.green)),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text('FREN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.red)),
                  ),
                ]),
              ),
            );
          });
        },
      );
}

/// Dış halka: hız (0–360 km/sa). İç sol yay: gaz, iç sağ yay: fren. Alt kısımda 90° boşluk.
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
  static const _half = 3 * math.pi / 4; // iç yayların her biri 135°

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerWidth = size.width * 0.07;
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

    canvas.drawArc(inner, _start, _half, false, stroke(innerWidth, trackColor));
    canvas.drawArc(inner, _start + _half, _half, false, stroke(innerWidth, trackColor));
    if (throttle > 0) canvas.drawArc(inner, _start, _half * throttle, false, stroke(innerWidth, throttleColor));
    if (brake > 0) {
      // Fren yayı sağ alttan yukarı doğru dolar.
      canvas.drawArc(inner, _start + 2 * _half - _half * brake, _half * brake, false, stroke(innerWidth, brakeColor));
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
