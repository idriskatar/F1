import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/remote/jolpica_repository.dart';
import '../../data/remote/news_repository.dart';
import '../../data/remote/replay_repository.dart';
import '../calendar/calendar_screen.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../news/news_screen.dart';
import '../replay/replay_screen.dart';
import '../results/results_screen.dart';
import '../../shared/widgets/responsive.dart';

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

    // Masaüstünde pencere odağı nerede olursa olsun klavye kısayolları çalışsın.
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /// Dar pencerelerde (telefon) alt gezinme çubuğu, geniş pencerelerde yan ray kullanılır.
  bool _isMobile(BuildContext context) {
    if (kIsWeb) return false;
    return !isDesktopLayout(context);
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

  void _selectTab(int index) {
    if (index >= 0 && index < 5 && _index != index) {
      setState(() => _index = index);
    }
  }

  /// Masaüstü klavye kısayolları:
  /// Ctrl/Cmd+1..5 sekmeler, Ctrl/Cmd+M menü, Esc açık sayfayı kapatır ya da
  /// ana sayfaya döner.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    // Açık bir alt sayfa (yarış detayı, replay, Ayarlar vb.) varsa sekme kısayolları devre dışı kalır.
    final hasSubRoute = Navigator.maybeOf(context)?.canPop() ?? false;
    final shortcut = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    if (shortcut) {
      if (hasSubRoute) return false;
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        _selectTab(0);
      } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
        _selectTab(1);
      } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
        _selectTab(2);
      } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
        _selectTab(3);
      } else if (event.logicalKey == LogicalKeyboardKey.digit5) {
        _selectTab(4);
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        _openMore();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (hasSubRoute) {
        Navigator.of(context).maybePop();
      } else if (_index != 0) {
        _selectTab(0);
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    if (_ownsRepository) _repository.close();
    if (_ownsNews) _news.close();
    if (_ownsReplayRepository) _replayRepository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    return PopScope<Object?>(
      canPop: Navigator.of(context).canPop() || _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: isMobile ? 'Menü' : 'Menü (Ctrl+M)',
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
        body: isMobile
            ? IndexedStack(index: _index, children: _screens())
            : Row(
                children: [
                  _DesktopNavigationRail(
                    index: _index,
                    onSelected: _selectTab,
                    onOpenMore: _openMore,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: IndexedStack(index: _index, children: _screens())),
                ],
              ),
        bottomNavigationBar: isMobile
            ? NavigationBar(
                selectedIndex: _index,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: _selectTab,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana sayfa'),
                  NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Takvim'),
                  NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'Haberler'),
                  NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Sonuçlar'),
                  NavigationDestination(icon: Icon(Icons.play_circle_outline_rounded), selectedIcon: Icon(Icons.play_circle_rounded), label: 'Replay'),
                ],
              )
            : null,
      ),
    );
  }
}

/// Masaüstünde sol tarafta duran genişletilmiş gezinme rayı.
/// Mobildeki alt gezinme çubuğuyla aynı beş sekmeyi ve Ayarlar/Hakkında erişimini sunar.
class _DesktopNavigationRail extends StatelessWidget {
  const _DesktopNavigationRail({required this.index, required this.onSelected, required this.onOpenMore});

  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 256,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: NavigationRail(
              extended: true,
              minExtendedWidth: 256,
              selectedIndex: index,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.none,
              groupAlignment: -1,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Ana sayfa')),
                NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Takvim')),
                NavigationRailDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: Text('Haberler')),
                NavigationRailDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: Text('Sonuçlar')),
                NavigationRailDestination(icon: Icon(Icons.play_circle_outline_rounded), selectedIcon: Icon(Icons.play_circle_rounded), label: Text('Replay')),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Ayarlar'),
              subtitle: const Text('Tema, hakkında, gizlilik'),
              onTap: onOpenMore,
            ),
          ),
        ],
      ),
    );
  }
}
