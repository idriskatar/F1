import 'package:material_ui/material_ui.dart';
import '../../data/remote/jolpica_repository.dart';
import '../../data/remote/news_repository.dart';
import '../../data/remote/replay_repository.dart';
import '../more/more_screen.dart';
import '../home/home_screen.dart';
import '../calendar/calendar_screen.dart';
import '../news/news_screen.dart';
import '../results/results_screen.dart';
import '../replay/replay_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.repository, this.newsRepository, this.replayRepository, this.clock, this.themeId = 'dark', this.onThemeChanged});

  final JolpicaRepository? repository;
  final NewsRepository? newsRepository;
  final ReplayRepository? replayRepository;
  final DateTime Function()? clock;
  final String themeId;
  final ValueChanged<String>? onThemeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final JolpicaRepository _repository;
  late final bool _ownsRepository;
  late final NewsRepository _news;
  late final bool _ownsNews;
  late final ReplayRepository _replayRepository;
  late final bool _ownsReplayRepository;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? JolpicaRepository();
    _ownsNews = widget.newsRepository == null;
    _news = widget.newsRepository ?? NewsRepository();
    _ownsReplayRepository = widget.replayRepository == null;
    _replayRepository = widget.replayRepository ?? ReplayRepository();
  }

  List<Widget> _screens() => [
      HomeScreen(
        repository: _repository,
        newsRepository: _news,
        clock: widget.clock,
        onOpenTab: (value) => setState(() => _index = value),
      ),
      CalendarScreen(repository: _repository, clock: widget.clock),
      NewsScreen(repository: _news),
      ResultsScreen(repository: _repository),
      ReplayScreen(repository: _replayRepository, embedded: true, active: _index == 4),
    ];

  void _openMore() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MoreScreen(themeId: widget.themeId, onThemeChanged: widget.onThemeChanged ?? (_) {}),
    ));
  }

  @override
  void dispose() {
    if (_ownsRepository) _repository.close();
    if (_ownsNews) _news.close();
    if (_ownsReplayRepository) _replayRepository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: Navigator.of(context).canPop() || _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Menü',
          icon: const Icon(Icons.menu_rounded),
          onPressed: _openMore,
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 30,
            height: 26,
            decoration: BoxDecoration(color: const Color(0xFFE10600), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 9),
          const Text('F1 TRACKER', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        ]),
      ),
      body: IndexedStack(index: _index, children: _screens()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana sayfa'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Takvim'),
          NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'Haberler'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Sonuçlar'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline_rounded), selectedIcon: Icon(Icons.play_circle_rounded), label: 'Replay'),
        ],
      ),
      ),
    );
  }
}
