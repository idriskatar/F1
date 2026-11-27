import 'package:material_ui/material_ui.dart';
import '../../core/models/news_models.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/news_repository.dart';
import '../../shared/open_url.dart';
import '../../shared/widgets/responsive.dart';

String _turkishUpperCase(String value) => value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

Color _sourceColor(String name) {
  final n = name.toLowerCase();
  if (n.contains('trf')) return AppColors.red;
  if (n.contains('motorsport')) return AppColors.amber;
  return AppColors.muted;
}

String _ago(DateTime? date) {
  if (date == null) return '';
  final left = DateTime.now().toLocal().difference(date.toLocal());
  if (left.inDays > 1) return '${left.inDays} gün önce';
  if (left.inDays == 1) return 'Dün';
  if (left.inHours >= 1) return '${left.inHours} sa önce';
  if (left.inMinutes >= 1) return '${left.inMinutes} dk önce';
  return 'Az önce';
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key, required this.repository, this.onOpenUrl});

  final NewsRepository repository;

  /// Testlerde bağlantı açmayı taklit etmek için; boşsa cihaz tarayıcısı.
  final Future<bool> Function(String url)? onOpenUrl;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<NewsFeedResult> _feed;
  String? _filter; // kaynak kimliği; null = tümü

  @override
  void initState() {
    super.initState();
    _feed = widget.repository.fetchAll();
  }

  Future<void> _refresh() async {
    final feed = widget.repository.fetchAll(force: true);
    setState(() {
      _feed = feed;
    });
    await feed;
  }

  Future<void> _open(NewsItem item) async {
    var opened = false;
    try {
      opened = await (widget.onOpenUrl ?? openExternalUrl)(item.url);
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktopLayout(context)) return _desktop();
    return _mobile();
  }

  /// Mobil görünüm korundu.
  Widget _mobile() {
    final sources = widget.repository.sources;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text('Haberler', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(sources.map((s) => s.name).join(' • '), style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 4, children: [
              ChoiceChip(label: const Text('Tümü'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
              for (final s in sources)
                ChoiceChip(label: Text(s.name), selected: _filter == s.id, onSelected: (_) => setState(() => _filter = s.id)),
            ]),
            const SizedBox(height: 14),
            FutureBuilder<NewsFeedResult>(
              future: _feed,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _Note(icon: Icons.cloud_off_outlined, text: 'Haberler yüklenemedi: ${snapshot.error}', onRetry: _refresh);
                }
                final data = snapshot.data!;
                final items = _filter == null ? data.items : data.items.where((i) => i.sourceId == _filter).toList();
                String nameOf(String id) => sources.firstWhere((s) => s.id == id, orElse: () => NewsSource(id: id, name: id, url: '')).name;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final entry in data.errors.entries)
                    _Note(
                      icon: Icons.cloud_off_outlined,
                      text: '${nameOf(entry.key)} güncellenemedi'
                          '${data.cachedSources.contains(entry.key) ? ' — önbellekteki haberler gösteriliyor' : ''}: ${entry.value}',
                      onRetry: _refresh,
                    ),
                  if (items.isEmpty && data.errors.isEmpty)
                    const _Note(icon: Icons.newspaper, text: 'Gösterilecek haber bulunamadı.'),
                  for (final item in items) _NewsCard(item: item, onTap: () => _open(item)),
                  const SizedBox(height: 8),
                  Text(
                    'Haberler kaynak sitelerin herkese açık RSS akışlarından alınır. Burada yalnızca başlık ve kısa özet gösterilir; haberin tamamı kaynağında açılır.',
                    style: TextStyle(color: AppColors.muted, fontSize: 10.5),
                  ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Masaüstü: manşet + iki sütunlu haber listesi, sayılı kaynak süzgeçleri.
  Widget _desktop() {
    final sources = widget.repository.sources;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red)),
              const SizedBox(width: 10),
              const Text('Haberler', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 6),
            Text(sources.map((s) => s.name).join(' • '), style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            FutureBuilder<NewsFeedResult>(
              future: _feed,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _Note(icon: Icons.cloud_off_outlined, text: 'Haberler yüklenemedi: ${snapshot.error}', onRetry: _refresh);
                }
                final data = snapshot.data!;
                final items = _filter == null ? data.items : data.items.where((i) => i.sourceId == _filter).toList();
                String nameOf(String id) => sources.firstWhere((s) => s.id == id, orElse: () => NewsSource(id: id, name: id, url: '')).name;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _filterChip('Tümü', data.items.length, null, AppColors.red),
                    for (final s in sources)
                      _filterChip(s.name, data.items.where((i) => i.sourceId == s.id).length, s.id, _sourceColor(s.name)),
                  ]),
                  for (final entry in data.errors.entries) ...[
                    const SizedBox(height: 12),
                    _Note(
                      icon: Icons.cloud_off_outlined,
                      text: '${nameOf(entry.key)} güncellenemedi'
                          '${data.cachedSources.contains(entry.key) ? ' — önbellekteki haberler gösteriliyor' : ''}: ${entry.value}',
                      onRetry: _refresh,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const _Note(icon: Icons.newspaper, text: 'Gösterilecek haber bulunamadı.')
                  else ...[
                    _HeroNewsCard(item: items.first, onTap: () => _open(items.first)),
                    if (items.length > 1) ...[
                      const SizedBox(height: 14),
                      _desktopGrid(items.skip(1).toList()),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Haberler kaynak sitelerin herkese açık RSS akışlarından alınır. Burada yalnızca başlık ve kısa özet gösterilir; haberin tamamı kaynağında açılır.',
                    style: TextStyle(color: AppColors.muted, fontSize: 10.5),
                  ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int count, String? id, Color color) {
    final selected = _filter == id;
    return InkWell(
      onTap: () => setState(() => _filter = id),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .16) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color.withValues(alpha: .5) : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.muted)),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      ),
    );
  }

  Widget _desktopGrid(List<NewsItem> items) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      (i.isEven ? left : right).add(_DesktopNewsCard(item: items[i], onTap: () => _open(items[i])));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: left)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: right)),
    ]);
  }
}

/// Masaüstü manşet kartı: ilk haber geniş ve vurgulu gösterilir.
class _HeroNewsCard extends StatelessWidget {
  const _HeroNewsCard({required this.item, required this.onTap});
  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _sourceColor(item.sourceName);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                const SizedBox(width: 8),
                Text('ÖNE ÇIKAN', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.2)),
              ]),
              const SizedBox(height: 9),
              Text(item.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.25)),
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(item.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Text(_turkishUpperCase(item.sourceName), style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
                if (item.publishedAt != null) ...[
                  const SizedBox(width: 9),
                  Text(MaterialLocalizationsDate.dayTime(item.publishedAt!.toLocal()), style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
                ],
                const Spacer(),
                Text(_ago(item.publishedAt), style: TextStyle(color: AppColors.green, fontSize: 10)),
                const SizedBox(width: 10),
                Text('Kaynakta aç ↗', style: TextStyle(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Masaüstündeki tek haber kartı; sol kenar çizgisi kaynağın rengini taşır.
class _DesktopNewsCard extends StatelessWidget {
  const _DesktopNewsCard({required this.item, required this.onTap});
  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _sourceColor(item.sourceName);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(_turkishUpperCase(item.sourceName), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .9)),
                  const Spacer(),
                  Text(_ago(item.publishedAt), style: TextStyle(color: AppColors.green, fontSize: 10)),
                ]),
                const SizedBox(height: 8),
                Text(item.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.35)),
                if (item.summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.45)),
                ],
                const SizedBox(height: 11),
                Row(children: [
                  if (item.publishedAt != null)
                    Text(MaterialLocalizationsDate.dayTime(item.publishedAt!.toLocal()), style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
                  const Spacer(),
                  Text('Kaynakta aç ↗', style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.onTap});
  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.publishedAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Text(_turkishUpperCase(item.sourceName), style: TextStyle(color: AppColors.red, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  Text(MaterialLocalizationsDate.dayTime(date.toLocal()), style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
                ],
                const Spacer(),
                Icon(Icons.open_in_new, size: 15, color: AppColors.muted),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Icon(icon, color: AppColors.amber, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      if (onRetry != null) IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 20), tooltip: 'Yeniden dene'),
    ]),
  );
}
