import 'package:flutter/material.dart';
import 'glass.dart';
import 'l10n.dart';
import 'state.dart';
import 'theme.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  /// Read without subscribing to rebuilds.
  static AppState read(BuildContext c) => (c.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}

extension Ctx on BuildContext {
  AppState get app => AppScope.of(this);
  AppState get appRead => AppScope.read(this);
  VC get vc => VC.of(this);
  Strings get t => AppScope.of(this).t;
}

Color toneColor(VC vc, String tone) => switch (tone) { 'red' => vc.red, 'amb' => vc.amb, 'ice' => vc.ice, _ => vc.acc };
Color toneBg(VC vc, String tone) => switch (tone) { 'red' => vc.redbg, 'amb' => vc.ambbg, 'ice' => vc.icebg, _ => vc.accbg };

/// Standard scrolling page: top inset for status bar, room for the floating tab bar.
class ScrollPage extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const ScrollPage({super.key, required this.children, this.gap = 14});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(18, mq.padding.top + 12, 18, 130 + mq.padding.bottom),
      children: [for (int i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : gap), child: children[i])],
    );
  }
}

class LargeTitle extends StatelessWidget {
  final String text;
  const LargeTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
      child: Text(text, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.1)));
}

class BackTitle extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const BackTitle(this.title, {super.key, required this.onBack});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        GlassIconButton(d: Ic.chevL, onTap: onBack, semantic: 'Back'),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.7))),
      ]));
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 0), child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)));
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .8, color: context.vc.sub));
}

class VTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  const VTextField({super.key, required this.controller, required this.hint, this.keyboard, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Container(
      height: 52,
      decoration: BoxDecoration(color: vc.chip, borderRadius: BorderRadius.circular(18), border: Border.all(color: vc.glBorder, width: .5)),
      child: TextField(
        controller: controller, keyboardType: keyboard, onChanged: onChanged,
        style: TextStyle(fontSize: 17, color: vc.tx),
        cursorColor: vc.acc,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: TextStyle(color: vc.sub2), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      ),
    );
  }
}

/// Bottom sheet chrome shared by all modal sheets (handle, title row, close).
class SheetFrame extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget child;
  final Widget? leading;
  final double topInset;
  const SheetFrame({super.key, required this.title, required this.child, this.titleColor, this.subtitle, this.leading, this.topInset = 90});

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Glass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
        gradient: vc.sheet,
        blur: 40,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + mq.viewInsets.bottom + mq.padding.bottom),
          child: Column(children: [
            Container(width: 38, height: 5, decoration: BoxDecoration(color: vc.hair, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 14),
            Row(children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.6, color: titleColor ?? vc.tx, height: 1.1)),
                  if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle!, style: TextStyle(fontSize: 13, color: vc.sub))),
                ]),
              ),
              Semantics(
                button: true, label: 'Close',
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(width: 40, height: 40, decoration: BoxDecoration(color: vc.chip, shape: BoxShape.circle), child: Center(child: VIcon(Ic.close, size: 18, color: vc.tx, stroke: 2.4))),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(child: child),
          ]),
        ),
      ),
    );
  }
}

Future<T?> showVSheet<T>(BuildContext context, WidgetBuilder builder) {
  final st = AppScope.read(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color.fromRGBO(0, 8, 12, .45),
    elevation: 0,
    useSafeArea: false,
    builder: (c) => AppScope(state: st, child: Theme(data: Theme.of(context), child: builder(c))),
  );
}

Future<T?> showVFull<T>(BuildContext context, WidgetBuilder builder) {
  final st = AppScope.read(context);
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (c, a, b) => AppScope(state: st, child: builder(c)),
    transitionsBuilder: (c, a, b, child) => SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  ));
}

/// Two-column grid with a fixed row height (tiles must not depend on font metrics).
Widget fixedGrid(List<Widget> children, double extent) => GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: extent),
      children: children,
    );
