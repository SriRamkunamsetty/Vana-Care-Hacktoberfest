import 'dart:typed_data';

/// The seam between the safety-checked assistant pipeline and an inference engine.
/// Production uses [GemmaModelManager]; tests use a fake.
abstract class LlmBackend {
  bool get isReady;

  /// Streams generated text. [image] is JPEG/PNG bytes for vision tasks.
  /// Throws [LlmUnavailable] when no model can run.
  Stream<String> generate({required String system, required String prompt, Uint8List? image, int maxOutputTokens = 400});
}

class LlmUnavailable implements Exception {
  final String reason;
  const LlmUnavailable(this.reason);
  @override
  String toString() => 'LlmUnavailable: $reason';
}
