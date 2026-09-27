import 'package:drift/drift.dart';

import 'package:aigui/core/errors/app_failure.dart';
import 'package:aigui/core/errors/result.dart';
import 'package:aigui/core/utils/app_logger.dart';
import 'package:aigui/data/datasources/local/database/app_database.dart';
import 'package:aigui/domain/entities/chat_message.dart';
import 'package:aigui/domain/entities/conversation.dart';
import 'package:aigui/domain/repositories/chat_repository.dart';

/// Concrete implementation of [ChatRepository] persisting conversations and messages into Drift SQLite.
class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl({required AppDatabase database})
      : _database = database;

  final AppDatabase _database;

  @override
  Stream<List<Conversation>> watchConversations() {
    return _database.watchAllConversations().map((rows) => rows.map(_mapConversationRow).toList());
  }

  @override
  Future<Result<Conversation?>> getConversation(String id) async {
    try {
      final row = await _database.getConversationById(id);
      return Result.success(row != null ? _mapConversationRow(row) : null);
    } catch (e, st) {
      AppLogger.e('Error getting conversation $id: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> saveConversation(Conversation conv) async {
    try {
      await _database.upsertConversation(
        ConversationsTableCompanion(
          id: Value(conv.id),
          title: Value(conv.title),
          createdAt: Value(conv.createdAt),
          updatedAt: Value(conv.updatedAt),
          isPinned: Value(conv.isPinned),
          projectId: Value(conv.projectId),
          modelId: Value(conv.modelId),
          systemPrompt: Value(conv.systemPrompt),
          temperature: Value(conv.temperature),
          topP: Value(conv.topP),
          maxTokens: Value(conv.maxTokens),
        ),
      );
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error saving conversation: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteConversation(String id) async {
    try {
      await _database.deleteConversationCascade(id);
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error deleting conversation $id: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> togglePinConversation(String id) async {
    try {
      final conv = await _database.getConversationById(id);
      if (conv != null) {
        await _database.upsertConversation(
          ConversationsTableCompanion(
            id: Value(conv.id),
            title: Value(conv.title),
            createdAt: Value(conv.createdAt),
            updatedAt: Value(conv.updatedAt),
            isPinned: Value(!conv.isPinned),
            projectId: Value(conv.projectId),
            modelId: Value(conv.modelId),
            systemPrompt: Value(conv.systemPrompt),
            temperature: Value(conv.temperature),
            topP: Value(conv.topP),
            maxTokens: Value(conv.maxTokens),
          ),
        );
      }
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error toggling pin on conversation $id: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> renameConversation(String id, String newTitle) async {
    try {
      final conv = await _database.getConversationById(id);
      if (conv != null) {
        await _database.upsertConversation(
          ConversationsTableCompanion(
            id: Value(conv.id),
            title: Value(newTitle.trim()),
            createdAt: Value(conv.createdAt),
            updatedAt: Value(DateTime.now()),
            isPinned: Value(conv.isPinned),
            projectId: Value(conv.projectId),
            modelId: Value(conv.modelId),
            systemPrompt: Value(conv.systemPrompt),
            temperature: Value(conv.temperature),
            topP: Value(conv.topP),
            maxTokens: Value(conv.maxTokens),
          ),
        );
      }
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error renaming conversation $id: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _database
        .watchMessagesForConversation(conversationId)
        .map((rows) => rows.map(_mapMessageRow).toList());
  }

  @override
  Future<Result<List<ChatMessage>>> getMessages(String conversationId) async {
    try {
      final rows = await _database.getMessagesForConversation(conversationId);
      return Result.success(rows.map(_mapMessageRow).toList());
    } catch (e, st) {
      AppLogger.e('Error fetching messages: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> saveMessage(ChatMessage msg) async {
    try {
      await _database.upsertMessage(
        MessagesTableCompanion(
          id: Value(msg.id),
          conversationId: Value(msg.conversationId),
          role: Value(msg.role.name),
          content: Value(msg.content),
          createdAt: Value(msg.createdAt),
          isIncomplete: Value(msg.isIncomplete),
          isError: Value(msg.isError),
          tokenCount: Value(msg.tokenCount),
        ),
      );

      // Touch parent conversation updatedAt timestamp
      final conv = await _database.getConversationById(msg.conversationId);
      if (conv != null) {
        await _database.upsertConversation(
          ConversationsTableCompanion(
            id: Value(conv.id),
            title: Value(conv.title),
            createdAt: Value(conv.createdAt),
            updatedAt: Value(DateTime.now()),
            isPinned: Value(conv.isPinned),
            projectId: Value(conv.projectId),
            modelId: Value(conv.modelId),
            systemPrompt: Value(conv.systemPrompt),
            temperature: Value(conv.temperature),
            topP: Value(conv.topP),
            maxTokens: Value(conv.maxTokens),
          ),
        );
      }

      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error saving message: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteMessage(String id) async {
    try {
      await _database.deleteMessageById(id);
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error deleting message $id: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> markMessageIncomplete(String id, String partialContent) async {
    try {
      final existing = await _database.messagesTable.select().get();
      final target = existing.where((m) => m.id == id).firstOrNull;
      if (target != null) {
        await _database.upsertMessage(
          MessagesTableCompanion(
            id: Value(target.id),
            conversationId: Value(target.conversationId),
            role: Value(target.role),
            content: Value(partialContent),
            createdAt: Value(target.createdAt),
            isIncomplete: const Value(true),
            isError: const Value(false),
            tokenCount: Value(target.tokenCount),
          ),
        );
      }
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error marking message incomplete: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<ChatMessage>>> searchMessages(String query) async {
    try {
      final rows = await _database.searchMessages(query);
      return Result.success(rows.map(_mapMessageRow).toList());
    } catch (e, st) {
      AppLogger.e('Error searching messages: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  Conversation _mapConversationRow(ConversationsTableData row) {
    return Conversation(
      id: row.id,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isPinned: row.isPinned,
      projectId: row.projectId,
      modelId: row.modelId,
      systemPrompt: row.systemPrompt,
      temperature: row.temperature,
      topP: row.topP,
      maxTokens: row.maxTokens,
    );
  }

  ChatMessage _mapMessageRow(MessagesTableData row) {
    return ChatMessage(
      id: row.id,
      conversationId: row.conversationId,
      role: MessageRole.fromString(row.role),
      content: row.content,
      createdAt: row.createdAt,
      isIncomplete: row.isIncomplete,
      isError: row.isError,
      tokenCount: row.tokenCount,
    );
  }
}
