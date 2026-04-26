enum LoadingStatus { initial, loading, loaded, error }

class LoadingState {
  final LoadingStatus status;
  final String? errorMessage;
  
  const LoadingState({
    this.status = LoadingStatus.initial,
    this.errorMessage,
  });
  
  LoadingState copyWith({
    LoadingStatus? status,
    String? errorMessage,
  }) {
    return LoadingState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  bool get isLoading => status == LoadingStatus.loading;
  bool get isLoaded => status == LoadingStatus.loaded;
  bool get hasError => status == LoadingStatus.error;
  
  factory LoadingState.initial() => const LoadingState();
  factory LoadingState.loading() => const LoadingState(status: LoadingStatus.loading);
  factory LoadingState.loaded() => const LoadingState(status: LoadingStatus.loaded);
  factory LoadingState.error(String message) => LoadingState(
    status: LoadingStatus.error,
    errorMessage: message,
  );
}