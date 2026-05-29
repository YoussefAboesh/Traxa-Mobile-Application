abstract class AppException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stack;

  const AppException(this.message, {this.cause, this.stack});

  @override
  String toString() => '$runtimeType: $message';
}

// ===== Network =====

/// Reachability failure — no DNS, no socket, no response. Distinct from
/// [ServerException] so the UI can show "you're offline" instead of a
/// generic error.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stack});
}

class ServerException extends AppException {
  final int statusCode;
  final String? body;

  const ServerException(
    super.message, {
    required this.statusCode,
    this.body,
    super.cause,
    super.stack,
  });

  @override
  String toString() => 'ServerException($statusCode): $message';
}

class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Request timed out']);
}

// ===== Auth =====

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized']);
}

class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException([super.message = 'Invalid credentials']);
}

class SessionExpiredException extends AppException {
  const SessionExpiredException(
      [super.message = 'Session expired. Please log in again.']);
}

class AccountLockedException extends AppException {
  final int? remainingAttempts;
  final String? lockedAt;

  const AccountLockedException(
    super.message, {
    this.remainingAttempts,
    this.lockedAt,
    super.cause,
  });
}

// ===== Validation / business =====

class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;
  const ValidationException(super.message, {this.fieldErrors, super.cause});
}

/// Last-resort wrapper for anything unrecognised — guarantees every catch
/// site can deal with a typed exception.
class UnknownAppException extends AppException {
  const UnknownAppException(super.message, {super.cause, super.stack});
}
