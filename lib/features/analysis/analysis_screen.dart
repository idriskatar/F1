import 'package:flutter/material.dart';

import '../../core/models/race_models.dart';
import '../../core/models/session_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/openf1_repository.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, required this.repository, required this.active});

  final OpenF1Repository repository;
  final bool active;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  Future<CompletedSessionData?>? _session;

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
    _session = widget.repository.fetchLatest(force: force);
  }

  Future<void> _refresh() async {
    final future = widget.repository.fetchLatest(force: true);
    setState(() {
      _session = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the load error and retry action.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text('Analiz', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('OpenF1 tarihsel verisi • canlı seans bitiminden en az 30 dakika sonra', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            if (_session == null)
              const _Notice(text: 'Son seans verileri yüklenmek üzere hazır.')
            else
              FutureBuilder<CompletedSessionData?>(
                future: _session,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _Notice(
                      icon: Icons.downloading_rounded,
                      text: 'Son tamamlanan seans aranıyor…',
                      showProgress: true,
                    );
                  }
                  if (snapshot.hasError) {
                    return _Notice(
                      icon: Icons.cloud_off_outlined,
                      text: 'Seans verileri yüklenemedi: ${snapshot.error}',
                      action: _refresh,
                    );
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return _Notice(
                      icon: Icons.event_busy_outlined,
                      text: 'Tamamlanmış bir seans sonucu bulunamadı. Biraz sonra yeniden deneyin.',
                      action: _refresh,
                    );
                  }
                  return _CompletedSessionCard(data: data);
                },
              ),
            const SizedBox(height: 16),
            const _Panel(title: 'Tur zamanı analizi', subtitle: 'Pilotların tur bazında tempo karşılaştırması'),
            const SizedBox(height: 12),
            const _Panel(title: 'Lastik stratejisi', subtitle: 'Hamur, stint uzunluğu ve lastik yaşı'),
            const SizedBox(height: 12),
            const _Panel(title: 'Sektör karşılaştırması', subtitle: 'S1, S2 ve S3 en iyi dereceleri'),
            const SizedBox(height: 12),
            const _Panel(title: 'Pit stop analizi', subtitle: 'Pit girişleri, çıkışları ve duruş süreleri'),
          ],
        ),
      ),
    );
  }
}

class _CompletedSessionCard extends StatelessWidget {
  const _CompletedSessionCard({required this.data});
  final CompletedSessionData data;

  @override
  Widget build(BuildContext context) {
    final date = data.dateEnd.toLocal();
    final eventName = [data.meetingName, if (data.circuitName.isNotEmpty) data.circuitName]
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(' • ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.timer_outlined, color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('SON TAMAMLANAN SEANS', style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w900))),
          if (data.isCached) Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 16),
        ]),
        const SizedBox(height: 7),
        Text(data.sessionName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        if (eventName.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(eventName, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
        const SizedBox(height: 3),
        Text(
          '${MaterialLocalizationsDate.date(date)} • ${MaterialLocalizationsDate.format(date)}${data.isCached ? ' • Çevrimdışı veri' : ''}',
          style: TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
        const SizedBox(height: 14),
        if (data.standings.isEmpty)
          Text('Bu seans için sıralama bulunamadı.', style: TextStyle(color: AppColors.muted))
        else ...[
          const _TableHeader(),
          const Divider(height: 12),
          for (final row in data.standings.take(10)) _StandingRow(row: row),
        ],
        const SizedBox(height: 6),
        Text('Kaynak: OpenF1 • Sonuçlar seans tamamlandıktan sonra yayımlanır.', style: TextStyle(color: AppColors.muted, fontSize: 10)),
      ]),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 28, child: Text('P', style: _headerStyle)),
        Expanded(child: Text('PİLOT', style: _headerStyle)),
        SizedBox(width: 104, child: Text('DERECE / FARK', textAlign: TextAlign.right, style: _headerStyle)),
        SizedBox(width: 42, child: Text('TUR', textAlign: TextAlign.right, style: _headerStyle)),
      ]);
}

final _headerStyle = TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .7);

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.row});
  final SessionStanding row;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(width: 28, child: Text('${row.position}', style: const TextStyle(fontWeight: FontWeight.w900))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.driverName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
              Text(
                [row.driverCode, if (row.teamName.isNotEmpty) row.teamName].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted, fontSize: 9),
              ),
            ]),
          ),
          SizedBox(
            width: 104,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (row.resultSeconds != null)
                Text(_formatSeconds(row.resultSeconds!), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              Text(row.gapToLeader, textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 9)),
            ]),
          ),
          SizedBox(width: 42, child: Text(row.laps > 0 ? '${row.laps}' : '—', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 10))),
        ]),
      );
}

String _formatSeconds(double value) {
  final totalMilliseconds = (value * 1000).round();
  final hours = totalMilliseconds ~/ 3600000;
  final minutes = (totalMilliseconds % 3600000) ~/ 60000;
  final seconds = (totalMilliseconds % 60000) ~/ 1000;
  final milliseconds = totalMilliseconds % 1000;
  final clock = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
  return hours > 0 ? '$hours:$clock' : clock;
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    this.icon = Icons.info_outline,
    this.action,
    this.showProgress = false,
  });

  final String text;
  final IconData icon;
  final Future<void> Function()? action;
  final bool showProgress;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          if (showProgress)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(icon, color: AppColors.muted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: AppColors.muted, fontSize: 11))),
          if (action != null) IconButton(onPressed: action, icon: const Icon(Icons.refresh), tooltip: 'Yeniden dene'),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 16),
          Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.show_chart_rounded, color: AppColors.red, size: 34),
          ),
          const SizedBox(height: 8),
          Text('Ayrıntılı grafik için seans verisi bekleniyor', style: TextStyle(color: AppColors.muted, fontSize: 10)),
        ]),
      );
}
