import 'package:flutter/foundation.dart';

/// Debug-only logger. Stripped from release builds so no data ends up in
/// production logs.
void logDebug(Object? message) {
  if (kDebugMode) debugPrint('$message');
}
