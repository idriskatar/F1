import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/models/replay_models.dart';
import '../../core/theme/app_theme.dart';
import 'replay_panel.dart' show replayCompoundColor, replayEventColor;

const _codeWidth = 44.0;
const _stopsWidth = 52.0;

/// Tüm pilotların lastik stratejisi: her pilot için turlara yayılmış stint çubuğu.
/// Safety car, VSC ve kırmızı bayrak turları çubukların arkasında renkli bant olarak görünür.
class ReplayStrategyScreen extends StatelessWidget {
  const ReplayStrategyScreen({super.key, required this.data});

  final ReplayData data;

  /// Çubukların kapsadığı tur sayısı: toplam tur ile en uzun stint'in büyüğü.
  int get _laps {
    var laps = data.totalLaps;
    for (final driver in data.drivers) {
      for (final stint in driver.stints) {
        final end = stint.lapEnd ?? stint.lapStart;
        if (end > laps) laps = end;
      }
    }
    return math.max(laps, 1);
  }

  @override
  Widget build(BuildContext context) {
    final laps = _laps;
    final bands = [
      for (final period in data.periods)
        _StrategyBand(first: data.lapAt(period.time), last: data.lapAt(period.end ?? period.time), color: replayEventColor(period.kind)),
    ];
    final drivers = [
      for (final driver in data.drivers)
        if (driver.stints.isNotEmpty) driver,
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Lastik stratejisi · ${data.event.name}')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _Legend(showNeutral: data.periods.isNotEmpty),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const SizedBox(width: _codeWidth),
              Expanded(
                child: SizedBox(
                  height: 16,
                  child: CustomPaint(painter: _AxisPainter(laps: laps, color: AppColors.muted)),
                ),
              ),
              const SizedBox(width: _stopsWidth),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: drivers.isEmpty
                ? Center(child: Text('Bu seansta lastik verisi yok.', style: TextStyle(color: AppColors.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: drivers.length,
                    itemBuilder: (context, i) => _StrategyRow(driver: drivers[i], laps: laps, bands: bands),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _StrategyBand {
  const _StrategyBand({required this.first, required this.last, required this.color});

  final int first;
  final int last;
  final Color color;
}

class _StrategyRow extends StatelessWidget {
  const _StrategyRow({required this.driver, required this.laps, required this.bands});

  final ReplayDriver driver;
  final int laps;
  final List<_StrategyBand> bands;

  @override
  Widget build(BuildContext context) {
    final stops = driver.stints.length - 1;
    return Padding(
      key: Key('strategy-row-${driver.code}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(children: [
        SizedBox(
          width: _codeWidth,
          child: Text(driver.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: CustomPaint(
              painter: _StintPainter(stints: driver.stints, laps: laps, bands: bands),
            ),
          ),
        ),
        SizedBox(
          width: _stopsWidth,
          child: Text('$stops pit', textAlign: TextAlign.end, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ]),
    );
  }
}

class _StintPainter extends CustomPainter {
  _StintPainter({required this.stints, required this.laps, required this.bands});

  final List<ReplayStint> stints;
  final int laps;
  final List<_StrategyBand> bands;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / laps;
    for (final band in bands) {
      canvas.drawRect(
        Rect.fromLTRB((band.first - 1) * unit, 0, band.last * unit, size.height),
        Paint()..color = band.color.withValues(alpha: .22),
      );
    }
    for (final stint in stints) {
      final first = math.max(stint.lapStart, 1);
      final last = math.min(stint.lapEnd ?? laps, laps);
      if (last < first) continue;
      final rect = Rect.fromLTRB((first - 1) * unit + 1, 3, last * unit - 1, size.height - 3);
      final fill = replayCompoundColor(stint.letter);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = fill);
      if (rect.width >= 16) {
        final dark = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark;
        final painter = TextPainter(
          text: TextSpan(
            text: stint.letter,
            style: TextStyle(color: dark ? Colors.white : const Color(0xFF111111), fontSize: 11, fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(rect.left + (rect.width - painter.width) / 2, rect.top + (rect.height - painter.height) / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StintPainter old) => old.stints != stints || old.laps != laps || old.bands != bands;
}

class _AxisPainter extends CustomPainter {
  _AxisPainter({required this.laps, required this.color});

  final int laps;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final step = laps > 30 ? 10 : 5;
    final marks = <int>[1, for (var lap = step; lap <= laps; lap += step) lap];
    for (final lap in marks) {
      final painter = TextPainter(
        text: TextSpan(text: '$lap', style: TextStyle(color: color, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      final center = (lap - 0.5) / laps * size.width;
      final x = math.min(math.max(center - painter.width / 2, 0.0), math.max(size.width - painter.width, 0.0));
      painter.paint(canvas, Offset(x, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _AxisPainter old) => old.laps != laps || old.color != color;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.showNeutral});

  final bool showNeutral;

  static const _compounds = <(String, String)>[
    ('S', 'Soft'),
    ('M', 'Medium'),
    ('H', 'Hard'),
    ('I', 'Intermediate'),
    ('W', 'Wet'),
  ];

  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 6, children: [
        for (final (letter, name) in _compounds) _LegendItem(color: replayCompoundColor(letter), label: name),
        if (showNeutral) ...[
          _LegendItem(color: replayEventColor(ReplayEventKind.safetyCar).withValues(alpha: .5), label: 'SC / VSC'),
          _LegendItem(color: replayEventColor(ReplayEventKind.redFlag).withValues(alpha: .5), label: 'Kırmızı bayrak'),
        ],
      ]);
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ]);
}
