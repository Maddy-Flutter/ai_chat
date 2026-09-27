import 'package:aigui/core/errors/result.dart';
import 'package:aigui/domain/entities/chat_message.dart';
import 'package:aigui/domain/entities/conversation.dart';

/// Abstract contract for conversation lifecycle and local message persistence.
abstract class ChatRepository {
  /// Emits real-time updates whenever conversations are created, updated, or removed.
  Stream<List<Conversation>> watchConversations();

  /// Retrieves a specific conversation by ID.
  Future<Result<Conversation?>> getConversation(String id);

  /// Saves or updates a conversation record.
  Future<Result<void>> saveConversation(Conversation conversation);

  /// Deletes a conversation and all its associated messages.
  Future<Result<void>> deleteConversation(String id);

  /// Toggles the pinned status of a conversation.
  Future<Result<void>> togglePinConversation(String id);

  /// Renames an existing conversation title.
  Future<Result<void>> renameConversation(String id, String newTitle);

  /// Emits real-time updates for messages within a specific conversation.
  Stream<List<ChatMessage>> watchMessages(String conversationId);

  /// Retrieves all messages for a specific conversation.
  Future<Result<List<ChatMessage>>> getMessages(String conversationId);

  /// Appends or updates a message in the local store.
  Future<Result<void>> saveMessage(ChatMessage message);

  /// Deletes a specific message by ID.
  Future<Result<void>> deleteMessage(String id);

  /// Marks a message as incomplete due to stream cancellation or network drop.
  Future<Result<void>> markMessageIncomplete(String id, String partialContent);

  /// Performs full-text search across all stored messages.
  Future<Result<List<ChatMessage>>> searchMessages(String query);
}
