import 'package:aigui/core/constants/app_constants.dart';
import 'package:aigui/core/errors/app_failure.dart';
import 'package:aigui/core/errors/result.dart';
import 'package:aigui/core/utils/app_logger.dart';
import 'package:aigui/data/datasources/local/database/app_database.dart';
import 'package:aigui/data/datasources/local/secure_storage_data_source.dart';
import 'package:aigui/domain/repositories/settings_repository.dart';

/// Concrete implementation of [SettingsRepository] managing user preferences and credentials.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required SecureStorageDataSource secureStorage,
    required AppDatabase database,
  })  : _secureStorage = secureStorage,
        _database = database;

  final SecureStorageDataSource _secureStorage;
  final AppDatabase _database;

  static const _prefModelKey = 'app_default_model_id';
  static const _prefPromptKey = 'app_default_system_prompt';

  @override
  Future<Result<String?>> getApiKey() {
    return _secureStorage.getApiKey();
  }

  @override
  Future<Result<void>> saveApiKey(String apiKey) {
    return _secureStorage.saveApiKey(apiKey);
  }

  @override
  Future<Result<void>> clearApiKey() {
    return _secureStorage.clearApiKey();
  }

  @override
  Future<Result<String>> getDefaultModel() async {
    final saved = await _secureStorage.readValue(_prefModelKey);
    return Result.success(saved ?? AppConstants.defaultModelId);
  }

  @override
  Future<Result<void>> setDefaultModel(String modelId) async {
    await _secureStorage.writeValue(_prefModelKey, modelId);
    return const Result.success(null);
  }

  @override
  Future<Result<String>> getDefaultSystemPrompt() async {
    final saved = await _secureStorage.readValue(_prefPromptKey);
    return Result.success(
      saved ??
          'You are an expert AI assistant. Provide concise, accurate, and deeply insightful responses. Format code with clean Markdown and language tags.',
    );
  }

  @override
  Future<Result<void>> setDefaultSystemPrompt(String systemPrompt) async {
    await _secureStorage.writeValue(_prefPromptKey, systemPrompt);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> clearAllData() async {
    try {
      await _database.clearEntireDatabase();
      await _secureStorage.clearApiKey();
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error clearing all application data: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }
}
