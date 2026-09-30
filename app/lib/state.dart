import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data.dart';
import 'l10n.dart';

enum Screen { home, explore, ai, library, profile, map, lost, tools }

class Contact {
  final int id;
  final String name, rel, phone;
  const Contact(this.id, this.name, this.rel, this.phone);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'rel': rel, 'phone': phone};
  factory Contact.fromJson(Map j) => Contact(j['id'] as int, j['name'] as String, j['rel'] as String? ?? 'Family', j['phone'] as String);
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
  String get telUri => 'tel:${phone.replaceAll(RegExp(r'[^+\d]'), '')}';
}

class Profile {
  final String name, blood, allergies, conditions, meds;
  const Profile({this.name = '', this.blood = '', this.allergies = '', this.conditions = '', this.meds = ''});
  Profile copy({String? name, String? blood, String? allergies, String? conditions, String? meds}) => Profile(
      name: name ?? this.name, blood: blood ?? this.blood, allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions, meds: meds ?? this.meds);
  Map<String, dynamic> toJson() => {'name': name, 'blood': blood, 'allergies': allergies, 'conditions': conditions, 'meds': meds};
  factory Profile.fromJson(Map j) => Profile(
      name: j['name'] ?? '', blood: j['blood'] ?? '', allergies: j['allergies'] ?? '', conditions: j['conditions'] ?? '', meds: j['meds'] ?? '');
  String get firstName => name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).first;
}

class TrailPoint {
  final double lat, lon;
  final int ts;
  const TrailPoint(this.lat, this.lon, this.ts);
  List<num> toJson() => [lat, lon, ts];
  factory TrailPoint.fromJson(List j) => TrailPoint((j[0] as num).toDouble(), (j[1] as num).toDouble(), (j[2] as num).toInt());
}

class EmergencyEvent {
  final String id, category, status;
  final int ts;
  final double? lat, lon, acc;
  final int? battery;
  const EmergencyEvent(this.id, this.category, this.ts, this.lat, this.lon, this.acc, this.battery, this.status);
  Map<String, dynamic> toJson() => {'id': id, 'cat': category, 'ts': ts, 'lat': lat, 'lon': lon, 'acc': acc, 'bat': battery, 'status': status};
  factory EmergencyEvent.fromJson(Map j) => EmergencyEvent(j['id'], j['cat'], j['ts'], (j['lat'] as num?)?.toDouble(), (j['lon'] as num?)?.toDouble(), (j['acc'] as num?)?.toDouble(), j['bat'], j['status']);
}

class ChatMsg {
  final bool user;
  final String text;
  final String? imagePath;
  final List<String> steps;
  final String? guide;
  const ChatMsg({required this.user, this.text = '', this.imagePath, this.steps = const [], this.guide});
}

class AppState extends ChangeNotifier {
  AppState({AssistantEngine? assistant, FlutterSecureStorage? secure}) : assistant = assistant ?? ScriptedAssistant(), _secure = secure ?? const FlutterSecureStorage();

  final AssistantEngine assistant;
  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;

  // App-level
  bool ready = false;
  bool onboarded = false;
  ThemeMode themeMode = ThemeMode.dark;
  String lang = 'en';
  Strings get t => Strings(lang);
  Screen screen = Screen.home;

  // Onboarding permissions (what the user opted into; OS prompts happen on finish)
  Map<String, bool> perms = {'loc': true, 'cam': true, 'mic': false};
  Map<String, bool> packs = {'cas': true, 'sie': false, 'ala': false};
  Map<String, bool> priv = {'sessions': true, 'track': true, 'photos': false};
  Map<String, bool> tools = {'whistle': false, 'strobe': false, 'mirror': false, 'saver': false};
  Map<int, bool> lostChk = {};
  Map<String, Set<int>> guideChecked = {};
  bool checkin = false;

  // Data
  Profile profile = const Profile();
  List<Contact> contacts = [];
  List<EmergencyEvent> events = [];

  // Live sensors
  Position? pos;
  bool locationDenied = false;
  double heading = 0;
  bool hasHeading = false;
  int? batteryPct;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  final Battery _battery = Battery();

  // Trip
  bool recording = false;
  List<TrailPoint> trail = [];
  DateTime? tripStart;
  Timer? _tripTick;
  DateTime now = DateTime.now();

  // Chat
  final List<ChatMsg> chat = [const ChatMsg(user: false, text: "I'm Vana. I run fully on this phone, so no signal is needed. What's happening?")];
  bool typing = false;
  String? attach;

  // Emergency
  String emCategory = 'General';
  String incidentId = _newIncidentId();
  bool sosActive = false;

  // Toast
  String toastMsg = '';
  Timer? _toastT;

  static String _newIncidentId() {
    final d = DateTime.now();
    final r = (d.millisecondsSinceEpoch % 9000) + 1000;
    return 'VC-${(d.year % 100).toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}-$r';
  }

  // ---------------------------------------------------------------- lifecycle
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final p = _prefs!;
      onboarded = p.getBool('onboarded') ?? false;
      themeMode = (p.getString('theme') ?? 'dark') == 'light' ? ThemeMode.light : ThemeMode.dark;
      lang = p.getString('lang') ?? 'en';
      checkin = p.getBool('checkin') ?? false;
      for (final k in priv.keys) { priv[k] = p.getBool('priv.$k') ?? priv[k]!; }
      for (final k in packs.keys) { packs[k] = p.getBool('pack.$k') ?? packs[k]!; }
      for (final k in tools.keys) { tools[k] = p.getBool('tool.$k') ?? tools[k]!; }
      final tr = p.getString('trail');
      if (tr != null) trail = (jsonDecode(tr) as List).map((e) => TrailPoint.fromJson(e as List)).toList();
      final ts = p.getInt('tripStart');
      if (ts != null) tripStart = DateTime.fromMillisecondsSinceEpoch(ts);
    } catch (_) {}
    try {
      final raw = await _secure.read(key: 'vana.care.profile');
      if (raw != null) {
        final d = jsonDecode(raw) as Map;
        profile = Profile.fromJson(d['profile'] as Map? ?? {});
        contacts = ((d['contacts'] as List?) ?? []).map((e) => Contact.fromJson(e as Map)).toList();
        events = ((d['events'] as List?) ?? []).map((e) => EmergencyEvent.fromJson(e as Map)).toList();
      }
    } catch (_) {}
    ready = true;
    notifyListeners();
    if (onboarded) startLocation();
    refreshBattery();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _magSub?.cancel();
    _tripTick?.cancel();
    _toastT?.cancel();
    super.dispose();
  }

  Future<void> _persistSecure() async {
    try {
      await _secure.write(
          key: 'vana.care.profile',
          value: jsonEncode({'profile': profile.toJson(), 'contacts': contacts.map((c) => c.toJson()).toList(), 'events': events.map((e) => e.toJson()).toList()}));
    } catch (_) {}
  }

  Future<void> _persistTrip() async {
    try {
      await _prefs?.setString('trail', jsonEncode(trail.map((e) => e.toJson()).toList()));
      if (tripStart != null) await _prefs?.setInt('tripStart', tripStart!.millisecondsSinceEpoch);
    } catch (_) {}
  }

  void toast(String m) {
    _toastT?.cancel();
    toastMsg = m;
    notifyListeners();
    _toastT = Timer(const Duration(milliseconds: 2400), () { toastMsg = ''; notifyListeners(); });
  }

  // ---------------------------------------------------------------- settings
  void setTheme(ThemeMode m) { themeMode = m; _prefs?.setString('theme', m == ThemeMode.light ? 'light' : 'dark'); notifyListeners(); }
  void setLang(String l) { lang = l; _prefs?.setString('lang', l); notifyListeners(); }
  void go(Screen s) {
    screen = s;
    _syncCompass();
    notifyListeners();
  }
  void toggleMap(Map<String, bool> m, String k, String prefix) { m[k] = !(m[k] ?? false); _prefs?.setBool('$prefix.$k', m[k]!); notifyListeners(); }
  void togglePerm(String k) { perms[k] = !perms[k]!; notifyListeners(); }
  void toggleLost(int i) { lostChk[i] = !(lostChk[i] ?? false); notifyListeners(); }
  void toggleStep(String guide, int i) {
    final s = guideChecked.putIfAbsent(guide, () => {});
    if (!s.remove(i)) s.add(i);
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    _prefs?.setBool('onboarded', true);
    screen = Screen.home;
    notifyListeners();
    if (perms['loc'] == true) await startLocation();
  }

  // ---------------------------------------------------------------- profile & contacts
  Future<void> saveProfile(Profile p) async { profile = p; notifyListeners(); await _persistSecure(); toast('Medical ID saved'); }
  Future<void> saveContact(Contact c) async {
    final i = contacts.indexWhere((x) => x.id == c.id);
    if (i >= 0) { contacts[i] = c; } else { contacts.add(c); }
    notifyListeners();
    await _persistSecure();
    toast('Contact saved');
  }
  Future<void> removeContact(int id) async { contacts.removeWhere((c) => c.id == id); notifyListeners(); await _persistSecure(); toast('Contact removed'); }

  // ---------------------------------------------------------------- location / compass / battery
  Future<void> restartLocation() async {
    await _posSub?.cancel();
    _posSub = null;
    await startLocation();
  }

  Future<void> startLocation() async {
    if (_posSub != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { locationDenied = true; notifyListeners(); return; }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) { locationDenied = true; notifyListeners(); return; }
      locationDenied = false;
      _posSub = Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: tools['saver'] == true ? LocationAccuracy.medium : LocationAccuracy.high, distanceFilter: tools['saver'] == true ? 25 : 4)).listen(_onPos, onError: (_) {});
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && pos == null) { pos = last; notifyListeners(); }
    } catch (_) {
      locationDenied = true;
      notifyListeners();
    }
  }

  void _onPos(Position p) {
    pos = p;
    if (recording) {
      final last = trail.isEmpty ? null : trail.last;
      if (last == null || Geolocator.distanceBetween(last.lat, last.lon, p.latitude, p.longitude) >= 4) {
        trail.add(TrailPoint(p.latitude, p.longitude, DateTime.now().millisecondsSinceEpoch));
        if (trail.length % 10 == 0) _persistTrip();
      }
    }
    notifyListeners();
  }

  void _syncCompass() {
    final need = screen == Screen.tools || screen == Screen.map;
    if (need && _magSub == null) {
      try {
        _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
          final h = (math.atan2(-e.x, e.y) * 180 / math.pi + 360) % 360;
          // low-pass on the circle
          var d = h - heading;
          if (d > 180) d -= 360;
          if (d < -180) d += 360;
          heading = hasHeading ? (heading + d * .2 + 360) % 360 : h;
          hasHeading = true;
          notifyListeners();
        }, onError: (_) { hasHeading = false; });
      } catch (_) {}
    } else if (!need && _magSub != null) {
      _magSub!.cancel();
      _magSub = null;
    }
  }

  Future<void> refreshBattery() async {
    try { batteryPct = await _battery.batteryLevel; notifyListeners(); } catch (_) {}
  }

  // ---------------------------------------------------------------- trip recording
  void setRecording(bool on) {
    if (on == recording) return;
    recording = on;
    if (on) {
      if (trail.isEmpty || tripStart == null) { tripStart = DateTime.now(); trail = []; }
      if (pos != null && trail.isEmpty) trail.add(TrailPoint(pos!.latitude, pos!.longitude, DateTime.now().millisecondsSinceEpoch));
      startLocation();
      _tripTick = Timer.periodic(const Duration(seconds: 1), (_) { now = DateTime.now(); notifyListeners(); });
    } else {
      _tripTick?.cancel();
      _persistTrip();
    }
    notifyListeners();
  }

  void clearTrip() { trail = []; tripStart = null; recording = false; _tripTick?.cancel(); _prefs?.remove('trail'); _prefs?.remove('tripStart'); notifyListeners(); }

  double get distanceM {
    var d = 0.0;
    for (var i = 1; i < trail.length; i++) { d += Geolocator.distanceBetween(trail[i - 1].lat, trail[i - 1].lon, trail[i].lat, trail[i].lon); }
    return d;
  }
  Duration get elapsed => tripStart == null ? Duration.zero : now.difference(tripStart!);

  Future<void> setCheckin(bool on) async {
    checkin = on;
    _prefs?.setBool('checkin', on);
    notifyListeners();
    if (on) await sendCheckin();
  }

  Future<void> sendCheckin() async {
    if (contacts.isEmpty) { toast('Add an emergency contact first'); return; }
    await _sms(contacts.first, 'Vana Care check-in. I am OK. ${_posLine(includeLink: true)}');
  }

  // ---------------------------------------------------------------- formatting helpers
  String? get fmtPos {
    final p = pos;
    if (p == null) return null;
    return '${p.latitude.abs().toStringAsFixed(4)}° ${p.latitude >= 0 ? 'N' : 'S'}, ${p.longitude.abs().toStringAsFixed(4)}° ${p.longitude >= 0 ? 'E' : 'W'}';
  }
  String _posLine({bool includeLink = false}) {
    final p = pos;
    if (p == null) return 'Position unavailable.';
    return 'My position: $fmtPos${includeLink ? ' (https://maps.google.com/?q=${p.latitude},${p.longitude})' : ''}';
  }
  String get posAcc => pos == null ? '' : '±${pos!.accuracy.round()} m';

  /// Minutes of daylight remaining (null if no fix or the sun is down).
  Duration? get daylightLeft {
    final p = pos;
    if (p == null) return null;
    final ss = _sunsetUtc(p.latitude, p.longitude, DateTime.now().toUtc());
    if (ss == null) return null;
    final d = ss.difference(DateTime.now().toUtc());
    return d.isNegative ? Duration.zero : d;
  }

  // NOAA-style approximation, accurate to a few minutes.
  static DateTime? _sunsetUtc(double lat, double lon, DateTime utc) {
    final n = utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;
    final g = 2 * math.pi / 365 * (n - 1);
    final eqt = 229.18 * (0.000075 + 0.001868 * math.cos(g) - 0.032077 * math.sin(g) - 0.014615 * math.cos(2 * g) - 0.040849 * math.sin(2 * g));
    final decl = 0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g) - 0.006758 * math.cos(2 * g) + 0.000907 * math.sin(2 * g) - 0.002697 * math.cos(3 * g) + 0.00148 * math.sin(3 * g);
    final latR = lat * math.pi / 180;
    final cosH = math.cos(90.833 * math.pi / 180) / (math.cos(latR) * math.cos(decl)) - math.tan(latR) * math.tan(decl);
    if (cosH < -1 || cosH > 1) return null;
    final ha = math.acos(cosH) * 180 / math.pi;
    final minutes = 720 - 4 * (lon - ha) - eqt;
    final ssMin = 720 - 4 * (lon + ha) - eqt; // minutes UTC of sunset
    final _ = minutes;
    var day = DateTime.utc(utc.year, utc.month, utc.day).add(Duration(seconds: (ssMin * 60).round()));
    // keep sunset within the next ~24h window of `utc`
    while (day.isBefore(utc.subtract(const Duration(hours: 12)))) { day = day.add(const Duration(days: 1)); }
    while (day.isAfter(utc.add(const Duration(hours: 12)))) { day = day.subtract(const Duration(days: 1)); }
    return day;
  }

  // ---------------------------------------------------------------- communication
  Future<void> call112() async {
    final ok = await _launch(Uri.parse('tel:112'));
    if (!ok) toast('This device cannot place calls');
  }
  Future<void> callContact(Contact c) async { await _launch(Uri.parse(c.telUri)); }

  Future<void> sharePosition() async {
    if (contacts.isEmpty) { toast('Add an emergency contact first'); go(Screen.profile); return; }
    await _sms(contacts.first, 'Vana Care emergency. I need help. ${_posLine(includeLink: true)}');
  }

  Future<void> sendReportSms() async {
    if (contacts.isEmpty) { toast('Add an emergency contact first'); return; }
    final b = StringBuffer('VANA CARE — EMERGENCY REPORT\nIncident $incidentId\nCategory: $emCategory\n${_posLine(includeLink: true)}');
    if (pos != null) b.write('\nGPS accuracy: $posAcc');
    if (batteryPct != null) b.write('\nBattery: $batteryPct%');
    await _sms(contacts.first, b.toString());
  }

  Future<void> _sms(Contact c, String body) async {
    final uri = Uri(scheme: 'sms', path: c.phone.replaceAll(RegExp(r'[^+\d]'), ''), queryParameters: {'body': body});
    if (!await _launch(uri)) toast('This device cannot send SMS');
  }

  Future<bool> _launch(Uri u) async {
    try { return await launchUrl(u); } catch (_) { return false; }
  }

  // ---------------------------------------------------------------- SOS
  void prepareSos({String? category}) {
    sosActive = false;
    incidentId = _newIncidentId();
    if (category != null) emCategory = category;
    refreshBattery();
    if (pos == null) startLocation();
    notifyListeners();
  }

  Future<void> activateSos() async {
    sosActive = true;
    final ev = EmergencyEvent(incidentId, emCategory, DateTime.now().millisecondsSinceEpoch, pos?.latitude, pos?.longitude, pos?.accuracy, batteryPct, 'Saved · waiting for signal');
    events.insert(0, ev);
    notifyListeners();
    await _persistSecure();
  }

  void cancelSos() { sosActive = false; notifyListeners(); }

  // ---------------------------------------------------------------- chat
  Future<void> send(String text, {String? keywords}) async {
    text = text.trim();
    final img = attach;
    if ((text.isEmpty && img == null) || typing) return;
    chat.add(ChatMsg(user: true, text: text, imagePath: img));
    attach = null;
    typing = true;
    notifyListeners();
    final r = await assistant.respond(keywords ?? text, hasImage: img != null);
    typing = false;
    chat.add(ChatMsg(user: false, text: r.text, steps: r.steps, guide: r.guide));
    notifyListeners();
  }
  void setAttach(String? p) { attach = p; notifyListeners(); }
}
