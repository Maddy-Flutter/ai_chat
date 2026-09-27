import 'package:aigui/core/errors/result.dart';

/// Abstract contract for managing user settings, secure API credentials, and storage maintenance.
abstract class SettingsRepository {
  /// Fetches the securely stored NVIDIA NIM API key.
  Future<Result<String?>> getApiKey();

  /// Persists a new NVIDIA NIM API key into secure OS vault.
  Future<Result<void>> saveApiKey(String apiKey);

  /// Clears the stored API key.
  Future<Result<void>> clearApiKey();

  /// Gets the currently configured default LLM model identifier.
  Future<Result<String>> getDefaultModel();

  /// Sets the preferred default LLM model identifier.
  Future<Result<void>> setDefaultModel(String modelId);

  /// Gets the default system prompt template.
  Future<Result<String>> getDefaultSystemPrompt();

  /// Sets the default system prompt template.
  Future<Result<void>> setDefaultSystemPrompt(String systemPrompt);

  /// Completely clears all local SQLite tables and stored data.
  Future<Result<void>> clearAllData();
}
