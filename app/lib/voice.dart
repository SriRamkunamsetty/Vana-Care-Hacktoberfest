import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'core/log.dart';

const _stt = {'en': 'en_IN', 'te': 'te_IN', 'hi': 'hi_IN'};
const _tts = {'en': 'en-IN', 'te': 'te-IN', 'hi': 'hi-IN'};

enum ListenState { idle, listening, done, unavailable }

/// Speech in and out. Recognition asks the phone's recogniser to stay on-device first and
/// only falls back to the default recogniser (which may use the network) if no offline
/// language pack is installed. [usedNetworkFallback] lets the UI tell the user.
class VoiceService {
  final SpeechToText _recognizer = SpeechToText();
  final FlutterTts _speaker = FlutterTts();
  bool _ready = false;
  bool usedNetworkFallback = false;
  String lastError = '';

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _recognizer.initialize(onError: (e) => lastError = e.errorMsg, debugLogging: false);
    } catch (e) {
      logError('voice', e);
      _ready = false;
    }
    return _ready;
  }

  bool get isListening => _recognizer.isListening;

  /// Starts listening. [onText] receives partial text; [onDone] is called once with the final text ('' if nothing was heard).
  Future<void> listen({required String lang, required void Function(String text) onText, required void Function(String text) onDone, void Function()? onUnavailable}) async {
    if (!await init()) {
      onUnavailable?.call();
      return;
    }
    usedNetworkFallback = false;
    var delivered = false;
    String last = '';
    void finish() {
      if (delivered) return;
      delivered = true;
      onDone(last);
    }

    Future<void> start({required bool onDevice}) => _recognizer.listen(
          onResult: (r) {
            last = r.recognizedWords;
            onText(last);
            if (r.finalResult) finish();
          },
          listenOptions: SpeechListenOptions(localeId: _stt[lang] ?? 'en_IN', onDevice: onDevice, partialResults: true, cancelOnError: true, listenMode: ListenMode.dictation, pauseFor: const Duration(seconds: 3), listenFor: const Duration(seconds: 30)),
        );

    lastError = '';
    try {
      await start(onDevice: true);
      // An offline language pack that is not installed fails almost immediately.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!_recognizer.isListening && lastError.isNotEmpty && !delivered) {
        usedNetworkFallback = true;
        lastError = '';
        await start(onDevice: false);
      }
    } catch (e) {
      logError('voice', e);
      onUnavailable?.call();
      return;
    }
    // Safety net: if the engine ends without a final result, still hand back what we heard.
    Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (delivered) {
        t.cancel();
      } else if (!_recognizer.isListening) {
        t.cancel();
        finish();
      }
    });
  }

  Future<void> stopListening() async {
    try {
      await _recognizer.stop();
    } catch (_) {}
  }

  Future<void> speak(String text, String lang) async {
    try {
      await _speaker.setLanguage(_tts[lang] ?? 'en-IN');
      await _speaker.setSpeechRate(0.45);
      await _speaker.speak(text);
    } catch (e) {
      logError('tts', e);
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _speaker.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
  }
}
