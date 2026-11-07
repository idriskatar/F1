import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/jolpica_repository.dart';
import 'data/remote/news_repository.dart';
import 'features/shell/app_shell.dart';

class F1TrackerApp extends StatefulWidget {
  const F1TrackerApp({super.key, this.repository, this.newsRepository, this.clock});

  /// Testlerde sahte veri kaynağı vermek için; boşsa uygulama kendi
  /// [JolpicaRepository] örneğini oluşturur ve kapatır.
  final JolpicaRepository? repository;
  final NewsRepository? newsRepository;

  /// Testlerde sabit saat vermek için; boşsa `DateTime.now` kullanılır.
  final DateTime Function()? clock;

  @override
  State<F1TrackerApp> createState() => _F1TrackerAppState();
}

class _F1TrackerAppState extends State<F1TrackerApp> {
  String _themeId = 'dark';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('f1_tracker_theme');
      if (mounted && saved != null && {'dark', 'light', 'pitwall'}.contains(saved)) {
        setState(() => _themeId = saved);
      }
    } catch (_) {
      // Keep the default dark theme when platform preferences are unavailable.
    }
  }

  Future<void> _setTheme(String id) async {
    setState(() => _themeId = id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('f1_tracker_theme', id);
    } catch (_) {
      // The selected theme remains active for this app session.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'F1 Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forId(_themeId),
      home: AppShell(repository: widget.repository, newsRepository: widget.newsRepository, clock: widget.clock, themeId: _themeId, onThemeChanged: _setTheme),
    );
  }
}
