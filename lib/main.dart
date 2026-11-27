import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

/// Masaüstü (Windows/Linux/macOS) ortamında mı çalışıyoruz?
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_isDesktop) {
    // Masaüstünde sqflite'ı FFI arka ucuyla çalıştır (SQLite uygulamayla birlikte gelir).
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const F1TrackerApp());
  if (_isDesktop) {
    // İlk kare çizilmeden önce pencereyi boyutlandır; başarısız olursa varsayılan boyutla devam edilir.
    unawaited(_configureDesktopWindow());
  }
}

/// Masaüstü penceresini başlangıç boyutu, minimum boyut ve başlıkla hazırlar.
/// Mobilde bu adım atlanır; uygulama tam ekran çalışmaya devam eder.
Future<void> _configureDesktopWindow() async {
  final window = await _currentWindow();
  if (window == null) return;
  try {
    window
      ..title = 'F1 Tracker'
      ..backgroundColor = const Color(0xFF090A0D).toNative()
      ..minimumSize = const Size(1000, 650).toNative()
      ..setSize(const Size(1400, 900).toNative(), false)
      ..center()
      ..show()
      ..focus();
  } catch (_) {
    // Pencere API'si bu platformda kullanılamıyorsa uygulama varsayılan pencereyle açılır.
  }
}

/// Pencere nesnesi ilk karelerde hazır olmayabilir; kısa süre boyunca yeniden dener.
Future<Window?> _currentWindow() async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final window = WindowManager.instance.getCurrent();
    if (window != null) return window;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return null;
}
