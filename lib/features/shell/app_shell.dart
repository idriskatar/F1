import 'package:flutter/material.dart';
import '../../data/remote/jolpica_repository.dart';
import '../home/home_screen.dart';
import '../calendar/calendar_screen.dart';
import '../news/news_screen.dart';
import '../results/results_screen.dart';
import '../analysis/analysis_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.repository, this.clock});

  final JolpicaRepository? repository;
  final DateTime Function()? clock;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final JolpicaRepository _repository;
  late final bool _ownsRepository;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? JolpicaRepository();
    _screens = [
      HomeScreen(
        repository: _repository,
        clock: widget.clock,
        onOpenTab: (value) => setState(() => _index = value),
      ),
      CalendarScreen(repository: _repository),
      const NewsScreen(),
      ResultsScreen(repository: _repository),
      const AnalysisScreen(),
    ];
  }

  @override
  void dispose() {
    if (_ownsRepository) _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana sayfa'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Takvim'),
          NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'Haberler'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Sonuçlar'),
          NavigationDestination(icon: Icon(Icons.query_stats_outlined), selectedIcon: Icon(Icons.query_stats), label: 'Analiz'),
        ],
      ),
    );
  }
}
