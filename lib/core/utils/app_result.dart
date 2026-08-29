/// Generic result wrapper for handling asynchronous success and error states
/// across Pukaar services and repository layers.
class AppResult<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  const AppResult._({
    this.data,
    this.errorMessage,
    required this.isSuccess,
  });

  factory AppResult.success(T data) {
    return AppResult._(data: data, isSuccess: true);
  }

  factory AppResult.failure(String errorMessage) {
    return AppResult._(errorMessage: errorMessage, isSuccess: false);
  }
}
