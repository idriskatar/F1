import 'package:material_ui/material_ui.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/jolpica_repository.dart';
import '../../shared/widgets/responsive.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.repository});
  final JolpicaRepository repository;
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

typedef _ResultBundle = (JolpicaData<DriverResult>, JolpicaData<DriverStanding>, JolpicaData<TeamStanding>);

class _ResultsScreenState extends State<ResultsScreen> {
  JolpicaRepository get _repository => widget.repository;
  late Future<_ResultBundle> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_ResultBundle> _load() async {
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
  Widget build(BuildContext context) {
    if (isDesktopLayout(context)) return _desktop();
    return _mobile();
  }

  /// Mobil görünüm korundu.
  Widget _mobile() => SafeArea(
    child: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Sonuçlar', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Yarış sınıflandırması ve sezon puanları', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        FutureBuilder<_ResultBundle>(
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

  /// Masaüstü: son yarış tek kartta iki sütun, şampiyonalar yan yana.
  Widget _desktop() => SafeArea(
    child: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red)),
            const SizedBox(width: 10),
            const Text('Sonuçlar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          Text('Yarış sınıflandırması ve sezon puanları', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          FutureBuilder<_ResultBundle>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) return _error('${snapshot.error}');
              final (results, drivers, teams) = snapshot.data!;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _source(results.isCached || drivers.isCached || teams.isCached, results.updatedAt),
                const SizedBox(height: 18),
                _sectionTitle('Son yarış', '${results.items.length} pilot · tüm sonuçlar'),
                const SizedBox(height: 12),
                _raceCard(results.items, results.label),
                const SizedBox(height: 20),
                _sectionTitle('Şampiyona', 'Tüm sıralama'),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _standingsCard(
                    title: '${DateTime.now().year} Pilotlar Şampiyonası',
                    col1: 'PİLOT',
                    col2: 'TAKIM',
                    colorName: false,
                    rows: [for (final r in drivers.items) _StandRow(r.position, r.name, r.team, r.points)],
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _standingsCard(
                    title: '${DateTime.now().year} Takımlar Şampiyonası',
                    col1: 'TAKIM',
                    col2: 'GALİBİYET',
                    colorName: true,
                    rows: [for (final r in teams.items) _StandRow(r.position, r.name, r.wins, r.points)],
                  )),
                ]),
              ]);
            },
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String title, String meta) => Row(children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red)),
    const SizedBox(width: 9),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    const Spacer(),
    Text(meta, style: TextStyle(color: AppColors.muted, fontSize: 11)),
  ]);

  Widget _raceCard(List<DriverResult> rows, String? label) {
    final podium = rows.where((r) => r.position > 0).take(3).toList();
    final fastest = rows.where((r) => r.fastestLapRank == 1).toList();
    final pole = rows.where((r) => r.grid == 1).toList();
    final half = (rows.length / 2).round();
    final leftRows = rows.take(half).toList();
    final rightRows = rows.skip(half).toList();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 32,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.border)), color: AppColors.surface2.withValues(alpha: .35)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SON YARIŞ', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.4)),
              const SizedBox(height: 7),
              Text(label ?? 'Son yarış', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(children: [
                _stat('TUR', '${rows.isNotEmpty ? rows.first.laps : 0}'),
                const SizedBox(width: 6),
                _stat('POLE', pole.isEmpty ? '—' : pole.first.code),
                const SizedBox(width: 6),
                _stat('EN HIZLI TUR', fastest.isEmpty ? '—' : (fastest.first.fastestLapTime ?? '—')),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              for (final r in podium) _podiumRow(r),
            ]),
          ),
        ),
        Expanded(
          flex: 68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _resultHeader(),
              if (rows.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text('Henüz yayımlanmış yarış sonucu yok.', style: TextStyle(color: AppColors.muted, fontSize: 12)))
              else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(children: [for (final r in leftRows) _resultRow(r)])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(children: [for (final r in rightRows) _resultRow(r)])),
                ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String key, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(key, style: TextStyle(color: AppColors.muted, fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
      ]),
    ),
  );

  Widget _podiumRow(DriverResult r) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      SizedBox(width: 26, child: Text('${r.position}', style: TextStyle(color: r.position == 1 ? AppColors.red : AppColors.muted, fontWeight: FontWeight.w900, fontSize: 12))),
      Container(width: 3, height: 16, color: Color(r.color)),
      const SizedBox(width: 7),
      SizedBox(width: 40, child: Text(r.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
      Expanded(child: Text(r.team, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 11))),
      Text(r.time, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
    ]),
  );

  Widget _resultHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    child: Row(children: [
      SizedBox(width: 22, child: Text('SIRA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.muted))),
      SizedBox(width: 42, child: Text('PİLOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.muted))),
      Expanded(child: Text('TAKIM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.muted))),
      SizedBox(width: 68, child: Text('SONUÇ', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.muted))),
    ]),
  );

  Widget _resultRow(DriverResult r) => Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: .55)))),
    child: Row(children: [
      SizedBox(width: 22, child: Text('${r.position}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.muted))),
      SizedBox(width: 42, child: Text(r.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
      Expanded(child: Text(r.team, overflow: TextOverflow.ellipsis, style: TextStyle(color: teamColorFromName(r.team), fontSize: 10.5))),
      SizedBox(width: 68, child: Text(r.time, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800))),
    ]),
  );

  Widget _standingsCard({
    required String title,
    required String col1,
    required String col2,
    required bool colorName,
    required List<_StandRow> rows,
  }) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 12), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          SizedBox(width: 30, child: Text('SIRA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.muted))),
          Expanded(child: Text(col1, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.muted))),
          Expanded(child: Text(col2, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.muted))),
          SizedBox(width: 48, child: Text('PUAN', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.muted))),
        ]),
      ),
      if (rows.isEmpty)
        Padding(padding: const EdgeInsets.all(16), child: Text('Bu sezon için puan durumu henüz oluşmadı.', style: TextStyle(color: AppColors.muted, fontSize: 12)))
      else
        for (final row in rows) _standRow(row, colorName),
    ]),
  );

  Widget _standRow(_StandRow row, bool colorName) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: .55)))),
    child: Row(children: [
      SizedBox(width: 30, child: Text('${row.position}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: row.position == 1 ? AppColors.red : AppColors.muted))),
      Expanded(child: Text(row.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: colorName ? teamColorFromName(row.name) : null))),
      Expanded(child: Text(row.second, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: colorName ? AppColors.muted : teamColorFromName(row.second)))),
      SizedBox(width: 48, child: Text(row.points, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
    ]),
  );

  Widget _source(bool cached, DateTime updatedAt) => Row(children: [
    Icon(cached ? Icons.offline_pin_outlined : Icons.cloud_done_outlined, size: 15, color: cached ? AppColors.amber : AppColors.green),
    const SizedBox(width: 6),
    Text(cached ? 'Jolpica önbelleği • ${_stamp(updatedAt)}' : 'Jolpica • güncellendi ${_stamp(updatedAt)}', style: TextStyle(color: AppColors.muted, fontSize: 11)),
  ]);

  Widget _heading(String title) => Text(title, style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 11));

  Widget _resultsTable(List<DriverResult> rows) => _table([
    const _HeaderRow(cells: ['SIRA', 'PİLOT', 'TAKIM', 'SONUÇ']),
    ...rows.map((row) => _DataRow(cells: [row.position.toString().padLeft(2, '0'), row.code, row.team, row.time], color: row.color)),
  ]);

  Widget _driversTable(List<DriverStanding> rows) => _table([
    const _HeaderRow(cells: ['SIRA', 'PİLOT', 'TAKIM', 'PUAN']),
    ...rows.map((row) => _DataRow(cells: [row.position.toString().padLeft(2, '0'), row.name, row.team, row.points])),
  ]);

  Widget _teamsTable(List<TeamStanding> rows) => _table([
    const _HeaderRow(cells: ['SIRA', 'TAKIM', 'GALİBİYET', 'PUAN']),
    ...rows.map((row) => _DataRow(cells: [row.position.toString().padLeft(2, '0'), row.name, row.wins, row.points])),
  ]);

  Widget _table(List<Widget> rows) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 1), rows[i]]]),
  );

  Widget _empty(String message) => Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Text(message, style: TextStyle(color: AppColors.muted, fontSize: 12)));

  Widget _error(String message) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Jolpica verisi yüklenemedi', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(message, style: TextStyle(color: AppColors.muted, fontSize: 12)), Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Yeniden dene')))]));
}

class _StandRow {
  const _StandRow(this.position, this.name, this.second, this.points);
  final int position;
  final String name;
  final String second;
  final String points;
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
