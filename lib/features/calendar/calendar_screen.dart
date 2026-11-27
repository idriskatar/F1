import 'package:material_ui/material_ui.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/jolpica_repository.dart';
import '../../shared/widgets/demo_notice.dart';
import '../../shared/widgets/responsive.dart';
import '../shell/shell_page_opener.dart';
import 'race_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.repository, this.clock});
  final JolpicaRepository repository;

  /// Testlerde sabit saat vermek için; boşsa `DateTime.now`.
  final DateTime Function()? clock;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  JolpicaRepository get _repository => widget.repository;
  late Future<JolpicaData<RaceWeekend>> _calendar;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _calendar = _repository.calendar();
  }

  void _open(RaceWeekend weekend) {
    final opener = ShellPageOpener.maybeOf(context);
    if (opener != null) {
      opener.open(RaceDetailScreen(
        weekend: weekend,
        repository: _repository,
        clock: widget.clock,
        embedded: true,
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RaceDetailScreen(weekend: weekend, repository: _repository, clock: widget.clock),
      ));
    }
  }

  Future<void> _refresh() async {
    setState(() => _calendar = _repository.calendar());
    await _calendar;
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: desktop ? const EdgeInsets.fromLTRB(24, 18, 24, 28) : const EdgeInsets.all(20),
          children: [
            Row(children: [
              if (desktop) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red)),
                const SizedBox(width: 10),
              ],
              Text('Takvim', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 6),
            Text('Sezon programı • saatler cihazının yerel saatinde', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            FutureBuilder<JolpicaData<RaceWeekend>>(
              future: _calendar,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _LoadError(message: '${snapshot.error}', onRetry: _refresh);
                }
                final data = snapshot.data!;
                if (data.items.isEmpty) return const DemoNotice(text: 'Jolpica bu sezon için henüz takvim verisi döndürmedi.');
                if (desktop) {
                  final next = upcomingRace(data.items, _now());
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _SourceBadge(cached: data.isCached, updatedAt: data.updatedAt),
                    const SizedBox(height: 14),
                    _desktopGrid(data.items, next),
                  ]);
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SourceBadge(cached: data.isCached, updatedAt: data.updatedAt),
                  const SizedBox(height: 12),
                  ...data.items.map(_weekendCard),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Masaüstünde yarış kartları iki sütuna bölünür; sıra soldan sağa, üstten alta gider.
  Widget _desktopGrid(List<RaceWeekend> items, RaceWeekend? next) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final card = _DesktopWeekendCard(
        weekend: items[i],
        isNext: next != null && items[i] == next,
        now: _now(),
        onTap: () => _open(items[i]),
      );
      (i.isEven ? left : right).add(card);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: left)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: right)),
    ]);
  }

  Widget _weekendCard(RaceWeekend weekend) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AppColors.border)),
      child: InkWell(
        onTap: () => _open(weekend),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('ROUND ${weekend.round.toString().padLeft(2, '0')}', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)),
              const Spacer(),
              Text('Sonuçlar ve puan durumu', style: TextStyle(color: AppColors.muted, fontSize: 10)),
              Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
            ]),
            const SizedBox(height: 4),
            Text(weekend.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text('${weekend.location}${weekend.country.isEmpty ? '' : ', ${weekend.country}'} • ${weekend.dateLabel}', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            if (weekend.sessions.isEmpty) Text('Seans saatleri henüz yayımlanmadı.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ...weekend.sessions.map((session) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Icon(session.status == SessionStatus.completed ? Icons.check_circle_outline : Icons.schedule, color: session.status == SessionStatus.completed ? AppColors.muted : AppColors.red, size: 16),
                const SizedBox(width: 9),
                Expanded(child: Text(session.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(session.localTime, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            )),
          ]),
        ),
      ),
    ),
  );
}

/// Masaüstündeki yarış kartı: durum rozeti, geri sayım ve iki sütunlu seans listesi.
class _DesktopWeekendCard extends StatelessWidget {
  const _DesktopWeekendCard({required this.weekend, required this.isNext, required this.now, required this.onTap});

  final RaceWeekend weekend;
  final bool isNext;
  final DateTime now;
  final VoidCallback onTap;

  String get _badge {
    if (isNext) return 'SIRADAKİ YARIŞ';
    if (weekend.sessions.isNotEmpty && weekend.sessions.every((s) => s.status == SessionStatus.completed)) return 'TAMAMLANDI';
    if (weekend.hasSprint) return 'SPRINT';
    return 'YAKLAŞAN';
  }

  Color get _badgeColor {
    if (isNext) return AppColors.red;
    if (_badge == 'TAMAMLANDI') return AppColors.green;
    if (_badge == 'SPRINT') return AppColors.amber;
    return AppColors.muted;
  }

  String _countdown(DateTime target) {
    final left = target.difference(now.toUtc());
    if (left.isNegative) return 'BAŞLADI';
    return '${left.inDays.toString().padLeft(2, '0')} GÜN ${(left.inHours % 24).toString().padLeft(2, '0')} SAAT';
  }

  @override
  Widget build(BuildContext context) {
    final start = weekend.raceStart;
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < weekend.sessions.length; i++) {
      final session = weekend.sessions[i];
      final done = session.status == SessionStatus.completed;
      final row = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(done ? Icons.check_circle_outline : Icons.circle, size: done ? 14 : 8, color: done ? AppColors.green : AppColors.red),
          const SizedBox(width: 6),
          Expanded(child: Text(session.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: done ? AppColors.muted : Colors.white, fontWeight: done ? FontWeight.w500 : FontWeight.w700))),
          const SizedBox(width: 4),
          Text(session.localTime, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: done ? AppColors.muted : AppColors.red)),
        ]),
      );
      (i.isEven ? left : right).add(row);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isNext ? AppColors.red.withValues(alpha: .55) : AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('ROUND ${weekend.round.toString().padLeft(2, '0')}', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _badgeColor.withValues(alpha: .15), borderRadius: BorderRadius.circular(999)),
                  child: Text(_badge, style: TextStyle(color: _badgeColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .6)),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
              ]),
              const SizedBox(height: 9),
              Text(weekend.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(child: Text('${weekend.location}${weekend.country.isEmpty ? '' : ', ${weekend.country}'} • ${weekend.dateLabel}', overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 11))),
                if (isNext && start != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(999)),
                    child: Text('◷ ${_countdown(start)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
              ]),
              if (weekend.sessions.isEmpty)
                Padding(padding: const EdgeInsets.only(top: 10), child: Text('Seans saatleri henüz yayımlanmadı.', style: TextStyle(color: AppColors.muted, fontSize: 11)))
              else ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: left)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: right)),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.cached, required this.updatedAt});
  final bool cached;
  final DateTime updatedAt;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(cached ? Icons.offline_pin_outlined : Icons.cloud_done_outlined, size: 15, color: cached ? AppColors.amber : AppColors.green),
    const SizedBox(width: 6),
    Text(cached ? 'Önbellek • ${_stamp(updatedAt)}' : 'Jolpica • ${_stamp(updatedAt)}', style: TextStyle(color: AppColors.muted, fontSize: 11)),
  ]);
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Takvim yüklenemedi', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(message, style: TextStyle(color: AppColors.muted, fontSize: 12)),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Yeniden dene'))),
    ]),
  );
}

String _stamp(DateTime value) => '${value.toLocal().day.toString().padLeft(2, '0')}.${value.toLocal().month.toString().padLeft(2, '0')} ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';
