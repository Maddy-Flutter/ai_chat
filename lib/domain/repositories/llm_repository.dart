import 'package:aigui/core/errors/result.dart';
import 'package:aigui/domain/entities/chat_message.dart';
import 'package:aigui/domain/entities/llm_model.dart';

/// Abstract contract for interacting with NVIDIA NIM or any OpenAI-compatible LLM inference provider.
///
/// Ensures ViewModels are completely decoupled from Dio, HTTP endpoints, or provider specifics.
abstract class LlmRepository {
  /// Fetches available models from the provider endpoint.
  Future<Result<List<LlmModel>>> fetchModels({bool forceRefresh = false});

  /// Emits real-time cached models whenever they are refreshed or loaded.
  Stream<List<LlmModel>> watchModels();

  /// Streams token deltas for chat completions over SSE.
  Stream<Result<String>> streamChatCompletion({
    required String modelId,
    required List<ChatMessage> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? systemPrompt,
  });

  /// Sends a non-streaming chat completion request.
  Future<Result<String>> sendChatCompletion({
    required String modelId,
    required List<ChatMessage> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? systemPrompt,
  });

  /// Tests connectivity using the provided API key.
  Future<Result<bool>> testConnection(String apiKey);
}
