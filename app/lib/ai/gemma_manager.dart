import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/log.dart';
import 'llm.dart';

enum GemmaVariant { e2b, e4b }

class GemmaSpec {
  final GemmaVariant variant;
  final String label, url, file;
  final int bytes;

  /// Minimum total device RAM (MB) to run this variant comfortably.
  final int minRamMb;
  const GemmaSpec(this.variant, this.label, this.url, this.file, this.bytes, this.minRamMb);
  String get sizeLabel => '${(bytes / 1e9).toStringAsFixed(1)} GB';
}

const _hf = 'https://huggingface.co/litert-community';

/// Gemma 4 LiteRT-LM bundles (Apache-2.0, not gated). Sizes from the HuggingFace listing.
const gemmaSpecs = <GemmaVariant, GemmaSpec>{
  GemmaVariant.e2b: GemmaSpec(GemmaVariant.e2b, 'Gemma 4 E2B', '$_hf/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm', 'gemma-4-E2B-it.litertlm', 2588147712, 4096),
  GemmaVariant.e4b: GemmaSpec(GemmaVariant.e4b, 'Gemma 4 E4B', '$_hf/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm', 'gemma-4-E4B-it.litertlm', 3659530240, 8000),
};

/// One on-device speed measurement (blueprint section 14: measure on real phones, never promise a universal latency).
class GemmaBenchmark {
  final int loadMs, firstTokenMs, totalMs, chars;
  final String backend;
  const GemmaBenchmark(this.loadMs, this.firstTokenMs, this.totalMs, this.chars, this.backend);
  double get charsPerSecond => totalMs <= firstTokenMs ? 0 : chars / ((totalMs - firstTokenMs) / 1000);
}

enum GemmaStatus { unknown, notInstalled, downloading, installed, loading, loaded, error, unsupported }

/// Downloads, loads and runs Gemma 4 on-device. All inference stays on the phone.
class GemmaModelManager extends ChangeNotifier implements LlmBackend {
  GemmaModelManager({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  GemmaStatus status = GemmaStatus.unknown;
  GemmaVariant? installed;
  GemmaVariant? recommended;
  int ramMb = 0;
  int progress = 0;
  String? error;
  PreferredBackend? activeBackend;
  bool _initialised = false;
  CancelToken? _cancel;
  InferenceModel? _model;
  Future<InferenceModel>? _loading;
  bool _busy = false;

  @override
  bool get isReady => installed != null && status != GemmaStatus.error && status != GemmaStatus.unsupported && status != GemmaStatus.downloading;
  bool get isDownloading => status == GemmaStatus.downloading;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    _prefs = _prefsOverride ?? await SharedPreferences.getInstance();
    try {
      await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()], maxDownloadRetries: 10);
    } catch (e) {
      logError('gemma', e);
    }
    ramMb = await _deviceRamMb();
    recommended = recommend(ramMb);
    final saved = _prefs!.getString('gemma.installed');
    installed = GemmaVariant.values.where((v) => v.name == saved).firstOrNull;
    if (recommended == null && installed == null) {
      status = GemmaStatus.unsupported;
    } else {
      status = installed == null ? GemmaStatus.notInstalled : GemmaStatus.installed;
    }
    notifyListeners();
  }

  /// E4B for >= 8 GB devices, E2B for >= 4 GB, otherwise null (safety-engine and retrieval-only mode).
  static GemmaVariant? recommend(int ramMb) {
    if (ramMb == 0) return GemmaVariant.e2b; // unknown hardware: take the smaller model
    if (ramMb >= gemmaSpecs[GemmaVariant.e4b]!.minRamMb) return GemmaVariant.e4b;
    if (ramMb >= gemmaSpecs[GemmaVariant.e2b]!.minRamMb) return GemmaVariant.e2b;
    return null;
  }

  Future<int> _deviceRamMb() async {
    try {
      if (Platform.isAndroid) return (await DeviceInfoPlugin().androidInfo).physicalRamSize;
    } catch (e) {
      logError('gemma', e);
    }
    return 0;
  }

  Future<bool> onMobileData() async {
    try {
      final c = await Connectivity().checkConnectivity();
      return c.contains(ConnectivityResult.mobile) && !c.contains(ConnectivityResult.wifi) && !c.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  /// Downloads the bundle (resumable, foreground service on Android) and activates it.
  Future<void> install(GemmaVariant v) async {
    if (_busy) return;
    _busy = true;
    final spec = gemmaSpecs[v]!;
    status = GemmaStatus.downloading;
    progress = 0;
    error = null;
    final token = CancelToken();
    _cancel = token;
    notifyListeners();
    try {
      await FlutterGemma.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm)
          .fromNetwork(spec.url, foreground: true)
          .withCancelToken(token)
          .withProgress((p) {
        progress = p;
        notifyListeners();
      }).install();
      installed = v;
      await _prefs?.setString('gemma.installed', v.name);
      status = GemmaStatus.installed;
    } on DownloadException catch (e) {
      error = e.error.toUserMessage();
      status = installed == null ? GemmaStatus.notInstalled : GemmaStatus.installed;
    } catch (e) {
      logError('gemma', e);
      error = token.isCancelled ? 'Download cancelled.' : 'Could not download the model. Check your connection and free storage, then try again.';
      status = installed == null ? GemmaStatus.notInstalled : GemmaStatus.installed;
    } finally {
      _busy = false;
      _cancel = null;
      notifyListeners();
    }
  }

  void cancelInstall() => _cancel?.cancel('User cancelled');

  Future<void> uninstall() async {
    await unload();
    final v = installed;
    if (v != null) {
      try {
        await FlutterGemma.uninstallModel(gemmaSpecs[v]!.file);
        await FlutterGemma.clearActiveInferenceIdentity();
      } catch (e) {
        logError('gemma', e);
      }
    }
    installed = null;
    await _prefs?.remove('gemma.installed');
    status = recommended == null ? GemmaStatus.unsupported : GemmaStatus.notInstalled;
    notifyListeners();
  }

  Future<void> unload() async {
    final m = _model;
    _model = null;
    _loading = null;
    activeBackend = null;
    try {
      await m?.close();
    } catch (e) {
      logError('gemma', e);
    }
    if (installed != null && status == GemmaStatus.loaded) {
      status = GemmaStatus.installed;
      notifyListeners();
    }
  }

  /// Loads the model, preferring the GPU and falling back to CPU. One load is shared by concurrent callers.
  Future<InferenceModel> _acquire() {
    if (_model != null) return Future.value(_model);
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<InferenceModel> _load() async {
    if (installed == null) throw const LlmUnavailable('Gemma is not installed');
    status = GemmaStatus.loading;
    notifyListeners();
    Object? last;
    for (final backend in const [PreferredBackend.gpu, PreferredBackend.cpu]) {
      try {
        final m = await FlutterGemma.getActiveModel(
          maxTokens: 4096,
          preferredBackend: backend,
          supportImage: true,
          maxNumImages: 1,
          // Some Adreno/Metal GPUs mis-copy digits at lower precision; correctness of
          // numbers (coordinates, counts) matters more than prefill speed here.
          activationDataType: ActivationDataType.float32,
        );
        _model = m;
        activeBackend = backend;
        status = GemmaStatus.loaded;
        error = null;
        notifyListeners();
        logInfo('gemma', 'loaded on ${backend.name}');
        return m;
      } catch (e) {
        last = e;
        logError('gemma', e);
      }
    }
    status = GemmaStatus.error;
    error = 'The model could not start on this phone. Free some memory and try again.';
    notifyListeners();
    throw LlmUnavailable('load failed: ${last.runtimeType}');
  }

  /// Times model start-up, time to first token and generation speed with a short fixed prompt.
  Future<GemmaBenchmark> benchmark() async {
    final sw = Stopwatch()..start();
    final alreadyLoaded = _model != null;
    await _acquire();
    final loadMs = alreadyLoaded ? 0 : sw.elapsedMilliseconds;
    sw.reset();
    var first = -1, chars = 0;
    await for (final t in generate(system: 'You are a concise first-aid assistant.', prompt: 'In three short sentences, how do I stop a nosebleed?', maxOutputTokens: 96)) {
      if (first < 0) first = sw.elapsedMilliseconds;
      chars += t.length;
    }
    return GemmaBenchmark(loadMs, first < 0 ? sw.elapsedMilliseconds : first, sw.elapsedMilliseconds, chars, activeBackend?.name ?? 'unknown');
  }

  /// Release the weights when the OS is short on memory; they reload on the next question.
  void onMemoryPressure() {
    if (_model != null) unload();
  }

  Future<void> warmUp() async {
    if (installed == null || _model != null) return;
    try {
      await _acquire();
    } catch (_) {}
  }

  @override
  Stream<String> generate({required String system, required String prompt, Uint8List? image, int maxOutputTokens = 400}) async* {
    final model = await _acquire();
    final chat = await model.createChat(
      temperature: 0.2,
      topK: 40,
      topP: 0.9,
      supportImage: image != null,
      systemInstruction: system,
      maxOutputTokens: maxOutputTokens,
      modelType: ModelType.gemma4,
    );
    try {
      await chat.addQueryChunk(image == null ? Message.text(text: prompt, isUser: true) : Message.withImage(text: prompt, imageBytes: image, isUser: true));
      await for (final r in chat.generateChatResponseAsync()) {
        if (r is TextResponse) yield r.token;
      }
    } finally {
      try {
        await chat.close();
      } catch (_) {}
    }
  }
}
