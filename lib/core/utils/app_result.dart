/// Generic result wrapper for handling asynchronous success and error states
/// across Pukaar services and repository layers.
class AppResult<T> {
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final bool isSuccess;

  const AppResult._({
    this.data,
    this.errorMessage,
    this.statusCode,
    required this.isSuccess,
  });

  bool get isFailure => !isSuccess;

  factory AppResult.success(T data, {int? statusCode}) {
    return AppResult._(data: data, statusCode: statusCode ?? 200, isSuccess: true);
  }

  factory AppResult.failure(String errorMessage, {int? statusCode}) {
    return AppResult._(errorMessage: errorMessage, statusCode: statusCode, isSuccess: false);
  }
}

