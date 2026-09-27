/// Sealed class hierarchy representing every possible domain/infrastructure failure.
///
/// Ensures compile-time exhaustiveness in ViewModels and UI state mapping,
/// preventing unhandled runtime exceptions from escaping into presentation code.
sealed class AppFailure {
  const AppFailure({required this.message, this.code});

  /// User-facing explanatory message.
  final String message;

  /// Optional machine-readable or HTTP status code.
  final String? code;
}

/// Returned when internet connectivity is lost or DNS/socket resolution fails.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = 'Network connection failed. Please check your internet connection.',
    super.code = 'NETWORK_ERROR',
  });
}

/// Returned on HTTP 401 / 403 when the NVIDIA NIM API key is missing or invalid.
final class AuthFailure extends AppFailure {
  const AuthFailure({
    super.message = 'Invalid or expired NVIDIA NIM API key. Please verify in Settings.',
    super.code = 'AUTH_ERROR',
  });
}

/// Returned on HTTP 429 when API rate limits are encountered.
final class RateLimitFailure extends AppFailure {
  const RateLimitFailure({
    super.message = 'Rate limit exceeded on NVIDIA NIM endpoint.',
    super.code = 'RATE_LIMIT',
    this.retryAfterSeconds,
  });

  /// Optional wait time suggested by the server's `Retry-After` header.
  final int? retryAfterSeconds;
}

/// Returned on HTTP 5xx errors from the NVIDIA NIM servers.
final class ServerFailure extends AppFailure {
  const ServerFailure({
    required super.message,
    super.code = 'SERVER_ERROR',
    this.statusCode,
  });

  final int? statusCode;
}

/// Returned when the SSE stream drops unexpectedly mid-response.
final class StreamInterruptedFailure extends AppFailure {
  const StreamInterruptedFailure({
    super.message = 'Connection lost mid-response. Incomplete message was saved.',
    super.code = 'STREAM_INTERRUPTED',
    this.partialResponse,
  });

  /// The partial content accumulated prior to interruption.
  final String? partialResponse;
}

/// Returned when SQLite/Drift database operations encounter errors.
final class DatabaseFailure extends AppFailure {
  const DatabaseFailure({
    required super.message,
    super.code = 'DATABASE_ERROR',
  });
}

/// Returned when project local folder or file reading operations fail.
final class FileSystemFailure extends AppFailure {
  const FileSystemFailure({
    required super.message,
    super.code = 'FILE_SYSTEM_ERROR',
  });
}

/// Catch-all fallback for uncaught unexpected edge-cases.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    required super.message,
    super.code = 'UNKNOWN_ERROR',
  });
}
