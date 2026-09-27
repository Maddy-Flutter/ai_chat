import 'dart:async';

import 'package:dio/dio.dart';

import 'package:aigui/core/constants/app_constants.dart';
import 'package:aigui/core/errors/app_failure.dart';
import 'package:aigui/core/errors/result.dart';
import 'package:aigui/core/network/sse_stream_parser.dart';
import 'package:aigui/core/utils/app_logger.dart';
import 'package:aigui/data/models/nvidia_model_dto.dart';
import 'package:aigui/domain/entities/chat_message.dart';
import 'package:aigui/domain/entities/llm_model.dart';

/// Remote datasource handling HTTP and SSE communication with NVIDIA NIM endpoints.
class NvidiaApiDataSource {
  NvidiaApiDataSource({
    Dio? dio,
    SseStreamParser? sseParser,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.nvidiaBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 180),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ),
        _sseParser = sseParser ?? const SseStreamParser();

  final Dio _dio;
  final SseStreamParser _sseParser;

  /// Fetches the dynamically available model catalog from NVIDIA NIM.
  Future<Result<List<LlmModel>>> fetchModels(String apiKey) async {
    try {
      final response = await _dio.get(
        '/models',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        final rawList = data['data'] as List<dynamic>;
        final models = rawList
            .whereType<Map<String, dynamic>>()
            .map((item) => NvidiaModelDto.fromJson(item).toDomain())
            .where((m) => _isChatCompletionModel(m.id))
            .toList();

        return Result.success(models);
      }

      return const Result.success([]);
    } on DioException catch (e) {
      return Result.failure(_mapDioException(e));
    } catch (e, st) {
      AppLogger.e('Unexpected error in fetchModels: $e', e, st);
      return Result.failure(UnknownFailure(message: e.toString()));
    }
  }

  /// Filters out non-chat models (embeddings, rerankers, guardrails, vision-only extractors).
  static bool _isChatCompletionModel(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('embed') ||
        lower.contains('rerank') ||
        lower.contains('guard') ||
        lower.contains('reward') ||
        lower.contains('deplot') ||
        lower.contains('diffusion')) {
      return false;
    }
    return true;
  }

  /// Sends a streaming chat completion request and yields parsed token text chunks.
  Stream<Result<String>> streamChatCompletion({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? systemPrompt,
    CancelToken? cancelToken,
  }) async* {
    if (modelId.toLowerCase().contains('embed')) {
      yield Result.failure(ServerFailure(
        message: 'The model "$modelId" is a text embedding model (used for vector search), not a chat completion model. Please select an active chat model like meta/llama-3.2-11b-vision-instruct or moonshotai/kimi-k3.',
        statusCode: 400,
        code: 'EMBEDDING_MODEL_NOT_SUPPORTED',
      ));
      return;
    }

    final payload = _buildChatPayload(
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
      stream: true,
    );

    try {
      final response = await _dio.post<ResponseBody>(
        '/chat/completions',
        data: payload,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
      );

      final responseStream = response.data?.stream;
      if (responseStream == null) {
        yield const Result.failure(ServerFailure(
          message: 'Empty response stream received from NVIDIA NIM endpoint.',
        ));
        return;
      }

      final textChunkStream = _sseParser.parseByteStream(
        responseStream.cast<List<int>>(),
      );

      yield* textChunkStream.map((delta) => Result.success(delta)).handleError(
        (error) {
          if (error is DioException) {
            return Result.failure(_mapDioException(error));
          }
          return Result.failure(StreamInterruptedFailure(
            message: 'Stream disconnected: $error',
          ));
        },
      );
    } on DioException catch (e) {
      yield Result.failure(_mapDioException(e));
    } catch (e, st) {
      AppLogger.e('Unexpected error in streamChatCompletion: $e', e, st);
      yield Result.failure(UnknownFailure(message: e.toString()));
    }
  }

  /// Sends a non-streaming chat completion request.
  Future<Result<String>> sendChatCompletion({
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? systemPrompt,
    CancelToken? cancelToken,
  }) async {
    if (modelId.toLowerCase().contains('embed')) {
      return Result.failure(ServerFailure(
        message: 'The model "$modelId" is a text embedding model (used for vector search), not a chat completion model. Please select an active chat model like meta/llama-3.2-11b-vision-instruct or moonshotai/kimi-k3.',
        statusCode: 400,
        code: 'EMBEDDING_MODEL_NOT_SUPPORTED',
      ));
    }

    final payload = _buildChatPayload(
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
      stream: false,
    );

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: payload,
        cancelToken: cancelToken,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String? ?? '';
        return Result.success(content);
      }

      return const Result.failure(ServerFailure(
        message: 'No response message returned in API completion payload.',
      ));
    } on DioException catch (e) {
      return Result.failure(_mapDioException(e));
    } catch (e, st) {
      AppLogger.e('Unexpected error in sendChatCompletion: $e', e, st);
      return Result.failure(UnknownFailure(message: e.toString()));
    }
  }

  /// Verifies API key validity by performing a lightweight query.
  Future<Result<bool>> testConnection(String apiKey) async {
    final result = await fetchModels(apiKey);
    return result.when(
      onSuccess: (_) => const Result.success(true),
      onFailure: (failure) => Result.failure(failure),
    );
  }

  Map<String, dynamic> _buildChatPayload({
    required String modelId,
    required List<ChatMessage> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? systemPrompt,
    required bool stream,
  }) {
    final formattedMessages = <Map<String, String>>[];

    // Insert system prompt if provided
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      formattedMessages.add({
        'role': 'system',
        'content': systemPrompt.trim(),
      });
    }

    for (final msg in messages) {
      formattedMessages.add({
        'role': msg.role.name,
        'content': msg.content,
      });
    }

    final isKimi = modelId.toLowerCase().contains('kimi');
    final payload = <String, dynamic>{
      'model': modelId,
      'messages': formattedMessages,
      'temperature': temperature ?? (isKimi ? 1.0 : 0.7),
      'max_tokens': maxTokens ?? (isKimi ? 16384 : 4096),
      'stream': stream,
    };

    // NVIDIA NIM kimi-k3 specifies seed: 0 and omits top_p
    if (isKimi || modelId.toLowerCase().contains('r1')) {
      payload['reasoning_effort'] = 'low';
      payload['seed'] = 0;
    } else if (topP != null) {
      payload['top_p'] = topP;
    }

    return payload;
  }

  AppFailure _mapDioException(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return const StreamInterruptedFailure(
        message: 'Request was cancelled.',
        code: 'USER_CANCELLED',
      );
    }

    String? serverDetail;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('detail')) {
        serverDetail = data['detail'].toString();
      } else if (data.containsKey('message')) {
        serverDetail = data['message'].toString();
      } else if (data.containsKey('error')) {
        final err = data['error'];
        if (err is Map<String, dynamic> && err.containsKey('message')) {
          serverDetail = err['message'].toString();
        } else {
          serverDetail = err.toString();
        }
      }
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return const AuthFailure();
    }

    if (statusCode == 410) {
      return ServerFailure(
        message: serverDetail != null
            ? 'Model is retired or unavailable: $serverDetail. Please select an active model from the top dropdown.'
            : 'The selected model is unavailable or retired on NVIDIA NIM (HTTP 410). Please select an active model from the top dropdown.',
        statusCode: 410,
        code: 'MODEL_RETIRED',
      );
    }

    if (statusCode == 404) {
      return ServerFailure(
        message: serverDetail != null
            ? 'Model function not found on your NVIDIA account (HTTP 404): $serverDetail. Please select an active model (such as moonshotai/kimi-k3 or meta/llama-3.2-11b-vision-instruct).'
            : 'The selected model is not provisioned or active for your NVIDIA NIM account (HTTP 404). Please switch to an active model.',
        statusCode: 404,
        code: 'MODEL_NOT_FOUND',
      );
    }

    if (statusCode == 429) {
      int? retryAfter;
      final retryHeader = e.response?.headers.value('retry-after');
      if (retryHeader != null) {
        retryAfter = int.tryParse(retryHeader);
      }
      return RateLimitFailure(retryAfterSeconds: retryAfter);
    }

    if (statusCode != null && statusCode >= 500) {
      return ServerFailure(
        message: serverDetail != null
            ? 'NVIDIA server error ($statusCode): $serverDetail'
            : 'NVIDIA server error ($statusCode). Please try again later.',
        statusCode: statusCode,
      );
    }

    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return ServerFailure(
        message: serverDetail ?? 'Client request error ($statusCode). Please verify the selected model and configuration.',
        statusCode: statusCode,
      );
    }

    if (e.type == DioExceptionType.receiveTimeout) {
      return const ServerFailure(
        message: 'NVIDIA NIM request timed out while generating a response (receive timeout). The model may be queuing or under heavy load. Please try again or switch to a faster model (e.g. meta/llama-3.1-8b-instruct or mistralai/mistral-large-2407).',
        code: 'RECEIVE_TIMEOUT',
      );
    }

    if (e.type == DioExceptionType.connectionTimeout) {
      return const NetworkFailure(
        message: 'Connection timed out while establishing connection to NVIDIA NIM servers. Please check your internet connection or firewall.',
        code: 'CONNECT_TIMEOUT',
      );
    }

    if (e.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure(
        message: 'Request send timed out. Please check your network connection.',
        code: 'SEND_TIMEOUT',
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      return const NetworkFailure(
        message: 'Unable to connect to NVIDIA NIM servers (DNS or network unreachable). Please verify your internet connection, proxy, or VPN.',
        code: 'CONNECTION_ERROR',
      );
    }

    return UnknownFailure(
      message: serverDetail ?? e.message ?? 'An unknown network error occurred.',
    );
  }
}
