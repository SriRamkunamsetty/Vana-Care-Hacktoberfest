import 'package:sqflite/sqflite.dart';
import '../core/db.dart';

class RoutePoint {
  final double lat, lon;
  final int ts;
  final double? acc;
  const RoutePoint(this.lat, this.lon, this.ts, [this.acc]);
}

class Trip {
  final int id;
  final String name;
  final DateTime start;
  final DateTime? plannedReturn, end;
  const Trip(this.id, this.name, this.start, this.plannedReturn, this.end);
  factory Trip.fromRow(Map<String, Object?> r) => Trip(
      r['id'] as int,
      r['name'] as String,
      DateTime.fromMillisecondsSinceEpoch(r['start_time'] as int),
      (r['planned_return'] as int?) == null ? null : DateTime.fromMillisecondsSinceEpoch(r['planned_return'] as int),
      (r['end_time'] as int?) == null ? null : DateTime.fromMillisecondsSinceEpoch(r['end_time'] as int));
}

class TripRepository {
  TripRepository(this._d);
  final AppDatabase _d;

  Future<Trip> start(String name, {DateTime? plannedReturn}) async {
    final now = DateTime.now();
    final id = await _d.db.insert('trip', {'name': name, 'start_time': now.millisecondsSinceEpoch, 'planned_return': plannedReturn?.millisecondsSinceEpoch});
    return Trip(id, name, now, plannedReturn, null);
  }

  Future<void> finish(int id) => _d.db.update('trip', {'end_time': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);

  /// The most recent trip that has not been ended, if any (survives app restarts).
  Future<Trip?> active() async {
    final rows = await _d.db.query('trip', where: 'end_time IS NULL', orderBy: 'start_time DESC', limit: 1);
    return rows.isEmpty ? null : Trip.fromRow(rows.first);
  }

  Future<List<Trip>> all() async => (await _d.db.query('trip', orderBy: 'start_time DESC')).map(Trip.fromRow).toList();

  Future<void> addPoint(int tripId, RoutePoint p) =>
      _d.db.insert('route_point', {'trip_id': tripId, 'lat': p.lat, 'lon': p.lon, 'ts': p.ts, 'acc': p.acc});

  Future<List<RoutePoint>> points(int tripId) async => (await _d.db.query('route_point', where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'ts ASC'))
      .map((r) => RoutePoint((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble(), r['ts'] as int, (r['acc'] as num?)?.toDouble()))
      .toList();

  Future<void> delete(int id) => _d.db.delete('trip', where: 'id = ?', whereArgs: [id]);
}

class HealthSession {
  final int id;
  final DateTime createdAt;
  final String summary, status;
  const HealthSession(this.id, this.createdAt, this.summary, this.status);
}

class SymptomEntry {
  final String symptom;
  final String? duration, severity;
  const SymptomEntry(this.symptom, {this.duration, this.severity});
}

/// User-initiated health sessions. Only saved when the user explicitly asks (privacy setting).
class HealthSessionRepository {
  HealthSessionRepository(this._d);
  final AppDatabase _d;

  Future<int> save(String summary, {String status = 'open', List<SymptomEntry> symptoms = const []}) async {
    return _d.db.transaction((tx) async {
      final id = await tx.insert('health_session', {'created_at': DateTime.now().millisecondsSinceEpoch, 'summary': summary, 'status': status});
      for (final s in symptoms) {
        await tx.insert('symptom_entry', {'session_id': id, 'symptom': s.symptom, 'duration': s.duration, 'severity': s.severity});
      }
      return id;
    });
  }

  Future<List<HealthSession>> all() async => (await _d.db.query('health_session', orderBy: 'created_at DESC'))
      .map((r) => HealthSession(r['id'] as int, DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int), r['summary'] as String, r['status'] as String))
      .toList();

  Future<void> delete(int id) => _d.db.delete('health_session', where: 'id = ?', whereArgs: [id]);
  Future<void> deleteAll() => _d.db.delete('health_session');
}

class OfflineRegion {
  final String id, name, version, path;
  final int size;
  final double? minLat, minLon, maxLat, maxLon;
  final int? minZoom, maxZoom;
  const OfflineRegion({required this.id, required this.name, required this.version, required this.path, required this.size, this.minLat, this.minLon, this.maxLat, this.maxLon, this.minZoom, this.maxZoom});

  bool covers(double lat, double lon) =>
      minLat != null && lat >= minLat! && lat <= maxLat! && lon >= minLon! && lon <= maxLon!;

  Map<String, Object?> toRow() => {'id': id, 'name': name, 'version': version, 'size': size, 'path': path, 'min_lat': minLat, 'min_lon': minLon, 'max_lat': maxLat, 'max_lon': maxLon, 'min_zoom': minZoom, 'max_zoom': maxZoom};
  factory OfflineRegion.fromRow(Map<String, Object?> r) => OfflineRegion(
      id: r['id'] as String, name: r['name'] as String, version: r['version'] as String, path: r['path'] as String, size: r['size'] as int,
      minLat: (r['min_lat'] as num?)?.toDouble(), minLon: (r['min_lon'] as num?)?.toDouble(), maxLat: (r['max_lat'] as num?)?.toDouble(), maxLon: (r['max_lon'] as num?)?.toDouble(),
      minZoom: r['min_zoom'] as int?, maxZoom: r['max_zoom'] as int?);
}

class RegionRepository {
  RegionRepository(this._d);
  final AppDatabase _d;
  Future<List<OfflineRegion>> all() async => (await _d.db.query('offline_region', orderBy: 'name')).map(OfflineRegion.fromRow).toList();
  Future<void> upsert(OfflineRegion r) => _d.db.insert('offline_region', r.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> delete(String id) => _d.db.delete('offline_region', where: 'id = ?', whereArgs: [id]);
}
