import 'dart:async';
import 'dart:typed_data';
import 'package:vana_care/ai/llm.dart';

class FakeLlm implements LlmBackend {
  FakeLlm({this.ready = true, this.reply = '', this.fail = false});
  bool ready;
  String reply;
  bool fail;
  final prompts = <String>[];
  @override
  bool get isReady => ready;
  @override
  Stream<String> generate({required String system, required String prompt, Uint8List? image, int maxOutputTokens = 400}) async* {
    prompts.add(prompt);
    if (fail) throw const LlmUnavailable('boom');
    for (final w in reply.split(' ')) {
      yield '$w ';
    }
  }
}
