class ErrorState {
  final bool hasError;
  final String? message;
  
  const ErrorState({
    this.hasError = false,
    this.message,
  });
  
  factory ErrorState.none() => const ErrorState();
  factory ErrorState.error(String message) => ErrorState(
    hasError: true,
    message: message,
  );
  
  ErrorState copyWith({
    bool? hasError,
    String? message,
  }) {
    return ErrorState(
      hasError: hasError ?? this.hasError,
      message: message ?? this.message,
    );
  }
  
  @override
  String toString() => 'ErrorState(hasError: $hasError, message: $message)';
}