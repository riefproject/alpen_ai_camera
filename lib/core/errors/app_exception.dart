abstract class AppException implements Exception {
  const AppException(this.message);

  // TODO: Standardize how domain/data failures are mapped into user-facing errors.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}
