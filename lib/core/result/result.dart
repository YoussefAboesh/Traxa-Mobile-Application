import '../exceptions/app_exception.dart';

/// Typed success/failure container. Replaces the legacy
/// `Map{'success': true/false, 'error': ...}` pattern so callers can't
/// forget the failure branch.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  AppException? get exceptionOrNull => switch (this) {
        Success() => null,
        Failure(exception: final e) => e,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(AppException error) failure,
  }) {
    return switch (this) {
      Success(value: final v) => success(v),
      Failure(exception: final e) => failure(e),
    };
  }

  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(value: final v) => Success(transform(v)),
      Failure(exception: final e) => Failure(e),
    };
  }

  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T value) next,
  ) async {
    return switch (this) {
      Success(value: final v) => await next(v),
      Failure(exception: final e) => Failure<R>(e),
    };
  }
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);
}
