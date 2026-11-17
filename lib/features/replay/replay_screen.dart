import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../core/models/replay_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/replay_repository.dart';
import 'replay_panel.dart';
import '../../shared/widgets/section_title.dart';

String _clock(double seconds) => formatReplayClock(seconds);

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
  // Sıralama, tur, sektör ve pit vurgusu için ~0,5 sn'de bir güncellenen zaman (her karede yeniden çizmemek için).
  final ValueNotifier<double> _slowTime = ValueNotifier<double>(0);
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
    _time.addListener(_syncSlowTime);
    if (widget.data.drivers.isNotEmpty) _selected = widget.data.drivers.first.code;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.removeListener(_syncSlowTime);
    _slowTime.dispose();
    _time.dispose();
    super.dispose();
  }

  void _syncSlowTime() {
    if ((_time.value - _slowTime.value).abs() >= 0.5) _slowTime.value = _time.value;
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

  void _clearSelection() => setState(() => _selected = null);

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
        child: ReplayLowerPanel(
          data: data,
          time: _time,
          slowTime: _slowTime,
          selected: _selected,
          onSelect: _select,
          onClose: _clearSelection,
          onOpenPit: (pit) {
            _select(pit.driver);
            _seek(pit.inTime - 5);
          },
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
