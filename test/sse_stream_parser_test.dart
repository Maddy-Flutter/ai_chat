import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aigui/core/network/sse_stream_parser.dart';

void main() {
  group('SseStreamParser', () {
    const parser = SseStreamParser();

    test('correctly parses token deltas from OpenAI-compatible SSE events', () async {
      const ssePayload = '''
: heartbeat
data: {"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{"delta":{"content":"Hello"}}]}

data: {"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{"delta":{"content":" world"}}]}

data: {"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{"delta":{"content":"!"}}]}

data: [DONE]
''';

      final byteStream = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(utf8.encode(ssePayload)),
      ]);

      final tokens = await parser.parseByteStream(byteStream).toList();

      expect(tokens, ['Hello', ' world', '!']);
      expect(tokens.join(), 'Hello world!');
    });

    test('gracefully ignores malformed lines and comments', () async {
      const ssePayload = '''
: ping
malformed line without data prefix
data: not a json payload

data: {"id":"1","choices":[{"delta":{"content":"Valid"}}]}

data: [DONE]
''';

      final byteStream = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(utf8.encode(ssePayload)),
      ]);

      final tokens = await parser.parseByteStream(byteStream).toList();

      expect(tokens, ['Valid']);
    });

    test('correctly parses reasoning_content deltas from reasoning models', () async {
      const ssePayload = '''
data: {"id":"1","choices":[{"delta":{"reasoning_content":"Thinking"}}]}
data: {"id":"1","choices":[{"delta":{"reasoning_content":"..."}}]}
data: {"id":"1","choices":[{"delta":{"content":"Answer"}}]}
data: [DONE]
''';

      final byteStream = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(utf8.encode(ssePayload)),
      ]);

      final tokens = await parser.parseByteStream(byteStream).toList();

      expect(tokens, ['Thinking', '...', 'Answer']);
      expect(tokens.join(), 'Thinking...Answer');
    });
  });
}
