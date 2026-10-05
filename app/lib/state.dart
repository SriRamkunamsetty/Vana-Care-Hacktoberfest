import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai/assistant.dart';
import 'ai/gemma_manager.dart';
import 'ai/knowledge.dart';
import 'ai/llm.dart';
import 'core/db.dart';
import 'core/log.dart';
import 'data.dart';
import 'data_i18n.dart';
import 'data/repositories.dart';
import 'l10n.dart';
import 'voice.dart';

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
  String text;
  final String? imagePath;
  List<String> steps;
  String? guide;
  List<AssistantSource> sources;
  bool emergency, callEmergency, modelUsed, streaming;
  ChatMsg({required this.user, this.text = '', this.imagePath, this.steps = const [], this.guide, this.sources = const [], this.emergency = false, this.callEmergency = false, this.modelUsed = false, this.streaming = false});
}

class ForecastDay {
  final String date;
  final double? tMax, tMin, rain, wind;
  const ForecastDay(this.date, this.tMax, this.tMin, this.rain, this.wind);
  Map<String, dynamic> toJson() => {'d': date, 'x': tMax, 'n': tMin, 'r': rain, 'w': wind};
  factory ForecastDay.fromJson(Map j) => ForecastDay(j['d'] as String, (j['x'] as num?)?.toDouble(), (j['n'] as num?)?.toDouble(), (j['r'] as num?)?.toDouble(), (j['w'] as num?)?.toDouble());
}

class Forecast {
  final DateTime savedAt;
  final List<ForecastDay> days;
  const Forecast(this.savedAt, this.days);
  Map<String, dynamic> toJson() => {'at': savedAt.millisecondsSinceEpoch, 'days': days.map((d) => d.toJson()).toList()};
  factory Forecast.fromJson(Map j) => Forecast(DateTime.fromMillisecondsSinceEpoch(j['at'] as int), [for (final d in j['days'] as List) ForecastDay.fromJson(d as Map)]);

  factory Forecast.fromOpenMeteo(Map j, DateTime now) {
    final d = j['daily'] as Map;
    List l(String k) => (d[k] as List?) ?? const [];
    final dates = l('time');
    double? at(String k, int i) => i < l(k).length ? (l(k)[i] as num?)?.toDouble() : null;
    return Forecast(now, [for (var i = 0; i < dates.length; i++) ForecastDay(dates[i] as String, at('temperature_2m_max', i), at('temperature_2m_min', i), at('precipitation_sum', i), at('wind_speed_10m_max', i))]);
  }
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  /// [llm] and [database] are injected by tests. In production Gemma runs through [gemma].
  AppState({GemmaModelManager? gemma, LlmBackend? llm, AppDatabase? database, FlutterSecureStorage? secure})
      : gemma = gemma ?? GemmaModelManager(),
        _llmOverride = llm,
        _dbOverride = database,
        _secure = secure ?? const FlutterSecureStorage();

  final GemmaModelManager gemma;
  final VoiceService voice = VoiceService();
  final LlmBackend? _llmOverride;
  final AppDatabase? _dbOverride;
  AppDatabase? db;
  KnowledgeBase? kb;
  VanaAssistant? assistant;
  TripRepository? trips;
  HealthSessionRepository? sessions;
  RegionRepository? regions;
  int? tripId;
  List<OfflineRegion> offlineRegions = [];
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

  /// Last GPS fix, kept across restarts so Lost Mode and reports still have a position without a signal.
  TrailPoint? lastKnown;
  int _lastSaved = 0;
  bool locationDenied = false;
  double heading = 0;
  bool hasHeading = false;
  int? batteryPct;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  int _lastHeadingNotify = 0;
  final Battery _battery = Battery();

  // Trip
  bool recording = false;
  List<TrailPoint> trail = [];
  DateTime? tripStart;
  Timer? _tripTick;
  DateTime now = DateTime.now();

  // Chat
  final List<ChatMsg> chat = [ChatMsg(user: false, text: "I'm Vana. I run fully on this phone, so no signal is needed. What's happening?")];
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
      for (final k in tools.keys) { tools[k] = p.getBool('tool.$k') ?? tools[k]!; }
      final lk = p.getString('lastKnown');
      if (lk != null) lastKnown = TrailPoint.fromJson(jsonDecode(lk) as List);
      final fc = p.getString('forecast');
      if (fc != null) forecast = Forecast.fromJson(jsonDecode(fc) as Map);
    } catch (e) {
      logError('state', e);
    }
    await _initData();
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

  /// Opens the database, indexes approved knowledge, restores any unfinished trip and starts Gemma's manager.
  Future<void> _initData() async {
    try {
      db = _dbOverride ?? await AppDatabase.open();
      trips = TripRepository(db!);
      sessions = HealthSessionRepository(db!);
      regions = RegionRepository(db!);
      kb = KnowledgeBase(db!);
      await kb!.load();
      offlineRegions = await regions!.all();
      final t = await trips!.active();
      if (t != null) {
        tripId = t.id;
        tripStart = t.start;
        trail = (await trips!.points(t.id)).map((e) => TrailPoint(e.lat, e.lon, e.ts)).toList();
      }
    } catch (e, st) {
      logError('state', e, st);
    }
    WidgetsBinding.instance.addObserver(this);
    final llm = _llmOverride;
    if (llm == null) {
      gemma.addListener(notifyListeners);
      await gemma.init();
    }
    if (kb != null) assistant = VanaAssistant(kb: kb!, llm: llm ?? gemma);
  }

  @override
  void didHaveMemoryPressure() => gemma.onMemoryPressure();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_llmOverride == null) gemma.removeListener(notifyListeners);
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
    if (s == Screen.ai) gemma.warmUp();
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
      _posSub = Geolocator.getPositionStream(locationSettings: _locationSettings()).listen(_onPos, onError: (_) {});
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && pos == null) { pos = last; notifyListeners(); }
    } catch (_) {
      locationDenied = true;
      notifyListeners();
    }
  }

  /// Battery-conscious tracking: medium accuracy and a wider filter in battery-saver mode.
  /// While a trip is being recorded Android keeps tracking alive with a foreground service
  /// (a visible notification) and iOS shows the background-location indicator.
  LocationSettings _locationSettings() {
    final saver = tools['saver'] == true;
    final acc = saver ? LocationAccuracy.medium : LocationAccuracy.high;
    final filter = saver ? 25 : 4;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: acc,
        distanceFilter: filter,
        foregroundNotificationConfig: recording
            ? const ForegroundNotificationConfig(notificationTitle: 'Vana Care is recording your trail', notificationText: 'Tap to open. Recording uses GPS and battery.', setOngoing: true)
            : null,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(accuracy: acc, distanceFilter: filter, activityType: ActivityType.fitness, pauseLocationUpdatesAutomatically: true, allowBackgroundLocationUpdates: recording, showBackgroundLocationIndicator: recording);
    }
    return LocationSettings(accuracy: acc, distanceFilter: filter);
  }

  void _onPos(Position p) {
    pos = p;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    lastKnown = TrailPoint(p.latitude, p.longitude, nowMs);
    if (nowMs - _lastSaved > 30000) {
      _lastSaved = nowMs;
      _prefs?.setString('lastKnown', jsonEncode(lastKnown!.toJson()));
    }
    if (recording) {
      final last = trail.isEmpty ? null : trail.last;
      if (last == null || Geolocator.distanceBetween(last.lat, last.lon, p.latitude, p.longitude) >= 4) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        trail.add(TrailPoint(p.latitude, p.longitude, ts));
        _savePoint(p.latitude, p.longitude, ts, p.accuracy);
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
          final next = hasHeading ? (heading + d * .2 + 360) % 360 : h;
          final first = !hasHeading;
          final moved = (next - heading).abs();
          heading = next;
          hasHeading = true;
          // The compass sensor fires ~60 times a second. Redraw at most ~20 times a second, and only for a real change.
          final t = DateTime.now().millisecondsSinceEpoch;
          if (first || (moved >= .8 && t - _lastHeadingNotify >= 50)) {
            _lastHeadingNotify = t;
            notifyListeners();
          }
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
  void _savePoint(double lat, double lon, int ts, double? acc) {
    final id = tripId;
    if (id == null || trips == null) return;
    trips!.addPoint(id, RoutePoint(lat, lon, ts, acc)).catchError((Object e) => logError('trip', e));
  }

  Future<void> setRecording(bool on) async {
    if (on == recording) return;
    recording = on;
    if (on) {
      if (tripId == null || trail.isEmpty) {
        final d = DateTime.now();
        final t = await trips?.start('Trek ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
        tripId = t?.id;
        tripStart = t?.start ?? d;
        trail = [];
      }
      if (pos != null && trail.isEmpty) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        trail.add(TrailPoint(pos!.latitude, pos!.longitude, ts));
        _savePoint(pos!.latitude, pos!.longitude, ts, pos!.accuracy);
      }
    } else {
      _tripTick?.cancel();
    }
    notifyListeners();
    await restartLocation(); // switches the foreground-service notification on or off
  }

  Future<void> clearTrip() async {
    final id = tripId;
    trail = [];
    tripStart = null;
    tripId = null;
    recording = false;
    _tripTick?.cancel();
    notifyListeners();
    if (id != null) {
      try {
        await trips?.delete(id);
      } catch (e) {
        logError('trip', e);
      }
    }
    await restartLocation();
  }

  double get distanceM {
    var d = 0.0;
    for (var i = 1; i < trail.length; i++) { d += Geolocator.distanceBetween(trail[i - 1].lat, trail[i - 1].lon, trail[i].lat, trail[i].lon); }
    return d;
  }
  Duration get elapsed => tripStart == null ? Duration.zero : DateTime.now().difference(tripStart!);

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
  static String _fmt(double lat, double lon) => '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}, ${lon.abs().toStringAsFixed(4)}° ${lon >= 0 ? 'E' : 'W'}';

  String? get fmtPos {
    final p = pos;
    return p == null ? null : _fmt(p.latitude, p.longitude);
  }

  /// Saved position from an earlier fix, with how old it is. Null when there is a live fix or nothing was ever saved.
  String? get lastKnownLine {
    final k = lastKnown;
    if (pos != null || k == null) return null;
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(k.ts));
    final when = age.inMinutes < 60 ? '${age.inMinutes} min ago' : (age.inHours < 48 ? '${age.inHours} h ago' : '${age.inDays} d ago');
    return '${_fmt(k.lat, k.lon)} (last known, $when)';
  }
  String _posLine({bool includeLink = false}) {
    final p = pos;
    if (p == null) {
      final k = lastKnown;
      if (k == null) return 'Position unavailable.';
      return 'My last known position: ${_fmt(k.lat, k.lon)}${includeLink ? ' (https://maps.google.com/?q=${k.lat},${k.lon})' : ''}';
    }
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
  List<ChatTurn> get _history => [for (final m in chat.skip(1)) if (m.text.isNotEmpty) ChatTurn(m.user, m.text)];

  Future<void> send(String text) async {
    text = text.trim();
    final img = attach;
    if ((text.isEmpty && img == null) || typing) return;
    final history = _history;
    chat.add(ChatMsg(user: true, text: text, imagePath: img));
    attach = null;
    typing = true;
    notifyListeners();
    final ai = ChatMsg(user: false, streaming: true);
    try {
      if (img != null) {
        await _answerPhoto(text, img, ai);
      } else {
        await _answerText(text, history, ai);
      }
    } catch (e, st) {
      logError('chat', e, st);
      ai.text = 'Something went wrong on this phone. If this is an emergency, call 112 now.';
      ai.callEmergency = true;
    } finally {
      ai.streaming = false;
      typing = false;
      if (!chat.contains(ai)) chat.add(ai);
      notifyListeners();
    }
  }

  Future<void> _answerText(String text, List<ChatTurn> history, ChatMsg ai) async {
    final a = assistant;
    if (a == null) {
      ai.text = 'The assistant is still starting. If this is an emergency, call 112.';
      ai.callEmergency = true;
      return;
    }
    var lastPaint = 0;
    final r = await a.respond(text, lang: lang, history: history, onPartial: (p) {
      if (!chat.contains(ai)) chat.add(ai);
      ai.text = p;
      typing = false;
      final t = DateTime.now().millisecondsSinceEpoch;
      if (t - lastPaint >= 80) {
        lastPaint = t;
        notifyListeners();
      }
    });
    ai
      ..text = r.text
      ..steps = (r.emergency && r.guideId != null) ? localizedGuide(guideById(r.guideId!), lang).steps.take(5).toList() : r.steps
      ..guide = r.guideId
      ..sources = r.sources
      ..emergency = r.emergency
      ..callEmergency = r.callEmergency
      ..modelUsed = r.modelUsed;
  }

  Future<void> _answerPhoto(String text, String path, ChatMsg ai) async {
    final a = assistant;
    if (a == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      final r = await a.assessImage(bytes, lang: lang, note: text);
      applyAssessment(ai, r);
    } on LlmUnavailable {
      ai.text = 'To look at photos I need Gemma on this phone. Open Profile, then Offline AI, to download it. For now, describe what you see in words and I will help from the approved first-aid guides.';
    }
  }

  /// Turns a vision result into a chat answer. Steps come from the approved protocol, not from the model.
  void applyAssessment(ChatMsg ai, ImageAssessment r) {
    final b = StringBuffer();
    if (r.features.isEmpty) {
      b.write('I could not make out enough in this photo to describe it. Try again in better light, closer to the area, and hold the phone steady.');
    } else {
      b.write('In the photo I can see: ${r.features.join('; ')}.');
      if (r.quality != 'good') b.write(' The photo is not very clear, so please take this with caution.');
      if (r.cannotTell.isNotEmpty) b.write(' I cannot judge ${r.cannotTell.join(', ')} from a photo.');
    }
    b.write(' This is not a diagnosis.');
    if (r.urgentSigns) b.write(' Urgent signs may be present. Get medical help now.');
    ai
      ..text = b.toString()
      ..guide = r.guideId
      ..steps = r.guideId == null ? const [] : localizedGuide(guideById(r.guideId!), lang).steps.take(3).toList()
      ..sources = r.sources
      ..emergency = r.urgentSigns
      ..callEmergency = r.urgentSigns
      ..modelUsed = r.modelUsed;
  }

  void setAttach(String? p) { attach = p; notifyListeners(); }

  /// Saves the typed symptoms of this conversation as a note a health worker can read. Only when the user allows it.
  Future<bool> saveHealthNotes() async {
    if (priv['sessions'] != true || sessions == null) {
      toast('Turn on "Save health sessions" in Profile first');
      return false;
    }
    final turns = _history;
    if (!turns.any((t) => t.user)) return false;
    await sessions!.save(VanaAssistant.healthSummary(turns));
    toast('Health notes saved on this phone');
    return true;
  }

  String get healthNotesText => VanaAssistant.healthSummary(_history);

  // ---------------------------------------------------------------- forecast snapshot
  /// Last saved forecast (one entry per day), kept so it can be read with no signal.
  Forecast? forecast;
  bool forecastBusy = false;

  /// Downloads a 3-day forecast for the current position from Open-Meteo (no account needed) and saves it on the phone.
  Future<void> saveForecast({http.Client? client}) async {
    final p = pos;
    if (p == null) { toast('Waiting for a GPS fix first'); return; }
    forecastBusy = true;
    notifyListeners();
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': p.latitude.toStringAsFixed(3),
        'longitude': p.longitude.toStringAsFixed(3),
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max',
        'timezone': 'auto',
        'forecast_days': '3',
      });
      final r = await (client ?? http.Client()).get(uri).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw const HttpException('bad status');
      final f = Forecast.fromOpenMeteo(jsonDecode(r.body) as Map, DateTime.now());
      forecast = f;
      await _prefs?.setString('forecast', jsonEncode(f.toJson()));
      toast('Forecast saved for offline use');
    } catch (e) {
      logError('forecast', e);
      toast('Could not get the forecast. You need a connection to save one.');
    } finally {
      forecastBusy = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- offline maps & data control
  Future<void> addRegion(OfflineRegion r) async {
    await regions?.upsert(r);
    offlineRegions = await regions?.all() ?? offlineRegions;
    notifyListeners();
  }

  Future<void> removeRegion(OfflineRegion r) async {
    await regions?.delete(r.id);
    try {
      final f = File(r.path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      logError('region', e);
    }
    offlineRegions = await regions?.all() ?? offlineRegions;
    notifyListeners();
  }

  OfflineRegion? get regionHere {
    final p = pos;
    if (p == null) return offlineRegions.isEmpty ? null : offlineRegions.first;
    for (final r in offlineRegions) {
      if (r.covers(p.latitude, p.longitude)) return r;
    }
    return null;
  }

  /// "Delete all my data": profile, contacts, events, trips, health notes, chat and settings. The AI model stays installed.
  Future<void> deleteAllData() async {
    await clearTrip();
    try {
      await sessions?.deleteAll();
      await db?.wipe();
      await _secure.delete(key: 'vana.care.profile');
      final keep = {'lang', 'theme', 'gemma.installed'};
      for (final k in (_prefs?.getKeys() ?? <String>{}).where((k) => !keep.contains(k)).toList()) {
        await _prefs?.remove(k);
      }
    } catch (e) {
      logError('delete', e);
    }
    lastKnown = null;
    profile = const Profile();
    contacts = [];
    events = [];
    chat
      ..clear()
      ..add(ChatMsg(user: false, text: "I'm Vana. I run fully on this phone, so no signal is needed. What's happening?"));
    guideChecked = {};
    lostChk = {};
    checkin = false;
    notifyListeners();
    toast('All your data was deleted from this phone');
  }
}
