import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vana_care/ai/assistant.dart';
import 'package:vana_care/ai/knowledge.dart';
import 'package:vana_care/ai/llm.dart';
import 'helpers.dart';
import 'package:vana_care/core/db.dart';
import 'package:vana_care/data.dart';
import 'package:vana_care/data/repositories.dart';
import 'package:vana_care/domain/safety.dart';

Future<(AppDatabase, KnowledgeBase)> _kb() async {
  final db = await AppDatabase.open(path: inMemoryDatabasePath);
  final kb = KnowledgeBase(db);
  await kb.load(extra: const [
    KnowledgeChunk(id: 'doc:ors', docId: 'ors', title: 'Diarrhoea and oral rehydration', text: 'Sip oral rehydration solution often in small amounts.', source: 'test', version: '1'),
    KnowledgeChunk(id: 'doc:lost', docId: 'lost', title: 'Lost in the forest', text: 'Stop moving, sit down, use a whistle three blasts.', source: 'test', version: '1'),
  ]);
  return (db, kb);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SafetyEngine', () {
    const s = SafetyEngine();
    test('routes English emergencies to protocols', () {
      expect(s.assess('He is bleeding badly from a deep cut').protocolId, 'bleeding');
      expect(s.assess('I got bitten by a snake').protocolId, 'bites');
      expect(s.assess("she is not breathing").primary!.id, 'not_breathing');
      expect(s.assess('my friend is choking').protocolId, 'choking');
      expect(s.assess('I feel very cold and shivering').protocolId, 'hypothermia');
    });
    test('life threats outrank minor matches', () {
      final d = s.assess('he fell, broke his ankle and is unconscious');
      expect(d.primary!.id, 'not_breathing');
      expect(d.callEmergency, isTrue);
      expect(d.ruleIds, contains('fracture'));
    });
    test('works in Hindi and Telugu', () {
      expect(s.assess('उसे साँप ने काटा है').protocolId, 'bites');
      expect(s.assess('खून बह रहा है').protocolId, 'bleeding');
      expect(s.assess('నాకు పాము కరిచింది').protocolId, 'bites');
      expect(s.assess('రక్తం కారుతోంది').protocolId, 'bleeding');
    });
    test('chest pain escalates without a protocol', () {
      final d = s.assess('I have chest pain');
      expect(d.isEmergency, isTrue);
      expect(d.callEmergency, isTrue);
      expect(d.protocolId, isNull);
    });
    test('does not fire on unrelated text', () {
      expect(s.assess('how do I pack a rucksack for a website demo').isEmergency, isFalse);
    });
    test('sanitize removes doses and definite diagnoses', () {
      final r = s.sanitize('Rest in the shade. Take 500 mg paracetamol every six hours. You have a fracture of the wrist. Drink water.');
      expect(r.changed, isTrue);
      expect(r.text, contains('Rest in the shade.'));
      expect(r.text, contains('Drink water.'));
      expect(r.text.toLowerCase(), isNot(contains('paracetamol')));
      expect(r.text.toLowerCase(), isNot(contains('fracture')));
    });
    test('sanitize leaves safe text alone', () {
      final r = s.sanitize('Keep the limb still. Call 112.');
      expect(r.changed, isFalse);
    });
  });

  group('every protocol is governed', () {
    test('has version, source, steps and a red-flag line', () {
      for (final g in guides) {
        expect(g.version, isNotEmpty);
        expect(g.source, isNotEmpty);
        expect(g.steps.length, greaterThanOrEqualTo(4), reason: g.id);
        expect(g.warn, isNotEmpty);
      }
    });
    test('every safety rule protocol exists', () {
      for (final r in SafetyEngine.rules) {
        if (r.protocolId != null) expect(guides.any((g) => g.id == r.protocolId), isTrue, reason: r.id);
      }
    });
  });

  group('KnowledgeBase', () {
    test('retrieves the right protocol and doc', () async {
      final (db, kb) = await _kb();
      expect(kb.search('severe bleeding from a cut').first.chunk.id, 'protocol:bleeding');
      expect(kb.search('how to rehydrate with oral rehydration').first.chunk.docId, 'ors');
      expect(kb.search('I am lost and need a whistle').first.chunk.docId, 'lost');
      await db.close();
    });
    test('returns nothing for gibberish', () async {
      final (db, kb) = await _kb();
      expect(kb.search('zzxqv plorb'), isEmpty);
      await db.close();
    });
    test('persists chunks with version and source', () async {
      final (db, _) = await _kb();
      final rows = await db.db.query('knowledge_chunk', where: "id = 'protocol:bleeding'");
      expect(rows.single['version'], isNotEmpty);
      expect(rows.single['source'], isNotEmpty);
      await db.close();
    });
  });

  group('VanaAssistant', () {
    test('emergency: steps come from the protocol even if the model misbehaves', () async {
      final (db, kb) = await _kb();
      final llm = FakeLlm(reply: 'Take 500 mg ibuprofen. Stay calm and press on the wound.');
      final r = await VanaAssistant(kb: kb, llm: llm).respond('he is bleeding badly');
      expect(r.emergency, isTrue);
      expect(r.callEmergency, isTrue);
      expect(r.guideId, 'bleeding');
      expect(r.steps, guideById('bleeding').steps.take(5).toList());
      expect(r.text.toLowerCase(), isNot(contains('ibuprofen')));
      expect(r.text, contains('Stay calm'));
      await db.close();
    });
    test('no model installed: answers from approved content, never improvised', () async {
      final (db, kb) = await _kb();
      final r = await VanaAssistant(kb: kb, llm: FakeLlm(ready: false)).respond('I have diarrhoea, what should I do about oral rehydration');
      expect(r.modelUsed, isFalse);
      expect(r.text, contains('oral rehydration'));
      expect(r.sources, isNotEmpty);
      await db.close();
    });
    test('model failure degrades to approved content', () async {
      final (db, kb) = await _kb();
      final r = await VanaAssistant(kb: kb, llm: FakeLlm(fail: true)).respond('snake bite');
      expect(r.modelUsed, isFalse);
      expect(r.steps, isNotEmpty);
      await db.close();
    });
    test('grounds the prompt in retrieved context and cites sources', () async {
      final (db, kb) = await _kb();
      final llm = FakeLlm(reply: 'Sip the solution often.');
      final r = await VanaAssistant(kb: kb, llm: llm).respond('oral rehydration for diarrhoea');
      expect(llm.prompts.single, contains('CONTEXT:'));
      expect(llm.prompts.single, contains('Sip oral rehydration solution'));
      expect(r.sources.first.title, contains('rehydration'));
      expect(r.modelUsed, isTrue);
      await db.close();
    });
    test('streams sanitized partials', () async {
      final (db, kb) = await _kb();
      final seen = <String>[];
      await VanaAssistant(kb: kb, llm: FakeLlm(reply: 'Rest now. Take 200 mg aspirin. Drink water.')).respond('oral rehydration', onPartial: seen.add);
      expect(seen, isNotEmpty);
      expect(seen.every((p) => !p.toLowerCase().contains('aspirin')), isTrue);
      await db.close();
    });
    test('unknown question without a model asks for details', () async {
      final (db, kb) = await _kb();
      final r = await VanaAssistant(kb: kb, llm: FakeLlm(ready: false)).respond('qwerty asdf');
      expect(r.text, contains('112'));
      await db.close();
    });
  });

  group('image assessment parsing', () {
    test('parses JSON wrapped in prose', () async {
      final (db, kb) = await _kb();
      final a = VanaAssistant.parseAssessment('Here you go: {"quality":"good","visible_features":["open wound on forearm with bleeding"],"cannot_tell":["depth"],"urgent_signs_visible":false} done', const SafetyEngine(), kb);
      expect(a.quality, 'good');
      expect(a.features, hasLength(1));
      expect(a.guideId, 'bleeding');
      expect(a.urgentSigns, isTrue); // safety rule overrides the model's "false"
      await db.close();
    });
    test('malformed output degrades to unclear, never invents', () async {
      final (db, kb) = await _kb();
      final a = VanaAssistant.parseAssessment('I think this is a nasty infection!', const SafetyEngine(), kb);
      expect(a.features, isEmpty);
      expect(a.quality, isNot('good'));
      await db.close();
    });
    test('assessImage requires a model', () async {
      final (db, kb) = await _kb();
      expect(VanaAssistant(kb: kb, llm: FakeLlm(ready: false)).assessImage(Uint8List(1)), throwsA(isA<LlmUnavailable>()));
      await db.close();
    });
  });

  group('repositories', () {
    test('trip survives and reloads points', () async {
      final db = await AppDatabase.open(path: inMemoryDatabasePath);
      final repo = TripRepository(db);
      final t = await repo.start('Morning trek');
      await repo.addPoint(t.id, const RoutePoint(17.0, 78.0, 1));
      await repo.addPoint(t.id, const RoutePoint(17.1, 78.1, 2));
      expect((await repo.active())!.id, t.id);
      expect(await repo.points(t.id), hasLength(2));
      await repo.finish(t.id);
      expect(await repo.active(), isNull);
      await db.close();
    });
    test('health sessions can be saved and deleted', () async {
      final db = await AppDatabase.open(path: inMemoryDatabasePath);
      final repo = HealthSessionRepository(db);
      final id = await repo.save('Headache since morning', symptoms: const [SymptomEntry('headache', duration: '1 day')]);
      expect(await repo.all(), hasLength(1));
      await repo.delete(id);
      expect(await repo.all(), isEmpty);
      await db.close();
    });
    test('offline region coverage', () {
      const r = OfflineRegion(id: 'a', name: 'A', version: '1', path: 'x', size: 1, minLat: 10, minLon: 70, maxLat: 20, maxLon: 80);
      expect(r.covers(15, 75), isTrue);
      expect(r.covers(25, 75), isFalse);
    });
  });
}
