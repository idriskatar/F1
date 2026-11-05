import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite cache. Schema is intentionally small for the first milestone.
class LocalStore {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      p.join(dbPath, 'f1_tracker.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache_entries (
            cache_key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<void> saveJson(String key, String payload) async {
    final db = await database;
    await db.insert(
      'cache_entries',
      {
        'cache_key': key,
        'payload': payload,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readJson(String key) async {
    final db = await database;
    final rows = await db.query(
      'cache_entries',
      columns: ['payload'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['payload'] as String;
  }
}
