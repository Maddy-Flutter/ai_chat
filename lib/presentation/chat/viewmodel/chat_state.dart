import 'package:aigui/core/constants/app_constants.dart';
import 'package:aigui/domain/entities/chat_message.dart';
import 'package:aigui/domain/entities/conversation.dart';
import 'package:aigui/domain/entities/llm_model.dart';
import 'package:aigui/domain/entities/project.dart';

/// Immutable UI state for the chat screen.
class ChatState {
  const ChatState({
    this.conversation,
    this.messages = const [],
    this.isStreaming = false,
    this.streamingMessageId,
    this.selectedModelId = AppConstants.defaultModelId,
    this.availableModels = const [],
    this.activeProject,
    this.errorMessage,
    this.approximateTokenCount = 0,
  });

  final Conversation? conversation;
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String? streamingMessageId;
  final String selectedModelId;
  final List<LlmModel> availableModels;
  final Project? activeProject;
  final String? errorMessage;
  final int approximateTokenCount;

  ChatState copyWith({
    Conversation? Function()? conversation,
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? Function()? streamingMessageId,
    String? selectedModelId,
    List<LlmModel>? availableModels,
    Project? Function()? activeProject,
    String? Function()? errorMessage,
    int? approximateTokenCount,
  }) {
    return ChatState(
      conversation: conversation != null ? conversation() : this.conversation,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingMessageId: streamingMessageId != null ? streamingMessageId() : this.streamingMessageId,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      availableModels: availableModels ?? this.availableModels,
      activeProject: activeProject != null ? activeProject() : this.activeProject,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      approximateTokenCount: approximateTokenCount ?? this.approximateTokenCount,
    );
  }
}
