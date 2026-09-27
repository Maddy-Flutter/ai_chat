import 'package:aigui/core/errors/app_failure.dart';

/// A pure functional result type wrapping either successful data [T] or an [AppFailure].
///
/// Ensures error branches are handled explicitly in the business logic layer
/// without relying on unhandled exception re-throwing.
sealed class Result<T> {
  const Result();

  /// Constructs a successful [Result] containing [data].
  const factory Result.success(T data) = Success<T>;

  /// Constructs a failed [Result] containing [failure].
  const factory Result.failure(AppFailure failure) = Failure<T>;

  /// Whether this result represents a success.
  bool get isSuccess => this is Success<T>;

  /// Whether this result represents a failure.
  bool get isFailure => this is Failure<T>;

  /// Returns the value if successful, or `null` if failure.
  T? get dataOrNull => switch (this) {
        Success(data: final data) => data,
        Failure() => null,
      };

  /// Returns the failure if failed, or `null` if success.
  AppFailure? get failureOrNull => switch (this) {
        Success() => null,
        Failure(failure: final failure) => failure,
      };

  /// Pattern matching handler for both success and failure branches.
  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) =>
      switch (this) {
        Success(data: final data) => onSuccess(data),
        Failure(failure: final failure) => onFailure(failure),
      };

  /// Transforms the success value using [transform].
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
        Success(data: final data) => Result.success(transform(data)),
        Failure(failure: final failure) => Result.failure(failure),
      };
}

/// A successful [Result] carrying [data].
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

/// A failed [Result] carrying an [AppFailure].
final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;
}
