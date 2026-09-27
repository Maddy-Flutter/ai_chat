import 'dart:async';
import 'dart:convert';

/// Parses raw text/event-stream byte chunks into a stream of incremental LLM token strings.
class SseStreamParser {
  const SseStreamParser();

  /// Transforms an incoming byte stream into incremental token text chunks.
  Stream<String> parseByteStream(Stream<List<int>> byteStream) {
    return utf8.decoder
        .bind(byteStream)
        .transform(const LineSplitter())
        .transform(_sseLineToDeltaTransformer());
  }

  /// Transforms an incoming string stream into incremental token text chunks.
  Stream<String> parseStringStream(Stream<String> stringStream) {
    return stringStream
        .transform(const LineSplitter())
        .transform(_sseLineToDeltaTransformer());
  }

  StreamTransformer<String, String> _sseLineToDeltaTransformer() {
    return StreamTransformer<String, String>.fromHandlers(
      handleData: (line, sink) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return;

        // Standard SSE comment or heartbeat line
        if (trimmed.startsWith(':')) return;

        if (trimmed.startsWith('data:')) {
          final payload = trimmed.substring(5).trim();

          // OpenAI-compatible termination sentinel
          if (payload == '[DONE]') return;

          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final choices = json['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final firstChoice = choices[0] as Map<String, dynamic>;
              final delta = firstChoice['delta'] as Map<String, dynamic>?;
              if (delta != null) {
                final content = delta['content'] as String?;
                final reasoning = delta['reasoning_content'] as String?;
                if (content != null && content.isNotEmpty) {
                  sink.add(content);
                } else if (reasoning != null && reasoning.isNotEmpty) {
                  sink.add(reasoning);
                }
              }
            }
          } catch (_) {
            // Ignore malformed intermediate chunks or non-JSON payloads
          }
        }
      },
    );
  }
}
