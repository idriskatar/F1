import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../core/models/replay_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/replay_repository.dart';
import '../../shared/widgets/section_title.dart';

String _clock(double seconds) {
  final total = seconds.isNaN || seconds < 0 ? 0 : seconds.floor();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// Hazır replay'lerin listesi. [repository] verilmezse kendi deposunu oluşturur ve kapatır.
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key, this.repository, this.embedded = false, this.active = true});

  final ReplayRepository? repository;

  /// true: ana iskeletin alt gezinme sekmesi olarak (kendi Scaffold/AppBar'ı olmadan) çizilir.
  final bool embedded;

  /// false iken veri istenmez; sekme ilk kez açılınca liste yüklenir.
  final bool active;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late final ReplayRepository _repository;
  late final bool _ownsRepository;
  Future<ReplayIndex>? _index;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? ReplayRepository();
    if (widget.active) _index = _repository.fetchIndex();
  }

  @override
  void didUpdateWidget(covariant ReplayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && _index == null) _index = _repository.fetchIndex();
  }

  @override
  void dispose() {
    if (_ownsRepository) _repository.close();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _index = _repository.fetchIndex();
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Yarış replay')),
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody() {
    final future = _index;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<ReplayIndex>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(
            icon: Icons.cloud_off_rounded,
            text: '${snapshot.error}',
            action: FilledButton(onPressed: _reload, child: const Text('Tekrar dene')),
          );
        }
        final index = snapshot.data!;
        if (index.sessions.isEmpty) {
          return _Message(
            icon: Icons.hourglass_empty_rounded,
            text: 'Henüz hazır replay yok. Yarış verisi yayınlandıktan sonra otomatik eklenir.',
            action: FilledButton.tonal(onPressed: _reload, child: const Text('Yenile')),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            try {
              await _index;
            } catch (_) {
              // Hata FutureBuilder tarafından gösterilir.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.embedded) ...[
                const SectionTitle('Yarış replay'),
                const SizedBox(height: 4),
              ],
              Text('Konum ve telemetriyle yarışı yeniden izle', style: TextStyle(color: AppColors.muted)),
              if (index.isCached)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Çevrimdışı kopya gösteriliyor', style: TextStyle(color: AppColors.amber, fontSize: 12)),
                ),
              const SizedBox(height: 16),
              for (final entry in index.sessions)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(Icons.play_circle_outline_rounded, color: AppColors.red),
                    title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${entry.sessionLabel} · ${entry.year} · Yarış ${entry.round} · ${_clock(entry.duration)}',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => ReplayPlayerScreen(repository: _repository, entry: entry)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

/// Tek bir seansı indirir ve oynatıcıyı gösterir.
class ReplayPlayerScreen extends StatefulWidget {
  const ReplayPlayerScreen({super.key, required this.repository, required this.entry});

  final ReplayRepository repository;
  final ReplayIndexEntry entry;

  @override
  State<ReplayPlayerScreen> createState() => _ReplayPlayerScreenState();
}

class _ReplayPlayerScreenState extends State<ReplayPlayerScreen> {
  late Future<ReplayData> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.repository.fetchSession(widget.entry);
  }

  void _retry() {
    setState(() {
      _data = widget.repository.fetchSession(widget.entry);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.entry.name)),
        body: SafeArea(
          child: FutureBuilder<ReplayData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _Message(icon: Icons.downloading_rounded, text: 'Replay verisi hazırlanıyor…');
              }
              if (snapshot.hasError) {
                return _Message(
                  icon: Icons.error_outline_rounded,
                  text: '${snapshot.error}',
                  action: FilledButton(onPressed: _retry, child: const Text('Tekrar dene')),
                );
              }
              return _ReplayView(data: snapshot.data!);
            },
          ),
        ),
      );
}

class _ReplayView extends StatefulWidget {
  const _ReplayView({required this.data});

  final ReplayData data;

  @override
  State<_ReplayView> createState() => _ReplayViewState();
}

class _ReplayViewState extends State<_ReplayView> with SingleTickerProviderStateMixin {
  static const _speeds = <double>[1, 2, 5, 10, 30, 60];

  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  final Map<String, TextPainter> _labels = {};
  Duration _lastElapsed = Duration.zero;
  bool _playing = false;
  bool _showNames = true;
  double _speed = 10;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.data.drivers.isNotEmpty) _selected = widget.data.drivers.first.code;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    final next = _time.value + dt * _speed;
    if (next >= widget.data.duration) {
      _time.value = widget.data.duration;
      _pause();
    } else {
      _time.value = next;
    }
  }

  void _play() {
    if (_time.value >= widget.data.duration) _time.value = 0;
    _lastElapsed = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    setState(() => _playing = true);
  }

  void _pause() {
    if (_ticker.isActive) _ticker.stop();
    if (mounted) setState(() => _playing = false);
  }

  void _seek(double seconds) => _time.value = seconds.clamp(0.0, widget.data.duration).toDouble();

  void _select(String code) => setState(() => _selected = code);

  void _onTapTrack(Offset local, Size size) {
    final fit = _Fit.of(size, widget.data);
    final t = _time.value;
    String? best;
    var bestDistance = 28.0;
    for (final driver in widget.data.drivers) {
      final point = driver.positionAt(t, widget.data.hz);
      if (point == null) continue;
      final distance = (fit.map(point.x, point.y) - local).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = driver.code;
      }
    }
    if (best != null) _select(best);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(children: [
      ValueListenableBuilder<double>(
        valueListenable: _time,
        builder: (context, t, _) {
          final inPits = [
            for (final d in data.drivers)
              if (data.inPit(d.code, t)) d.code,
          ];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              Text('Tur ${data.lapAt(t)}/${data.totalLaps}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 14),
              Text('${_clock(t)} / ${_clock(data.duration)}', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  inPits.isEmpty ? '' : 'Pitte: ${inPits.join(' · ')}',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          );
        },
      ),
      Expanded(
        flex: 5,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _onTapTrack(details.localPosition, size),
                  child: CustomPaint(
                    size: size,
                    painter: _TrackPainter(
                      data: data,
                      time: _time,
                      selected: _selected,
                      showNames: _showNames,
                      labels: _labels,
                      trackColor: AppColors.surface2,
                      edgeColor: AppColors.border,
                      labelColor: AppColors.muted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          IconButton(tooltip: '10 sn geri', onPressed: () => _seek(_time.value - 10), icon: const Icon(Icons.replay_10_rounded)),
          IconButton.filled(
            tooltip: _playing ? 'Duraklat' : 'Oynat',
            onPressed: _playing ? _pause : _play,
            icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          IconButton(tooltip: '10 sn ileri', onPressed: () => _seek(_time.value + 10), icon: const Icon(Icons.forward_10_rounded)),
          const Spacer(),
          PopupMenuButton<double>(
            tooltip: 'Oynatma hızı',
            initialValue: _speed,
            onSelected: (value) => setState(() => _speed = value),
            itemBuilder: (context) => [
              for (final s in _speeds) PopupMenuItem<double>(value: s, child: Text('${s.toStringAsFixed(0)}×')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('${_speed.toStringAsFixed(0)}×', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          IconButton(
            tooltip: 'Pilot kodlarını göster/gizle',
            onPressed: () => setState(() => _showNames = !_showNames),
            icon: Icon(Icons.label_outline, color: _showNames ? AppColors.red : AppColors.muted),
          ),
        ]),
      ),
      ValueListenableBuilder<double>(
        valueListenable: _time,
        builder: (context, t, _) => Slider(
          value: t.clamp(0.0, data.duration).toDouble(),
          max: data.duration,
          onChanged: _seek,
        ),
      ),
      Expanded(
        flex: 4,
        child: DefaultTabController(
          length: 2,
          child: Column(children: [
            const TabBar(tabs: [Tab(text: 'Telemetri'), Tab(text: 'Pit stoplar')]),
            Expanded(
              child: TabBarView(children: [
                _TelemetryTab(data: data, time: _time, selected: _selected, onSelect: _select),
                _PitTab(
                  data: data,
                  time: _time,
                  onOpen: (pit) {
                    _select(pit.driver);
                    _seek(pit.inTime - 5);
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Pist koordinatlarını ekrana oturtur. F1 y ekseni yukarı olduğu için y çevrilir.
class _Fit {
  const _Fit(this.scale, this.dx, this.dy, this.minX, this.maxY);

  final double scale;
  final double dx;
  final double dy;
  final double minX;
  final double maxY;

  factory _Fit.of(Size size, ReplayData data, {double padding = 20}) {
    final w = math.max(data.maxX - data.minX, 1.0);
    final h = math.max(data.maxY - data.minY, 1.0);
    final availableW = math.max(size.width - padding * 2, 1.0);
    final availableH = math.max(size.height - padding * 2, 1.0);
    final scale = math.min(availableW / w, availableH / h);
    return _Fit(scale, (size.width - w * scale) / 2, (size.height - h * scale) / 2, data.minX, data.maxY);
  }

  Offset map(double x, double y) => Offset(dx + (x - minX) * scale, dy + (maxY - y) * scale);
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.data,
    required this.time,
    required this.selected,
    required this.showNames,
    required this.labels,
    required this.trackColor,
    required this.edgeColor,
    required this.labelColor,
  }) : super(repaint: time);

  final ReplayData data;
  final ValueListenable<double> time;
  final String? selected;
  final bool showNames;
  final Map<String, TextPainter> labels;
  final Color trackColor;
  final Color edgeColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = _Fit.of(size, data);
    final path = Path();
    for (var i = 0; i < data.trackX.length; i++) {
      final o = fit.map(data.trackX[i], data.trackY[i]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke..strokeWidth = 17..color = edgeColor);
    canvas.drawPath(path, stroke..strokeWidth = 12..color = trackColor);

    final t = time.value;
    // Lider en üstte görünsün diye sondan başa çiz; seçili pilot her zaman en üstte.
    for (final driver in data.drivers.reversed) {
      if (driver.code != selected) _drawCar(canvas, fit, driver, t, false);
    }
    final chosen = data.driverByCode(selected);
    if (chosen != null) _drawCar(canvas, fit, chosen, t, true);
  }

  void _drawCar(Canvas canvas, _Fit fit, ReplayDriver driver, double t, bool isSelected) {
    final point = driver.positionAt(t, data.hz);
    if (point == null) return;
    final o = fit.map(point.x, point.y);
    final inPit = data.inPit(driver.code, t);
    final radius = isSelected ? 8.5 : 6.0;
    canvas.drawCircle(o, radius, Paint()..color = Color(driver.colorValue));
    canvas.drawCircle(
      o,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = inPit ? 3 : 1.5
        ..color = inPit ? AppColors.amber : Colors.white,
    );
    if (showNames || isSelected) {
      final label = labels.putIfAbsent(driver.code, () {
        final painter = TextPainter(
          text: TextSpan(text: driver.code, style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
        );
        painter.layout();
        return painter;
      });
      label.paint(canvas, Offset(o.dx + radius + 2, o.dy - 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) =>
      old.data != data || old.selected != selected || old.showNames != showNames || old.trackColor != trackColor;
}

class _TelemetryTab extends StatelessWidget {
  const _TelemetryTab({required this.data, required this.time, required this.selected, required this.onSelect});

  final ReplayData data;
  final ValueListenable<double> time;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final driver = data.driverByCode(selected);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 20), children: [
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: data.drivers.length,
          separatorBuilder: (context, index) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final d = data.drivers[i];
            return ChoiceChip(
              label: Text(d.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              avatar: CircleAvatar(radius: 5, backgroundColor: Color(d.colorValue)),
              selected: d.code == selected,
              onSelected: (_) => onSelect(d.code),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      if (driver == null)
        Text('Pistte bir araca dokun ya da yukarıdan pilot seç.', style: TextStyle(color: AppColors.muted))
      else
        _DriverPanel(data: data, driver: driver, time: time),
    ]);
  }
}

class _DriverPanel extends StatelessWidget {
  const _DriverPanel({required this.data, required this.driver, required this.time});

  final ReplayData data;
  final ReplayDriver driver;
  final ValueListenable<double> time;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${driver.position != null ? 'P${driver.position} · ' : ''}${driver.name.isEmpty ? driver.code : driver.name}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        if (driver.team.isNotEmpty) Text(driver.team, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),
        if (!driver.hasTelemetry)
          Text('Bu pilot için telemetri verisi yok.', style: TextStyle(color: AppColors.muted))
        else
          ValueListenableBuilder<double>(
            valueListenable: time,
            builder: (context, t, _) {
              final speed = driver.speedAt(t, data.hz);
              final gear = driver.gearAt(t, data.hz);
              final throttle = driver.throttleAt(t, data.hz);
              final brake = driver.brakeAt(t, data.hz) ?? false;
              final drs = driver.drsAt(t, data.hz) ?? false;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(speed == null ? '—' : '${speed.round()}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 4),
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('km/sa', style: TextStyle(color: AppColors.muted, fontSize: 12))),
                  const SizedBox(width: 18),
                  Text(gear == null ? '—' : 'V$gear', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  _Badge(label: 'FREN', active: brake, color: AppColors.red),
                  const SizedBox(width: 6),
                  _Badge(label: 'DRS', active: drs, color: AppColors.green),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: ((throttle ?? 0) / 100).clamp(0.0, 1.0).toDouble(), minHeight: 8),
                ),
                const SizedBox(height: 2),
                Text('Gaz', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 70,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SpeedPainter(
                      series: driver.speedSeries(math.max(0.0, t - 60), t, data.hz),
                      lineColor: Color(driver.colorValue),
                      gridColor: AppColors.border,
                    ),
                  ),
                ),
                Text('Son 60 sn hız', style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ]);
            },
          ),
      ]);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.active, required this.color});

  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: active ? Colors.white : AppColors.muted),
        ),
      );
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
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
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
            subtitle: Text('Giriş ${_clock(pit.inTime)}', style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
