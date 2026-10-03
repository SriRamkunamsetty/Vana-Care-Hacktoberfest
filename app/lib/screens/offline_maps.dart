import 'package:flutter/material.dart';
import '../glass.dart';
import '../maps/region_service.dart';
import '../ui.dart';

Future<void> openOfflineMaps(BuildContext context) => showVSheet(context, (c) => const OfflineMapsSheet());

String _mb(int bytes) => bytes >= 1e9 ? '${(bytes / 1e9).toStringAsFixed(1)} GB' : '${(bytes / 1e6).round()} MB';

/// Manage downloaded regional maps. Maps are raster MBTiles files stored on the phone.
class OfflineMapsSheet extends StatefulWidget {
  const OfflineMapsSheet({super.key});
  @override
  State<OfflineMapsSheet> createState() => _OfflineMapsSheetState();
}

class _OfflineMapsSheetState extends State<OfflineMapsSheet> {
  final _svc = RegionService();
  List<RegionOffer>? _offers;
  String? _error;
  String? _busyId;
  double _progress = 0;
  bool _cancel = false;
  bool _loadingCatalogue = false;

  Future<void> _browse() async {
    setState(() { _loadingCatalogue = true; _error = null; });
    try {
      final o = await _svc.fetchCatalogue();
      if (mounted) setState(() => _offers = o);
    } on RegionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingCatalogue = false);
    }
  }

  Future<void> _download(RegionOffer o) async {
    final app = context.appRead;
    setState(() { _busyId = o.id; _progress = 0; _cancel = false; _error = null; });
    try {
      final r = await _svc.download(o, onProgress: (f) { if (mounted) setState(() => _progress = f); }, cancelled: () => _cancel);
      await app.addRegion(r);
      app.toast('${o.name} is ready offline');
    } on RegionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Download stopped. Check your connection and try again. It will resume where it left off.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _import() async {
    final app = context.appRead;
    setState(() => _error = null);
    try {
      final r = await _svc.importFile();
      if (r != null) {
        await app.addRegion(r);
        app.toast('${r.name} added');
      }
    } on RegionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, vc = context.vc;
    final installedIds = {for (final r in app.offlineRegions) r.id};
    return SheetFrame(
      topInset: 90, title: 'Offline maps', subtitle: 'Download before you go',
      child: ListView(padding: EdgeInsets.zero, children: [
        if (app.offlineRegions.isEmpty)
          Solid(child: Text('No map is saved on this phone yet. Without one, Forest Mode still records your trail and shows it on a plain grid, and the compass and GPS keep working.', style: TextStyle(fontSize: 14.5, height: 1.4, color: vc.sub))),
        for (final r in app.offlineRegions)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Solid(child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
              Text('${_mb(r.size)} · v${r.version}${r.minZoom == null ? '' : ' · zoom ${r.minZoom}-${r.maxZoom}'}', style: TextStyle(fontSize: 13, color: vc.sub)),
            ])),
            Tap(onTap: () => app.removeRegion(r), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: vc.redbg, borderRadius: BorderRadius.circular(999)), child: Text('Remove', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: vc.red)))),
          ]))),
        const SizedBox(height: 4),
        if (_busyId != null) ...[
          ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: _progress, minHeight: 10, color: vc.acc, backgroundColor: vc.hair)),
          const SizedBox(height: 8),
          Text('${(_progress * 100).round()}% · it resumes if the connection drops', style: TextStyle(fontSize: 12.5, color: vc.sub)),
          const SizedBox(height: 10),
          Tap(onTap: () => setState(() => _cancel = true), child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(24)), child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
        ] else ...[
          if (regionManifestUrl.isNotEmpty) PrimButton(_loadingCatalogue ? 'Loading…' : 'Browse available maps', height: 54, fontSize: 16, onTap: _loadingCatalogue ? null : _browse),
          if (regionManifestUrl.isNotEmpty) const SizedBox(height: 10),
          Tap(onTap: _import, child: Container(height: 54, alignment: Alignment.center, decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(27)), child: const Text('Import an .mbtiles file', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(fontSize: 13.5, height: 1.35, color: vc.red, fontWeight: FontWeight.w600))),
        if (_offers != null) ...[
          const SizedBox(height: 16),
          const FieldLabel('AVAILABLE REGIONS'),
          const SizedBox(height: 8),
          if (_offers!.isEmpty) Text('No maps are listed yet.', style: TextStyle(color: vc.sub)),
          for (final o in _offers!)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Solid(child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                Text('${_mb(o.bytes)} · v${o.version}', style: TextStyle(fontSize: 13, color: vc.sub)),
              ])),
              if (installedIds.contains(o.id)) Text('Installed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: vc.acc)) else Tap(onTap: _busyId == null ? () => _download(o) : null, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(gradient: vc.prim, borderRadius: BorderRadius.circular(999)), child: Text('Download', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: vc.onprim)))),
            ]))),
        ],
        const SizedBox(height: 14),
        Text('Maps are raster MBTiles files. A map never guarantees a safe route. Rivers, cliffs and weather change what is passable.', style: TextStyle(fontSize: 12.5, height: 1.4, color: vc.sub2)),
      ]),
    );
  }
}
