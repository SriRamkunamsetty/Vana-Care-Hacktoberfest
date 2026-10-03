import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'ai/assistant.dart';
import 'ai/gemma_manager.dart';
import 'ai/llm.dart';
import 'data.dart';
import 'data_i18n.dart';
import 'screens/offline_ai.dart';
import 'voice.dart';
import 'glass.dart';
import 'state.dart';
import 'theme.dart';
import 'ui.dart';

// ==================================================================== image picking
Future<String?> pickImage(BuildContext context, {bool cameraFirst = false}) async {
  final src = await showVSheet<ImageSource>(context, (c) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + MediaQuery.of(c).padding.bottom), child: Glass(radius: 32, gradient: c.vc.sheet, blur: 40, padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (s, label, d) in [(ImageSource.camera, 'Take a photo', Ic.image), (ImageSource.gallery, 'Choose from library', Ic.image)])
            Tap(onTap: () => Navigator.pop(c, s), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: c.vc.icebg, borderRadius: BorderRadius.circular(14)), child: Center(child: VIcon(d, size: 22, color: c.vc.ice))),
              const SizedBox(width: 14),
              Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ]))),
        ]))),
      ));
  if (src == null) return null;
  try {
    final f = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85);
    return f?.path;
  } catch (_) {
    if (context.mounted) AppScope.read(context).toast('Camera or photos unavailable. Check permissions.');
    return null;
  }
}

// ==================================================================== emergency
Future<void> openEmergency(BuildContext context) => showVSheet(context, (c) => const _EmergencySheet());

class _EmergencySheet extends StatelessWidget {
  const _EmergencySheet();
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final cats = [('bleeding', 'Bleeding', 'drop', 'red'), ('burns', 'Burns', 'flame', 'amb'), ('choking', 'Breathing', 'lungs', 'ice'), ('unconscious', 'Unconscious', 'person', 'ice'), ('fracture', 'Injury', 'bone', 'acc'), ('bites', 'Bites & stings', 'warn', 'red')];
    return SheetFrame(
      topInset: 92 + MediaQuery.of(context).padding.top * .3,
      title: t['emMode'], titleColor: vc.red, subtitle: t['emPick'],
      child: Column(children: [
        Expanded(child: SingleChildScrollView(child: Column(children: [
          fixedGrid([
            for (final (id, title, icon, tone) in cats)
              Tap(scale: .95, onTap: () { app.emCategory = title; openGuide(context, id); }, child: Solid(radius: 26, padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: toneBg(vc, tone), borderRadius: BorderRadius.circular(14)), child: Center(child: VIcon(Ic.byName[icon]!, size: 22, color: toneColor(vc, tone)))),
                Flexible(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              ]))),
          ], 104),
          const SizedBox(height: 12),
          Solid(radius: 22, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
            VIcon(Ic.pin, size: 20, color: vc.amb, stroke: 2.2),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: vc.sub)),
              Text(app.fmtPos == null ? (app.lastKnownLine ?? 'Location unavailable') : '${app.fmtPos} · ${app.posAcc}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
            ])),
          ])),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Tap(onTap: () => openVoice(context), child: _SolidBtn(t['voice'], Ic.mic))),
          const SizedBox(width: 12),
          Expanded(child: Tap(onTap: () => openSos(context), child: _SolidBtn(t['report'], Ic.book))),
        ]),
        const SizedBox(height: 12),
        AlertButton(t['call112'], height: 64, fontSize: 20, onTap: app.call112),
      ]),
    );
  }
}

class _SolidBtn extends StatelessWidget {
  final String label, d;
  const _SolidBtn(this.label, this.d);
  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Container(height: 56, decoration: BoxDecoration(color: vc.solid, borderRadius: BorderRadius.circular(28), boxShadow: vc.shadow, border: Border.all(color: vc.glBorder, width: .5)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [VIcon(d, size: 20, color: vc.solidtx, stroke: 2), const SizedBox(width: 8), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: vc.solidtx)))]));
  }
}

// ==================================================================== guide
Future<void> openGuide(BuildContext context, String id) => showVSheet(context, (c) => _GuideSheet(id));

class _GuideSheet extends StatelessWidget {
  final String id;
  const _GuideSheet(this.id);
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final g = localizedGuide(guideById(id), app.lang);
    final chk = app.guideChecked[id] ?? {};
    final done = chk.length, first = List.generate(g.steps.length, (i) => i).firstWhere((i) => !chk.contains(i), orElse: () => -1);
    return SheetFrame(
      topInset: 168, title: g.title, subtitle: 'Protocol v${g.version} · ${g.reviewed ? 'clinician reviewed' : 'draft, not yet clinician reviewed'}',
      leading: Container(width: 56, height: 56, decoration: BoxDecoration(color: toneBg(vc, g.tone), borderRadius: BorderRadius.circular(19)), child: Center(child: VIcon(Ic.byName[g.icon]!, size: 28, color: toneColor(vc, g.tone)))),
      child: Column(children: [
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Container(height: 8, color: vc.hair, alignment: Alignment.centerLeft, child: AnimatedFractionallySizedBox(duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack, widthFactor: done / g.steps.length, child: Container(decoration: BoxDecoration(gradient: vc.prim)))))),
          const SizedBox(width: 12),
          Text('$done / ${g.steps.length}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: vc.acc)),
        ]),
        const SizedBox(height: 12),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          for (int i = 0; i < g.steps.length; i++)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Tap(scale: .98, onTap: () => app.toggleStep(id, i), child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: i == first ? kOrange : Colors.transparent, width: 2)),
              child: Opacity(opacity: chk.contains(i) ? .55 : 1, child: Solid(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(duration: const Duration(milliseconds: 350), width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: chk.contains(i) ? kGreen : (i == first ? kOrange : const Color(0xFF64748B))), child: Center(child: chk.contains(i) ? const VIcon(Ic.check, size: 16, color: Colors.white, stroke: 3) : Text('${i + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
                const SizedBox(width: 14),
                Expanded(child: Text(g.steps[i], style: const TextStyle(fontSize: 16.5, height: 1.4, fontWeight: FontWeight.w500))),
              ]))),
            ))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: vc.redbg, borderRadius: BorderRadius.circular(22)), child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14.5, height: 1.4), children: [TextSpan(text: '${t['getHelp']} ', style: TextStyle(fontWeight: FontWeight.w700, color: vc.red)), TextSpan(text: g.warn)]))),
        ])),
        const SizedBox(height: 12),
        AlertButton(t['call112'], height: 56, onTap: app.call112),
      ]),
    );
  }
}

// ==================================================================== voice
Future<void> openVoice(BuildContext context) => showVSheet(context, (c) => const _VoiceSheet());

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();
  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> with SingleTickerProviderStateMixin {
  final _voice = VoiceService();
  ListenState listen = ListenState.idle;
  String heard = '';
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _voice.dispose();
    _wave.dispose();
    super.dispose();
  }

  Future<void> _mic() async {
    if (listen == ListenState.listening) {
      await _voice.stopListening();
      return;
    }
    setState(() { listen = ListenState.listening; heard = ''; });
    await _voice.listen(
      lang: context.app.lang,
      onText: (s) { if (mounted) setState(() => heard = s); },
      onDone: (s) { if (mounted) setState(() { heard = s; listen = s.trim().isEmpty ? ListenState.idle : ListenState.done; }); },
      onUnavailable: () { if (mounted) setState(() => listen = ListenState.unavailable); },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final on = listen == ListenState.listening;
    final status = switch (listen) {
      ListenState.idle => t['tapMic'],
      ListenState.listening => heard.isEmpty ? t['listening'] : heard,
      ListenState.done => heard,
      ListenState.unavailable => 'Voice input is not available. Check the microphone permission and that speech recognition is installed on this phone, or type your question instead.',
    };
    return SheetFrame(
      topInset: 300, title: t['voice'],
      child: Column(children: [
        Segmented(items: const [('en', 'English'), ('te', 'తెలుగు'), ('hi', 'हिन्दी')], current: app.lang, onChanged: app.setLang),
        SizedBox(height: 110, child: AnimatedBuilder(animation: _wave, builder: (c, _) => Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
          for (int i = 0; i < 21; i++)
            Container(margin: const EdgeInsets.symmetric(horizontal: 2.5), width: 5, height: on ? (18 + ((i * 37) % 62)) * (.35 + .65 * ((i.isEven ? _wave.value : 1 - _wave.value))) : 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), gradient: on ? vc.ai : null, color: on ? null : vc.hair)),
        ]))),
        Container(constraints: const BoxConstraints(minHeight: 56), alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(status, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w600, color: listen == ListenState.idle || (on && heard.isEmpty) ? vc.sub : vc.tx))),
        if (_voice.usedNetworkFallback && listen != ListenState.idle) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Offline speech pack not installed for this language, so this phone may use the internet to understand your voice.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: vc.amb))),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Tap(onTap: _mic, child: AnimatedScale(scale: on ? 1.1 : 1, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack, child: Semantics(button: true, label: 'Microphone', child: Container(width: 76, height: 76, decoration: BoxDecoration(shape: BoxShape.circle, gradient: on ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)]) : vc.ai, boxShadow: [BoxShadow(color: on ? const Color(0x80EF4444) : const Color(0x733882F6), blurRadius: 30, offset: const Offset(0, 12))]), child: const Center(child: VIcon(Ic.mic, size: 32, color: Colors.white)))))),
          if (listen == ListenState.done) ...[const SizedBox(width: 16), Flexible(child: Tap(onTap: () { Navigator.pop(context); app.go(Screen.ai); app.send(heard); }, child: Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 24), alignment: Alignment.center, decoration: BoxDecoration(gradient: vc.prim, borderRadius: BorderRadius.circular(28)), child: Text(t['send'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: vc.onprim)))))],
        ]),
      ]),
    );
  }
}

// ==================================================================== vision
Future<void> openVision(BuildContext context) => showVFull(context, (c) => const _VisionScreen());

enum _Vis { finder, analysing, result, needModel, failed }

class _VisionScreen extends StatefulWidget {
  const _VisionScreen();
  @override
  State<_VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<_VisionScreen> {
  _Vis vis = _Vis.finder;
  String? img;
  ImageAssessment? result;

  Future<void> _capture() async {
    final p = await pickImage(context);
    if (p == null || !mounted) return;
    setState(() { img = p; vis = _Vis.analysing; });
    final app = context.app;
    try {
      final r = await app.assistant!.assessImage(await File(p).readAsBytes(), lang: app.lang);
      if (mounted) setState(() { result = r; vis = _Vis.result; });
    } on LlmUnavailable {
      if (mounted) setState(() => vis = _Vis.needModel);
    } catch (_) {
      if (mounted) setState(() => vis = _Vis.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final mq = MediaQuery.of(context);
    const white = Colors.white;
    Widget frost(Widget c, {double r = 999}) => Glass(radius: r, blur: 20, gradient: const LinearGradient(colors: [Color.fromRGBO(255, 255, 255, .18), Color.fromRGBO(255, 255, 255, .18)]), border: true, child: c);
    Widget panel(List<Widget> kids) => Positioned(left: 10, right: 10, bottom: 10 + mq.padding.bottom * .5, child: Glass(radius: 40, gradient: vc.sheet, blur: 40, padding: const EdgeInsets.fromLTRB(20, 22, 20, 20), child: DefaultTextStyle(style: TextStyle(color: vc.tx), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: kids))));
    final r = result;
    return Theme(
      data: ThemeData(brightness: Brightness.dark),
      child: Material(
        color: const Color(0xFF050B0A),
        child: DefaultTextStyle(
          style: const TextStyle(color: white),
          child: Stack(children: [
            Positioned.fill(child: img == null ? const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.2), radius: 1, colors: [Color(0xFF1C3B35), Color(0xFF050B0A)]))) : Image.file(File(img!), fit: BoxFit.cover)),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.2), radius: 1, colors: [Colors.transparent, const Color(0xBF050B0A)], stops: const [.4, 1])))),
            Positioned(top: mq.padding.top + 8, left: 18, right: 18, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(onTap: () => Navigator.pop(context), child: SizedBox(width: 42, height: 42, child: frost(const Center(child: VIcon(Ic.close, size: 18, color: white, stroke: 2.4))))),
              Flexible(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: frost(Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Text('${t['vision']} · Gemma', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))))),
              const SizedBox(width: 42),
            ])),
            if (vis == _Vis.finder) ...[
              Positioned(left: 44, right: 44, top: mq.padding.top + 130, height: 300, child: CustomPaint(painter: _Corners())),
              Positioned(left: 40, right: 40, top: mq.padding.top + 450, child: Text(t['frame'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              Positioned(left: 0, right: 0, bottom: 56 + mq.padding.bottom, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Tap(onTap: _capture, child: SizedBox(width: 52, height: 52, child: frost(const Center(child: VIcon(Ic.image, size: 24, color: white, stroke: 1.8)), r: 16))),
                Tap(onTap: _capture, child: Semantics(button: true, label: 'Capture', child: Container(width: 82, height: 82, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: white, width: 4)), child: Center(child: Container(width: 64, height: 64, decoration: const BoxDecoration(shape: BoxShape.circle, color: white)))))),
                const SizedBox(width: 52),
              ])),
            ],
            if (vis == _Vis.analysing) Positioned.fill(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF7C9CFF), backgroundColor: Color.fromRGBO(255, 255, 255, .25))),
              const SizedBox(height: 18),
              Text(t['analysing'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(app.gemma.status == GemmaStatus.loading ? 'Starting Gemma on your phone…' : 'Reading the photo on your phone…', style: const TextStyle(fontSize: 13, color: Color(0xB3FFFFFF))),
            ])),
            if (vis == _Vis.needModel) panel([
              Text('Gemma is not installed', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Photo analysis runs fully on this phone and needs the Gemma 4 model. Download it once while you have Wi-Fi.', style: TextStyle(fontSize: 15.5, height: 1.4, color: vc.sub)),
              const SizedBox(height: 16),
              PrimButton('Set up offline AI', height: 54, fontSize: 16, onTap: () { Navigator.pop(context); openOfflineAi(context); }),
            ]),
            if (vis == _Vis.failed) panel([
              const Text('Could not read the photo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Something went wrong. Try again, or describe the injury in the chat.', style: TextStyle(fontSize: 15.5, height: 1.4, color: vc.sub)),
              const SizedBox(height: 16),
              PrimButton(t['retake'], height: 54, fontSize: 16, onTap: () => setState(() { vis = _Vis.finder; img = null; })),
            ]),
            if (vis == _Vis.result && r != null) panel([
              Row(children: [VIcon(Ic.sparkle, size: 14, color: vc.ice, stroke: 2), const SizedBox(width: 8), Text(t['seen'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: vc.ice))]),
              const SizedBox(height: 12),
              if (r.features.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('I could not make out enough in this photo. Try again in better light, closer to the area, with the phone held steady.', style: const TextStyle(fontSize: 16.5, height: 1.35, fontWeight: FontWeight.w500))),
              for (final f in r.features)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 7, right: 12), decoration: const BoxDecoration(shape: BoxShape.circle, color: kSky)), Expanded(child: Text(f, style: const TextStyle(fontSize: 16.5, height: 1.35, fontWeight: FontWeight.w500)))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: vc.ambbg, borderRadius: BorderRadius.circular(18)), child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14, height: 1.4), children: [
                TextSpan(text: '${t['uncertain']} ', style: TextStyle(fontWeight: FontWeight.w700, color: vc.amb)),
                TextSpan(text: '${t['visNote']}${r.quality == 'good' ? '' : ' The photo is not very clear.'}${r.cannotTell.isEmpty ? '' : ' Cannot judge from a photo: ${r.cannotTell.join(', ')}.'}'),
              ]))),
              if (r.urgentSigns) Padding(padding: const EdgeInsets.only(top: 12), child: AlertButton(t['call112'], height: 52, onTap: app.call112)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Tap(onTap: () => setState(() { vis = _Vis.finder; img = null; result = null; }), child: Container(height: 54, alignment: Alignment.center, decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(27)), child: Text(t['retake'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))))),
                if (r.guideId != null) ...[const SizedBox(width: 10), Expanded(flex: 2, child: PrimButton(t['openSteps'], height: 54, fontSize: 16, onTap: () { openGuide(context, r.guideId!); }))],
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Corners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    const l = 44.0, r = 16.0;
    for (final (cx, cy, sx, sy) in [(0.0, 0.0, 1.0, 1.0), (s.width, 0.0, -1.0, 1.0), (0.0, s.height, 1.0, -1.0), (s.width, s.height, -1.0, -1.0)]) {
      final path = Path()..moveTo(cx, cy + sy * l)..lineTo(cx, cy + sy * r)..quadraticBezierTo(cx, cy, cx + sx * r, cy)..lineTo(cx + sx * l, cy);
      canvas.drawPath(path, p);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ==================================================================== SOS
Future<void> openSos(BuildContext context, {String? category}) {
  AppScope.read(context).prepareSos(category: category);
  return showVFull(context, (c) => const _SosScreen());
}

class _SosScreen extends StatefulWidget {
  const _SosScreen();
  @override
  State<_SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<_SosScreen> with SingleTickerProviderStateMixin {
  double prog = 0;
  Timer? _t;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Created eagerly: a lazy controller would first be built inside dispose() if the sheet closes before SOS is activated.
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void dispose() { _t?.cancel(); _pulse.dispose(); super.dispose(); }

  void _down() {
    final app = AppScope.read(context);
    if (app.sosActive) return;
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 25), (t) {
      final p = prog + 1.4;
      if (p >= 100) { t.cancel(); setState(() => prog = 100); app.activateSos(); } else { setState(() => prog = p); }
    });
  }

  void _up() {
    _t?.cancel();
    if (!AppScope.read(context).sosActive && prog > 0) setState(() => prog = 0);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t;
    final mq = MediaQuery.of(context);
    final on = app.sosActive;
    final rows = [('Incident ID', app.incidentId), ('Category', app.emCategory), ('Position', app.fmtPos ?? app.lastKnownLine ?? 'Unavailable'), ('GPS accuracy', app.pos == null ? '—' : app.posAcc), ('Battery', app.batteryPct == null ? '—' : '${app.batteryPct}%'), ('Notify', app.contacts.isEmpty ? 'No contact set' : app.contacts.first.name), ('Status', on ? 'Saved · waiting for signal' : 'Draft')];
    const soft = Color.fromRGBO(255, 225, 220, .85);
    return Theme(
      data: ThemeData(brightness: Brightness.dark),
      child: Material(
        color: Colors.transparent,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Container(
            decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.15), radius: .95, colors: [Color.fromRGBO(200, 50, 38, .6), Color.fromRGBO(24, 5, 4, .97)], stops: [0, .7])),
            child: Container(
              color: const Color(0xF2180504),
              padding: EdgeInsets.fromLTRB(22, mq.padding.top + 24, 22, 20 + mq.padding.bottom),
              child: Column(children: [
                Align(alignment: Alignment.centerRight, child: GestureDetector(onTap: () => Navigator.pop(context), child: Semantics(button: true, label: 'Close', child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color.fromRGBO(255, 255, 255, .18)), child: const Center(child: VIcon(Ic.close, size: 18, color: Colors.white, stroke: 2.4)))))),
                Text(on ? 'REPORT SAVED' : 'EMERGENCY', style: const TextStyle(fontSize: 13, letterSpacing: 2.6, fontWeight: FontWeight.w700, color: Color(0xFFFF9A8B))),
                const SizedBox(height: 8),
                Text(on ? 'Stay where you are' : 'Hold to send SOS', textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -.7, height: 1.1)),
                const SizedBox(height: 10),
                Text(on ? 'Your report is saved on this phone. Send it to your contact, or call 112 if you have signal.' : 'Press and hold for two seconds. Nothing is sent until the ring completes.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, height: 1.42, color: soft)),
                Expanded(child: Center(child: Stack(alignment: Alignment.center, children: [
                  if (on) AnimatedBuilder(animation: _pulse, builder: (c, _) => Stack(alignment: Alignment.center, children: [
                    for (final off in const [0.0, .33]) Builder(builder: (_) { final v = (_pulse.value + off) % 1; return Opacity(opacity: (1 - v) * .8, child: Transform.scale(scale: .4 + 1.2 * v, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xCCFF8C78), width: 2))))); }),
                  ])),
                  Listener(
                    onPointerDown: (_) => _down(), onPointerUp: (_) => _up(), onPointerCancel: (_) => _up(),
                    child: AnimatedScale(scale: prog > 0 && !on ? .96 : 1, duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, child: Semantics(button: true, label: 'Hold to send SOS', child: Container(
                      width: 208, height: 208,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(startAngle: -1.5708, endAngle: 4.7124, colors: const [Color(0xFFFFD2CA), Color(0xFFFFD2CA), Color.fromRGBO(255, 255, 255, .16), Color.fromRGBO(255, 255, 255, .16)], stops: [0, prog / 100, prog / 100 + .0001, 1])),
                      child: Center(child: Container(width: 190, height: 190, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.3, -.5), radius: 1, colors: [Color(0xFFFF9C8C), Color(0xFFD7372A)], stops: [0, .65]), boxShadow: [BoxShadow(color: Color(0x80FF4632), blurRadius: 60, offset: Offset(0, 20))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(on ? 'ON' : 'SOS', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800)), Text(on ? 'Saved' : 'Hold 2 seconds', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xEBFFEBE6)))]))),
                    ))),
                  ),
                ]))),
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, .12), borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color.fromRGBO(255, 255, 255, .14), width: .5)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['reportTitle'], style: const TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Color(0xFFFF9A8B))),
                    const SizedBox(height: 8),
                    for (final (k, v) in rows) Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: const TextStyle(fontSize: 14.5, color: Color.fromRGBO(255, 225, 220, .7))), const SizedBox(width: 12), Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])))])),
                    Text(t['reportNote'], style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color.fromRGBO(255, 225, 220, .75))),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: AlertButton(t['call112'], height: 54, onTap: app.call112)),
                  const SizedBox(width: 10),
                  Expanded(child: Tap(onTap: app.sendReportSms, child: Container(height: 54, alignment: Alignment.center, decoration: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, .2), borderRadius: BorderRadius.circular(21)), child: const Text('Send by SMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))))),
                ]),
                if (on) GestureDetector(onTap: () { app.cancelSos(); setState(() => prog = 0); }, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(t['cancel'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color.fromRGBO(255, 225, 220, .85))))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================================================================== contact form
Future<void> openContact(BuildContext context, {Contact? existing}) => showVSheet(context, (c) => _ContactSheet(existing));

class _ContactSheet extends StatefulWidget {
  final Contact? existing;
  const _ContactSheet(this.existing);
  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late String rel = widget.existing?.rel ?? 'Family';
  @override
  void dispose() { _name.dispose(); _phone.dispose(); super.dispose(); }
  bool get _ok => _name.text.trim().isNotEmpty && _phone.text.replaceAll(RegExp(r'\D'), '').length >= 3;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return SheetFrame(
      topInset: 150, title: widget.existing == null ? 'New contact' : 'Edit contact',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('NAME'), const SizedBox(height: 8),
          VTextField(controller: _name, hint: 'Full name', onChanged: (_) => setState(() {})),
          const SizedBox(height: 14), const FieldLabel('PHONE'), const SizedBox(height: 8),
          VTextField(controller: _phone, hint: 'Phone number', keyboard: TextInputType.phone, onChanged: (_) => setState(() {})),
          const SizedBox(height: 14), const FieldLabel('RELATIONSHIP'), const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final r in const ['Family', 'Friend', 'Doctor', 'Other']) Chip2(r, selected: rel == r, onTap: () => setState(() => rel = r))]),
        ]))),
        if (widget.existing != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Tap(onTap: () { app.removeContact(widget.existing!.id); Navigator.pop(context); }, child: Container(height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: context.vc.redbg, borderRadius: BorderRadius.circular(26)), child: Text('Remove contact', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.vc.red))))),
        PrimButton('Save contact', opacity: _ok ? 1 : .45, onTap: !_ok ? null : () {
          app.saveContact(Contact(widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch, _name.text.trim(), rel, _phone.text.trim()));
          Navigator.pop(context);
        }),
      ]),
    );
  }
}

// ==================================================================== medical ID
Future<void> openProfileEdit(BuildContext context) => showVSheet(context, (c) => const _ProfileSheet());

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();
  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final Profile p0 = AppScope.read(context).profile;
  late final _name = TextEditingController(text: p0.name), _all = TextEditingController(text: p0.allergies), _cond = TextEditingController(text: p0.conditions), _meds = TextEditingController(text: p0.meds);
  late String blood = p0.blood;
  @override
  void dispose() { _name.dispose(); _all.dispose(); _cond.dispose(); _meds.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    Widget f(String label, TextEditingController c, String hint) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FieldLabel(label), const SizedBox(height: 8), VTextField(controller: c, hint: hint), const SizedBox(height: 14)]);
    return SheetFrame(
      topInset: 96, title: 'Edit Medical ID',
      child: Column(children: [
        Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          f('NAME', _name, 'Your name'),
          const FieldLabel('BLOOD TYPE'), const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final b in const ['A+', 'A−', 'B+', 'B−', 'O+', 'O−', 'AB+', 'AB−']) Chip2(b, selected: blood == b, onTap: () => setState(() => blood = blood == b ? '' : b))]),
          const SizedBox(height: 14),
          f('ALLERGIES', _all, 'e.g. Penicillin'),
          f('CONDITIONS', _cond, 'e.g. Asthma'),
          f('MEDICATION', _meds, 'e.g. Inhaler'),
        ]))),
        PrimButton('Save', onTap: () { app.saveProfile(Profile(name: _name.text.trim(), blood: blood, allergies: _all.text.trim(), conditions: _cond.text.trim(), meds: _meds.text.trim())); Navigator.pop(context); }),
      ]),
    );
  }
}
