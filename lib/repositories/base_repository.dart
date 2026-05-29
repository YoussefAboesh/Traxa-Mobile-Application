import 'dart:async' as async;
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/exceptions/app_exception.dart';
import '../core/logger.dart';
import '../core/result/result.dart';

abstract class BaseRepository {
  /// Wraps an async call and converts every thrown / network error into a
  /// typed [Result] so cubits never need to reason about raw exceptions.
  Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String? tag,
  }) async {
    try {
      return Success(await action());
    } on AppException catch (e) {
      return Failure(e);
    } on SocketException catch (e, s) {
      AppLogger.w('Network down', tag: tag, error: e);
      return Failure(NetworkException('No internet connection',
          cause: e, stack: s));
    } on http.ClientException catch (e, s) {
      AppLogger.w('HTTP client error', tag: tag, error: e);
      return Failure(NetworkException(e.message, cause: e, stack: s));
    } on async.TimeoutException {
      AppLogger.w('Request timed out', tag: tag);
      return Failure(const TimeoutException());
    } catch (e, s) {
      AppLogger.e('Unexpected error', tag: tag, error: e, stack: s);
      return Failure(UnknownAppException(e.toString(), cause: e, stack: s));
    }
  }

  /// Converts the legacy `{'success': bool, 'error': ...}` response into a
  /// [Result], mapping well-known errors (locked / invalid creds / expired)
  /// to their typed exceptions so the UI can branch on type, not on text.
  Result<Map<String, dynamic>> fromLegacyResponse(
    Map<String, dynamic> response, {
    String defaultError = 'Request failed',
  }) {
    if (response['success'] == true) {
      return Success(response);
    }
    final err = response['error']?.toString() ?? defaultError;

    if (response['locked'] == true || response['error'] == 'ACCOUNT_LOCKED') {
      return Failure(AccountLockedException(
        err,
        remainingAttempts: response['remainingAttempts'] as int?,
        lockedAt: response['lockedAt']?.toString(),
      ));
    }
    if (err.toLowerCase().contains('invalid credentials')) {
      return Failure(InvalidCredentialsException(err));
    }
    if (err.toLowerCase().contains('session expired')) {
      return Failure(SessionExpiredException(err));
    }
    return Failure(UnknownAppException(err));
  }
}
