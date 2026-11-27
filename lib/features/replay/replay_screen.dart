import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../core/models/replay_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/replay_repository.dart';
import '../shell/shell_page_opener.dart';
import 'replay_panel.dart';
import 'replay_strategy.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/responsive.dart';

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
  int? _yearFilter;

  /// null: hepsi, false: yalnız yarışlar, true: yalnız sprintler.
  bool? _sprintFilter;

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
        final years = ({for (final e in index.sessions) e.year}.toList()..sort((a, b) => b.compareTo(a)));
        final hasSprints = index.sessions.any((e) => e.session == 'S');
        final hasRaces = index.sessions.any((e) => e.session != 'S');
        final visible = [
          for (final e in index.sessions)
            if ((_yearFilter == null || e.year == _yearFilter) && (_sprintFilter == null || (e.session == 'S') == _sprintFilter)) e,
        ];
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
              // Süzgeç yalnızca seçilecek bir şey varken görünür (tek yıl ve tek seans türünde gizli).
              if (years.length > 1 || (hasSprints && hasRaces))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(spacing: 8, runSpacing: 4, children: [
                    if (years.length > 1) ...[
                      ChoiceChip(label: const Text('Tüm yıllar'), selected: _yearFilter == null, onSelected: (_) => setState(() => _yearFilter = null)),
                      for (final year in years)
                        ChoiceChip(label: Text('$year'), selected: _yearFilter == year, onSelected: (_) => setState(() => _yearFilter = year)),
                    ],
                    if (hasSprints && hasRaces) ...[
                      ChoiceChip(label: const Text('Yarış ve sprint'), selected: _sprintFilter == null, onSelected: (_) => setState(() => _sprintFilter = null)),
                      ChoiceChip(label: const Text('Yalnız yarışlar'), selected: _sprintFilter == false, onSelected: (_) => setState(() => _sprintFilter = false)),
                      ChoiceChip(label: const Text('Yalnız sprintler'), selected: _sprintFilter == true, onSelected: (_) => setState(() => _sprintFilter = true)),
                    ],
                  ]),
                ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Bu süzgece uyan replay yok.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                ),
              for (final entry in visible) _SessionCard(repository: _repository, entry: entry),
            ],
          ),
        );
      },
    );
  }
}

/// Listedeki tek seans: ad (sprintse rozetle), pist ve ülke, ardından tür · yıl · tur · süre.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.repository, required this.entry});

  final ReplayRepository repository;
  final ReplayIndexEntry entry;

  @override
  Widget build(BuildContext context) {
    // Aynı ülkede birden çok yarış olabildiği için (ör. ABD) pist adı ayırt edicidir.
    final place = [entry.circuit, entry.country].where((part) => part.isNotEmpty).join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        isThreeLine: place.isNotEmpty,
        leading: Icon(Icons.play_circle_outline_rounded, color: AppColors.red),
        title: Row(children: [
          Flexible(child: Text(entry.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
          if (entry.session == 'S') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: .16), borderRadius: BorderRadius.circular(6)),
              child: Text('SPRINT', style: TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ],
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (place.isNotEmpty) Text(place, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          Text(
            '${entry.sessionLabel} · ${entry.year} · Yarış ${entry.round} · ${_clock(entry.duration)}',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ]),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          final player = ReplayPlayerScreen(repository: repository, entry: entry, embedded: true);
          final opener = ShellPageOpener.maybeOf(context);
          if (opener != null) {
            opener.open(player);
          } else {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReplayPlayerScreen(repository: repository, entry: entry)));
          }
        },
      ),
    );
  }
}

/// Masaüstü lastik stratejisi kartı: ilk 4 pilotun stint şeritleri.
class _DesktopStrategy extends StatefulWidget {
  const _DesktopStrategy({required this.data});
  final ReplayData data;

  @override
  State<_DesktopStrategy> createState() => _DesktopStrategyState();
}

class _DesktopStrategyState extends State<_DesktopStrategy> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drivers = widget.data.drivers.where((d) => d.stints.isNotEmpty).toList();
    if (drivers.isEmpty) {
      return Center(child: Text('Strateji verisi yok.', style: TextStyle(color: AppColors.muted, fontSize: 11)));
    }
    return Listener(
      onPointerSignal: (signal) {
        if (signal is! PointerScrollEvent) return;
        final next = (_scroll.offset + signal.scrollDelta.dy).clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.jumpTo(next);
      },
      child: SingleChildScrollView(
        controller: _scroll,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final d in drivers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 34, child: Text(d.code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Row(children: [
                      for (final s in d.stints) ...[
                        Expanded(
                          flex: ((s.lapEnd ?? (s.lapStart + 1)) - s.lapStart + 1) < 1 ? 1 : ((s.lapEnd ?? (s.lapStart + 1)) - s.lapStart + 1),
                          child: Container(height: 10, color: _stintColor(s.letter)),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

Color _stintColor(String letter) => switch (letter) {
  'S' => const Color(0xFFFF3B30),
  'M' => const Color(0xFFFFC247),
  'H' => const Color(0xFFD0D4DA),
  'I' => const Color(0xFF52E252),
  'W' => const Color(0xFF2F6BFF),
  _ => const Color(0xFF9299A6),
};

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
  const ReplayPlayerScreen({super.key, required this.repository, required this.entry, this.embedded = false});

  final ReplayRepository repository;
  final ReplayIndexEntry entry;

  /// Masaüstünde kabuğun içinde, sol gezinme rayı korunarak gösterilir.
  final bool embedded;

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
  Widget build(BuildContext context) => FutureBuilder<ReplayData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final ready = !snapshot.hasError && data != null && snapshot.connectionState != ConnectionState.waiting;
          // Yatayda AppBar yoktur: ad, geri ve strateji düğmesi haritanın üstündeki satırda yer alır.
          // Scaffold/SafeArea/_ReplayView yapısı iki durumda aynı kaldığı için döndürmek oynatmayı sıfırlamaz.
          final landscape = ready && _useLandscape(MediaQuery.sizeOf(context));
          VoidCallback? openStrategy;
          if (data != null && data.drivers.any((d) => d.stints.isNotEmpty)) {
            openStrategy = () {
              final page = ReplayStrategyScreen(data: data);
              final opener = ShellPageOpener.maybeOf(context);
              if (opener != null) {
                opener.open(page);
              } else {
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
              }
            };
          }
          final Widget body;
          if (snapshot.connectionState == ConnectionState.waiting) {
            body = const _Message(icon: Icons.downloading_rounded, text: 'Replay verisi hazırlanıyor…');
          } else if (snapshot.hasError || data == null) {
            body = _Message(
              icon: Icons.error_outline_rounded,
              text: '${snapshot.error}',
              action: FilledButton(onPressed: _retry, child: const Text('Tekrar dene')),
            );
          } else {
            body = _ReplayView(data: data, landscape: landscape, title: widget.entry.name, onOpenStrategy: openStrategy);
          }
          if (widget.embedded) return body;
          return Scaffold(
            appBar: landscape
                ? null
                : AppBar(
                    title: Text(widget.entry.name),
                    actions: [
                      if (openStrategy != null)
                        IconButton(
                          tooltip: 'Lastik stratejisi',
                          icon: const Icon(Icons.stacked_bar_chart_rounded),
                          onPressed: openStrategy,
                        ),
                    ],
                  ),
            body: SafeArea(child: body),
          );
        },
      );
}

/// Geniş ve belirgin biçimde yatay ekran: ekran ikiye bölünür. 700 dp altında yarım ekran (350 dp)
/// kontrol satırını ve pilot panelini sığdıramaz; orada dikey düzen kalır.
bool _useLandscape(Size size) => size.width >= 700 && size.width > size.height * 1.15;

class _ReplayView extends StatefulWidget {
  const _ReplayView({required this.data, this.landscape = false, this.title = '', this.onOpenStrategy});

  final ReplayData data;

  /// true: ekran ikiye bölünür (solda ad/tur/harita, sağda kontroller ve pilot paneli).
  final bool landscape;

  /// Yatayda üst satırda gösterilen yarış adı (AppBar yok).
  final String title;
  final VoidCallback? onOpenStrategy;

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
  String? _rivalCode;

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

  void _jumpLap({required bool forward}) => _seek(widget.data.lapJumpTarget(_time.value, forward: forward));

  Future<void> _pickLap() async {
    final data = widget.data;
    final target = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _LapPicker(data: data, current: data.lapAt(_time.value)),
    );
    if (target != null && mounted) _seek(target);
  }

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
    if (isDesktopLayout(context)) return _buildDesktop(data);
    if (!widget.landscape) {
      return Column(children: [
        _buildHeader(data, const EdgeInsets.fromLTRB(16, 0, 20, 4)),
        Expanded(flex: 5, child: _buildMap(data, const EdgeInsets.symmetric(horizontal: 16))),
        _buildControls(data),
        _ReplayTimeline(data: data, time: _time, selected: _selected, onSeek: _seek),
        Expanded(flex: 4, child: _buildPanel(data)),
      ]);
    }
    // Yatay: sol yarı yarış adı, tur/süre bilgisi ve harita; sağ yarı oynatma kontrolleri,
    // zaman çubuğu ve pilot paneli.
    return Row(key: const Key('replay-landscape'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: Column(children: [
          Row(children: [
            IconButton(
              tooltip: 'Geri',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (widget.onOpenStrategy != null)
              IconButton(
                tooltip: 'Lastik stratejisi',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onOpenStrategy,
                icon: const Icon(Icons.stacked_bar_chart_rounded),
              ),
          ]),
          _buildHeader(data, const EdgeInsets.fromLTRB(12, 0, 12, 4)),
          Expanded(child: _buildMap(data, const EdgeInsets.fromLTRB(16, 0, 8, 12))),
        ]),
      ),
      Expanded(
        child: Column(children: [
          _buildControls(data, compact: true),
          _ReplayTimeline(data: data, time: _time, selected: _selected, onSeek: _seek),
          Expanded(child: _buildPanel(data)),
        ]),
      ),
    ]);
  }

  /// Masaüstü: sol ray korunur, üç kolonlu kart düzeni.
  Widget _buildDesktop(ReplayData data) {
    final selectedDriver = data.driverByCode(_selected);
    final rivals = [for (final d in data.drivers) if (d.hasTelemetry && d.code != _selected) d];
    final rival = _rivalCode == null
        ? (rivals.isEmpty ? null : rivals.first)
        : data.driverByCode(_rivalCode);
    return Column(key: const Key('replay-desktop'), children: [
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 250, child: Column(children: [
          _desktopCard(
            title: 'CANLI SIRALAMA',
            flex: 1,
            child: ReplayPositionListCard(
              data: data,
              time: _slowTime,
              selected: _selected,
              onSelect: _select,
            ),
          ),
        ])),
        const SizedBox(width: 14),
        Expanded(flex: 40, child: Column(children: [
          _desktopCard(
            title: 'TELEMETRİ · SEÇİLİ PİLOT',
            flex: 3,
            child: selectedDriver == null
                ? Center(child: Text('Soldan bir pilot seçin.', style: TextStyle(color: AppColors.muted, fontSize: 11)))
                : ReplayTelemetryDesktop(data: data, driver: selectedDriver, time: _time, slowTime: _slowTime),
          ),
          const SizedBox(height: 12),
          _desktopCard(
            title: 'HIZ GRAFİĞİ · SON 60 SN',
            flex: 1.6,
            child: selectedDriver == null
                ? const SizedBox.shrink()
                : ReplaySpeedGraphCard(data: data, driver: selectedDriver, time: _time),
          ),
          const SizedBox(height: 12),
          _desktopCard(
            title: 'TUR SÜRELERİ',
            flex: 1.2,
            child: selectedDriver == null
                ? const SizedBox.shrink()
                : ReplayLapTimesCard(data: data, driver: selectedDriver, time: _time),
          ),
          const SizedBox(height: 12),
          _desktopCard(
            title: 'PİLOT KARŞILAŞTIRMASI',
            flex: 1.6,
            child: ReplayCompareCard(
              data: data,
              driver: selectedDriver,
              rival: rival,
              time: _time,
              slowTime: _slowTime,
              onPickRival: () {
                if (rivals.isEmpty) return;
                final i = rivals.indexWhere((d) => d.code == rival?.code);
                setState(() => _rivalCode = rivals[(i + 1) % rivals.length].code);
              },
            ),
          ),
        ])),
        const SizedBox(width: 14),
        Expanded(flex: 38, child: Column(children: [
          _desktopCard(title: 'PİST HARİTASI', flex: 3, child: Column(children: [
            ValueListenableBuilder<double>(
              valueListenable: _slowTime,
              builder: (context, t, _) => Text(
                'Tur ${data.lapAt(t)}/${data.totalLaps} · ${_clock(t)}',
                style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            _desktopControls(data),
            const SizedBox(height: 6),
            Expanded(child: _buildMap(data, EdgeInsets.zero)),
          ])),
          const SizedBox(height: 12),
          _desktopCard(title: 'LASTİK STRATEJİSİ · TÜM PİLOTLAR', flex: 2, child: _DesktopStrategy(data: data)),
          const SizedBox(height: 12),
          Expanded(flex: 2, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _desktopCard(title: 'PİT STOPLAR', flex: 1, child: ReplayPitStopsCard(
              data: data,
              time: _slowTime,
              onOpen: (pit) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${pit.driver} · tur ${pit.lap} · pit şeridi ${pit.pitLaneSeconds?.toStringAsFixed(1) ?? '—'} sn')),
              ),
            )),
            const SizedBox(width: 12),
            _desktopCard(title: 'OLAYLAR', flex: 1, child: ReplayEventsCard(
              data: data,
              time: _slowTime,
              onOpen: (event) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(event.badge))),
            )),
          ])),
        ])),
      ])),
    ]);
  }

  Widget _desktopControls(ReplayData data) => Row(children: [
    IconButton(
      tooltip: _playing ? 'Duraklat' : 'Oynat',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      color: AppColors.red,
      onPressed: () => _playing ? _pause() : _play(),
      icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 19),
    ),
    IconButton(
      tooltip: '10 sn geri',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: () => _seek(_time.value - 10),
      icon: const Icon(Icons.rotate_left, size: 17),
    ),
    IconButton(
      tooltip: '10 sn ileri',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: () => _seek(_time.value + 10),
      icon: const Icon(Icons.rotate_right, size: 17),
    ),
    TextButton(
      onPressed: () => setState(() {
        final i = _speeds.indexOf(_speed);
        _speed = _speeds[(i + 1) % _speeds.length];
      }),
      child: Text('${_speed.toInt()}×', style: const TextStyle(fontSize: 11)),
    ),
    Expanded(child: _ReplayTimeline(data: data, time: _time, selected: _selected, onSeek: _seek)),
  ]);

  Widget _desktopCard({required String title, required double flex, required Widget child}) => Expanded(
    flex: flex.round(),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 6),
        Expanded(child: child),
      ]),
    ),
  );

  /// Tur etiketi, saat ve pitteki pilotlar.
  Widget _buildHeader(ReplayData data, EdgeInsets padding) => ValueListenableBuilder<double>(
        valueListenable: _time,
        builder: (context, t, _) {
          final inPits = [
            for (final d in data.drivers)
              if (data.inPit(d.code, t)) d.code,
          ];
          return Padding(
            padding: padding,
            child: Row(children: [
              InkWell(
                key: const Key('replay-lap-label'),
                borderRadius: BorderRadius.circular(8),
                onTap: data.lapStarts.isEmpty ? null : _pickLap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 2, 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Tur ${data.lapAt(t)}/${data.totalLaps}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (data.lapStarts.isNotEmpty) Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.muted),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
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
      );

  /// Pist haritası: araçlar, hava şeridi ve safety car rozeti.
  Widget _buildMap(ReplayData data, EdgeInsets margin) => Container(
        margin: margin,
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
              return Stack(children: [
                Positioned.fill(
                  child: GestureDetector(
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
                  ),
                ),
                if (data.weather.isNotEmpty)
                  Positioned(top: 10, left: 10, right: 10, child: ReplayWeatherStrip(data: data, time: _slowTime)),
                if (data.periods.isNotEmpty)
                  Positioned(
                    top: data.weather.isEmpty ? 10 : 46,
                    left: 10,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _slowTime,
                      builder: (context, t, _) {
                        final period = data.periodAt(t);
                        return period == null ? const SizedBox.shrink() : _PeriodBadge(event: period);
                      },
                    ),
                  ),
              ]);
            },
          ),
        ),
      );

  /// Oynat/duraklat, ±10 sn, tur atlama, hız ve kod göster/gizle. [compact]: yarım ekranda
  /// (yatay mod) sığması için tüm düğmeler küçülür.
  Widget _buildControls(ReplayData data, {bool compact = false}) {
    final density = compact ? VisualDensity.compact : null;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          if (data.lapStarts.isNotEmpty)
            IconButton(
              tooltip: 'Önceki tur',
              visualDensity: VisualDensity.compact,
              onPressed: () => _jumpLap(forward: false),
              icon: const Icon(Icons.skip_previous_rounded),
            ),
          IconButton(
            tooltip: '10 sn geri',
            visualDensity: density,
            onPressed: () => _seek(_time.value - 10),
            icon: const Icon(Icons.replay_10_rounded),
          ),
          IconButton.filled(
            tooltip: _playing ? 'Duraklat' : 'Oynat',
            visualDensity: density,
            onPressed: _playing ? _pause : _play,
            icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: '10 sn ileri',
            visualDensity: density,
            onPressed: () => _seek(_time.value + 10),
            icon: const Icon(Icons.forward_10_rounded),
          ),
          if (data.lapStarts.isNotEmpty)
            IconButton(
              tooltip: 'Sonraki tur',
              visualDensity: VisualDensity.compact,
              onPressed: () => _jumpLap(forward: true),
              icon: const Icon(Icons.skip_next_rounded),
            ),
          const Spacer(),
          PopupMenuButton<double>(
            tooltip: 'Oynatma hızı',
            initialValue: _speed,
            onSelected: (value) => setState(() => _speed = value),
            itemBuilder: (context) => [
              for (final s in _speeds) PopupMenuItem<double>(value: s, child: Text('${s.toStringAsFixed(0)}×')),
            ],
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 8),
              child: Text('${_speed.toStringAsFixed(0)}×', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          IconButton(
            tooltip: 'Pilot kodlarını göster/gizle',
            visualDensity: density,
            onPressed: () => setState(() => _showNames = !_showNames),
            icon: Icon(Icons.label_outline, color: _showNames ? AppColors.red : AppColors.muted),
          ),
        ]),
      );
  }

  Widget _buildPanel(ReplayData data) => ReplayLowerPanel(
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
        onOpenEvent: (event) => _seek(event.time - 5),
      );
}

/// Safety car / VSC / kırmızı bayrak sürerken haritanın köşesinde görünen rozet.
class _PeriodBadge extends StatelessWidget {
  const _PeriodBadge({required this.event});

  final ReplayEvent event;

  @override
  Widget build(BuildContext context) {
    final color = replayEventColor(event.kind);
    final outlined = event.kind == ReplayEventKind.virtualSafetyCar;
    final textColor = outlined
        ? color
        : event.kind == ReplayEventKind.redFlag
            ? Colors.white
            : const Color(0xFF111111);
    return Container(
      key: const Key('replay-period-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: outlined ? color.withValues(alpha: .18) : color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(event.badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textColor)),
    );
  }
}

/// "Tura git" alt sayfası: kısayollar ve tur numaraları. Seçilen anı (sn) döndürür.
class _LapPicker extends StatelessWidget {
  const _LapPicker({required this.data, required this.current});

  final ReplayData data;
  final int current;

  @override
  Widget build(BuildContext context) {
    final total = data.totalLaps;
    final lastLapStart = data.lapStartTime(total);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tura git', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: [
            ActionChip(label: const Text('Yarış başı'), onPressed: () => Navigator.of(context).pop(0.0)),
            if (lastLapStart != null) ActionChip(label: const Text('Son tur'), onPressed: () => Navigator.of(context).pop(lastLapStart)),
            ActionChip(label: const Text('Bitiş'), onPressed: () => Navigator.of(context).pop(data.duration)),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (var lap = 1; lap <= total; lap++)
              if (data.lapStartTime(lap) != null)
                ChoiceChip(
                  key: Key('replay-lap-$lap'),
                  label: Text('$lap'),
                  selected: lap == current,
                  onSelected: (_) => Navigator.of(context).pop(data.lapStartTime(lap)),
                ),
          ]),
        ]),
      ),
    );
  }
}

/// Dokunup sürüklenebilen zaman çubuğu. Slider yerine özel çizilir; çünkü üzerine
/// tur sınırları, pit stoplar ve safety car / kırmızı bayrak dönemleri işlenir.
class _ReplayTimeline extends StatelessWidget {
  const _ReplayTimeline({required this.data, required this.time, required this.selected, required this.onSeek});

  final ReplayData data;
  final ValueListenable<double> time;
  final String? selected;
  final ValueChanged<double> onSeek;

  static const _inset = 12.0;
  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final pits = data.pitsByDriver[selected] ?? const <ReplayPit>[];
    final penalties = [
      for (final event in data.events)
        if (event.kind == ReplayEventKind.penalty) event.time,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          double toTime(double dx) {
            final span = math.max(width - _inset * 2, 1.0);
            return ((dx - _inset) / span).clamp(0.0, 1.0) * data.duration;
          }

          return GestureDetector(
            key: const Key('replay-timeline'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => onSeek(toTime(details.localPosition.dx)),
            onHorizontalDragUpdate: (details) => onSeek(toTime(details.localPosition.dx)),
            child: ValueListenableBuilder<double>(
              valueListenable: time,
              builder: (context, t, _) => CustomPaint(
                size: Size(width, _height),
                painter: _TimelinePainter(
                  duration: data.duration,
                  t: t,
                  lapStarts: data.lapStarts,
                  periods: data.periods,
                  pitTimes: [for (final pit in pits) pit.inTime],
                  penaltyTimes: penalties,
                  trackColor: AppColors.border,
                  tickColor: AppColors.muted.withValues(alpha: .5),
                  progressColor: AppColors.red,
                  pitColor: AppColors.amber,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.duration,
    required this.t,
    required this.lapStarts,
    required this.periods,
    required this.pitTimes,
    required this.penaltyTimes,
    required this.trackColor,
    required this.tickColor,
    required this.progressColor,
    required this.pitColor,
  });

  final double duration;
  final double t;
  final List<double> lapStarts;
  final List<ReplayEvent> periods;
  final List<double> pitTimes;
  final List<double> penaltyTimes;
  final Color trackColor;
  final Color tickColor;
  final Color progressColor;
  final Color pitColor;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _ReplayTimeline._inset;
    const left = inset;
    final span = math.max(size.width - inset * 2, 1.0);
    double xOf(double seconds) => left + (duration <= 0 ? 0.0 : (seconds / duration).clamp(0.0, 1.0)) * span;
    final midY = size.height / 2;

    // Safety car / VSC / kırmızı bayrak bantları pistin arkasında.
    for (final period in periods) {
      final start = xOf(period.time);
      final end = math.max(xOf(period.end ?? period.time), start + 2);
      canvas.drawRect(
        Rect.fromLTRB(start, midY - 9, end, midY + 9),
        Paint()..color = replayEventColor(period.kind).withValues(alpha: .5),
      );
    }

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, midY), Offset(left + span, midY), track);
    canvas.drawLine(
      Offset(left, midY),
      Offset(xOf(t), midY),
      Paint()
        ..color = progressColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final tick = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    for (final start in lapStarts) {
      final x = xOf(start);
      canvas.drawLine(Offset(x, midY - 6), Offset(x, midY + 6), tick);
    }

    // Seçili pilotun pit girişleri üstte, cezalar altta küçük noktalar.
    for (final seconds in pitTimes) {
      canvas.drawCircle(Offset(xOf(seconds), midY - 14), 3, Paint()..color = pitColor);
    }
    for (final seconds in penaltyTimes) {
      canvas.drawCircle(Offset(xOf(seconds), midY + 14), 2.5, Paint()..color = replayEventColor(ReplayEventKind.penalty));
    }

    canvas.drawCircle(Offset(xOf(t), midY), 7, Paint()..color = progressColor);
    canvas.drawCircle(Offset(xOf(t), midY), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.t != t ||
      old.duration != duration ||
      old.pitTimes != pitTimes ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
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
    // Hava durumu şeridi varsa pist onun altından başlar (şerit pisti örtmesin).
    final top = data.weather.isEmpty ? 0.0 : 36.0;
    final w = math.max(data.maxX - data.minX, 1.0);
    final h = math.max(data.maxY - data.minY, 1.0);
    final availableW = math.max(size.width - padding * 2, 1.0);
    final availableH = math.max(size.height - top - padding * 2, 1.0);
    final scale = math.min(availableW / w, availableH / h);
    return _Fit(scale, (size.width - w * scale) / 2, top + (size.height - top - h * scale) / 2, data.minX, data.maxY);
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
