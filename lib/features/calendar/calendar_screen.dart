import 'package:flutter/material.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/jolpica_repository.dart';
import '../../shared/widgets/demo_notice.dart';
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

  @override
  void initState() {
    super.initState();
    _calendar = _repository.calendar();
  }

  void _open(RaceWeekend weekend) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RaceDetailScreen(weekend: weekend, repository: _repository, clock: widget.clock),
    ));
  }

  Future<void> _refresh() async {
    setState(() => _calendar = _repository.calendar());
    await _calendar;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Takvim', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
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
