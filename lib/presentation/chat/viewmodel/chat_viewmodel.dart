import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:aigui/data/di/repository_providers.dart';
import 'package:aigui/domain/entities/chat_message.dart';
import 'package:aigui/domain/entities/conversation.dart';
import 'package:aigui/domain/entities/llm_model.dart';
import 'package:aigui/domain/entities/project.dart';
import 'package:aigui/domain/repositories/chat_repository.dart';
import 'package:aigui/domain/repositories/llm_repository.dart';
import 'package:aigui/domain/repositories/project_repository.dart';
import 'package:aigui/domain/repositories/settings_repository.dart';
import 'package:aigui/presentation/chat/viewmodel/chat_state.dart';
import 'package:aigui/presentation/settings/viewmodel/settings_viewmodel.dart';

/// Pure Riverpod ViewModel managing chat interactions, SSE token streaming, and cancellation.
///
/// Strictly conforms to MVVM: imports ZERO Flutter UI/widget packages.
class ChatViewModel extends Notifier<ChatState> {
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription? _streamSubscription;
  StreamSubscription<List<LlmModel>>? _modelsSubscription;
  final _uuid = const Uuid();

  ChatRepository get _chatRepo => ref.read(chatRepositoryProvider);
  LlmRepository get _llmRepo => ref.read(llmRepositoryProvider);
  ProjectRepository get _projectRepo => ref.read(projectRepositoryProvider);
  SettingsRepository get _settingsRepo => ref.read(settingsRepositoryProvider);

  @override
  ChatState build() {
    ref.onDispose(() {
      _messagesSubscription?.cancel();
      _streamSubscription?.cancel();
      _modelsSubscription?.cancel();
    });

    // Listen to settings changes so default model and model catalog stay synchronized
    ref.listen<SettingsState>(settingsViewModelProvider, (previous, next) {
      if (previous?.defaultModel != next.defaultModel) {
        if (state.conversation == null) {
          state = state.copyWith(selectedModelId: next.defaultModel);
        }
      }
      if (next.availableModels.isNotEmpty && next.availableModels != state.availableModels) {
        state = state.copyWith(availableModels: next.availableModels);
      }
    });

    // Fire initial asynchronous state setup
    Future.microtask(_init);

    return const ChatState();
  }

  Future<void> _init() async {
    // 1. Listen to cached models reactively from SQLite
    _modelsSubscription = _llmRepo.watchModels().listen((models) async {
      final defaultModelResult = await _settingsRepo.getDefaultModel();
      final defaultModel = defaultModelResult.dataOrNull ?? state.selectedModelId;

      String activeModel = state.selectedModelId;
      if (state.conversation == null) {
        activeModel = defaultModel;
      } else if (models.isNotEmpty && !models.any((m) => m.id == activeModel)) {
        activeModel = models.first.id;
      }

      state = state.copyWith(
        availableModels: models,
        selectedModelId: activeModel,
      );
    });

    // 2. Fetch models from endpoint to ensure cache is hot
    await _llmRepo.fetchModels();
    final defaultModelResult = await _settingsRepo.getDefaultModel();
    if (defaultModelResult.dataOrNull != null) {
      state = state.copyWith(selectedModelId: defaultModelResult.dataOrNull!);
    }
  }

  /// Starts a fresh conversation thread with optional project context.
  Future<void> startNewChat({Project? project, String? modelId}) async {
    await _streamSubscription?.cancel();
    await _messagesSubscription?.cancel();

    final defaultModelResult = await _settingsRepo.getDefaultModel();
    final chosenModel = modelId ?? defaultModelResult.dataOrNull ?? state.selectedModelId;

    state = state.copyWith(
      conversation: () => null,
      messages: const [],
      activeProject: () => project,
      selectedModelId: chosenModel,
      errorMessage: () => null,
    );
    _updateTokenCount();
  }

  /// Associates or disassociates a project with the current conversation.
  Future<void> setProject(Project? project) async {
    state = state.copyWith(activeProject: () => project);
    if (state.conversation != null) {
      final updated = state.conversation!.copyWith(projectId: project?.id);
      await _chatRepo.saveConversation(updated);
      state = state.copyWith(conversation: () => updated);
    }
  }

  /// Refreshes the available model catalog from NVIDIA NIM.
  Future<void> refreshModels() async {
    final result = await _llmRepo.fetchModels(forceRefresh: true);
    result.when(
      onSuccess: (models) {
        state = state.copyWith(availableModels: models);
      },
      onFailure: (failure) {
        state = state.copyWith(errorMessage: () => failure.message);
      },
    );
  }

  /// Loads an existing conversation thread or resets to a new session.
  Future<void> loadConversation(String? conversationId) async {
    await _streamSubscription?.cancel();
    await _messagesSubscription?.cancel();

    if (conversationId == null) {
      await startNewChat(project: state.activeProject);
      return;
    }

    final convResult = await _chatRepo.getConversation(conversationId);
    final conv = convResult.dataOrNull;

    if (conv != null) {
      state = state.copyWith(
        conversation: () => conv,
        selectedModelId: conv.modelId,
      );

      // Load active project if attached
      if (conv.projectId != null) {
        final projectResult = await _projectRepo.getProject(conv.projectId!);
        state = state.copyWith(activeProject: () => projectResult.dataOrNull);
      } else {
        state = state.copyWith(activeProject: () => null);
      }

      // Stream conversation messages from database in real-time
      _messagesSubscription = _chatRepo.watchMessages(conversationId).listen((messages) {
        state = state.copyWith(messages: messages);
        _updateTokenCount();
      });
    }
  }

  /// Sets the selected inference model for the current conversation.
  void setModel(String modelId) {
    state = state.copyWith(selectedModelId: modelId);
    if (state.conversation != null) {
      final updated = state.conversation!.copyWith(modelId: modelId);
      _chatRepo.saveConversation(updated);
      state = state.copyWith(conversation: () => updated);
    }
  }

  /// Sends a user message, creates conversation if needed, and streams the assistant response.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isStreaming) return;

    state = state.copyWith(errorMessage: () => null);

    // 1. Ensure active conversation exists
    var conversation = state.conversation;
    if (conversation == null) {
      final title = trimmed.length > 36 ? '${trimmed.substring(0, 36)}...' : trimmed;
      conversation = Conversation(
        id: _uuid.v4(),
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        modelId: state.selectedModelId,
        projectId: state.activeProject?.id,
      );

      await _chatRepo.saveConversation(conversation);
      state = state.copyWith(conversation: () => conversation);

      // Listen to newly created conversation messages
      await _messagesSubscription?.cancel();
      _messagesSubscription = _chatRepo.watchMessages(conversation.id).listen((messages) {
        state = state.copyWith(messages: messages);
        _updateTokenCount();
      });
    }

    // 2. Persist User Message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversation.id,
      role: MessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );
    await _chatRepo.saveMessage(userMessage);

    // 3. Prepare Assistant Streaming Message Placeholder
    final assistantMessageId = _uuid.v4();
    final assistantMessage = ChatMessage(
      id: assistantMessageId,
      conversationId: conversation.id,
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );
    await _chatRepo.saveMessage(assistantMessage);

    state = state.copyWith(
      isStreaming: true,
      streamingMessageId: () => assistantMessageId,
    );

    // 4. Retrieve Project Context & System Prompt if attached
    final globalPromptResult = await _settingsRepo.getDefaultSystemPrompt();
    final globalPrompt = globalPromptResult.dataOrNull;

    final promptParts = <String>[];
    if (conversation.systemPrompt != null && conversation.systemPrompt!.trim().isNotEmpty) {
      promptParts.add(conversation.systemPrompt!.trim());
    } else if (globalPrompt != null && globalPrompt.trim().isNotEmpty) {
      promptParts.add(globalPrompt.trim());
    }

    if (state.activeProject != null) {
      final contextResult = await _projectRepo.getProjectContext(
        state.activeProject!.id,
      );
      final projectContext = contextResult.dataOrNull ?? '';
      if (projectContext.trim().isNotEmpty) {
        promptParts.add(projectContext.trim());
      }
    }
    final combinedSystemPrompt = promptParts.isNotEmpty ? promptParts.join('\n\n') : null;

    // 5. Build clean dialog history:
    // Only include successfully answered user/assistant pairs from previous turns,
    // plus the current new user message. Never concatenate retried user inputs.
    final accumulatedContent = StringBuffer();
    final historyForLlm = <ChatMessage>[];

    for (int i = 0; i < state.messages.length - 1; i++) {
      final msg = state.messages[i];
      final next = state.messages[i + 1];

      // Pair of valid user message and successful assistant response
      if (msg.role == MessageRole.user &&
          next.role == MessageRole.assistant &&
          !next.isError &&
          !next.isIncomplete &&
          next.content.trim().isNotEmpty &&
          msg.content.trim().isNotEmpty &&
          next.id != assistantMessageId) {
        historyForLlm.add(msg);
        historyForLlm.add(next);
      }
    }
    historyForLlm.add(userMessage);

    // 6. Initiate SSE Streaming from NVIDIA NIM
    final stream = _llmRepo.streamChatCompletion(
      modelId: state.selectedModelId,
      messages: historyForLlm,
      temperature: conversation.temperature,
      topP: conversation.topP,
      maxTokens: conversation.maxTokens,
      systemPrompt: combinedSystemPrompt,
    );

    _streamSubscription = stream.listen(
      (result) {
        result.when(
          onSuccess: (delta) {
            accumulatedContent.write(delta);
            _chatRepo.saveMessage(
              assistantMessage.copyWith(
                content: accumulatedContent.toString(),
                isStreaming: true,
              ),
            );
          },
          onFailure: (failure) {
            final text = accumulatedContent.toString().trim();
            if (text.isEmpty) {
              _chatRepo.saveMessage(
                assistantMessage.copyWith(
                  content: '⚠️ ${failure.message}',
                  isStreaming: false,
                  isIncomplete: false,
                  isError: true,
                ),
              );
            } else {
              _chatRepo.markMessageIncomplete(
                assistantMessageId,
                text,
              );
            }
            state = state.copyWith(
              isStreaming: false,
              streamingMessageId: () => null,
              errorMessage: () => failure.message,
            );
          },
        );
      },
      onDone: () async {
        await _chatRepo.saveMessage(
          assistantMessage.copyWith(
            content: accumulatedContent.toString(),
            isStreaming: false,
            isIncomplete: false,
          ),
        );
        state = state.copyWith(
          isStreaming: false,
          streamingMessageId: () => null,
        );
        _updateTokenCount();
      },
      onError: (err) {
        _chatRepo.markMessageIncomplete(
          assistantMessageId,
          accumulatedContent.toString(),
        );
        state = state.copyWith(
          isStreaming: false,
          streamingMessageId: () => null,
          errorMessage: () => err.toString(),
        );
      },
      cancelOnError: true,
    );
  }

  /// Cancels in-flight SSE stream mid-generation and retains the partial message marked as incomplete.
  Future<void> stopStreaming() async {
    if (!state.isStreaming || state.streamingMessageId == null) return;

    final targetId = state.streamingMessageId!;
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    final currentMsg = state.messages.where((m) => m.id == targetId).firstOrNull;
    final partialText = currentMsg?.content ?? '';

    await _chatRepo.markMessageIncomplete(targetId, partialText);

    state = state.copyWith(
      isStreaming: false,
      streamingMessageId: () => null,
    );
  }

  /// Regenerates the last assistant response.
  Future<void> regenerateLast() async {
    if (state.isStreaming || state.messages.isEmpty) return;

    final last = state.messages.last;
    if (last.role == MessageRole.assistant) {
      await _chatRepo.deleteMessage(last.id);
    }

    final conversation = state.conversation;
    if (conversation == null) return;

    final assistantMessageId = _uuid.v4();
    final assistantMessage = ChatMessage(
      id: assistantMessageId,
      conversationId: conversation.id,
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );
    await _chatRepo.saveMessage(assistantMessage);

    state = state.copyWith(
      isStreaming: true,
      streamingMessageId: () => assistantMessageId,
      errorMessage: () => null,
    );

    final globalPromptResult = await _settingsRepo.getDefaultSystemPrompt();
    final globalPrompt = globalPromptResult.dataOrNull;

    final promptParts = <String>[];
    if (conversation.systemPrompt != null && conversation.systemPrompt!.trim().isNotEmpty) {
      promptParts.add(conversation.systemPrompt!.trim());
    } else if (globalPrompt != null && globalPrompt.trim().isNotEmpty) {
      promptParts.add(globalPrompt.trim());
    }

    if (state.activeProject != null) {
      final contextResult = await _projectRepo.getProjectContext(state.activeProject!.id);
      final projectContext = contextResult.dataOrNull ?? '';
      if (projectContext.trim().isNotEmpty) {
        promptParts.add(projectContext.trim());
      }
    }
    final combinedSystemPrompt = promptParts.isNotEmpty ? promptParts.join('\n\n') : null;

    final accumulatedContent = StringBuffer();
    final userMsgToRegenerate = state.messages.where((m) => m.role == MessageRole.user).lastOrNull;
    if (userMsgToRegenerate == null) return;

    final historyForLlm = <ChatMessage>[];
    for (int i = 0; i < state.messages.length - 1; i++) {
      final msg = state.messages[i];
      final next = state.messages[i + 1];
      if (msg.id == userMsgToRegenerate.id) break;

      if (msg.role == MessageRole.user &&
          next.role == MessageRole.assistant &&
          !next.isError &&
          !next.isIncomplete &&
          next.content.trim().isNotEmpty &&
          msg.content.trim().isNotEmpty &&
          next.id != assistantMessageId) {
        historyForLlm.add(msg);
        historyForLlm.add(next);
      }
    }
    historyForLlm.add(userMsgToRegenerate);

    final stream = _llmRepo.streamChatCompletion(
      modelId: state.selectedModelId,
      messages: historyForLlm,
      temperature: conversation.temperature,
      topP: conversation.topP,
      maxTokens: conversation.maxTokens,
      systemPrompt: combinedSystemPrompt,
    );

    _streamSubscription = stream.listen(
      (result) {
        result.when(
          onSuccess: (delta) {
            accumulatedContent.write(delta);
            _chatRepo.saveMessage(
              assistantMessage.copyWith(
                content: accumulatedContent.toString(),
                isStreaming: true,
              ),
            );
          },
          onFailure: (failure) {
            final text = accumulatedContent.toString().trim();
            if (text.isEmpty) {
              _chatRepo.saveMessage(
                assistantMessage.copyWith(
                  content: '⚠️ ${failure.message}',
                  isStreaming: false,
                  isIncomplete: false,
                  isError: true,
                ),
              );
            } else {
              _chatRepo.markMessageIncomplete(
                assistantMessageId,
                text,
              );
            }
            state = state.copyWith(
              isStreaming: false,
              streamingMessageId: () => null,
              errorMessage: () => failure.message,
            );
          },
        );
      },
      onDone: () async {
        await _chatRepo.saveMessage(
          assistantMessage.copyWith(
            content: accumulatedContent.toString(),
            isStreaming: false,
            isIncomplete: false,
          ),
        );
        state = state.copyWith(
          isStreaming: false,
          streamingMessageId: () => null,
        );
        _updateTokenCount();
      },
      onError: (err) {
        _chatRepo.markMessageIncomplete(
          assistantMessageId,
          accumulatedContent.toString(),
        );
        state = state.copyWith(
          isStreaming: false,
          streamingMessageId: () => null,
          errorMessage: () => err.toString(),
        );
      },
      cancelOnError: true,
    );
  }

  /// Deletes a specific message by its ID.
  Future<void> deleteMessage(String messageId) async {
    await _chatRepo.deleteMessage(messageId);
  }

  /// Edits a previous user message, deletes subsequent turns, and regenerates.
  Future<void> editAndResend(String messageId, String newText) async {
    if (state.isStreaming) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    // Delete target message and all subsequent messages
    final toDelete = state.messages.sublist(index);
    for (final msg in toDelete) {
      await _chatRepo.deleteMessage(msg.id);
    }

    await sendMessage(newText);
  }

  void clearError() {
    state = state.copyWith(errorMessage: () => null);
  }

  void _updateTokenCount() {
    int chars = 0;
    for (final m in state.messages) {
      chars += m.content.length;
    }
    state = state.copyWith(approximateTokenCount: chars ~/ 4);
  }
}

/// Provider exposing [ChatViewModel] and its immutable [ChatState].
final chatViewModelProvider =
    NotifierProvider<ChatViewModel, ChatState>(ChatViewModel.new);
