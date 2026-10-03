import 'package:flutter/foundation.dart';

/// Diagnostic logging that is silent in release builds. Never pass user text,
/// symptoms, coordinates or contact details to these functions: log event names and
/// error types only.
void logInfo(String tag, String message) {
  if (kDebugMode) debugPrint('[$tag] $message');
}

void logError(String tag, Object error, [StackTrace? stack]) {
  if (kDebugMode) debugPrint('[$tag] ${error.runtimeType}: $error${stack == null ? '' : '\n$stack'}');
}
