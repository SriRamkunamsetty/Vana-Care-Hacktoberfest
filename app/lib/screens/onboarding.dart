import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../glass.dart';
import '../theme.dart';
import '../ui.dart';

const _logo = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 74 74"><g fill="#0F4A40"><path d="M37 8 L58 44 L48 44 L54 54 L20 54 L26 44 L16 44 Z"/><rect x="34" y="54" width="6" height="12" rx="1"/><rect x="28" y="60" width="18" height="6" rx="1.5"/></g><path d="M37 8 L42 17 L37 15 L32 17 Z" fill="#fff"/></svg>';

/// Sunrise-forest backdrop used behind splash + onboarding, with a parallax by [step].
class ScapePainter extends CustomPainter {
  final int step;
  ScapePainter(this.step);

  static const _sunX = [.62, .5, .36, .56];

  void _poly(Canvas c, Rect r, List<double> pts, Paint p) {
    final path = Path();
    for (var i = 0; i < pts.length; i += 2) {
      final x = r.left + r.width * pts[i] / 100, y = r.top + r.height * pts[i + 1] / 100;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    c.drawPath(path, p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 393, h = size.height / 852;
    final full = Offset.zero & size;
    canvas.drawRect(full, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF15303E), Color(0xFF2F5B69), Color(0xFF8AA5A0), Color(0xFFF0A868), Color(0xFFF8D28E)], stops: [0, .28, .46, .62, .74]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final sun = Offset(size.width * _sunX[step], 150 * h + 180 * k);
    canvas.drawCircle(sun, 180 * k, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFF3CF), Color(0xE6FFDC96), Color(0x73FFB464), Color(0x00FFA05A)], stops: [0, .08, .28, .66]).createShader(Rect.fromCircle(center: sun, radius: 180 * k)));
    _poly(canvas, Rect.fromLTWH((-80 - step * 10) * k, 300 * h, 553 * k, 300 * h), [0, 100, 0, 62, 10, 48, 18, 58, 30, 22, 40, 50, 48, 38, 58, 60, 68, 28, 78, 52, 88, 40, 100, 60, 100, 100], Paint()..color = const Color(0xFF4F7F82).withValues(alpha: .75));
    _poly(canvas, Rect.fromLTWH((-80 - step * 24) * k, 390 * h, 553 * k, 280 * h), [0, 100, 0, 46, 12, 30, 24, 50, 38, 26, 52, 52, 64, 34, 78, 54, 90, 30, 100, 48, 100, 100], Paint()..color = const Color(0xFF2A5C58));
    final fr = Rect.fromLTWH((-90 - step * 44) * k, 470 * h, 573 * k, 382 * h);
    _poly(canvas, fr, [0, 100, 0, 30, 2, 14, 4, 30, 6, 6, 8.5, 32, 11, 16, 13, 34, 16, 2, 19, 34, 22, 18, 24, 36, 27, 8, 30, 36, 33, 20, 36, 38, 39, 4, 42, 38, 45, 22, 48, 40, 51, 10, 54, 38, 57, 20, 60, 40, 63, 0, 66, 36, 69, 18, 72, 38, 75, 8, 78, 36, 81, 22, 84, 40, 87, 6, 90, 36, 93, 16, 96, 34, 98, 12, 100, 30, 100, 100],
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF123B36), Color(0xFF0A2621), Color(0xFF061713)], stops: [0, .6, 1]).createShader(fr));
  }

  @override
  bool shouldRepaint(ScapePainter o) => o.step != step;
}

class SplashView extends StatelessWidget {
  final VoidCallback onTap;
  const SplashView({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        Positioned(
          top: mq.size.height * .2, left: 0, right: 0,
          child: Column(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1), duration: const Duration(seconds: 5), curve: Curves.linear,
              builder: (c, v, ch) => Transform.translate(offset: Offset(0, -7 * math.sin(v * math.pi)), child: ch),
              child: Glass(
                width: 116, height: 116, radius: 58, blur: 20,
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.fromRGBO(255, 255, 255, .75), Color.fromRGBO(255, 255, 255, .4)]),
                child: Center(child: SvgPicture.string(_logo, width: 74, height: 74)),
              ),
            ),
            const SizedBox(height: 22),
            const Text('VANA CARE', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w700, letterSpacing: 4.3, color: Color(0xFF0E3F37))),
            const SizedBox(height: 10),
            const Text('No Network.\nStill Not Alone.', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.35, color: Color(0xFF0E3F37))),
          ]),
        ),
        Positioned(
          bottom: 64 + mq.padding.bottom, left: 0, right: 0,
          child: const Text('AI Powered\nField Health & Survival Companion', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.45, shadows: [Shadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 1))])),
        ),
      ]),
    );
  }
}

class _Frost extends StatelessWidget {
  final Widget child;
  final BorderRadiusGeometry radius;
  final Gradient? gradient;
  const _Frost({required this.child, this.radius = const BorderRadius.all(Radius.circular(26)), this.gradient});
  @override
  Widget build(BuildContext context) => Glass(
        borderRadius: radius as BorderRadius, blur: 24,
        gradient: gradient ?? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.fromRGBO(255, 255, 255, .3), Color.fromRGBO(255, 255, 255, .08)]),
        shadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12))],
        child: child,
      );
}

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});
  @override
  State<OnboardingView> createState() => OnboardingViewState();
}

class OnboardingViewState extends State<OnboardingView> {
  int step = 0;
  int dl = 0;
  bool dling = false;
  Timer? _t;
  static const _steps = [
    ('AI POWERED', 'No network. Still not alone.', 'Vana runs on your phone. Ask about injuries, illness or survival with no signal at all.'),
    ('FIELD FIRST AID', 'Health guidance, step by step.', 'Clear first-aid steps you can follow with one hand, in any weather.'),
    ('HOW IT WORKS', 'Built for safety.', 'Approved protocols come first. The AI explains and never replaces them.'),
    ('OFFLINE SETUP', 'Set up your pack.', 'Pick a language, allow what you need and save the regional map and guides.'),
  ];

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  /// Prototype behaviour: the pack download is simulated. Replace with a real
  /// resumable downloader (WorkManager / background_downloader) when packs exist.
  void _startDl() {
    if (dling || dl >= 100) return;
    setState(() => dling = true);
    _t = Timer.periodic(const Duration(milliseconds: 55), (t) {
      final n = math.min(100, dl + 1 + (t.tick % 3));
      setState(() { dl = n; dling = n < 100; });
      if (n >= 100) t.cancel();
    });
  }

  void _next() {
    if (step < 3) { setState(() => step++); return; }
    if (dl >= 100) { context.appRead.finishOnboarding(); } else { _startDl(); }
  }

  ScapeHook get _hook => ScapeHook.of(context);

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final mq = MediaQuery.of(context);
    final (eyebrow, title, sub) = _steps[step];
    WidgetsBinding.instance.addPostFrameCallback((_) => _hook.setStep(step));
    final sheetH = math.min(step == 3 ? 600.0 : 452.0, mq.size.height - 140);
    final cta = step < 3 ? 'Continue' : (dl >= 100 ? 'Enter Vana Care' : (dling ? 'Downloading… $dl%' : 'Download offline pack'));
    return Stack(children: [
      Positioned(top: mq.padding.top + 8, right: 20, child: Tap(onTap: () => context.appRead.finishOnboarding(), child: const _SkipPill())),
      Positioned(top: mq.padding.top + 60, left: 22, right: 22, child: AnimatedSwitcher(duration: const Duration(milliseconds: 500), child: KeyedSubtree(key: ValueKey(step), child: _hero())),),
      Positioned(
        left: 10, right: 10, bottom: 10 + mq.padding.bottom * .5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600), curve: Curves.easeOutBack, height: sheetH,
          child: Glass(
            radius: 48, blur: 40,
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.fromRGBO(16, 56, 49, .62), Color.fromRGBO(6, 26, 22, .8)]),
            padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(eyebrow, style: const TextStyle(fontSize: 12, letterSpacing: 1.9, fontWeight: FontWeight.w700, color: Color(0xFFFFB65C))),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 32, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -.8, color: Colors.white)),
              const SizedBox(height: 12),
              Text(sub, style: const TextStyle(fontSize: 16.5, height: 1.42, color: Color.fromRGBO(226, 240, 233, .78))),
              if (step == 3) Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 14),
                Row(children: [
                  for (final (k, l) in const [('en', 'English'), ('te', 'తెలుగు'), ('hi', 'हिन्दी')])
                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: GestureDetector(onTap: () => app.setLang(k), child: AnimatedContainer(duration: const Duration(milliseconds: 350), padding: const EdgeInsets.symmetric(vertical: 11), alignment: Alignment.center, decoration: BoxDecoration(color: app.lang == k ? const Color(0xFFFFB65C) : const Color.fromRGBO(255, 255, 255, .12), borderRadius: BorderRadius.circular(16)), child: Text(l, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: app.lang == k ? const Color(0xFF06251E) : Colors.white)))))),
                ]),
                const SizedBox(height: 8),
                for (final (k, label, d) in [('loc', 'Location', Ic.pin), ('cam', 'Camera', Ic.image), ('mic', 'Microphone', Ic.mic)])
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color.fromRGBO(143, 227, 181, .16), borderRadius: BorderRadius.circular(11)), child: Center(child: VIcon(d, size: 19, color: kMint))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))),
                    VSwitch(on: app.perms[k]!, onChanged: (_) => app.togglePerm(k)),
                  ])),
              ]))) else const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 0; i < 4; i++) AnimatedContainer(duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack, margin: const EdgeInsets.symmetric(horizontal: 3.5), height: 8, width: i == step ? 28 : 8, decoration: BoxDecoration(color: i == step ? kMint : const Color.fromRGBO(255, 255, 255, .3), borderRadius: BorderRadius.circular(4))),
              ]),
              const SizedBox(height: 18),
              Tap(
                scale: .97, onTap: (step == 3 && dling) ? null : _next,
                child: Opacity(
                  opacity: (step == 3 && dling) ? .7 : 1,
                  child: Container(height: 58, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(29), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB5F3CF), Color(0xFF7BD9A6)]), boxShadow: const [BoxShadow(color: Color(0x5950D296), blurRadius: 30, offset: Offset(0, 10))]), child: Text(cta, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF06251E)))),
                ),
              ),
              if (step == 3) GestureDetector(onTap: () => context.appRead.finishOnboarding(), child: const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: Text('Set up later', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color.fromRGBO(226, 240, 233, .7)))))),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _hero() {
    switch (step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
          _Frost(radius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24), bottomLeft: Radius.circular(24), bottomRight: Radius.circular(6)), child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text("Deep cut on my forearm. It won't stop bleeding.", style: TextStyle(fontSize: 16, height: 1.35, color: Colors.white)))),
          SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: _Frost(radius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24), bottomRight: Radius.circular(24), bottomLeft: Radius.circular(6)), gradient: LinearGradient(colors: [Color.fromRGBO(10, 40, 35, .55), Color.fromRGBO(10, 40, 35, .35)]), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [VIcon(Ic.sparkle, size: 14, color: kMint, stroke: 2), SizedBox(width: 6), Text('VANA · ON DEVICE', style: TextStyle(color: kMint, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1))]),
            SizedBox(height: 6),
            Text('Press firmly with a clean cloth and hold for 10 minutes. Raise the arm above your heart.', style: TextStyle(fontSize: 15.5, height: 1.4, color: Colors.white)),
          ])))),
        ]);
      case 1:
        return GridView.count(shrinkWrap: true, crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .8, padding: EdgeInsets.zero, physics: const NeverScrollableScrollPhysics(), children: [
          for (final (l, d, c) in const [('Bleeding', Ic.drop, Color(0xFFFF9A8B)), ('Burns', Ic.flame, Color(0xFFFFC978)), ('Fracture', Ic.bone, Color(0xFFB5F3CF)), ('Cold', Ic.snow, Color(0xFFBFE0FF))])
            _Frost(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [VIcon(d, size: 30, color: c), const SizedBox(height: 10), Text(l, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600))])),
        ]);
      case 2:
        return Column(children: const [
          _Frost(child: Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16), child: SizedBox(width: double.infinity, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('GOOD TO KNOW', style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Color(0xFFFFB65C))), SizedBox(height: 6), Text('Vana is an information and decision-support tool. It is not a doctor and cannot guarantee a rescue.', style: TextStyle(fontSize: 15.5, height: 1.42, color: Colors.white))])))),
          SizedBox(height: 12),
          _Frost(child: Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16), child: SizedBox(width: double.infinity, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PRIVATE BY DEFAULT', style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: kMint)), SizedBox(height: 6), Text('Questions, photos and health notes stay on this phone unless you choose to share them.', style: TextStyle(fontSize: 15.5, height: 1.42, color: Colors.white))])))),
        ]);
      default:
        return Center(
          child: Container(
            width: 124, height: 124,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 16))], gradient: SweepGradient(startAngle: -math.pi / 2, endAngle: 3 * math.pi / 2, colors: [kMint, kMint, const Color.fromRGBO(255, 255, 255, .22), const Color.fromRGBO(255, 255, 255, .22)], stops: [0, dl / 100, dl / 100 + .0001, 1], transform: const GradientRotation(0))),
            child: Center(child: Container(width: 110, height: 110, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.fromRGBO(14, 50, 44, .88), Color.fromRGBO(10, 38, 33, .92)])), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$dl%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)), const Text('MAP + GUIDES', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: .4, color: Color.fromRGBO(226, 240, 233, .75)))]))),
          ),
        );
    }
  }
}

class _SkipPill extends StatelessWidget {
  const _SkipPill();
  @override
  Widget build(BuildContext context) => const Glass(radius: 999, blur: 20, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9), gradient: LinearGradient(colors: [Color.fromRGBO(255, 255, 255, .28), Color.fromRGBO(255, 255, 255, .1)]), child: Text('Skip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)));
}

/// Lets the onboarding view drive the parallax of the shell's [ScapePainter].
class ScapeHook extends InheritedWidget {
  final void Function(int) setStep;
  const ScapeHook({super.key, required this.setStep, required super.child});
  static ScapeHook of(BuildContext c) => c.getInheritedWidgetOfExactType<ScapeHook>()!;
  @override
  bool updateShouldNotify(ScapeHook o) => false;
}
