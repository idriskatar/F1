import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

/// Masaüstü (Windows/Linux/macOS) ortamında mıyız?
bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Uygulama verilerinin (SQLite önbelleği, replay dosyaları) tutulacağı temel dizin.
///
/// Mobilde mevcut davranış korunur: `sqflite`'ın `getDatabasesPath()` sonucu kullanılır.
/// Masaüstünde ise platforma uygun uygulama destek dizini (`path_provider`) kullanılır;
/// böylece SQLite dosyası ve replay önbelleği kalıcı bir konumda tutulur.
Future<String> appDataDirectory() async {
  if (isDesktopPlatform) {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return dir.path;
  }
  return getDatabasesPath();
}

/// Alt dizin adı verilerek o alt dizinin tam yolu döndürülür (oluşturulmaz).
Future<String> appDataSubdirectory(String name) async {
  final base = await appDataDirectory();
  return p.join(base, name);
}
