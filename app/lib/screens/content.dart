import 'dart:io';
import 'package:flutter/material.dart';
import '../data.dart';
import '../glass.dart';
import '../sheets.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';

// ==================================================================== AI
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() { _input.dispose(); _scroll.dispose(); super.dispose(); }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      });

  void _send(AppState app) {
    final v = _input.text;
    if (v.trim().isEmpty && app.attach == null) return;
    _input.clear();
    app.send(v);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final barBottom = kb > 0 ? kb + 10 : 104 + mq.padding.bottom;
    if (app.chat.length + (app.typing ? 1 : 0) != _lastCount) { _lastCount = app.chat.length + (app.typing ? 1 : 0); _toEnd(); }
    final chips = <(String, VoidCallback)>[
      ('Scan an injury', () => openVision(context)),
      for (final s in const ['Deep cut, bleeding', 'I feel very cold', 'Snake bite', 'Ankle looks broken']) (s, () => app.send(s)),
    ];
    return Stack(children: [
      ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(16, mq.padding.top + 64, 16, 236 + mq.padding.bottom),
        children: [
          for (final m in app.chat) Padding(padding: const EdgeInsets.only(bottom: 12), child: Align(alignment: m.user ? Alignment.centerRight : Alignment.centerLeft, child: m.user ? _UserBubble(m) : _AiBubble(m))),
          if (app.typing) Align(alignment: Alignment.centerLeft, child: Glass(borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24), bottomRight: Radius.circular(24), bottomLeft: Radius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), child: const _Dots())),
        ],
      ),
      Positioned(left: 0, right: 0, top: 0, child: ProgressiveBlur(top: true, height: mq.padding.top + 60, fade: vc.fade)),
      Positioned(left: 22, top: mq.padding.top + 10, child: Row(children: [
        const Text('Vana', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1)),
        const SizedBox(width: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5), decoration: BoxDecoration(color: vc.icebg, borderRadius: BorderRadius.circular(999)), child: Row(children: [VIcon(Ic.bolt, size: 12, color: vc.ice, stroke: 2.4), const SizedBox(width: 6), Text('Gemma · ${t['onDevice']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vc.ice))])),
      ])),
      if (kb == 0) Positioned(left: 0, right: 0, bottom: 0, child: ProgressiveBlur(top: false, height: 270 + mq.padding.bottom, fade: vc.fade2)),
      Positioned(
        left: 0, right: 0, bottom: barBottom,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final (l, go) in chips) Padding(padding: const EdgeInsets.only(right: 8), child: Tap(onTap: go, child: Glass(radius: 999, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9), child: Text(l, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))))),
          ])),
          if (app.attach != null) Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Stack(clipBehavior: Clip.none, children: [
            ClipRRect(borderRadius: BorderRadius.circular(22), child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 1.5), borderRadius: BorderRadius.circular(22)), child: Image.file(File(app.attach!), width: 76, height: 76, fit: BoxFit.cover))),
            Positioned(top: -7, right: -7, child: GestureDetector(onTap: () => app.setAttach(null), child: Container(width: 24, height: 24, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xEB0A241F)), child: const Center(child: VIcon(Ic.close, size: 12, color: Colors.white, stroke: 3))))),
          ])),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Glass(height: 56, radius: 28, padding: const EdgeInsets.symmetric(horizontal: 7), child: Row(children: [
            Tap(scale: .9, onTap: () async { final p = await pickImage(context); if (p != null) app.setAttach(p); }, child: Semantics(button: true, label: 'Attach photo', child: Container(width: 42, height: 42, decoration: BoxDecoration(color: vc.chip, shape: BoxShape.circle), child: Center(child: VIcon(Ic.plus, size: 22, color: vc.tx, stroke: 2.2))))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _input, onChanged: (_) => setState(() {}), onSubmitted: (_) => _send(app), textInputAction: TextInputAction.send, style: TextStyle(fontSize: 17, color: vc.tx), cursorColor: vc.acc, decoration: InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: t['describe'], hintStyle: TextStyle(color: vc.sub2)))),
            GestureDetector(onTap: () => openVoice(context), child: SizedBox(width: 40, height: 40, child: Center(child: VIcon(Ic.mic, size: 21, color: vc.sub)))),
            Tap(onTap: () => _send(app), child: AnimatedOpacity(duration: const Duration(milliseconds: 250), opacity: (_input.text.trim().isNotEmpty || app.attach != null) ? 1 : .5, child: Semantics(button: true, label: 'Send', child: Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, gradient: vc.ai), child: const Center(child: VIcon(Ic.arrowUp, size: 20, color: Colors.white, stroke: 2.6)))))),
          ]))),
        ]),
      ),
    ]);
  }
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (c, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < 3; i++)
            Builder(builder: (_) {
              final p = ((_c.value - i * .125) % 1.0);
              final up = p < .4 ? (1 - (p / .2 - 1).abs()).clamp(0.0, 1.0) : 0.0;
              return Container(margin: const EdgeInsets.symmetric(horizontal: 2.5), width: 8, height: 8, transform: Matrix4.translationValues(0, -5 * up, 0), decoration: BoxDecoration(shape: BoxShape.circle, color: context.vc.sub.withValues(alpha: .4 + .6 * up)));
            }),
        ]),
      );
}

class _UserBubble extends StatelessWidget {
  final ChatMsg m;
  const _UserBubble(this.m);
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 270),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(gradient: context.vc.ai, borderRadius: const BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26), bottomLeft: Radius.circular(26), bottomRight: Radius.circular(8)), boxShadow: const [BoxShadow(color: Color(0x4D3882F6), blurRadius: 22, offset: Offset(0, 8))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (m.imagePath != null) ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(21), topRight: Radius.circular(21), bottomLeft: Radius.circular(21), bottomRight: Radius.circular(6)), child: Image.file(File(m.imagePath!), width: 220, height: 150, fit: BoxFit.cover)),
            if (m.text.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), child: Text(m.text, style: const TextStyle(fontSize: 16, height: 1.38, fontWeight: FontWeight.w500, color: Colors.white))),
          ]),
        ),
      );
}

class _AiBubble extends StatelessWidget {
  final ChatMsg m;
  const _AiBubble(this.m);
  @override
  Widget build(BuildContext context) {
    final vc = context.vc, t = context.t;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: Glass(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26), bottomRight: Radius.circular(26), bottomLeft: Radius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(m.text, style: const TextStyle(fontSize: 16, height: 1.42)),
          for (int i = 0; i < m.steps.length; i++) Padding(padding: const EdgeInsets.only(top: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 22, height: 22, margin: const EdgeInsets.only(top: 1), decoration: BoxDecoration(shape: BoxShape.circle, color: vc.icebg), child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: vc.ice)))),
            const SizedBox(width: 10),
            Expanded(child: Text(m.steps[i], style: const TextStyle(fontSize: 15.5, height: 1.38))),
          ])),
          if (m.guide != null) Padding(padding: const EdgeInsets.only(top: 10), child: Tap(onTap: () => openGuide(context, m.guide!), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(gradient: vc.ai, borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(t['openGuide'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)), const SizedBox(width: 6), const VIcon(Ic.chevR, size: 14, color: Colors.white, stroke: 2.6)])))),
          if (m.steps.isNotEmpty || m.guide != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(t['aiNote'], style: TextStyle(fontSize: 11.5, color: vc.sub2))),
        ]),
      ),
    );
  }
}

// ==================================================================== LIBRARY
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String q = '', cat = 'All';
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final qq = q.trim().toLowerCase();
    final list = guides.where((g) => (cat == 'All' || g.cat == cat) && (qq.isEmpty || g.title.toLowerCase().contains(qq) || g.sub.toLowerCase().contains(qq))).toList();
    return ScrollPage(children: [
      LargeTitle(t['library']),
      Glass(height: 48, radius: 24, padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        VIcon(Ic.search, size: 19, color: vc.sub, stroke: 2),
        const SizedBox(width: 10),
        Expanded(child: TextField(onChanged: (v) => setState(() => q = v), style: TextStyle(fontSize: 17, color: vc.tx), cursorColor: vc.acc, decoration: InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: t['searchLib'], hintStyle: TextStyle(color: vc.sub2)))),
      ])),
      SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in libraryCats) Padding(padding: const EdgeInsets.only(right: 8), child: Chip2(c, selected: cat == c, fontSize: 14.5, onTap: () => setState(() => cat = c)))])),
      for (final g in list)
        Tap(scale: .97, onTap: () => openGuide(context, g.id), child: Glass(radius: 28, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: toneBg(vc, g.tone), borderRadius: BorderRadius.circular(17)), child: Center(child: VIcon(Ic.byName[g.icon]!, size: 25, color: toneColor(vc, g.tone)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.2)), Text(g.sub, style: TextStyle(fontSize: 13.5, color: vc.sub))])),
          Text(g.mins, style: TextStyle(fontSize: 13, color: vc.sub2)),
          VIcon(Ic.chevR, size: 16, color: vc.sub2, stroke: 2.2),
        ]))),
      if (list.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No guides match "$q"', style: TextStyle(fontSize: 16, color: vc.sub)))),
    ]);
  }
}

// ==================================================================== PROFILE
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final p = app.profile;
    final med = [('Blood type', p.blood), ('Allergies', p.allergies), ('Conditions', p.conditions), ('Medication', p.meds)];
    Widget switchRow(String k, String title, String sub, bool last) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => app.toggleMap(app.priv, k, 'priv'),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: vc.hair, width: .5))), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)), Text(sub, style: TextStyle(fontSize: 13, color: vc.sub))])),
            VSwitch(on: app.priv[k]!, onChanged: (_) => app.toggleMap(app.priv, k, 'priv')),
          ])),
        );
    return ScrollPage(children: [
      LargeTitle(t['profile']),
      Glass(radius: 30, padding: const EdgeInsets.all(16), child: Row(children: [
        Container(width: 62, height: 62, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD08A), Color(0xFFFFB65C)])), child: Text(p.name.trim().isEmpty ? '+' : p.name.trim()[0].toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF06251E)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name.trim().isEmpty ? 'Add your name' : p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.4)),
          Text('${t['medicalId']} · ${t['onDeviceOnly']}', style: TextStyle(fontSize: 13.5, color: vc.sub)),
        ])),
        Tap(onTap: () => openProfileEdit(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9), decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(999)), child: const Text('Edit', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)))),
      ])),
      GestureDetector(onTap: () => openProfileEdit(context), child: Glass(radius: 28, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), child: Column(children: [
        for (int i = 0; i < med.length; i++) Container(padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(border: i < 3 ? Border(bottom: BorderSide(color: vc.hair, width: .5)) : null), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(med[i].$1, style: TextStyle(fontSize: 16, color: vc.sub)),
          const SizedBox(width: 12),
          Flexible(child: Text(med[i].$2.isEmpty ? 'Not set' : med[i].$2, textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: med[i].$2.isEmpty ? vc.sub2 : vc.tx))),
        ])),
      ]))),
      Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(t['contacts'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        Tap(scale: .95, onTap: () => openContact(context), child: Container(padding: const EdgeInsets.fromLTRB(10, 8, 14, 8), decoration: BoxDecoration(gradient: vc.prim, borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [VIcon(Ic.plus, size: 18, color: vc.onprim, stroke: 2.6), const SizedBox(width: 6), Text('Add', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: vc.onprim))]))),
      ])),
      if (app.contacts.isEmpty)
        GestureDetector(onTap: () => openContact(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22), decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: vc.hair, width: 1.5)), child: Column(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: vc.accbg), child: Center(child: VIcon(Ic.person, size: 24, color: vc.acc))),
          const SizedBox(height: 8),
          const Text('No emergency contacts yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Add someone who should be told where you are if you need help.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.4, color: vc.sub)),
        ]))),
      for (final c in app.contacts)
        GestureDetector(onTap: () => openContact(context, existing: c), child: Glass(radius: 26, padding: const EdgeInsets.fromLTRB(16, 12, 12, 12), child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: vc.accbg), child: Center(child: Text(c.initial, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: vc.acc)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)), Text('${c.rel} · ${c.phone}', style: TextStyle(fontSize: 13, color: vc.sub))])),
          Semantics(button: true, label: 'Call ${c.name}', child: GestureDetector(onTap: () => app.callContact(c), child: Container(width: 42, height: 42, decoration: const BoxDecoration(shape: BoxShape.circle, color: kGreen), child: const Center(child: VIcon(Ic.phone, size: 19, color: Colors.white, stroke: 2.2))))),
        ]))),
      SectionTitle(t['language']),
      Segmented(items: const [('en', 'English'), ('te', 'తెలుగు'), ('hi', 'हिन्दी')], current: app.lang, onChanged: app.setLang),
      SectionTitle(t['appearance']),
      Segmented(items: [('dark', t['dark']), ('light', t['light'])], current: app.themeMode == ThemeMode.light ? 'light' : 'dark', onChanged: (k) => app.setTheme(k == 'light' ? ThemeMode.light : ThemeMode.dark)),
      SectionTitle(t['privacy']),
      Glass(radius: 28, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), child: Column(children: [
        switchRow('sessions', 'Save health sessions', 'Keep a summary for a healthcare professional', false),
        switchRow('track', 'Track location on trips', 'Only while a trip is active', false),
        switchRow('photos', 'Include photos in reports', 'Only when you attach them', true),
      ])),
      SectionTitle(t['packs']),
      for (final (k, name, size) in const [('cas', 'Cascades', '2.4 GB'), ('sie', 'Sierra Nevada', '3.1 GB'), ('ala', 'Alaska Range', '2.8 GB')])
        Glass(radius: 26, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)), Text(size, style: TextStyle(fontSize: 13, color: vc.sub))])),
          GestureDetector(onTap: () => app.toggleMap(app.packs, k, 'pack'), child: AnimatedContainer(duration: const Duration(milliseconds: 350), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(gradient: app.packs[k]! ? null : vc.prim, color: app.packs[k]! ? vc.accbg : null, borderRadius: BorderRadius.circular(999)), child: Text(app.packs[k]! ? 'Installed' : 'Download', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: app.packs[k]! ? vc.acc : vc.onprim)))),
        ])),
    ]);
  }
}
