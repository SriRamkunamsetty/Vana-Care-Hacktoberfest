import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../core/db.dart';
import '../core/log.dart';
import '../data.dart';

class KnowledgeChunk {
  final String id, docId, title, text, lang, source, version;
  const KnowledgeChunk({required this.id, required this.docId, required this.title, required this.text, this.lang = 'en', required this.source, required this.version});

  Map<String, Object?> toRow() => {'id': id, 'doc_id': docId, 'title': title, 'text': text, 'lang': lang, 'source': source, 'version': version};
  factory KnowledgeChunk.fromRow(Map<String, Object?> r) => KnowledgeChunk(
      id: r['id'] as String, docId: r['doc_id'] as String, title: r['title'] as String, text: r['text'] as String,
      lang: r['lang'] as String, source: r['source'] as String, version: r['version'] as String);
}

class Retrieved {
  final KnowledgeChunk chunk;
  final double score;
  const Retrieved(this.chunk, this.score);
}

/// Local retrieval over approved knowledge only (blueprint "Local RAG"). Uses BM25 so it
/// needs no embedding model and works on every device. Chunks are persisted in SQLite
/// with a nullable embedding column so a vector index can be added later.
class KnowledgeBase {
  KnowledgeBase(this._d);
  final AppDatabase _d;
  List<KnowledgeChunk> _chunks = const [];
  final Map<String, Map<String, int>> _tf = {};
  final Map<String, int> _df = {};
  double _avgLen = 1;

  List<KnowledgeChunk> get chunks => _chunks;

  static final _tok = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
  static const _stop = {'the', 'a', 'an', 'is', 'are', 'to', 'of', 'and', 'or', 'in', 'on', 'it', 'for', 'with', 'i', 'my', 'me', 'do', 'what', 'how', 'can', 'should', 'be', 'if', 'you', 'this', 'that', 'has', 'have', 'was', 'not', 'at', 'as'};

  static List<String> tokenize(String s) => [
        for (final m in _tok.allMatches(s.toLowerCase()))
          if (!_stop.contains(m.group(0)) && m.group(0)!.length > 1) _stem(m.group(0)!)
      ];

  static String _stem(String w) {
    if (w.length > 5 && w.endsWith('ing')) return w.substring(0, w.length - 3);
    if (w.length > 4 && w.endsWith('es')) return w.substring(0, w.length - 2);
    if (w.length > 3 && w.endsWith('s')) return w.substring(0, w.length - 1);
    return w;
  }

  /// Chunks derived from the built-in first-aid protocols.
  static List<KnowledgeChunk> fromGuides() => [
        for (final g in guides)
          KnowledgeChunk(
            id: 'protocol:${g.id}',
            docId: g.id,
            title: g.title,
            text: '${g.title}. ${g.sub}. Steps: ${[for (var i = 0; i < g.steps.length; i++) '${i + 1}. ${g.steps[i]}'].join(' ')} Get urgent medical help if ${g.warn}',
            source: g.source,
            version: g.version,
          ),
      ];

  static List<KnowledgeChunk> parseDocs(String json) => [
        for (final d in jsonDecode(json) as List)
          KnowledgeChunk(id: 'doc:${d['id']}', docId: d['id'] as String, title: d['title'] as String, text: d['text'] as String, lang: d['lang'] as String? ?? 'en', source: d['source'] as String, version: d['version'] as String)
      ];

  /// Loads the bundled pack into SQLite (replacing older versions) and builds the index.
  Future<void> load({AssetBundle? bundle, List<KnowledgeChunk>? extra}) async {
    final all = [...fromGuides(), ...?extra];
    if (extra == null) {
      try {
        all.addAll(parseDocs(await (bundle ?? rootBundle).loadString('assets/knowledge/field_guide.json')));
      } catch (e) {
        logError('kb', e);
      }
    }
    final b = _d.db.batch()..delete('knowledge_chunk');
    for (final c in all) {
      b.insert('knowledge_chunk', c.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
    _index((await _d.db.query('knowledge_chunk')).map(KnowledgeChunk.fromRow).toList());
    logInfo('kb', 'indexed ${_chunks.length} chunks');
  }

  void _index(List<KnowledgeChunk> cs) {
    _chunks = cs;
    _tf.clear();
    _df.clear();
    var total = 0;
    for (final c in cs) {
      final toks = tokenize('${c.title} ${c.title} ${c.text}');
      total += toks.length;
      final m = <String, int>{};
      for (final t in toks) {
        m[t] = (m[t] ?? 0) + 1;
      }
      _tf[c.id] = m;
      for (final t in m.keys) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
    _avgLen = cs.isEmpty ? 1 : total / cs.length;
  }

  List<Retrieved> search(String query, {int k = 3, double minScore = 0.5}) {
    final q = tokenize(query).toSet();
    if (q.isEmpty || _chunks.isEmpty) return const [];
    final n = _chunks.length;
    const k1 = 1.4, b = 0.75;
    final out = <Retrieved>[];
    for (final c in _chunks) {
      final tf = _tf[c.id]!;
      final len = tf.values.fold<int>(0, (a, v) => a + v);
      var score = 0.0;
      for (final t in q) {
        final f = tf[t];
        if (f == null) continue;
        final df = _df[t] ?? 0;
        final idf = math.log(1 + (n - df + 0.5) / (df + 0.5));
        score += idf * (f * (k1 + 1)) / (f + k1 * (1 - b + b * len / _avgLen));
      }
      if (score >= minScore) out.add(Retrieved(c, score));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out.take(k).toList();
  }

  KnowledgeChunk? byProtocol(String id) {
    for (final c in _chunks) {
      if (c.id == 'protocol:$id') return c;
    }
    return null;
  }
}
