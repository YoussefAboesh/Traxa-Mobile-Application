import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'env/app_env.dart';

enum LogLevel { debug, info, warn, error }

/// On release prod builds only [LogLevel.error] is emitted, and [onError]
/// fires so you can pipe it to Crashlytics/Sentry.
class AppLogger {
  AppLogger._();

  static LogLevel minLevel = AppEnv.isDev ? LogLevel.debug : LogLevel.warn;

  static void Function(
    Object message,
    Object? error,
    StackTrace? stack,
  )? onError;

  static void d(Object message, {String? tag}) =>
      _emit(LogLevel.debug, message, tag);

  static void i(Object message, {String? tag}) =>
      _emit(LogLevel.info, message, tag);

  static void w(Object message, {String? tag, Object? error}) =>
      _emit(LogLevel.warn, message, tag, error: error);

  static void e(
    Object message, {
    String? tag,
    Object? error,
    StackTrace? stack,
  }) {
    _emit(LogLevel.error, message, tag, error: error, stack: stack);
    if (onError != null) {
      try {
        onError!(message, error, stack);
      } catch (_) {
        // Reporter itself must never crash the app.
      }
    }
  }

  static void _emit(
    LogLevel level,
    Object message,
    String? tag, {
    Object? error,
    StackTrace? stack,
  }) {
    if (level.index < minLevel.index) return;
    if (kReleaseMode && level != LogLevel.error) return;

    developer.log(
      '${_prefix(level)} $message',
      name: tag ?? 'traxa',
      level: _levelValue(level),
      error: error,
      stackTrace: stack,
    );
  }

  static String _prefix(LogLevel l) {
    switch (l) {
      case LogLevel.debug:
        return '🟢';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warn:
        return '⚠️';
      case LogLevel.error:
        return '🔴';
    }
  }

  static int _levelValue(LogLevel l) {
    switch (l) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warn:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}

@Deprecated('Use AppLogger.d() instead')
void logDebug(Object? message) => AppLogger.d(message ?? 'null');
