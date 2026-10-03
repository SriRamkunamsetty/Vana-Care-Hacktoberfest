import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sqflite/sqflite.dart';
import '../core/log.dart';

final Uint8List _blankTile = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class MbTilesMeta {
  final String name, version, format;
  final double? minLat, minLon, maxLat, maxLon;
  final int? minZoom, maxZoom;
  const MbTilesMeta({required this.name, required this.version, required this.format, this.minLat, this.minLon, this.maxLat, this.maxLon, this.minZoom, this.maxZoom});

  /// Vector (pbf) packages cannot be drawn by this reader.
  bool get isRaster => format == 'png' || format == 'jpg' || format == 'jpeg' || format == 'webp';
}

/// Read-only access to an MBTiles raster tile package (the offline map file format).
class MbTilesReader {
  MbTilesReader._(this._db, this.meta);
  final Database _db;
  final MbTilesMeta meta;

  static Future<MbTilesReader> open(String path) async {
    final db = await openReadOnlyDatabase(path);
    final rows = await db.query('metadata');
    final m = {for (final r in rows) r['name'] as String: (r['value'] ?? '').toString()};
    double? d(int i) => m['bounds'] == null ? null : double.tryParse(m['bounds']!.split(',')[i].trim());
    final meta = MbTilesMeta(
      name: m['name'] ?? 'Offline map',
      version: m['version'] ?? '1',
      format: (m['format'] ?? 'png').toLowerCase(),
      minLon: d(0), minLat: d(1), maxLon: d(2), maxLat: d(3),
      minZoom: int.tryParse(m['minzoom'] ?? ''), maxZoom: int.tryParse(m['maxzoom'] ?? ''),
    );
    return MbTilesReader._(db, meta);
  }

  /// MBTiles stores rows in TMS order, so the y coordinate is flipped.
  Future<Uint8List?> tile(int z, int x, int y) async {
    final tmsY = (1 << z) - 1 - y;
    final r = await _db.query('tiles', columns: ['tile_data'], where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?', whereArgs: [z, x, tmsY], limit: 1);
    return r.isEmpty ? null : r.first['tile_data'] as Uint8List;
  }

  Future<void> close() => _db.close();
}

class MbTilesProvider extends TileProvider {
  MbTilesProvider(this.reader);
  final MbTilesReader reader;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => _MbTileImage(reader, coordinates.z, coordinates.x, coordinates.y);

  @override
  Future<void> dispose() async {
    super.dispose();
  }
}

class _MbTileImage extends ImageProvider<_MbTileImage> {
  const _MbTileImage(this.reader, this.z, this.x, this.y);
  final MbTilesReader reader;
  final int z, x, y;

  @override
  Future<_MbTileImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_MbTileImage key, ImageDecoderCallback decode) => MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    Uint8List? bytes;
    try {
      bytes = await reader.tile(z, x, y);
    } catch (e) {
      logError('mbtiles', e);
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes ?? _blankTile));
  }

  @override
  bool operator ==(Object other) => other is _MbTileImage && identical(other.reader, reader) && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(identityHashCode(reader), z, x, y);
}
