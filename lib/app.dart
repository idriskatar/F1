import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/jolpica_repository.dart';
import 'data/remote/news_repository.dart';
import 'features/shell/app_shell.dart';

class F1TrackerApp extends StatelessWidget {
  const F1TrackerApp({super.key, this.repository, this.newsRepository, this.clock});

  /// Testlerde sahte veri kaynağı vermek için; boşsa uygulama kendi
  /// [JolpicaRepository] örneğini oluşturur ve kapatır.
  final JolpicaRepository? repository;
  final NewsRepository? newsRepository;

  /// Testlerde sabit saat vermek için; boşsa `DateTime.now` kullanılır.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'F1 Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AppShell(repository: repository, newsRepository: newsRepository, clock: clock),
    );
  }
}
