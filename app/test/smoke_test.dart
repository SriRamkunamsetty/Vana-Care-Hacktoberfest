import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vana_care/main.dart';
import 'package:vana_care/sheets.dart';
import 'package:vana_care/state.dart';

void main() {
  testWidgets('onboarding, all tabs, all sheets, contact save', (t) async {
    t.view.physicalSize = const Size(393 * 3, 852 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (c) async => null);
    final st = AppState();
    await t.pumpWidget(VanaApp(state: st));
    debugPrint('A');
    await t.runAsync(() => st.init());
    debugPrint('B ready=${st.ready}');
    await t.pump(const Duration(seconds: 3));
    debugPrint('C');
    await t.pump(const Duration(seconds: 1));
    debugPrint('D ${find.text('Continue').evaluate().length}');
    for (var i = 0; i < 3; i++) {
      await t.tap(find.text('Continue'));
      await t.pump(const Duration(milliseconds: 700));
      debugPrint('step $i');
    }
    st.perms['loc'] = false;
    await t.runAsync(() => st.finishOnboarding());
    await t.pump(const Duration(seconds: 1));
    debugPrint('home ${find.text('Emergency Mode').evaluate().length}');
    for (final s in Screen.values) {
      st.go(s);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));
      debugPrint('screen $s');
    }
    st.setTheme(ThemeMode.light);
    await t.pump(const Duration(seconds: 1));
    debugPrint('light');
    st.go(Screen.home);
    await t.pump(const Duration(seconds: 1));
    debugPrint('done');
    final ctx = t.element(find.byType(Shell));
    final opens = <String, Future<void> Function()>{
      'emergency': () => openEmergency(ctx),
      'guide': () => openGuide(ctx, 'bites'),
      'voice': () => openVoice(ctx),
      'vision': () => openVision(ctx),
      'sos': () => openSos(ctx),
      'contact': () => openContact(ctx),
      'profile': () => openProfileEdit(ctx),
    };
    for (final e in opens.entries) {
      e.value();
      await t.pump(const Duration(milliseconds: 800));
      await t.pump(const Duration(milliseconds: 800));
      debugPrint('sheet ${e.key}');
      Navigator.of(ctx, rootNavigator: true).pop();
      await t.pump(const Duration(milliseconds: 800));
      await t.pump(const Duration(milliseconds: 800));
    }
    st.setTheme(ThemeMode.dark);
    await t.pump(const Duration(milliseconds: 500));
    // contact save flow
    openContact(ctx);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.enterText(find.byType(TextField).at(0), 'Asha Rao');
    await t.enterText(find.byType(TextField).at(1), '+91 98765 43210');
    await t.pump();
    await t.tap(find.text('Save contact'));
    await t.pump(const Duration(seconds: 1));
    await t.runAsync(() async {});
    debugPrint('contacts=${st.contacts.length} ${st.contacts.isEmpty ? '' : st.contacts.first.telUri}');
    expect(st.contacts.length, 1);
    await t.pump(const Duration(seconds: 3));
  });
}
