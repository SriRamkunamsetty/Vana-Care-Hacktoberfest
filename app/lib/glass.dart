import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme.dart';

/// SVG path data (24x24, stroke icons) taken from the prototype.
class Ic {
  static const home = "M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z";
  static const sparkle = "M10.5 3l1.9 5.6L18 10.5l-5.6 1.9L10.5 18l-1.9-5.6L3 10.5l5.6-1.9zM18.5 15l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z";
  static const cross = "M9 3h6v6h6v6h-6v6H9v-6H3V9h6z";
  static const compass = "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM15.5 8.5l-2 5-5 2 2-5z";
  static const book = "M4 19.5A2.5 2.5 0 0 1 6.5 17H20V3H6.5A2.5 2.5 0 0 0 4 5.5zM8 7h8M8 11h6";
  static const search = "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4";
  static const mic = "M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zM5 11a7 7 0 0 0 14 0M12 18v3";
  static const arrowUp = "M12 19V5M5 12l7-7 7 7";
  static const chevR = "M9 6l6 6-6 6";
  static const chevL = "M15 6l-6 6 6 6";
  static const check = "M5 12.5l4.5 4.5L19 7.5";
  static const close = "M6 6l12 12M18 6L6 18";
  static const pin = "M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21zM12 7.5a2 2 0 1 0 0 4 2 2 0 0 0 0-4z";
  static const flame = "M12 3c1 3 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z";
  static const drop = "M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z";
  static const snow = "M12 3v18M4.2 7.5l15.6 9M19.8 7.5l-15.6 9";
  static const bone = "M6 6l12 12M4.5 7.5a2 2 0 1 1 3-3M16.5 19.5a2 2 0 1 0 3-3";
  static const plus = "M12 5v14M5 12h14";
  static const bolt = "M13 3L5 14h6l-1 7 8-11h-6z";
  static const warn = "M12 4l9 16H3zM12 10v4M12 17v.5";
  static const sun = "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M5 19l1.5-1.5M17.5 6.5L19 5";
  static const pulse = "M3 12h4l2-6 4 12 2-6h6";
  static const mtn = "M3 19l6-11 4 7 3-4 5 8z";
  static const whistle = "M4 10a4 4 0 0 1 4-4h9v5a6 6 0 1 1-6 6";
  static const flash = "M9 3h6l-1 6h4l-8 12 1-8H6z";
  static const mirror = "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 9l8 6";
  static const phone = "M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z";
  static const image = "M4 5h16v14H4zM4 16l4-4 4 4 3-3 5 5M9 9.5v.01";
  static const person = "M12 4a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM4 20a8 8 0 0 1 16 0";
  static const lungs = "M12 3v10M12 13c-2 3-5 4-7 3 0-4 1-8 3-9M12 13c2 3 5 4 7 3 0-4-1-8-3-9";

  static const byName = {
    'drop': drop, 'flame': flame, 'bone': bone, 'lungs': lungs, 'person': person, 'snow': snow,
    'sun': sun, 'mtn': mtn, 'warn': warn, 'cross': cross,
  };
}

class VIcon extends StatelessWidget {
  final String d;
  final double size;
  final Color color;
  final double stroke;
  const VIcon(this.d, {super.key, this.size = 22, required this.color, this.stroke = 1.9});

  @override
  Widget build(BuildContext context) {
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" '
        'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round"><path d="$d"/></svg>';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }
}

/// Paints the 1px top highlight the prototype gets from `inset 0 1px 0`.
class _TopLight extends CustomPainter {
  final Color color;
  final BorderRadius radius;
  _TopLight(this.color, this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size).deflate(.5);
    final shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withValues(alpha: 0)], stops: const [0, .22])
        .createShader(Offset.zero & size);
    canvas.drawRRect(rrect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..shader = shader);
  }

  @override
  bool shouldRepaint(_TopLight o) => o.color != color || o.radius != radius;
}

/// Frosted-glass surface: backdrop blur + gradient fill + hairline border + top highlight.
class Glass extends StatelessWidget {
  final Widget? child;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width, height;
  final Gradient? gradient;
  final Color? color;
  final double blur;
  final List<BoxShadow>? shadow;
  final bool border;
  const Glass({super.key, this.child, this.radius = 28, this.borderRadius, this.padding, this.width, this.height, this.gradient, this.color, this.blur = 28, this.shadow, this.border = true});

  @override
  Widget build(BuildContext context) {
    final vc = VC.of(context);
    final br = borderRadius ?? BorderRadius.circular(radius);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: br, boxShadow: shadow ?? vc.shadow),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: CustomPaint(
            foregroundPainter: border ? _TopLight(vc.topLight, br) : null,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: color == null ? (gradient ?? vc.gl) : null,
                color: color,
                borderRadius: br,
                border: border ? Border.all(color: vc.glBorder, width: .5) : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Solid high-contrast card for emergency and first-aid content (no glass).
class Solid extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  const Solid({super.key, required this.child, this.radius = 24, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    final vc = VC.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: vc.solid, borderRadius: BorderRadius.circular(radius), boxShadow: vc.shadow, border: Border.all(color: vc.glBorder, width: .5)),
      child: DefaultTextStyle.merge(style: TextStyle(color: vc.solidtx), child: child),
    );
  }
}

/// Tap target with the prototype's spring-y press scale.
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Tap({super.key, required this.child, this.onTap, this.scale = .96});
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 180), curve: Curves.easeOutBack, child: widget.child),
      );
}

class VSwitch extends StatelessWidget {
  final bool on;
  final ValueChanged<bool>? onChanged;
  const VSwitch({super.key, required this.on, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final vc = VC.of(context);
    return Semantics(
      toggled: on,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 51, height: 31,
          decoration: BoxDecoration(color: on ? vc.swon : vc.swoff, borderRadius: BorderRadius.circular(16)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 350), curve: Curves.easeOutBack,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(width: 27, height: 27, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2))])),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled pill button (primary/forest gradient).
class PrimButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double opacity;
  final double fontSize;
  const PrimButton(this.label, {super.key, this.onTap, this.height = 58, this.opacity = 1, this.fontSize = 17});
  @override
  Widget build(BuildContext context) {
    final vc = VC.of(context);
    return Opacity(
      opacity: opacity,
      child: Tap(
        scale: .97,
        onTap: onTap,
        child: Container(
          height: height, alignment: Alignment.center,
          decoration: BoxDecoration(gradient: vc.prim, borderRadius: BorderRadius.circular(height / 2), boxShadow: [BoxShadow(color: vc.primShadow, blurRadius: 22, offset: const Offset(0, 8))]),
          child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: vc.onprim)),
        ),
      ),
    );
  }
}

class AlertButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  const AlertButton(this.label, {super.key, this.onTap, this.height = 60, this.fontSize = 17});
  @override
  Widget build(BuildContext context) => Tap(
        scale: .97,
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(gradient: kAlertGrad, borderRadius: BorderRadius.circular(height / 2.6), boxShadow: const [BoxShadow(color: Color(0x59EF4444), blurRadius: 26, offset: Offset(0, 10))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const VIcon(Ic.phone, size: 21, color: Colors.white, stroke: 2.2),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
        ),
      );
}

/// Stacked, masked blur layers that fade out toward the content (the "gradient blur").
class ProgressiveBlur extends StatelessWidget {
  final bool top;
  final double height;
  final Color fade;
  const ProgressiveBlur({super.key, required this.top, required this.height, required this.fade});

  Widget _layer(double sigma, List<double> stops) {
    final b = top ? Alignment.topCenter : Alignment.bottomCenter;
    final e = top ? Alignment.bottomCenter : Alignment.topCenter;
    return Positioned.fill(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(begin: b, end: e, colors: const [Colors.black, Colors.black, Colors.transparent], stops: stops).createShader(r),
        child: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: Container(color: Colors.transparent))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          height: height,
          child: Stack(children: [
            _layer(1, const [0, .7, 1]),
            _layer(3, const [0, .5, .8]),
            _layer(8, const [0, .3, .6]),
            _layer(18, const [0, .12, .4]),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: top ? Alignment.topCenter : Alignment.bottomCenter, end: top ? Alignment.bottomCenter : Alignment.topCenter, colors: [fade, fade.withValues(alpha: 0)])))),
          ]),
        ),
      );

}

/// Round glass icon button (back, close, etc).
class GlassIconButton extends StatelessWidget {
  final String d;
  final VoidCallback onTap;
  final double size;
  final String? semantic;
  const GlassIconButton({super.key, required this.d, required this.onTap, this.size = 42, this.semantic});
  @override
  Widget build(BuildContext context) {
    final vc = VC.of(context);
    return Semantics(
      button: true, label: semantic,
      child: Tap(onTap: onTap, child: Glass(width: size, height: size, radius: size / 2, child: Center(child: VIcon(d, size: size * .47, color: vc.tx, stroke: 2.2)))),
    );
  }
}

/// Segmented control used for language / theme.
class Segmented extends StatelessWidget {
  final List<(String, String)> items;
  final String current;
  final ValueChanged<String> onChanged;
  const Segmented({super.key, required this.items, required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final vc = VC.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        for (final (k, label) in items)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(k),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350), curve: Curves.easeOutBack,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: current == k ? vc.solid : Colors.transparent, borderRadius: BorderRadius.circular(18), boxShadow: current == k ? vc.shadow : null),
                child: Text(label, maxLines: 1, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: current == k && vc.dark ? vc.solidtx : vc.tx)),
              ),
            ),
          ),
      ]),
    );
  }
}

class Chip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;
  const Chip2(this.label, {super.key, required this.selected, required this.onTap, this.fontSize = 15});
  @override
  Widget build(BuildContext context) {
    final vc = VC.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(gradient: selected ? vc.prim : null, color: selected ? null : vc.chip, borderRadius: BorderRadius.circular(999), boxShadow: selected ? [BoxShadow(color: vc.primShadow, blurRadius: 14, offset: const Offset(0, 5))] : null),
        child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: selected ? vc.onprim : vc.tx)),
      ),
    );
  }
}
