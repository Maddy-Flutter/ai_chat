import 'package:drift/drift.dart';

import 'package:aigui/core/errors/app_failure.dart';
import 'package:aigui/core/errors/result.dart';
import 'package:aigui/data/datasources/local/database/app_database.dart';
import 'package:aigui/data/datasources/local/secure_storage_data_source.dart';
import 'package:aigui/data/datasources/remote/nvidia_api_data_source.dart';
import 'package:aigui/domain/entities/chat_message.dart';
import 'package:aigui/domain/entities/llm_model.dart';
import 'package:aigui/domain/repositories/llm_repository.dart';

/// Concrete implementation of [LlmRepository] backed by [NvidiaApiDataSource] and cached in [AppDatabase].
class LlmRepositoryImpl implements LlmRepository {
  const LlmRepositoryImpl({
    required NvidiaApiDataSource apiDataSource,
    required SecureStorageDataSource secureStorage,
    required AppDatabase database,
  })  : _apiDataSource = apiDataSource,
        _secureStorage = secureStorage,
        _database = database;

  final NvidiaApiDataSource _apiDataSource;
  final SecureStorageDataSource _secureStorage;
  final AppDatabase _database;

  @override
  Future<Result<List<LlmModel>>> fetchModels({bool forceRefresh = false}) async {
    // 1. Check local DB cache unless forceRefresh requested
    if (!forceRefresh) {
      final cached = await _database.getAllCachedModels();
      if (cached.isNotEmpty) {
        final models = cached
            .map((c) => LlmModel(
                  id: c.id,
                  name: c.name,
                  ownedBy: c.ownedBy,
                  contextLength: c.contextLength,
                ))
            .toList();
        return Result.success(models);
      }
    }

    // 2. Retrieve secure key for live remote fetch
    final keyResult = await _secureStorage.getApiKey();
    final apiKey = keyResult.dataOrNull;
    if (apiKey == null || apiKey.trim().isEmpty) {
      return const Result.failure(AuthFailure(
        message: 'NVIDIA API key not configured. Please enter your key in Settings.',
      ));
    }

    final apiResult = await _apiDataSource.fetchModels(apiKey);

    // 3. Cache results in Drift on success
    return apiResult.when(
      onSuccess: (models) async {
        if (models.isNotEmpty) {
          final companions = models
              .map((m) => CachedModelsTableCompanion(
                    id: Value(m.id),
                    name: Value(m.name),
                    ownedBy: Value(m.ownedBy),
                    contextLength: Value(m.contextLength),
                    cachedAt: Value(DateTime.now()),
                  ))
              .toList();
          await _database.replaceCachedModels(companions);
        }
        return Result.success(models);
      },
      onFailure: (failure) => Result.failure(failure),
    );
  }

  @override
  Stream<List<LlmModel>> watchModels() {
    return _database.watchAllCachedModels().map((rows) {
      return rows
          .map((c) => LlmModel(
                id: c.id,
                name: c.name,
                ownedBy: c.ownedBy,
                contextLength: c.contextLength,
              ))
          .toList();
    });
  }

  @override
  Stream<Result<String>> streamChatCompletion({
    required String modelId,
    required List<ChatMessage> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? systemPrompt,
  }) async* {
    final keyResult = await _secureStorage.getApiKey();
    final apiKey = keyResult.dataOrNull;
    if (apiKey == null || apiKey.trim().isEmpty) {
      yield const Result.failure(AuthFailure(
        message: 'NVIDIA API key not configured. Please enter your key in Settings.',
      ));
      return;
    }

    yield* _apiDataSource.streamChatCompletion(
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  @override
  Future<Result<String>> sendChatCompletion({
    required String modelId,
    required List<ChatMessage> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? systemPrompt,
  }) async {
    final keyResult = await _secureStorage.getApiKey();
    final apiKey = keyResult.dataOrNull;
    if (apiKey == null || apiKey.trim().isEmpty) {
      return const Result.failure(AuthFailure(
        message: 'NVIDIA API key not configured. Please enter your key in Settings.',
      ));
    }

    return _apiDataSource.sendChatCompletion(
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  @override
  Future<Result<bool>> testConnection(String apiKey) {
    return _apiDataSource.testConnection(apiKey);
  }
}
