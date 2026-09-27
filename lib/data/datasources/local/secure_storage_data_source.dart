import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aigui/core/constants/app_constants.dart';
import 'package:aigui/core/errors/app_failure.dart';
import 'package:aigui/core/errors/result.dart';
import 'package:aigui/core/utils/app_logger.dart';

/// Data source encapsulating platform-secure credential storage for API keys.
class SecureStorageDataSource {
  SecureStorageDataSource({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              wOptions: WindowsOptions(useBackwardCompatibility: false),
            );

  final FlutterSecureStorage _storage;

  /// Retrieves the persisted NVIDIA NIM API key, or null if none exists.
  Future<Result<String?>> getApiKey() async {
    try {
      final key = await _storage.read(key: AppConstants.secureStorageApiKey);
      return Result.success(key);
    } catch (e, st) {
      AppLogger.e('Failed to read secure API key: $e', e, st);
      return const Result.failure(DatabaseFailure(
        message: 'Could not access secure credential vault.',
      ));
    }
  }

  /// Securely saves the NVIDIA NIM API key.
  Future<Result<void>> saveApiKey(String apiKey) async {
    try {
      await _storage.write(
        key: AppConstants.secureStorageApiKey,
        value: apiKey.trim(),
      );
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Failed to write secure API key: $e', e, st);
      return const Result.failure(DatabaseFailure(
        message: 'Could not store API key in secure vault.',
      ));
    }
  }

  /// Deletes the API key from secure storage.
  Future<Result<void>> clearApiKey() async {
    try {
      await _storage.delete(key: AppConstants.secureStorageApiKey);
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Failed to clear secure API key: $e', e, st);
      return const Result.failure(DatabaseFailure(
        message: 'Could not remove API key from secure vault.',
      ));
    }
  }

  /// Reads a generic value by key.
  Future<String?> readValue(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  /// Writes a generic key-value pair.
  Future<void> writeValue(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, st) {
      AppLogger.e('Error writing key $key: $e', e, st);
    }
  }
}
