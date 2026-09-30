import 'dart:math' as math;
import 'package:flutter/material.dart';

Color hexA(int rgb, [double a = 1]) => Color(0xFF000000 | rgb).withValues(alpha: a);

/// Design tokens from the Vana Care prototype (dark + light).
class VC {
  final bool dark;
  final Color tx, sub, sub2, hair, chip, onprim, acc, accbg, amb, ambbg, red, redbg, ice, icebg;
  final Color solid, solidtx, tabtx, tabon, swoff, swon, mapbg, cont, fade, fade2, glBorder;
  final Gradient gl, prim, ai, sheet, tab, tabpill, bg;
  final Color b1, b2, b3;
  final double bo1, bo2, bo3;

  const VC._({
    required this.dark, required this.tx, required this.sub, required this.sub2, required this.hair,
    required this.chip, required this.onprim, required this.acc, required this.accbg, required this.amb,
    required this.ambbg, required this.red, required this.redbg, required this.ice, required this.icebg,
    required this.solid, required this.solidtx, required this.tabtx, required this.tabon, required this.swoff,
    required this.swon, required this.mapbg, required this.cont, required this.fade, required this.fade2,
    required this.glBorder, required this.gl, required this.prim, required this.ai, required this.sheet,
    required this.tab, required this.tabpill, required this.bg, required this.b1, required this.b2,
    required this.b3, required this.bo1, required this.bo2, required this.bo3,
  });

  static const _ai = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3882F6), Color(0xFF7C5CFF)]);

  static LinearGradient _lin(List<Color> c, {double deg = 150}) {
    // CSS angle -> Alignment (approximate for 150/160/170/180deg used in the design)
    final rad = deg * math.pi / 180;
    final dx = math.sin(rad), dy = -math.cos(rad);
    return LinearGradient(begin: Alignment(-dx, -dy), end: Alignment(dx, dy), colors: c);
  }

  static final dark_ = VC._(
    dark: true, tx: hexA(0xF1F8F4), sub: const Color.fromRGBO(226, 240, 233, .68), sub2: const Color.fromRGBO(226, 240, 233, .5),
    hair: const Color.fromRGBO(255, 255, 255, .14), chip: const Color.fromRGBO(255, 255, 255, .12),
    onprim: hexA(0x06251E), acc: hexA(0x8FE3B5), accbg: const Color.fromRGBO(143, 227, 181, .16),
    amb: hexA(0xFFB65C), ambbg: const Color.fromRGBO(249, 115, 22, .18), red: hexA(0xFF8A7A),
    redbg: const Color.fromRGBO(239, 68, 68, .18), ice: hexA(0x8CB4FF), icebg: const Color.fromRGBO(56, 130, 246, .2),
    solid: hexA(0x123A32), solidtx: hexA(0xF4FBF7), tabtx: const Color.fromRGBO(241, 248, 244, .72), tabon: hexA(0x8FE3B5),
    swoff: const Color.fromRGBO(255, 255, 255, .22), swon: hexA(0x7BD9A6), mapbg: hexA(0x0D2A26),
    cont: const Color.fromRGBO(143, 227, 181, .14), fade: const Color.fromRGBO(8, 20, 28, .62), fade2: const Color.fromRGBO(8, 18, 32, .72),
    glBorder: const Color.fromRGBO(255, 255, 255, .15),
    gl: _lin(const [Color.fromRGBO(255, 255, 255, .18), Color.fromRGBO(255, 255, 255, .05)]),
    prim: _lin([hexA(0xB5F3CF), hexA(0x7BD9A6)], deg: 180), ai: _ai,
    sheet: _lin(const [Color.fromRGBO(18, 62, 54, .94), Color.fromRGBO(8, 20, 30, .97)], deg: 170),
    tab: _lin(const [Color.fromRGBO(28, 84, 72, .74), Color.fromRGBO(8, 26, 36, .86)]),
    tabpill: _lin(const [Color.fromRGBO(255, 255, 255, .34), Color.fromRGBO(255, 255, 255, .12)]),
    bg: _lin([hexA(0x0B2E27), hexA(0x0A1B24), hexA(0x081220)], deg: 170),
    b1: hexA(0x2FB58E), b2: hexA(0xF97316), b3: hexA(0x3882F6), bo1: .5, bo2: .26, bo3: .4,
  );

  static final light_ = VC._(
    dark: false, tx: hexA(0x0F2D23), sub: const Color.fromRGBO(15, 45, 35, .68), sub2: const Color.fromRGBO(15, 45, 35, .52),
    hair: const Color.fromRGBO(15, 45, 35, .12), chip: const Color.fromRGBO(15, 45, 35, .07),
    onprim: hexA(0xF4F2EC), acc: hexA(0x2F7A5B), accbg: const Color.fromRGBO(62, 107, 90, .14),
    amb: hexA(0xC2570C), ambbg: const Color.fromRGBO(249, 115, 22, .14), red: hexA(0xD92D20),
    redbg: const Color.fromRGBO(239, 68, 68, .12), ice: hexA(0x2563C9), icebg: const Color.fromRGBO(56, 130, 246, .13),
    solid: Colors.white, solidtx: hexA(0x0F2D23), tabtx: const Color.fromRGBO(15, 45, 35, .6), tabon: hexA(0x0F2D23),
    swoff: const Color.fromRGBO(15, 45, 35, .2), swon: hexA(0x2F7A5B), mapbg: hexA(0xDCE6D9),
    cont: const Color.fromRGBO(15, 45, 35, .13), fade: const Color.fromRGBO(244, 242, 236, .78), fade2: const Color.fromRGBO(244, 242, 236, .84),
    glBorder: const Color.fromRGBO(255, 255, 255, .95),
    gl: _lin(const [Color.fromRGBO(255, 255, 255, .8), Color.fromRGBO(248, 250, 255, .5)]),
    prim: _lin([hexA(0x1E5442), hexA(0x0F2D23)], deg: 180), ai: _ai,
    sheet: _lin(const [Color.fromRGBO(248, 250, 255, .97), Color.fromRGBO(238, 242, 236, .98)], deg: 170),
    tab: _lin(const [Color.fromRGBO(255, 255, 255, .86), Color.fromRGBO(248, 250, 255, .66)]),
    tabpill: _lin(const [Color.fromRGBO(62, 107, 90, .24), Color.fromRGBO(62, 107, 90, .1)]),
    bg: _lin([hexA(0xF4F2EC), hexA(0xEEF1EA), hexA(0xE6EEEA)], deg: 170),
    b1: hexA(0x7FB59A), b2: hexA(0xFBC08A), b3: hexA(0x9DBEFF), bo1: .55, bo2: .45, bo3: .55,
  );

  static VC of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark_ : light_;

  /// Card shadow (the design's inset highlight is drawn by [GlassPainter]).
  List<BoxShadow> get shadow => [BoxShadow(color: Color.fromRGBO(dark ? 0 : 15, dark ? 0 : 45, dark ? 0 : 35, dark ? .26 : .13), blurRadius: 30, offset: const Offset(0, 10))];
  Color get primShadow => dark ? const Color.fromRGBO(80, 210, 150, .3) : const Color.fromRGBO(15, 45, 35, .3);
  Color get topLight => dark ? const Color.fromRGBO(255, 255, 255, .5) : Colors.white;
}

const kAlert = Color(0xFFEF4444);
const kAlertGrad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF25A4B), Color(0xFFD92D20)]);
const kOrange = Color(0xFFF97316);
const kMint = Color(0xFF8FE3B5);
const kSky = Color(0xFF3882F6);
const kGreen = Color(0xFF16A34A);
