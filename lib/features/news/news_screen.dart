import 'package:flutter/material.dart';
import '../../core/models/news_models.dart';
import '../../core/models/race_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/news_repository.dart';
import '../../shared/open_url.dart';

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
    setState(() => _feed = widget.repository.fetchAll(force: true));
    await _feed;
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
            Text(sources.map((s) => s.name).join(' • '), style: const TextStyle(color: AppColors.muted)),
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
                  const Text(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Text(item.sourceName.toUpperCase(), style: const TextStyle(color: AppColors.red, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  Text(MaterialLocalizationsDate.dayTime(date.toLocal()), style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
                ],
                const Spacer(),
                const Icon(Icons.open_in_new, size: 15, color: AppColors.muted),
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
