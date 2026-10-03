import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../core/log.dart';
import '../data.dart';
import '../domain/safety.dart';
import 'knowledge.dart';
import 'llm.dart';

class AssistantSource {
  final String title, source, version;
  const AssistantSource(this.title, this.source, this.version);
}

class AssistantReply {
  final String text;
  final List<String> steps;
  final String? guideId;
  final List<AssistantSource> sources;

  /// A deterministic safety rule fired. The UI must show the emergency actions.
  final bool emergency, callEmergency;
  final List<String> ruleIds;

  /// True when Gemma wrote [text]. False means the answer came straight from approved content.
  final bool modelUsed;
  const AssistantReply({required this.text, this.steps = const [], this.guideId, this.sources = const [], this.emergency = false, this.callEmergency = false, this.ruleIds = const [], this.modelUsed = false});
}

class ChatTurn {
  final bool user;
  final String text;
  const ChatTurn(this.user, this.text);
}

class ImageAssessment {
  final String quality; // good | poor | unusable
  final List<String> features, cannotTell;
  final bool urgentSigns, modelUsed;
  final String? guideId;
  final List<AssistantSource> sources;
  const ImageAssessment({required this.quality, required this.features, required this.cannotTell, required this.urgentSigns, required this.modelUsed, this.guideId, this.sources = const []});
}

const languageNames = {'en': 'English', 'hi': 'Hindi (हिन्दी)', 'te': 'Telugu (తెలుగు)'};

/// Per-task prompts. Kept separate on purpose: one small prompt per job (blueprint section 7).
class Prompts {
  static String health(String lang) => '''You are Vana, an offline first-aid and field-health assistant on a phone with no internet.
Rules you must always follow:
- Use ONLY the facts in CONTEXT. If CONTEXT does not cover the question, say you do not have approved guidance for it and advise seeing a health worker or calling 112.
- Never diagnose. Never name a drug or give a dose. Never invent treatments.
- If anything sounds life-threatening, start by telling the user to call 112.
- If you need more information to help safely, ask at most two short questions (who is affected, how long, how severe, awake and breathing) instead of guessing.
- Use short, plain sentences, at most 90 words. No markdown, no lists.
- Reply in ${languageNames[lang] ?? 'English'}.''';

  static String emergency(String lang) => '''You are Vana, an offline first-aid assistant. A safety rule has detected an emergency and the approved steps are shown to the user separately.
Write at most two calm, short sentences in ${languageNames[lang] ?? 'English'} telling the person to act now and to call 112 if the situation is serious. Do not list steps, do not diagnose, do not mention drugs or doses.''';

  static const translate = 'Translate the user message into a short English phrase of the key health or safety words. Output only the English words, nothing else.';

  static String vision(String lang) => '''You inspect a photo for a first-aid app. You are NOT a doctor and must never diagnose.
Return ONLY a JSON object with these keys:
{"quality":"good|poor|unusable","visible_features":["short plain description of what is visibly there, e.g. colour, size estimate, bleeding, swelling, wound edges"],"cannot_tell":["things that cannot be judged from a photo"],"urgent_signs_visible":true|false}
Describe only what is visible. Write the strings in ${languageNames[lang] ?? 'English'}.''';

  static String context(List<Retrieved> hits) => [for (var i = 0; i < hits.length; i++) '[${i + 1}] ${hits[i].chunk.title}: ${hits[i].chunk.text}'].join('\n');

  static String question(String q, List<ChatTurn> history, List<Retrieved> hits) {
    final h = history.length > 4 ? history.sublist(history.length - 4) : history;
    final b = StringBuffer();
    if (h.isNotEmpty) {
      b.writeln('CONVERSATION SO FAR:');
      for (final t in h) {
        b.writeln('${t.user ? 'User' : 'Vana'}: ${t.text}');
      }
      b.writeln();
    }
    b.writeln('CONTEXT:');
    b.writeln(hits.isEmpty ? '(no approved guidance found)' : context(hits));
    b.writeln();
    b.writeln('QUESTION: $q');
    return b.toString();
  }
}

/// The full pipeline: safety rules -> local retrieval -> Gemma -> output validation.
/// Gemma only phrases and explains. Emergency steps always come from the approved protocol.
class VanaAssistant {
  VanaAssistant({required this.kb, required this.llm, this.safety = const SafetyEngine()});
  final KnowledgeBase kb;
  final LlmBackend llm;
  final SafetyEngine safety;

  Future<AssistantReply> respond(String text, {String lang = 'en', List<ChatTurn> history = const [], void Function(String partial)? onPartial}) async {
    final decision = safety.assess(text);
    final protocol = decision.protocolId == null ? null : guideById(decision.protocolId!);

    var hits = <Retrieved>[];
    if (protocol != null) {
      final c = kb.byProtocol(protocol.id);
      if (c != null) hits.add(Retrieved(c, 100));
    }
    hits = _merge(hits, kb.search(text, k: 3));
    if (hits.isEmpty && lang != 'en' && llm.isReady) {
      final en = await _translate(text);
      if (en != null) hits = _merge(hits, kb.search(en, k: 3));
    }
    final sources = [for (final h in hits.take(3)) AssistantSource(h.chunk.title, h.chunk.source, h.chunk.version)];
    final guideId = protocol?.id ?? _protocolHit(hits);

    String? generated;
    if (llm.isReady) {
      try {
        generated = await _generate(
          system: decision.isEmergency ? Prompts.emergency(lang) : Prompts.health(lang),
          prompt: decision.isEmergency ? text : Prompts.question(text, history, hits.take(3).toList()),
          onPartial: onPartial,
        );
      } catch (e) {
        logError('assistant', e);
      }
    }

    final steps = decision.isEmergency && protocol != null ? protocol.steps.take(5).toList() : const <String>[];
    final modelUsed = generated != null && generated.isNotEmpty;
    final body = modelUsed ? generated : _fallbackText(decision, protocol, hits, lang);
    return AssistantReply(
      text: body,
      steps: steps,
      guideId: guideId,
      sources: sources,
      emergency: decision.isEmergency,
      callEmergency: decision.callEmergency,
      ruleIds: decision.ruleIds,
      modelUsed: modelUsed,
    );
  }

  List<Retrieved> _merge(List<Retrieved> a, List<Retrieved> b) {
    final seen = {for (final r in a) r.chunk.id};
    return [...a, for (final r in b) if (seen.add(r.chunk.id)) r];
  }

  String? _protocolHit(List<Retrieved> hits) {
    for (final h in hits) {
      if (h.chunk.id.startsWith('protocol:') && h.score >= 2) return h.chunk.docId;
    }
    return null;
  }

  Future<String?> _translate(String text) async {
    try {
      final b = StringBuffer();
      await for (final t in llm.generate(system: Prompts.translate, prompt: text, maxOutputTokens: 40)) {
        b.write(t);
      }
      final s = b.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  Future<String> _generate({required String system, required String prompt, void Function(String)? onPartial}) async {
    final buf = StringBuffer();
    await for (final t in llm.generate(system: system, prompt: prompt, maxOutputTokens: 220)) {
      buf.write(t);
      if (onPartial != null) onPartial(safety.sanitize(buf.toString()).text);
    }
    final clean = safety.sanitize(buf.toString());
    return clean.text.replaceAll(RegExp(r'[*#`]+'), '').trim();
  }

  /// Offline answer with no model: the approved content itself, never improvised text.
  String _fallbackText(SafetyDecision d, Guide? protocol, List<Retrieved> hits, String lang) {
    if (d.isEmergency) {
      final call = d.callEmergency ? ' Call 112 now if you can.' : '';
      return protocol != null ? 'This sounds serious. Follow the steps for "${protocol.title}" below.$call' : 'This may be a medical emergency.$call Stay with the person and keep them calm.';
    }
    if (hits.isNotEmpty) {
      final c = hits.first.chunk;
      return '${c.title}: ${_firstSentences(c.text, 420)}';
    }
    return 'I do not have approved guidance for that. Tell me who is hurt, what happened, and whether they are awake and breathing, or call 112 for urgent help.';
  }

  static String _firstSentences(String s, int max) {
    if (s.length <= max) return s;
    final cut = s.lastIndexOf('. ', max);
    return cut > 80 ? s.substring(0, cut + 1) : '${s.substring(0, max)}...';
  }

  // ---------------------------------------------------------------- vision
  /// Summarises visible features of a photo. Never diagnoses. Throws [LlmUnavailable] when no model is installed.
  Future<ImageAssessment> assessImage(Uint8List bytes, {String lang = 'en', String note = ''}) async {
    if (!llm.isReady) throw const LlmUnavailable('Gemma is not installed');
    final buf = StringBuffer();
    await for (final t in llm.generate(system: Prompts.vision(lang), prompt: note.trim().isEmpty ? 'Describe what is visible in this photo.' : 'Describe what is visible. The user says: $note', image: bytes, maxOutputTokens: 320)) {
      buf.write(t);
    }
    return parseAssessment(buf.toString(), safety, kb);
  }

  /// Parses the model's JSON leniently. A malformed answer degrades to "unclear", never to made-up content.
  static ImageAssessment parseAssessment(String raw, SafetyEngine safety, KnowledgeBase kb) {
    var quality = 'poor';
    var features = <String>[];
    var cannot = <String>[];
    var urgent = false;
    final a = raw.indexOf('{'), b = raw.lastIndexOf('}');
    if (a >= 0 && b > a) {
      try {
        final j = jsonDecode(raw.substring(a, b + 1)) as Map;
        final q = (j['quality'] as String?)?.toLowerCase();
        if (q == 'good' || q == 'poor' || q == 'unusable') quality = q!;
        features = [for (final f in (j['visible_features'] as List? ?? const [])) f.toString().trim()].where((s) => s.isNotEmpty).toList();
        cannot = [for (final f in (j['cannot_tell'] as List? ?? const [])) f.toString().trim()].where((s) => s.isNotEmpty).toList();
        urgent = j['urgent_signs_visible'] == true;
      } catch (_) {}
    }
    if (features.isEmpty) quality = quality == 'good' ? 'poor' : quality;
    final joined = features.join('. ');
    final decision = safety.assess(joined);
    final hits = kb.search(joined, k: 2);
    String? guide = decision.protocolId;
    if (guide == null) {
      for (final h in hits) {
        if (h.chunk.id.startsWith('protocol:') && h.score >= 2) {
          guide = h.chunk.docId;
          break;
        }
      }
    }
    return ImageAssessment(
      quality: quality,
      features: features,
      cannotTell: cannot,
      urgentSigns: urgent || decision.isEmergency,
      modelUsed: true,
      guideId: guide,
      sources: [for (final h in hits) AssistantSource(h.chunk.title, h.chunk.source, h.chunk.version)],
    );
  }

  /// Plain-text summary a person can show a health worker. Built from what the user typed, with no model involved.
  static String healthSummary(List<ChatTurn> turns, {DateTime? now}) {
    final user = [for (final t in turns) if (t.user && t.text.trim().isNotEmpty) t.text.trim()];
    final d = (now ?? DateTime.now());
    final stamp = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'Vana Care health notes ($stamp)\nReported by the user:\n${user.map((e) => '- $e').join('\n')}\nThese notes are not a diagnosis.';
  }
}
