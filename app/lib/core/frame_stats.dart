import 'dart:async';
import 'package:flutter/scheduler.dart';

/// Developer tool for measuring smoothness on a real phone. Off unless the app is built with
/// `--dart-define=FRAME_STATS=true`. Every 2 s it prints one line to logcat (tag "flutter") with the
/// build (UI thread) and raster (GPU thread) cost of the frames drawn in that window.
class FrameStats {
  static bool _on = false;
  static final List<FrameTiming> _buf = [];

  static void startIfRequested() {
    if (!const bool.fromEnvironment('FRAME_STATS') || _on) return;
    _on = true;
    SchedulerBinding.instance.addTimingsCallback(_buf.addAll);
    Timer.periodic(const Duration(seconds: 2), (_) => _flush());
  }

  static double _pct(List<double> s, double p) => s.isEmpty ? 0 : s[((s.length - 1) * p).round()];

  static void _flush() {
    if (_buf.isEmpty) return;
    final b = [for (final t in _buf) t.buildDuration.inMicroseconds / 1000]..sort();
    final r = [for (final t in _buf) t.rasterDuration.inMicroseconds / 1000]..sort();
    final tot = [for (final t in _buf) t.totalSpan.inMicroseconds / 1000];
    final over16 = tot.where((v) => v > 16.7).length, over8 = tot.where((v) => v > 8.3).length;
    // ignore: avoid_print
    print('FRAMESTATS n=${_buf.length} build p50=${_pct(b, .5).toStringAsFixed(1)} p90=${_pct(b, .9).toStringAsFixed(1)} p99=${_pct(b, .99).toStringAsFixed(1)}'
        ' raster p50=${_pct(r, .5).toStringAsFixed(1)} p90=${_pct(r, .9).toStringAsFixed(1)} p99=${_pct(r, .99).toStringAsFixed(1)} over16=$over16 over8=$over8');
    _buf.clear();
  }
}
