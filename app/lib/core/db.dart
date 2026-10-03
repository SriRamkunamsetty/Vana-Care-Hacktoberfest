import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'log.dart';

/// Local-first SQLite store (blueprint section 9). Contacts, the Medical ID and
/// emergency events stay in encrypted secure storage; everything else lives here.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static const _version = 1;
  static AppDatabase? _instance;

  /// Opens the shared on-disk database. Pass [path] (e.g. [inMemoryDatabasePath]) in tests.
  static Future<AppDatabase> open({String? path}) async {
    if (path == null && _instance != null) return _instance!;
    final dbPath = path ?? p.join(await getDatabasesPath(), 'vana_care.db');
    final db = await openDatabase(dbPath, version: _version, onCreate: _create, onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'));
    final inst = AppDatabase._(db);
    if (path == null) _instance = inst;
    return inst;
  }

  static Future<void> _create(Database d, int v) async {
    logInfo('db', 'create v$v');
    final b = d.batch();
    b.execute('''CREATE TABLE knowledge_chunk (
      id TEXT PRIMARY KEY, doc_id TEXT NOT NULL, title TEXT NOT NULL, text TEXT NOT NULL,
      lang TEXT NOT NULL DEFAULT 'en', source TEXT NOT NULL, version TEXT NOT NULL, embedding BLOB)''');
    b.execute('CREATE INDEX idx_chunk_doc ON knowledge_chunk(doc_id)');
    b.execute('''CREATE TABLE health_session (
      id INTEGER PRIMARY KEY AUTOINCREMENT, created_at INTEGER NOT NULL, summary TEXT NOT NULL, status TEXT NOT NULL)''');
    b.execute('''CREATE TABLE symptom_entry (
      id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL REFERENCES health_session(id) ON DELETE CASCADE,
      symptom TEXT NOT NULL, duration TEXT, severity TEXT)''');
    b.execute('''CREATE TABLE trip (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, start_time INTEGER NOT NULL,
      planned_return INTEGER, end_time INTEGER)''');
    b.execute('''CREATE TABLE route_point (
      id INTEGER PRIMARY KEY AUTOINCREMENT, trip_id INTEGER NOT NULL REFERENCES trip(id) ON DELETE CASCADE,
      lat REAL NOT NULL, lon REAL NOT NULL, ts INTEGER NOT NULL, acc REAL)''');
    b.execute('CREATE INDEX idx_route_trip ON route_point(trip_id, ts)');
    b.execute('''CREATE TABLE offline_region (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, version TEXT NOT NULL, size INTEGER NOT NULL, path TEXT NOT NULL,
      min_lat REAL, min_lon REAL, max_lat REAL, max_lon REAL, min_zoom INTEGER, max_zoom INTEGER)''');
    await b.commit(noResult: true);
  }

  Future<void> close() async {
    await db.close();
    if (identical(_instance?.db, db)) _instance = null;
  }

  /// Deletes every record this database holds (used by "delete all my data").
  Future<void> wipe() async {
    final b = db.batch();
    for (final t in ['symptom_entry', 'health_session', 'route_point', 'trip']) {
      b.delete(t);
    }
    await b.commit(noResult: true);
  }
}
