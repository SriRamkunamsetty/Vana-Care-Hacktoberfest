import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/log.dart';
import '../data/repositories.dart';
import 'mbtiles.dart';

/// Where the catalogue of downloadable map regions lives. Set with
/// `--dart-define=VANA_REGION_MANIFEST=https://your.host/regions.json`.
/// Do not point this at the public OpenStreetMap tile servers: bulk downloading from them violates their usage policy.
const regionManifestUrl = String.fromEnvironment('VANA_REGION_MANIFEST');

class RegionOffer {
  final String id, name, version, url, sha256;
  final int bytes;
  final List<double> bounds; // minLon, minLat, maxLon, maxLat
  final int? minZoom, maxZoom;
  const RegionOffer({required this.id, required this.name, required this.version, required this.url, required this.sha256, required this.bytes, required this.bounds, this.minZoom, this.maxZoom});

  factory RegionOffer.fromJson(Map j) => RegionOffer(
        id: j['id'] as String,
        name: j['name'] as String,
        version: '${j['version']}',
        url: j['url'] as String,
        sha256: (j['sha256'] as String).toLowerCase(),
        bytes: (j['bytes'] as num).toInt(),
        bounds: [for (final v in (j['bounds'] as List)) (v as num).toDouble()],
        minZoom: (j['minzoom'] as num?)?.toInt(),
        maxZoom: (j['maxzoom'] as num?)?.toInt(),
      );
}

class RegionException implements Exception {
  final String message;
  const RegionException(this.message);
  @override
  String toString() => message;
}

class RegionService {
  RegionService({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'maps'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<RegionOffer>> fetchCatalogue() async {
    if (regionManifestUrl.isEmpty) throw const RegionException('No map catalogue is configured for this build. You can still import an .mbtiles file.');
    try {
      final r = await _http.get(Uri.parse(regionManifestUrl)).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw RegionException('The map catalogue could not be loaded (${r.statusCode}).');
      return [for (final j in jsonDecode(utf8.decode(r.bodyBytes)) as List) RegionOffer.fromJson(j as Map)];
    } on RegionException {
      rethrow;
    } catch (e) {
      logError('regions', e);
      throw const RegionException('Could not reach the map catalogue. Check your connection.');
    }
  }

  /// Resumable, checksum-verified download into app storage.
  Future<OfflineRegion> download(RegionOffer o, {required void Function(double fraction) onProgress, bool Function()? cancelled}) async {
    final dir = await _dir();
    final part = File(p.join(dir.path, '${o.id}.part'));
    final dest = File(p.join(dir.path, '${o.id}-${o.version}.mbtiles'));
    var have = await part.exists() ? await part.length() : 0;
    if (have > o.bytes) {
      await part.delete();
      have = 0;
    }
    final req = http.Request('GET', Uri.parse(o.url));
    if (have > 0) req.headers['Range'] = 'bytes=$have-';
    final res = await _http.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200 && res.statusCode != 206) throw RegionException('Download failed (${res.statusCode}).');
    if (res.statusCode == 200 && have > 0) {
      await part.writeAsBytes(const []); // server ignored Range: start over
      have = 0;
    }
    final sink = part.openWrite(mode: FileMode.append);
    var got = have;
    try {
      await for (final chunk in res.stream) {
        if (cancelled?.call() == true) throw const RegionException('Download cancelled.');
        sink.add(chunk);
        got += chunk.length;
        onProgress(got / o.bytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    final digest = await sha256.bind(part.openRead()).first;
    if (digest.toString() != o.sha256) {
      await part.delete();
      throw const RegionException('The downloaded map failed its integrity check and was discarded. Please try again.');
    }
    if (await dest.exists()) await dest.delete();
    await part.rename(dest.path);
    return _register(dest.path, id: o.id, name: o.name, version: o.version, bounds: o.bounds, minZoom: o.minZoom, maxZoom: o.maxZoom);
  }

  /// Lets the user pick an .mbtiles file from storage (for example one copied over USB or shared by a trek leader).
  Future<OfflineRegion?> importFile() async {
    final r = await FilePicker.pickFiles(type: FileType.any);
    final path = r.isEmpty ? null : r.first.path;
    if (path == null) return null;
    if (!path.toLowerCase().endsWith('.mbtiles')) throw const RegionException('Please choose a file ending in .mbtiles.');
    final dir = await _dir();
    final id = 'import-${DateTime.now().millisecondsSinceEpoch}';
    final dest = await File(path).copy(p.join(dir.path, '$id.mbtiles'));
    try {
      return await _register(dest.path, id: id);
    } catch (e) {
      await dest.delete();
      rethrow;
    }
  }

  Future<OfflineRegion> _register(String path, {required String id, String? name, String? version, List<double>? bounds, int? minZoom, int? maxZoom}) async {
    MbTilesReader reader;
    try {
      reader = await MbTilesReader.open(path);
    } catch (_) {
      throw const RegionException('This file is not a valid MBTiles map.');
    }
    final m = reader.meta;
    await reader.close();
    if (!m.isRaster) throw const RegionException('Only raster (image) map files are supported, not vector tiles.');
    final b = bounds ?? [m.minLon, m.minLat, m.maxLon, m.maxLat].whereType<double>().toList();
    return OfflineRegion(
      id: id, name: name ?? m.name, version: version ?? m.version, path: path, size: await File(path).length(),
      minLon: b.length == 4 ? b[0] : null, minLat: b.length == 4 ? b[1] : null, maxLon: b.length == 4 ? b[2] : null, maxLat: b.length == 4 ? b[3] : null,
      minZoom: minZoom ?? m.minZoom, maxZoom: maxZoom ?? m.maxZoom,
    );
  }
}
