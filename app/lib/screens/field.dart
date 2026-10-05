import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:geolocator/geolocator.dart';
import 'package:torch_light/torch_light.dart';
import '../data/repositories.dart';
import '../glass.dart';
import '../maps/mbtiles.dart';
import 'offline_maps.dart';
import '../sheets.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';

String fmtDur(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Trip timer. Owns its own once-a-second timer so only this widget rebuilds, not the whole app.
class ElapsedStat extends StatefulWidget {
  final double size;
  final String label;
  const ElapsedStat({super.key, required this.size, required this.label});
  @override
  State<ElapsedStat> createState() => _ElapsedStatState();
}

class _ElapsedStatState extends State<ElapsedStat> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.appRead.recording) setState(() {});
    });
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Stat(fmtDur(context.appRead.elapsed), '', widget.label, size: widget.size);
}

class Stat extends StatelessWidget {
  final String value, unit, label;
  final double size;
  const Stat(this.value, this.unit, this.label, {super.key, this.size = 25});
  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: value, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, letterSpacing: -.5, fontFeatures: const [FontFeature.tabularFigures()])),
        if (unit.isNotEmpty) TextSpan(text: ' $unit', style: TextStyle(fontSize: 13, color: vc.sub, fontWeight: FontWeight.w400)),
      ])),
      Text(label, style: TextStyle(fontSize: 12.5, color: vc.sub)),
    ]);
  }
}

// ==================================================================== HOME
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final dl = app.daylightLeft;
    return ScrollPage(children: [
      Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Tap(onTap: () => app.go(Screen.profile), child: Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD08A), Color(0xFFFFB65C)]), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))]), child: Text(app.profile.name.trim().isEmpty ? '+' : app.profile.name.trim()[0].toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF06251E))))),
        Glass(radius: 999, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: vc.acc, boxShadow: [BoxShadow(color: vc.acc, blurRadius: 10)])),
          const SizedBox(width: 8),
          Text(t['offlineAi'], style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ])),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(4, 2, 4, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t['greet'], style: TextStyle(fontSize: 16, color: vc.sub, fontWeight: FontWeight.w500)),
        Text(app.profile.firstName.isEmpty ? 'Welcome' : app.profile.firstName, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1.1, height: 1.05)),
      ])),
      Tap(
        onTap: () => openEmergency(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(gradient: kAlertGrad, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x66EF4444), blurRadius: 34, offset: Offset(0, 14))]),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, .2), borderRadius: BorderRadius.circular(18)), child: const Center(child: VIcon(Ic.cross, size: 28, color: Colors.white, stroke: 1.8))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['emMode'], style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.4, color: Colors.white)),
              Text(t['emSub'], style: const TextStyle(fontSize: 14, color: Color.fromRGBO(255, 255, 255, .92))),
            ])),
            const VIcon(Ic.chevR, size: 22, color: Colors.white, stroke: 2.4),
          ]),
        ),
      ),
      Tap(
        onTap: () => app.go(Screen.ai),
        child: Glass(height: 64, radius: 32, padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, gradient: vc.ai, boxShadow: const [BoxShadow(color: Color(0x663882F6), blurRadius: 16, offset: Offset(0, 6))]), child: const Center(child: VIcon(Ic.sparkle, size: 22, color: Colors.white))),
          const SizedBox(width: 12),
          Expanded(child: Text(t['askPh'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, color: vc.sub))),
          SizedBox(width: 40, child: Center(child: VIcon(Ic.mic, size: 22, color: vc.sub, stroke: 1.8))),
        ])),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 0), child: Text(t['quick'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.4))),
      fixedGrid([
        _Quick(t['firstAid'], t['firstAidSub'], Ic.cross, vc.redbg, vc.red, () { app.go(Screen.library); }),
        _Quick(t['vision'], t['visionSub'], Ic.image, vc.icebg, vc.ice, () => openVision(context)),
        _Quick(t['forest'], t['forestSub'], Ic.mtn, vc.accbg, vc.acc, () => app.go(Screen.explore)),
        _Quick(t['survival'], t['survivalSub'], Ic.compass, vc.ambbg, vc.amb, () => app.go(Screen.tools)),
      ], 116),
      Glass(radius: 30, padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          VIcon(Ic.pin, size: 16, color: vc.amb, stroke: 2),
          const SizedBox(width: 8),
          Expanded(child: Text(app.fmtPos == null ? (app.locationDenied ? 'Location is off. Enable it in Settings.' : 'Waiting for a GPS fix…') : '${app.fmtPos} · ${app.posAcc}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: vc.sub))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Stat(app.pos == null ? '—' : app.pos!.altitude.round().toString(), 'm', t['elev'])),
          Expanded(child: dl == null ? Stat('—', '', t['daylight']) : Stat('${dl.inHours}', 'h ${dl.inMinutes % 60}m', t['daylight'])),
          Expanded(child: Stat(app.batteryPct?.toString() ?? '—', '%', t['battery'])),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (app.batteryPct ?? 0) / 100, minHeight: 7, backgroundColor: vc.hair, valueColor: const AlwaysStoppedAnimation(kOrange))),
      ])),
    ]);
  }
}

class _Quick extends StatelessWidget {
  final String title, sub, d;
  final Color tint, color;
  final VoidCallback onTap;
  const _Quick(this.title, this.sub, this.d, this.tint, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap, scale: .95,
        child: Glass(radius: 28, padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)), child: Center(child: VIcon(d, size: 22, color: color))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.2)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: context.vc.sub)),
          ]),
        ])),
      );
}

// ==================================================================== TRAIL MAP
class TrailMap extends StatefulWidget {
  final double height;
  const TrailMap({super.key, required this.height});
  @override
  State<TrailMap> createState() => _TrailMapState();
}

class _TrailMapState extends State<TrailMap> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final app = context.app, vc = context.vc;
    final region = app.regionHere;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: vc.shadow),
      child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Stack(fit: StackFit.expand, children: [
        if (region != null)
          _TileMap(key: ValueKey(region.path), region: region)
        else
          Stack(fit: StackFit.expand, children: [
            RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: _MapPainter(vc, app.trail, app.pos == null ? null : (app.pos!.latitude, app.pos!.longitude)))),
            if (app.pos != null) RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: _PulsePainter(vc, app.trail, (app.pos!.latitude, app.pos!.longitude), _c))),
          ]),
        if (region == null)
          Positioned(left: 12, bottom: 12, child: Tap(onTap: () => openOfflineMaps(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: vc.solid, borderRadius: BorderRadius.circular(999), border: Border.all(color: vc.glBorder, width: .5)), child: Text('No offline map saved · add one', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: vc.acc))))),
      ])),
    );
  }
}

/// Raster offline map from a downloaded MBTiles region, with the recorded trail and the user's position on top.
class _TileMap extends StatefulWidget {
  final OfflineRegion region;
  const _TileMap({super.key, required this.region});
  @override
  State<_TileMap> createState() => _TileMapState();
}

class _TileMapState extends State<_TileMap> {
  final _ctl = MapController();
  MbTilesReader? _reader;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    MbTilesReader.open(widget.region.path).then((r) {
      if (!mounted) {
        r.close();
        return;
      }
      setState(() => _reader = r);
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _reader?.close();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, vc = context.vc, reg = widget.region;
    if (_failed) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('This map file could not be opened. Remove it and add it again in Offline maps.', textAlign: TextAlign.center, style: TextStyle(color: vc.sub))));
    final r = _reader;
    if (r == null) return ColoredBox(color: vc.mapbg);
    final me = app.pos == null ? null : LatLng(app.pos!.latitude, app.pos!.longitude);
    final centre = me != null && reg.covers(me.latitude, me.longitude) ? me : LatLng(((reg.minLat ?? 0) + (reg.maxLat ?? 0)) / 2, ((reg.minLon ?? 0) + (reg.maxLon ?? 0)) / 2);
    final maxZ = (reg.maxZoom ?? 16).toDouble();
    return Stack(fit: StackFit.expand, children: [
      FlutterMap(
        mapController: _ctl,
        options: MapOptions(initialCenter: centre, initialZoom: math.min(15, maxZ), minZoom: (reg.minZoom ?? 3).toDouble(), maxZoom: maxZ + 1, backgroundColor: vc.mapbg),
        children: [
          TileLayer(tileProvider: MbTilesProvider(r), maxNativeZoom: maxZ.toInt(), minNativeZoom: reg.minZoom ?? 0, tileDimension: 256),
          if (app.trail.length > 1) PolylineLayer(polylines: [Polyline(points: [for (final p in app.trail) LatLng(p.lat, p.lon)], color: vc.amb, strokeWidth: 4)]),
          MarkerLayer(markers: [
            if (app.trail.isNotEmpty) Marker(point: LatLng(app.trail.first.lat, app.trail.first.lon), width: 20, height: 20, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: vc.solid, border: Border.all(color: vc.acc, width: 3)))),
            if (me != null) Marker(point: me, width: 24, height: 24, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: kSky, border: Border.all(color: Colors.white, width: 3)))),
          ]),
        ],
      ),
      if (me != null) Positioned(right: 12, bottom: 12, child: Tap(onTap: () => _ctl.move(me, math.max(_ctl.camera.zoom, 14)), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: vc.solid, shape: BoxShape.circle, border: Border.all(color: vc.glBorder, width: .5)), child: Center(child: VIcon(Ic.pin, size: 20, color: vc.acc))))),
      Positioned(left: 12, bottom: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: vc.solid.withValues(alpha: .9), borderRadius: BorderRadius.circular(999)), child: Text(reg.name, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: vc.sub)))),
    ]);
  }
}

/// Maps lat/lon to canvas points so that the trail and the user's position fit the box. Shared by both map painters.
Offset Function((double, double))? _mapGeometry(Size size, List<TrailPoint> trail, (double, double)? me) {
  final pts = <(double, double)>[for (final p in trail) (p.lat, p.lon)];
  if (me != null) pts.add(me);
  if (pts.isEmpty) return null;
  final lat0 = pts.map((e) => e.$1).reduce((a, b) => a + b) / pts.length;
  final kx = math.cos(lat0 * math.pi / 180);
  final xs = pts.map((e) => e.$2 * kx), ys = pts.map((e) => -e.$1);
  var minX = xs.reduce(math.min), maxX = xs.reduce(math.max), minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  const minSpan = .0012;
  if (maxX - minX < minSpan) { final m = (maxX + minX) / 2; minX = m - minSpan / 2; maxX = m + minSpan / 2; }
  if (maxY - minY < minSpan) { final m = (maxY + minY) / 2; minY = m - minSpan / 2; maxY = m + minSpan / 2; }
  const pad = 36.0;
  final sc = math.min((size.width - pad * 2) / (maxX - minX), (size.height - pad * 2) / (maxY - minY));
  final ox = (size.width - (maxX - minX) * sc) / 2, oy = (size.height - (maxY - minY) * sc) / 2;
  return ((double, double) p) => Offset(ox + (p.$2 * kx - minX) * sc, oy + (-p.$1 - minY) * sc);
}

/// The still part of the map: grid rings, recorded trail, start marker and the position dot. Repaints only when data changes.
class _MapPainter extends CustomPainter {
  final VC vc;
  final List<TrailPoint> trail;
  final (double, double)? me;
  _MapPainter(this.vc, this.trail, this.me);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = vc.mapbg);
    final ring = Paint()..color = vc.cont..style = PaintingStyle.stroke..strokeWidth = 1;
    for (final (c, step) in [(Offset(size.width * .28, size.height * .62), 16.0), (Offset(size.width * .78, size.height * .26), 22.0)]) {
      for (var r = step; r < size.longestSide; r += step + 1) { canvas.drawCircle(c, r, ring); }
    }
    final o = _mapGeometry(size, trail, me);
    if (o == null) return;
    if (trail.length > 1) {
      final path = Path()..moveTo(o((trail.first.lat, trail.first.lon)).dx, o((trail.first.lat, trail.first.lon)).dy);
      for (final p in trail.skip(1)) { final q = o((p.lat, p.lon)); path.lineTo(q.dx, q.dy); }
      final dash = Paint()..color = vc.amb..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 9) { canvas.drawPath(m.extractPath(d, d + 1), dash); }
      }
    }
    if (trail.isNotEmpty) {
      final s0 = o((trail.first.lat, trail.first.lon));
      canvas.drawCircle(s0, 7, Paint()..color = vc.solid);
      canvas.drawCircle(s0, 7, Paint()..color = vc.acc..style = PaintingStyle.stroke..strokeWidth = 3);
    }
    if (me != null) {
      final p = o(me!);
      canvas.drawCircle(p, 10, Paint()..color = Colors.white);
      canvas.drawCircle(p, 7, Paint()..color = kSky);
    }
  }

  @override
  bool shouldRepaint(_MapPainter o) => o.trail.length != trail.length || o.me != me || o.vc != vc;
}

/// Only the expanding ring around the user's position. Cheap enough to animate every frame.
class _PulsePainter extends CustomPainter {
  final VC vc;
  final List<TrailPoint> trail;
  final (double, double) me;
  final Animation<double> t;
  _PulsePainter(this.vc, this.trail, this.me, this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final o = _mapGeometry(size, trail, me);
    if (o == null) return;
    canvas.drawCircle(o(me), 22 * (.4 + 1.2 * t.value), Paint()..color = vc.ice.withValues(alpha: .5 * (1 - t.value)));
  }

  @override
  bool shouldRepaint(_PulsePainter o) => o.me != me || o.trail.length != trail.length || o.vc != vc;
}

// ==================================================================== EXPLORE
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final km = app.distanceM / 1000;
    return ScrollPage(children: [
      LargeTitle(t['forest']),
      Padding(padding: const EdgeInsets.only(left: 4, top: 0), child: GestureDetector(onTap: () => openOfflineMaps(context), child: Text(app.offlineRegions.isEmpty ? 'No offline map saved · tap to add' : '${app.offlineRegions.length == 1 ? app.offlineRegions.first.name : '${app.offlineRegions.length} maps'} saved offline', style: TextStyle(fontSize: 15, color: vc.sub)))),
      Glass(radius: 30, padding: const EdgeInsets.all(18), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(app.recording ? t['tripOn'] : t['tripOff'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: vc.acc)),
          if (app.recording) Row(children: [Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: kAlert)), const SizedBox(width: 6), Text('REC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vc.red))]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: ElapsedStat(size: 24, label: t['elapsed'])),
          Expanded(child: Stat(km.toStringAsFixed(km < 10 ? 2 : 1), 'km', t['distance'], size: 24)),
          Expanded(child: Stat(app.pos == null ? '—' : '±${app.pos!.accuracy.round()}', 'm', 'GPS', size: 24)),
        ]),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.only(top: 12), decoration: BoxDecoration(border: Border(top: BorderSide(color: vc.hair, width: .5))), child: Row(children: [
          Expanded(child: Text(t['record'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          VSwitch(on: app.recording, onChanged: (v) => app.setRecording(v)),
        ])),
        if (!app.recording && app.trail.isNotEmpty) Align(alignment: Alignment.centerRight, child: GestureDetector(onTap: app.clearTrip, child: Padding(padding: const EdgeInsets.only(top: 10), child: Text('Clear recorded trail', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: vc.red))))),
      ])),
      GestureDetector(onTap: () => app.go(Screen.map), child: const TrailMap(height: 190)),
      fixedGrid([
        _Act(t['map'], Ic.pin, vc.accbg, vc.acc, () => app.go(Screen.map)),
        _Act(t['lost'], Ic.warn, vc.ambbg, vc.amb, () => app.go(Screen.lost)),
        _Act(t['survival'], Ic.compass, vc.icebg, vc.ice, () => app.go(Screen.tools)),
        _Act('Safety guides', Ic.book, vc.redbg, vc.red, () => app.go(Screen.library)),
      ], 104),
      Glass(radius: 28, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['checkin'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(t['checkinSub'], style: TextStyle(fontSize: 13, color: vc.sub, height: 1.35)),
        ])),
        const SizedBox(width: 14),
        VSwitch(on: app.checkin, onChanged: (v) => app.setCheckin(v)),
      ])),
      Glass(radius: 28, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: vc.icebg, borderRadius: BorderRadius.circular(14)), child: Center(child: VIcon(Ic.sun, size: 22, color: vc.ice))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.forecast == null ? 'No forecast saved' : 'Forecast saved ${_ago(app.forecast!.savedAt)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(app.forecast == null ? 'Live weather needs a connection. Save a forecast before you go.' : 'This is a snapshot, not live weather. Conditions can change quickly.', style: TextStyle(fontSize: 13, color: vc.sub, height: 1.3)),
          ])),
          Tap(onTap: app.forecastBusy ? null : app.saveForecast, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(999)), child: Text(app.forecastBusy ? '…' : (app.forecast == null ? 'Save' : 'Update'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)))),
        ]),
        if (app.forecast != null) ...[
          const SizedBox(height: 10),
          for (final d in app.forecast!.days)
            Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
              SizedBox(width: 92, child: Text(d.date.length >= 10 ? d.date.substring(5) : d.date, style: TextStyle(fontSize: 14, color: vc.sub))),
              Expanded(child: Text('${d.tMin?.round() ?? '–'}° to ${d.tMax?.round() ?? '–'}°C · rain ${d.rain?.toStringAsFixed(d.rain! >= 10 ? 0 : 1) ?? '–'} mm · wind ${d.wind?.round() ?? '–'} km/h', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            ])),
        ],
      ])),
    ]);
  }
}

class _Act extends StatelessWidget {
  final String title, d;
  final Color tint, color;
  final VoidCallback onTap;
  const _Act(this.title, this.d, this.tint, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap, scale: .95,
        child: Glass(radius: 28, padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(13)), child: Center(child: VIcon(d, size: 21, color: color))),
          Flexible(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -.2))),
        ])),
      );
}

// ==================================================================== MAP
String _cardinal(double bearing) => const ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'][((bearing % 360) / 45).round() % 8];

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final km = app.distanceM / 1000;
    return ScrollPage(children: [
      BackTitle(t['map'], onBack: () => app.go(Screen.explore)),
      Stack(children: [
        const TrailMap(height: 430),
        Positioned(top: 14, left: 14, child: Glass(radius: 999, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Text('N ↑ ${app.hasHeading ? app.heading.round() : '—'}°', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))),
        if (app.recording) Positioned(top: 14, right: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: kAlert, borderRadius: BorderRadius.circular(999)), child: const Text('REC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))),
        Positioned(right: 14, bottom: 14, child: GestureDetector(onTap: () => app.setRecording(!app.recording), child: Glass(width: 46, height: 46, radius: 23, child: Center(child: VIcon(Ic.pulse, size: 22, color: app.recording ? kAlert : vc.tx, stroke: 2))))),
      ]),
      Glass(radius: 28, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), child: Row(children: [
        Expanded(child: Stat('${km.toStringAsFixed(2)} km', '', t['distance'], size: 22)),
        Expanded(child: Stat('${app.trail.length}', 'pts', 'Recorded')),
        Expanded(child: ElapsedStat(size: 22, label: t['elapsed'])),
      ])),
      PrimButton(t['returnStart'], height: 56, onTap: () {
        final p = app.pos;
        if (app.trail.isEmpty || p == null) { app.toast('Record a trail with a GPS fix first'); return; }
        final s = app.trail.first;
        final d = Geolocator.distanceBetween(p.latitude, p.longitude, s.lat, s.lon);
        final b = (Geolocator.bearingBetween(p.latitude, p.longitude, s.lat, s.lon) + 360) % 360;
        app.toast('Start is ${d < 1000 ? '${d.round()} m' : '${(d / 1000).toStringAsFixed(1)} km'} to the ${_cardinal(b)} (${b.round()}°)');
      }),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(t['pathNote'], textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.4, color: vc.sub2))),
    ]);
  }
}

// ==================================================================== LOST
class LostScreen extends StatelessWidget {
  const LostScreen({super.key});
  static const rows = ['Stop and stay calm. Sit down and breathe.', 'Note landmarks, the time and your last known position.', 'Blow the whistle three times, then wait.', 'Save battery. Turn on battery saver.', 'Move only to open ground if it is safe.'];
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    return ScrollPage(children: [
      BackTitle(t['lost'], onBack: () => app.go(Screen.explore)),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF97316), Color(0xFFDC4A0B)]), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x59F97316), blurRadius: 34, offset: Offset(0, 14))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['lastPos'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: Colors.white)),
          const SizedBox(height: 6),
          Text(app.fmtPos ?? app.lastKnownLine ?? 'Location unavailable', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.4, color: Colors.white)),
          const SizedBox(height: 4),
          Text(app.pos == null ? 'Allow location access to see your position' : '${app.posAcc} · live GPS', style: const TextStyle(fontSize: 14, color: Colors.white)),
        ]),
      ),
      Row(children: [
        Expanded(child: AlertButton(t['call112'], onTap: app.call112)),
        const SizedBox(width: 12),
        Expanded(child: Tap(scale: .97, onTap: app.sharePosition, child: Container(height: 60, decoration: BoxDecoration(color: vc.solid, borderRadius: BorderRadius.circular(22), boxShadow: vc.shadow), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [VIcon(Ic.pin, size: 20, color: vc.solidtx, stroke: 2.2), const SizedBox(width: 8), Flexible(child: Text(t['sharePos'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: vc.solidtx)))])))),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 0), child: Text(t['lostCheck'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      for (int i = 0; i < rows.length; i++)
        Tap(scale: .98, onTap: () => app.toggleLost(i), child: Opacity(opacity: (app.lostChk[i] ?? false) ? .6 : 1, child: Solid(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), child: Row(children: [
          AnimatedContainer(duration: const Duration(milliseconds: 300), width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: (app.lostChk[i] ?? false) ? kGreen : kOrange), child: (app.lostChk[i] ?? false) ? const Center(child: VIcon(Ic.check, size: 16, color: Colors.white, stroke: 3)) : null),
          const SizedBox(width: 14),
          Expanded(child: Text(rows[i], style: const TextStyle(fontSize: 16.5, height: 1.35, fontWeight: FontWeight.w600))),
        ])))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(t['pathNote'], textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.4, color: vc.sub2))),
    ]);
  }
}

// ==================================================================== TOOLS
class _Dial extends CustomPainter {
  final VC vc;
  final double heading;
  _Dial(this.vc, this.heading);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * math.pi / 180);
    canvas.drawCircle(Offset.zero, r, Paint()..shader = RadialGradient(center: const Alignment(-.3, -.5), colors: [vc.chip, Colors.transparent], stops: const [0, .6]).createShader(Rect.fromCircle(center: Offset.zero, radius: r)));
    canvas.drawCircle(Offset.zero, r - .5, Paint()..color = vc.hair..style = PaintingStyle.stroke..strokeWidth = 1);
    for (var i = 0; i < 72; i++) {
      final major = i % 9 == 0, mid = i % 3 == 0;
      final len = major ? 16.0 : (mid ? 10.0 : 6.0);
      canvas.save();
      canvas.rotate(i * 5 * math.pi / 180);
      canvas.drawLine(Offset(0, -r + 5), Offset(0, -r + 5 + len), Paint()..color = major ? vc.tx : vc.sub2..strokeWidth = major ? 2.5 : 1.5);
      canvas.restore();
    }
    for (final (l, a, col) in [('N', 0.0, kAlert), ('E', 90.0, vc.tx), ('S', 180.0, vc.tx), ('W', 270.0, vc.tx)]) {
      canvas.save();
      canvas.rotate(a * math.pi / 180);
      final tp = TextPainter(text: TextSpan(text: l, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: col)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -r + 26));
      canvas.restore();
    }
    canvas.restore();
    canvas.drawCircle(c, 5, Paint()..color = kOrange);
    canvas.drawPath(Path()..moveTo(c.dx - 8, 0)..lineTo(c.dx + 8, 0)..lineTo(c.dx, 14)..close(), Paint()..color = kOrange);
  }
  @override
  bool shouldRepaint(_Dial o) => o.heading != heading || o.vc != vc;
}

/// Torch (SOS pattern) and whistle tone — the two hardware-backed survival tools.
class ToolsController {
  static final ToolsController i = ToolsController._();
  ToolsController._();
  bool _strobeOn = false;
  final AudioPlayer _player = AudioPlayer();
  Timer? _whistleT;

  static const _sos = [1, 1, 1, 3, 3, 3, 1, 1, 1]; // dot units

  Future<bool> strobe(bool on, void Function(String) toast) async {
    _strobeOn = on;
    if (!on) { try { await TorchLight.disableTorch(); } catch (_) {} return true; }
    try {
      if (!await TorchLight.isTorchAvailable()) { toast('No flashlight on this device'); return false; }
    } catch (_) { toast('Flashlight unavailable'); return false; }
    () async {
      while (_strobeOn) {
        for (final u in _sos) {
          if (!_strobeOn) break;
          try { await TorchLight.enableTorch(); } catch (_) {}
          await Future<void>.delayed(Duration(milliseconds: 220 * u));
          try { await TorchLight.disableTorch(); } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
        if (_strobeOn) await Future<void>.delayed(const Duration(milliseconds: 1400));
      }
    }();
    return true;
  }

  static Uint8List _tone({double hz = 2900, double seconds = .9, int rate = 22050}) {
    final n = (rate * seconds).round();
    final b = BytesBuilder();
    void w32(int v) => b.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]);
    void w16(int v) => b.add([v & 255, (v >> 8) & 255]);
    b.add('RIFF'.codeUnits); w32(36 + n * 2); b.add('WAVEfmt '.codeUnits); w32(16); w16(1); w16(1); w32(rate); w32(rate * 2); w16(2); w16(16);
    b.add('data'.codeUnits); w32(n * 2);
    for (var k = 0; k < n; k++) {
      // pea-whistle: carrier with a fast warble, short fade in/out
      final env = math.min(1.0, math.min(k / 800, (n - k) / 1500));
      final f = hz + 120 * math.sin(2 * math.pi * 26 * k / rate);
      w16((math.sin(2 * math.pi * f * k / rate) * 30000 * env).round() & 0xFFFF);
    }
    return b.toBytes();
  }

  Future<void> whistle(bool on) async {
    _whistleT?.cancel();
    await _player.stop();
    if (!on) return;
    final bytes = _tone();
    Future<void> blast3() async {
      for (var k = 0; k < 3; k++) {
        await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    }
    await blast3();
    _whistleT = Timer.periodic(const Duration(seconds: 9), (_) => blast3());
  }

  void stopAll() { _strobeOn = false; _whistleT?.cancel(); _player.stop(); TorchLight.disableTorch().catchError((_) {}); }
}

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final hd = app.heading;
    Widget row(String k, String title, String sub, String d, Color tint, Color color, bool last, Future<void> Function(bool) onSet) => GestureDetector(
          onTap: () => onSet(!(app.tools[k] ?? false)),
          behavior: HitTestBehavior.opaque,
          child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: vc.hair, width: .5))), child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(13)), child: Center(child: VIcon(d, size: 21, color: color))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)), Text(sub, style: TextStyle(fontSize: 13, color: vc.sub))])),
            VSwitch(on: app.tools[k] ?? false, onChanged: onSet),
          ])),
        );
    Future<void> setTool(String k, bool v) async { app.toggleMap(app.tools, k, 'tool'); if (app.tools[k] != v) app.toggleMap(app.tools, k, 'tool'); }
    return ScrollPage(children: [
      BackTitle(t['survival'], onBack: () => app.go(Screen.explore)),
      Glass(radius: 34, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(app.hasHeading ? '${hd.round()}°' : '—', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -1, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 8),
          Text(app.hasHeading ? _cardinal(hd) : '', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: vc.amb)),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: 236, height: 236, child: CustomPaint(painter: _Dial(vc, hd))),
        const SizedBox(height: 14),
        Text(app.hasHeading ? 'Magnetic north · GPS off · hold the phone flat' : 'Compass sensor not available on this device', style: TextStyle(fontSize: 13, color: vc.sub)),
      ])),
      Glass(radius: 30, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), child: Column(children: [
        row('whistle', 'Emergency whistle', 'Three blasts, repeating', Ic.whistle, vc.accbg, vc.acc, false, (v) async { await setTool('whistle', v); await ToolsController.i.whistle(v); }),
        row('strobe', 'Flashlight strobe', 'SOS pattern on the LED', Ic.flash, vc.ambbg, vc.amb, false, (v) async { final ok = await ToolsController.i.strobe(v, app.toast); if (ok || !v) await setTool('strobe', v); }),
        row('mirror', 'Signal mirror guide', 'Aim reflected sunlight at the target', Ic.mirror, vc.icebg, vc.ice, false, (v) async { await setTool('mirror', v); if (v) app.toast('Hold the mirror near your face, sweep light across the target slowly.'); }),
        row('saver', 'Battery saver', 'Lower GPS accuracy, fewer updates', Ic.bolt, vc.accbg, vc.acc, true, (v) async { await setTool('saver', v); await app.restartLocation(); }),
      ])),
    ]);
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 2) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
