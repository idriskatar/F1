import 'package:flutter/material.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/jolpica_repository.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.repository});
  final JolpicaRepository repository;
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  JolpicaRepository get _repository => widget.repository;
  late Future<(JolpicaData<DriverResult>, JolpicaData<DriverStanding>, JolpicaData<TeamStanding>)> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<(JolpicaData<DriverResult>, JolpicaData<DriverStanding>, JolpicaData<TeamStanding>)> _load() async {
    final values = await Future.wait<Object>([
      _repository.latestResults(),
      _repository.driverStandings(),
      _repository.teamStandings(),
    ]);
    return (
      values[0] as JolpicaData<DriverResult>,
      values[1] as JolpicaData<DriverStanding>,
      values[2] as JolpicaData<TeamStanding>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _data = _load());
    await _data;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Sonuçlar', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Yarış sınıflandırması ve sezon puanları', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        FutureBuilder<(JolpicaData<DriverResult>, JolpicaData<DriverStanding>, JolpicaData<TeamStanding>)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            if (snapshot.hasError) return _error('${snapshot.error}');
            final (results, drivers, teams) = snapshot.data!;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _source(results.isCached || drivers.isCached || teams.isCached, results.updatedAt),
              const SizedBox(height: 22),
              _heading('SON YARIŞ'),
              const SizedBox(height: 10),
              if (results.items.isEmpty) _empty('Henüz yayımlanmış yarış sonucu yok.') else _resultsTable(results.items),
              const SizedBox(height: 24),
              _heading('PİLOTLAR ŞAMPİYONASI'),
              const SizedBox(height: 10),
              if (drivers.items.isEmpty) _empty('Bu sezon için puan durumu henüz oluşmadı.') else _driversTable(drivers.items),
              const SizedBox(height: 24),
              _heading('TAKIMLAR ŞAMPİYONASI'),
              const SizedBox(height: 10),
              if (teams.items.isEmpty) _empty('Bu sezon için takım puan durumu henüz oluşmadı.') else _teamsTable(teams.items),
            ]);
          },
        ),
      ]),
    ),
  );

  Widget _source(bool cached, DateTime updatedAt) => Row(children: [
    Icon(cached ? Icons.offline_pin_outlined : Icons.cloud_done_outlined, size: 15, color: cached ? AppColors.amber : AppColors.green),
    const SizedBox(width: 6),
    Text(cached ? 'Jolpica önbelleği • ${_stamp(updatedAt)}' : 'Jolpica • güncellendi ${_stamp(updatedAt)}', style: TextStyle(color: AppColors.muted, fontSize: 11)),
  ]);

  Widget _heading(String title) => Text(title, style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 11));

  Widget _resultsTable(List<DriverResult> rows) => _table([
    const _HeaderRow(cells: ['POS', 'PİLOT', 'TAKIM', 'SONUÇ']),
    ...rows.map((row) => _DataRow(cells: [row.position.toString().padLeft(2, '0'), row.code, row.team, row.time], color: row.color)),
  ]);

  Widget _driversTable(List<DriverStanding> rows) => _table([
    const _HeaderRow(cells: ['POS', 'PİLOT', 'TAKIM', 'PUAN']),
    ...rows.map((row) => _DataRow(cells: [row.position.toString().padLeft(2, '0'), row.name, row.team, row.points])),
  ]);

  Widget _teamsTable(List<TeamStanding> rows) => _table([
    const _HeaderRow(cells: ['POS', 'TAKIM', 'GALİBİYET', 'PUAN']),
    ...rows.map((row) => _DataRow(cells: [row.position.toString().padLeft(2, '0'), row.name, row.wins, row.points])),
  ]);

  Widget _table(List<Widget> rows) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 1), rows[i]]]),
  );

  Widget _empty(String message) => Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Text(message, style: TextStyle(color: AppColors.muted, fontSize: 12)));

  Widget _error(String message) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Jolpica verisi yüklenemedi', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(message, style: TextStyle(color: AppColors.muted, fontSize: 12)), Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Yeniden dene')))]));
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.cells});
  final List<String> cells;
  @override
  Widget build(BuildContext context) => _cells(cells, header: true);
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.cells, this.color});
  final List<String> cells;
  final int? color;
  @override
  Widget build(BuildContext context) => _cells(cells, color: color);
}

Widget _cells(List<String> cells, {bool header = false, int? color}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  child: Row(children: [
    for (var i = 0; i < cells.length; i++) Expanded(
      flex: i == 0 ? 1 : (i == cells.length - 1 ? 1 : 2),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: i == 2 && color != null && !header
            ? Row(children: [Container(width: 3, height: 16, color: Color(color)), const SizedBox(width: 5), Expanded(child: Text(cells[i], overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 10)))] )
            : Text(cells[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: header ? 8 : 10, color: header ? AppColors.muted : (i == 0 ? AppColors.red : (i == cells.length - 1 ? (AppColors.themeId == 'light' ? Colors.black : Colors.white) : AppColors.muted)), fontWeight: header || i == 0 || i == cells.length - 1 ? FontWeight.w800 : FontWeight.w600)),
      ),
    ),
  ]),
);

String _stamp(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
