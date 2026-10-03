import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vana_care/ai/assistant.dart';
import 'package:vana_care/core/db.dart';
import 'package:vana_care/data.dart';
import 'package:vana_care/data_i18n.dart';
import 'package:vana_care/state.dart';
import 'helpers.dart';

Future<AppState> _app(FakeLlm llm) async {
  SharedPreferences.setMockInitialValues({});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (c) async => null);
  final db = await AppDatabase.open(path: inMemoryDatabasePath);
  final st = AppState(llm: llm, database: db);
  await st.init();
  return st;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('chat pipeline in AppState', () {
    test('emergency message produces protocol steps and a call-112 flag', () async {
      final st = await _app(FakeLlm(reply: 'Stay calm and press on the wound.'));
      await st.send('he is bleeding badly');
      final ai = st.chat.last;
      expect(ai.user, isFalse);
      expect(ai.emergency, isTrue);
      expect(ai.callEmergency, isTrue);
      expect(ai.steps, hasLength(5));
      expect(ai.guide, 'bleeding');
      expect(ai.streaming, isFalse);
      expect(st.typing, isFalse);
    });

    test('Hindi emergency shows Hindi steps', () async {
      final st = await _app(FakeLlm(ready: false));
      st.lang = 'hi';
      await st.send('उसे साँप ने काटा है');
      expect(st.chat.last.guide, 'bites');
      expect(st.chat.last.steps.first, guideTranslations['hi']!['bites']!.steps.first);
    });

    test('works with no model installed (approved content only)', () async {
      final st = await _app(FakeLlm(ready: false));
      await st.send('how do I treat hypothermia');
      expect(st.chat.last.modelUsed, isFalse);
      expect(st.chat.last.text, isNotEmpty);
    });

    test('photo question without a model explains how to enable it and never fakes an analysis', () async {
      final st = await _app(FakeLlm(ready: false));
      st.setAttach('/nonexistent.jpg');
      await st.send('what is this');
      expect(st.chat.last.text, anyOf(contains('Gemma'), contains('went wrong')));
      expect(st.chat.last.text.toLowerCase(), isNot(contains('i can see')));
    });

    test('vision result becomes protocol-backed steps and says it is not a diagnosis', () async {
      final st = await _app(FakeLlm());
      final ai = ChatMsg(user: false);
      st.applyAssessment(
          ai,
          const ImageAssessment(quality: 'good', features: ['open wound, bleeding'], cannotTell: ['depth'], urgentSigns: true, modelUsed: true, guideId: 'bleeding'));
      expect(ai.text, contains('not a diagnosis'));
      expect(ai.steps, hasLength(3));
      expect(ai.callEmergency, isTrue);
    });

    test('health notes are only saved when the user allows it', () async {
      final st = await _app(FakeLlm(ready: false));
      await st.send('I have had a headache since morning');
      st.priv['sessions'] = false;
      expect(await st.saveHealthNotes(), isFalse);
      st.priv['sessions'] = true;
      expect(await st.saveHealthNotes(), isTrue);
      expect(await st.sessions!.all(), hasLength(1));
    });
  });

  group('delete all data', () {
    test('clears profile, contacts, chat and trips', () async {
      final st = await _app(FakeLlm(ready: false));
      await st.saveProfile(const Profile(name: 'Asha', blood: 'O+'));
      await st.saveContact(const Contact(1, 'Ravi', 'Family', '+919999999999'));
      await st.send('snake bite');
      await st.setRecording(true);
      await st.setRecording(false);
      await st.deleteAllData();
      expect(st.profile.name, isEmpty);
      expect(st.contacts, isEmpty);
      expect(st.chat, hasLength(1));
      expect(st.tripId, isNull);
      expect(await st.trips!.all(), isEmpty);
    });
  });

  group('forecast', () {
    test('parses an Open-Meteo daily payload', () {
      final f = Forecast.fromOpenMeteo({
        'daily': {
          'time': ['2026-10-02', '2026-10-03'],
          'temperature_2m_max': [31.2, 29.0],
          'temperature_2m_min': [22.1, 21.0],
          'precipitation_sum': [0.0, 12.4],
          'wind_speed_10m_max': [14.0, 20.5],
        }
      }, DateTime(2026, 10, 2));
      expect(f.days, hasLength(2));
      expect(f.days[1].rain, 12.4);
      expect(Forecast.fromJson(f.toJson()).days.first.tMax, 31.2);
    });
  });

  group('translations', () {
    test('every guide has Hindi and Telugu with the same number of steps', () {
      for (final lang in ['hi', 'te']) {
        for (final g in guides) {
          final tr = guideTranslations[lang]![g.id];
          expect(tr, isNotNull, reason: '$lang ${g.id}');
          expect(tr!.steps.length, g.steps.length, reason: '$lang ${g.id}');
          expect(tr.warn, isNotEmpty);
        }
      }
    });
    test('translations stay marked as unreviewed', () {
      expect(localizedGuide(guides.first, 'hi').reviewed, isFalse);
    });
  });
}
