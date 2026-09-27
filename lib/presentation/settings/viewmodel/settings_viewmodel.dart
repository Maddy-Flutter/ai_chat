import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aigui/core/constants/app_constants.dart';
import 'package:aigui/data/di/repository_providers.dart';
import 'package:aigui/domain/entities/llm_model.dart';
import 'package:aigui/domain/repositories/llm_repository.dart';
import 'package:aigui/domain/repositories/settings_repository.dart';

/// Immutable UI state for the Settings screen.
class SettingsState {
  const SettingsState({
    this.apiKey,
    this.isTestingKey = false,
    this.isKeyValid,
    this.defaultModel = AppConstants.defaultModelId,
    this.availableModels = const [],
    this.isLoadingModels = false,
    this.defaultSystemPrompt = '',
    this.statusMessage,
    this.errorMessage,
  });

  final String? apiKey;
  final bool isTestingKey;
  final bool? isKeyValid;
  final String defaultModel;
  final List<LlmModel> availableModels;
  final bool isLoadingModels;
  final String defaultSystemPrompt;
  final String? statusMessage;
  final String? errorMessage;

  SettingsState copyWith({
    String? Function()? apiKey,
    bool? isTestingKey,
    bool? Function()? isKeyValid,
    String? defaultModel,
    List<LlmModel>? availableModels,
    bool? isLoadingModels,
    String? defaultSystemPrompt,
    String? Function()? statusMessage,
    String? Function()? errorMessage,
  }) {
    return SettingsState(
      apiKey: apiKey != null ? apiKey() : this.apiKey,
      isTestingKey: isTestingKey ?? this.isTestingKey,
      isKeyValid: isKeyValid != null ? isKeyValid() : this.isKeyValid,
      defaultModel: defaultModel ?? this.defaultModel,
      availableModels: availableModels ?? this.availableModels,
      isLoadingModels: isLoadingModels ?? this.isLoadingModels,
      defaultSystemPrompt: defaultSystemPrompt ?? this.defaultSystemPrompt,
      statusMessage: statusMessage != null ? statusMessage() : this.statusMessage,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

/// Pure Riverpod ViewModel managing settings, API credentials, and connection validation.
class SettingsViewModel extends Notifier<SettingsState> {
  SettingsRepository get _settingsRepo => ref.read(settingsRepositoryProvider);
  LlmRepository get _llmRepo => ref.read(llmRepositoryProvider);

  @override
  SettingsState build() {
    Future.microtask(_init);
    return const SettingsState();
  }

  Future<void> _init() async {
    final keyResult = await _settingsRepo.getApiKey();
    final modelResult = await _settingsRepo.getDefaultModel();
    final promptResult = await _settingsRepo.getDefaultSystemPrompt();
    final modelsResult = await _llmRepo.fetchModels();

    state = state.copyWith(
      apiKey: () => keyResult.dataOrNull,
      defaultModel: modelResult.dataOrNull ?? state.defaultModel,
      defaultSystemPrompt: promptResult.dataOrNull ?? state.defaultSystemPrompt,
      availableModels: modelsResult.dataOrNull ?? state.availableModels,
    );
  }

  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;

    final result = await _settingsRepo.saveApiKey(trimmed);
    result.when(
      onSuccess: (_) {
        state = state.copyWith(
          apiKey: () => trimmed,
          statusMessage: () => 'API key saved securely.',
          errorMessage: () => null,
        );
        refreshModels();
      },
      onFailure: (failure) {
        state = state.copyWith(errorMessage: () => failure.message);
      },
    );
  }

  Future<void> testApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(
      isTestingKey: true,
      errorMessage: () => null,
      statusMessage: () => null,
    );

    final result = await _llmRepo.testConnection(trimmed);
    result.when(
      onSuccess: (isValid) {
        state = state.copyWith(
          isTestingKey: false,
          isKeyValid: () => isValid,
          statusMessage: () => 'Successfully connected to NVIDIA NIM endpoint!',
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isTestingKey: false,
          isKeyValid: () => false,
          errorMessage: () => failure.message,
        );
      },
    );
  }

  Future<void> refreshModels() async {
    state = state.copyWith(isLoadingModels: true);
    final result = await _llmRepo.fetchModels(forceRefresh: true);
    result.when(
      onSuccess: (models) {
        state = state.copyWith(
          availableModels: models,
          isLoadingModels: false,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isLoadingModels: false,
          errorMessage: () => failure.message,
        );
      },
    );
  }

  Future<void> setDefaultModel(String modelId) async {
    await _settingsRepo.setDefaultModel(modelId);
    state = state.copyWith(defaultModel: modelId);
  }

  Future<void> setDefaultSystemPrompt(String prompt) async {
    await _settingsRepo.setDefaultSystemPrompt(prompt);
    state = state.copyWith(defaultSystemPrompt: prompt);
  }

  Future<void> clearAllData() async {
    await _settingsRepo.clearAllData();
    state = const SettingsState();
  }
}

/// Provider exposing [SettingsViewModel] and its state.
final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, SettingsState>(SettingsViewModel.new);
