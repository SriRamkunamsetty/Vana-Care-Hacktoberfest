import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass.dart';
import 'screens/content.dart';
import 'screens/field.dart';
import 'screens/onboarding.dart';
import 'sheets.dart';
import 'state.dart';
import 'theme.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  runApp(VanaApp(state: state));
  await state.init();
}

/// The prototype uses ~1.2 line height; Material 3 defaults are taller (e.g. 1.43) and would push layouts.
TextTheme _flat(TextTheme t) {
  TextStyle? f(TextStyle? s) => s?.copyWith(height: 1.2);
  return t.copyWith(
    displayLarge: f(t.displayLarge), displayMedium: f(t.displayMedium), displaySmall: f(t.displaySmall),
    headlineLarge: f(t.headlineLarge), headlineMedium: f(t.headlineMedium), headlineSmall: f(t.headlineSmall),
    titleLarge: f(t.titleLarge), titleMedium: f(t.titleMedium), titleSmall: f(t.titleSmall),
    bodyLarge: f(t.bodyLarge), bodyMedium: f(t.bodyMedium), bodySmall: f(t.bodySmall),
    labelLarge: f(t.labelLarge), labelMedium: f(t.labelMedium), labelSmall: f(t.labelSmall),
  );
}

class VanaApp extends StatelessWidget {
  final AppState state;
  const VanaApp({super.key, required this.state});

  ThemeData _theme(Brightness b) {
    final vc = b == Brightness.dark ? VC.dark_ : VC.light_;
    final base = ThemeData(brightness: b, useMaterial3: true, splashFactory: NoSplash.splashFactory, highlightColor: Colors.transparent);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: _flat(base.textTheme.apply(bodyColor: vc.tx, displayColor: vc.tx)),
      colorScheme: base.colorScheme.copyWith(primary: vc.acc, surface: vc.solid),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (c, _) => MaterialApp(
          title: 'Vana Care',
          debugShowCheckedModeBanner: false,
          themeMode: state.themeMode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          builder: (ctx, child) => AppScope(state: state, child: child!),
          home: const Shell(),
        ),
      );
}

enum Phase { splash, onboarding, app }

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  Phase phase = Phase.splash;
  int scapeStep = 0;
  Timer? _t;
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 2900), _afterSplash);
  }

  @override
  void dispose() { _t?.cancel(); _drift.dispose(); super.dispose(); }

  void _afterSplash() {
    if (!mounted || phase != Phase.splash) return;
    final app = AppScope.read(context);
    if (!app.ready) { _t = Timer(const Duration(milliseconds: 200), _afterSplash); return; }
    setState(() => phase = app.onboarded ? Phase.app : Phase.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, vc = context.vc;
    if (phase == Phase.onboarding && app.onboarded) phase = Phase.app;
    final oi = phase != Phase.app;
    final mq = MediaQuery.of(context);
    final scr = app.screen;
    final tabOf = switch (scr) { Screen.map || Screen.lost || Screen.tools => Screen.explore, _ => scr };
    final showBlur = const [Screen.home, Screen.explore, Screen.map, Screen.lost, Screen.library, Screen.profile, Screen.tools].contains(scr);
    final kb = mq.viewInsets.bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (oi || vc.dark) ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF06130F),
        body: ScapeHook(
          setStep: (s) { if (s != scapeStep) setState(() => scapeStep = s); },
          child: Stack(children: [
            // App backdrop
            Positioned.fill(child: AnimatedOpacity(duration: const Duration(milliseconds: 900), opacity: oi ? 0 : 1, child: _Backdrop(vc: vc, t: _drift))),
            // Splash/onboarding scape
            Positioned.fill(child: IgnorePointer(child: AnimatedOpacity(duration: const Duration(milliseconds: 900), opacity: oi ? 1 : 0, child: TweenAnimationBuilder<double>(tween: Tween(end: scapeStep.toDouble()), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic, builder: (c, v, _) => CustomPaint(painter: ScapePainter(v.round().clamp(0, 3))))))),
            if (phase == Phase.splash) Positioned.fill(child: SplashView(onTap: _afterSplash)),
            if (phase == Phase.onboarding) const Positioned.fill(child: OnboardingView()),
            if (phase == Phase.app) ...[
              Positioned.fill(child: AnimatedSwitcher(duration: const Duration(milliseconds: 450), switchInCurve: Curves.easeOutCubic, transitionBuilder: (w, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(a), child: w)), child: KeyedSubtree(key: ValueKey(scr), child: _screen(scr)))),
              if (showBlur) ...[
                Positioned(left: 0, right: 0, top: 0, child: ProgressiveBlur(top: true, height: mq.padding.top + 50, fade: vc.fade)),
                Positioned(left: 0, right: 0, bottom: 0, child: ProgressiveBlur(top: false, height: 160 + mq.padding.bottom, fade: vc.fade2)),
              ],
              if (!kb) Positioned(left: 16, right: 16, bottom: 18 + mq.padding.bottom, child: _TabBar(current: tabOf)),
            ],
            if (app.toastMsg.isNotEmpty) Positioned(top: mq.padding.top + 10, left: 24, right: 24, child: Center(child: Glass(radius: 999, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Text(app.toastMsg, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: vc.tx))))),
          ]),
        ),
      ),
    );
  }

  Widget _screen(Screen s) => switch (s) {
        Screen.home => const HomeScreen(),
        Screen.explore => const ExploreScreen(),
        Screen.ai => const AiScreen(),
        Screen.library => const LibraryScreen(),
        Screen.profile => const ProfileScreen(),
        Screen.map => const MapScreen(),
        Screen.lost => const LostScreen(),
        Screen.tools => const ToolsScreen(),
      };
}

class _Backdrop extends StatelessWidget {
  final VC vc;
  final Animation<double> t;
  const _Backdrop({required this.vc, required this.t});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    Widget blob(Color c, double o, double d, double x, double y, double ph, double amp) => AnimatedBuilder(
          animation: t,
          builder: (_, _) {
            final a = math.sin((t.value * 60 / d + ph) * 2 * math.pi);
            return Positioned(left: x + amp * a, top: y + amp * .8 * math.cos((t.value * 60 / d + ph) * 2 * math.pi), child: ImageFiltered(imageFilter: _blur, child: Opacity(opacity: o, child: Container(width: d * 26, height: d * 26, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)], stops: const [0, .68]))))));
          },
        );
    return DecoratedBox(
      decoration: BoxDecoration(gradient: vc.bg),
      child: ClipRect(child: Stack(children: [
        blob(vc.b1, vc.bo1, 16, -120, -100, 0, 60),
        blob(vc.b2, vc.bo2, 20, size.width - 260, size.height * .35, .3, 70),
        blob(vc.b3, vc.bo3, 18, -60, size.height - 300, .6, 55),
      ])),
    );
  }
}

final _blur = ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24);

class _TabBar extends StatelessWidget {
  final Screen current;
  const _TabBar({required this.current});
  @override
  Widget build(BuildContext context) {
    final app = context.app, t = app.t, vc = context.vc;
    final defs = [(Screen.home, t['home'], Ic.home), (Screen.explore, t['explore'], Ic.compass), (Screen.ai, t['ai'], Ic.sparkle), (Screen.library, t['library'], Ic.book), (Screen.profile, t['profile'], Ic.person)];
    final idx = defs.indexWhere((d) => d.$1 == current);
    return Row(children: [
      Expanded(child: Glass(height: 66, radius: 33, gradient: vc.tab, blur: 36, padding: const EdgeInsets.all(5), child: LayoutBuilder(builder: (c, box) {
        final w = box.maxWidth / 5;
        return Stack(children: [
          AnimatedPositioned(duration: const Duration(milliseconds: 550), curve: Curves.easeOutBack, left: idx * w, top: 0, width: w, height: 54, child: Container(decoration: BoxDecoration(gradient: vc.tabpill, borderRadius: BorderRadius.circular(27)))),
          Row(children: [
            for (int i = 0; i < defs.length; i++)
              Expanded(child: Semantics(button: true, selected: i == idx, label: defs[i].$2, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => app.go(defs[i].$1), child: SizedBox(height: 54, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                VIcon(defs[i].$3, size: 23, color: i == idx ? vc.tabon : vc.tabtx, stroke: 1.8),
                const SizedBox(height: 3),
                Text(defs[i].$2, maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: i == idx ? vc.tabon : vc.tabtx)),
              ]))))),
          ]),
        ]);
      }))),
      const SizedBox(width: 4),
      Semantics(button: true, label: 'SOS', child: Tap(scale: .92, onTap: () => openSos(context), child: Container(width: 66, height: 66, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.3, -.5), radius: 1, colors: [Color(0xFFFF8A7A), Color(0xFFDC2626)]), boxShadow: [BoxShadow(color: Color(0x73EF4444), blurRadius: 32, offset: Offset(0, 12))]), child: const Text('SOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))))),
    ]);
  }
}
