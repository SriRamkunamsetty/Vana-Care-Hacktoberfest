import 'package:flutter/material.dart';
import '../ai/gemma_manager.dart';
import '../glass.dart';
import '../ui.dart';

Future<void> openOfflineAi(BuildContext context) => showVSheet(context, (c) => const OfflineAiSheet());

/// Install, inspect and remove the on-device Gemma 4 model.
class OfflineAiSheet extends StatefulWidget {
  const OfflineAiSheet({super.key});
  @override
  State<OfflineAiSheet> createState() => _OfflineAiSheetState();
}

class _OfflineAiSheetState extends State<OfflineAiSheet> {
  GemmaVariant? _pick;
  bool _mobile = false;
  bool _confirmed = false;
  bool _testing = false;
  GemmaBenchmark? _bench;
  String? _benchError;

  @override
  void initState() {
    super.initState();
    context.appRead.gemma.onMobileData().then((v) {
      if (mounted) setState(() => _mobile = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, vc = context.vc, g = app.gemma;
    final variant = _pick ?? g.installed ?? g.recommended ?? GemmaVariant.e2b;
    final spec = gemmaSpecs[variant]!;
    final ramGb = g.ramMb == 0 ? null : (g.ramMb / 1024).toStringAsFixed(1);
    final tooSmall = g.recommended == null;
    final busy = g.status == GemmaStatus.downloading;

    String headline() => switch (g.status) {
          GemmaStatus.downloading => 'Downloading ${gemmaSpecs[variant]!.label}',
          GemmaStatus.installed => '${gemmaSpecs[g.installed!]!.label} is installed',
          GemmaStatus.loading => 'Starting Gemma…',
          GemmaStatus.loaded => '${gemmaSpecs[g.installed!]!.label} is running on this phone',
          GemmaStatus.error => 'Gemma could not start',
          GemmaStatus.unsupported => 'This phone is too small for Gemma 4',
          _ => 'Gemma 4 is not installed',
        };

    return SheetFrame(
      topInset: 90, title: 'Offline AI', subtitle: 'Gemma 4 runs on this phone',
      child: ListView(padding: EdgeInsets.zero, children: [
        Solid(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(headline(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            g.installed != null
                ? 'Photos, questions and voice are understood on the phone. No internet is used and nothing you type leaves it.'
                : 'Without the model, Vana still shows the approved first-aid steps and library. With it, Vana can read photos and answer in your language.',
            style: TextStyle(fontSize: 14.5, height: 1.4, color: vc.sub),
          ),
          if (g.activeBackend != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Running on ${g.activeBackend!.name.toUpperCase()}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: vc.acc))),
          if (busy) ...[
            const SizedBox(height: 14),
            ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: g.progress <= 0 ? null : g.progress / 100, minHeight: 10, color: vc.acc, backgroundColor: vc.hair)),
            const SizedBox(height: 8),
            Text('${g.progress}% · keep the app open, it resumes if the connection drops', style: TextStyle(fontSize: 12.5, color: vc.sub)),
          ],
          if (g.error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(g.error!, style: TextStyle(fontSize: 13.5, height: 1.35, color: vc.red, fontWeight: FontWeight.w600))),
        ])),
        const SizedBox(height: 12),
        if (g.installed == null && !busy && !tooSmall) ...[
          const FieldLabel('MODEL'),
          const SizedBox(height: 8),
          Segmented(items: [for (final s in gemmaSpecs.values) (s.variant.name, '${s.label.replaceFirst('Gemma 4 ', '')} · ${s.sizeLabel}')], current: variant.name, onChanged: (v) => setState(() => _pick = GemmaVariant.values.byName(v))),
          const SizedBox(height: 10),
          Text(
            '${ramGb == null ? 'Your phone memory could not be read.' : 'Your phone has about $ramGb GB of memory.'} We suggest ${gemmaSpecs[g.recommended!]!.label}. The larger E4B answers better but needs a faster phone. You can switch later.',
            style: TextStyle(fontSize: 13.5, height: 1.4, color: vc.sub),
          ),
          if (_mobile) Padding(padding: const EdgeInsets.only(top: 10), child: Text('You are on mobile data. This download is ${spec.sizeLabel} and may cost money. Wi-Fi is recommended.', style: TextStyle(fontSize: 13.5, height: 1.4, color: vc.amb, fontWeight: FontWeight.w600))),
          const SizedBox(height: 14),
          PrimButton(_mobile && !_confirmed ? 'Download on mobile data' : 'Download ${spec.label} · ${spec.sizeLabel}', onTap: () {
            if (_mobile && !_confirmed) {
              setState(() => _confirmed = true);
              return;
            }
            g.install(variant);
          }),
          const SizedBox(height: 6),
          Text('Needs about ${(spec.bytes * 1.2 / 1e9).toStringAsFixed(1)} GB of free storage. Apache-2.0 licensed model from Google.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: vc.sub2)),
        ],
        if (tooSmall && g.installed == null) Text('Vana will still work without the AI model: emergency steps, the offline library and Forest Mode do not need it.', style: TextStyle(fontSize: 14, height: 1.4, color: vc.sub)),
        if (busy) Tap(onTap: g.cancelInstall, child: Container(height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(26)), child: const Text('Cancel download', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
        if (g.installed != null && !busy) ...[
          Tap(onTap: _testing ? null : () async {
            setState(() { _testing = true; _bench = null; _benchError = null; });
            try {
              final b = await g.benchmark();
              if (mounted) setState(() => _bench = b);
            } catch (_) {
              if (mounted) setState(() => _benchError = 'The speed test could not run. Try freeing memory first.');
            } finally {
              if (mounted) setState(() => _testing = false);
            }
          }, child: Container(height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(26)), child: Text(_testing ? 'Testing…' : 'Run a speed test', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
          if (_bench != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Start-up ${(_bench!.loadMs / 1000).toStringAsFixed(1)} s · first word ${(_bench!.firstTokenMs / 1000).toStringAsFixed(1)} s · about ${_bench!.charsPerSecond.round()} characters per second on ${_bench!.backend.toUpperCase()}. Speed depends on this phone, its temperature and battery.', style: TextStyle(fontSize: 13, height: 1.4, color: vc.sub))),
          if (_benchError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_benchError!, style: TextStyle(fontSize: 13, color: vc.red))),
          const SizedBox(height: 10),
          Tap(onTap: g.status == GemmaStatus.error ? g.warmUp : () => g.unload(), child: Container(height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(26)), child: Text(g.status == GemmaStatus.error ? 'Try again' : 'Free memory now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 10),
          Tap(onTap: () async {
            await g.uninstall();
            if (mounted) setState(() => _confirmed = false);
          }, child: Container(height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: vc.redbg, borderRadius: BorderRadius.circular(26)), child: Text('Remove the model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: vc.red)))),
        ],
        const SizedBox(height: 16),
        Text('Vana is an information tool, not a doctor. Emergency steps always come from the approved first-aid guides, never from the AI model. In an emergency call 112.', style: TextStyle(fontSize: 12.5, height: 1.4, color: vc.sub2)),
      ]),
    );
  }
}
