/// Defines the conversational role of a participant.
enum MessageRole {
  user,
  assistant,
  system;

  static MessageRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        return MessageRole.user;
    }
  }
}

/// Pure domain entity representing an individual chat message in a conversation.
///
/// Fully decoupled from serialization and UI layers.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isStreaming = false,
    this.isError = false,
    this.isIncomplete = false,
    this.tokenCount,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final bool isStreaming;
  final bool isError;
  final bool isIncomplete;
  final int? tokenCount;

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    String? content,
    DateTime? createdAt,
    bool? isStreaming,
    bool? isError,
    bool? isIncomplete,
    int? tokenCount,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
      isIncomplete: isIncomplete ?? this.isIncomplete,
      tokenCount: tokenCount ?? this.tokenCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          conversationId == other.conversationId &&
          role == other.role &&
          content == other.content &&
          isStreaming == other.isStreaming &&
          isError == other.isError &&
          isIncomplete == other.isIncomplete;

  @override
  int get hashCode =>
      id.hashCode ^
      conversationId.hashCode ^
      role.hashCode ^
      content.hashCode ^
      isStreaming.hashCode ^
      isError.hashCode ^
      isIncomplete.hashCode;
}
