import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aigui/app/theme/app_theme.dart';
import 'package:aigui/domain/entities/chat_message.dart';
import 'package:aigui/domain/entities/llm_model.dart';
import 'package:aigui/domain/entities/project.dart';
import 'package:aigui/presentation/chat/view/widgets/markdown_message_view.dart';
import 'package:aigui/presentation/chat/viewmodel/chat_viewmodel.dart';
import 'package:aigui/presentation/projects/viewmodel/projects_viewmodel.dart';
import 'package:go_router/go_router.dart';

/// Primary desktop conversation screen implementing streaming chat, auto-scroll, and message editing.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  // Allowed controllers lifecycle only — business state remains strictly in Riverpod
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _scrollController = ScrollController();
    _focusNode = FocusNode();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.conversationId != null) {
        ref.read(chatViewModelProvider.notifier).loadConversation(widget.conversationId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      ref.read(chatViewModelProvider.notifier).loadConversation(widget.conversationId);
      _userScrolledUp = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // If user is more than 80px away from bottom, pause auto-scrolling
    _userScrolledUp = (maxScroll - currentScroll) > 80;
  }

  void _scrollToBottom() {
    if (_userScrolledUp || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    ref.read(chatViewModelProvider.notifier).sendMessage(text);
    _textController.clear();
    _userScrolledUp = false;
    _focusNode.requestFocus();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatViewModelProvider);
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>();

    // Scroll to bottom during streaming updates
    if (state.isStreaming) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: colors?.chatBg ?? theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header Bar
          _ChatHeader(
            selectedModelId: state.selectedModelId,
            availableModels: state.availableModels,
            activeProject: state.activeProject,
            tokenCount: state.approximateTokenCount,
            onModelSelected: (modelId) {
              ref.read(chatViewModelProvider.notifier).setModel(modelId);
            },
          ),

          // Error Banner if present
          if (state.errorMessage != null)
            _ErrorBanner(
              message: state.errorMessage!,
              onDismiss: () => ref.read(chatViewModelProvider.notifier).clearError(),
            ),

          // Main Conversation Area
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyChatState(
                    onStarterSelected: (prompt) {
                      _textController.text = prompt;
                      _handleSend();
                    },
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      final isLast = index == state.messages.length - 1;

                      return _MessageItem(
                        key: ValueKey(message.id),
                        message: message,
                        isLastAssistant: isLast && message.role == MessageRole.assistant,
                        isStreaming: state.isStreaming && state.streamingMessageId == message.id,
                        onDelete: () => ref
                            .read(chatViewModelProvider.notifier)
                            .deleteMessage(message.id),
                        onRegenerate: isLast && message.role == MessageRole.assistant
                            ? () => ref.read(chatViewModelProvider.notifier).regenerateLast()
                            : null,
                        onEditResend: (newText) => ref
                            .read(chatViewModelProvider.notifier)
                            .editAndResend(message.id, newText),
                      );
                    },
                  ),
          ),

          // Stop Streaming Action Pill
          if (state.isStreaming)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () => ref.read(chatViewModelProvider.notifier).stopStreaming(),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Stop generating', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),

          // Bottom Input Dock
          _ChatInputDock(
            controller: _textController,
            focusNode: _focusNode,
            isStreaming: state.isStreaming,
            onSend: _handleSend,
            onStop: () => ref.read(chatViewModelProvider.notifier).stopStreaming(),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({
    required this.selectedModelId,
    required this.availableModels,
    required this.onModelSelected,
    this.activeProject,
    this.tokenCount = 0,
  });

  final String selectedModelId;
  final List<LlmModel> availableModels;
  final ValueChanged<String> onModelSelected;
  final Project? activeProject;
  final int tokenCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>();
    final displayName = selectedModelId.contains('/')
        ? selectedModelId.split('/').last
        : selectedModelId;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: colors?.subtleBorder ?? theme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1. Interactive Model Selector Pill
          Flexible(
            child: Tooltip(
              message: 'Select AI Model ($selectedModelId)',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showModelDialog(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.nvidiaGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.nvidiaGreen.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.memory_rounded,
                        size: 14,
                        color: AppTheme.nvidiaGreen,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.nvidiaGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: colors?.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // 2. Interactive Project Selector Pill
          Flexible(
            child: Tooltip(
              message: activeProject != null
                  ? 'Active Project: ${activeProject!.name} (Click to switch or detach)'
                  : 'Attach a Project Workspace for Code Context',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showProjectDialog(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: activeProject != null
                        ? AppTheme.nvidiaGreen.withValues(alpha: 0.08)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: activeProject != null
                          ? AppTheme.nvidiaGreen.withValues(alpha: 0.35)
                          : colors?.subtleBorder ?? theme.dividerColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activeProject != null ? Icons.folder_rounded : Icons.folder_open_outlined,
                        size: 13,
                        color: activeProject != null ? AppTheme.nvidiaGreen : colors?.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          activeProject != null ? activeProject!.name : 'Attach Project',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: activeProject != null ? FontWeight.w600 : FontWeight.normal,
                            color: activeProject != null ? null : colors?.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 13,
                        color: colors?.textMuted,
                      ),
                      if (activeProject != null) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Detach project from chat',
                          child: InkWell(
                            onTap: () {
                              ref.read(chatViewModelProvider.notifier).setProject(null);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: colors?.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // 3. Token count indicator
          if (tokenCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors?.subtleBorder ?? theme.dividerColor,
                ),
              ),
              child: Text(
                '~$tokenCount tokens',
                style: TextStyle(
                  fontSize: 11,
                  color: colors?.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showModelDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _ModelSelectionDialog(
        currentModelId: selectedModelId,
        onSelected: (modelId) {
          onModelSelected(modelId);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showProjectDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _ProjectSelectionDialog(
        currentProject: activeProject,
        onProjectSelected: (project) {
          ref.read(chatViewModelProvider.notifier).setProject(project);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _ModelSelectionDialog extends ConsumerWidget {
  const _ModelSelectionDialog({
    required this.currentModelId,
    required this.onSelected,
  });

  final String currentModelId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>();
    final chatState = ref.watch(chatViewModelProvider);
    final searchNotifier = ValueNotifier<String>('');
    final providerNotifier = ValueNotifier<String>('All');
    final searchController = TextEditingController();

    final providers = ['All', 'Moonshot', 'Meta', 'Mistral', 'DeepSeek', 'NVIDIA'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: theme.colorScheme.surface,
      child: SizedBox(
        width: 580,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory_rounded, size: 20, color: AppTheme.nvidiaGreen),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select AI Model',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh models from NVIDIA NIM',
                    iconSize: 18,
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      ref.read(chatViewModelProvider.notifier).refreshModels();
                    },
                  ),
                  IconButton(
                    iconSize: 18,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search field
              TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search models (e.g. kimi, llama, mistral, deepseek)...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: ValueListenableBuilder<String>(
                    valueListenable: searchNotifier,
                    builder: (context, query, _) {
                      return query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                searchController.clear();
                                searchNotifier.value = '';
                              },
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colors?.subtleBorder ?? theme.dividerColor,
                    ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) {
                  searchNotifier.value = val;
                },
              ),
              const SizedBox(height: 10),

              // Provider Filter Chips
              ValueListenableBuilder<String>(
                valueListenable: providerNotifier,
                builder: (context, activeProvider, _) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: providers.map((prov) {
                        final isSelected = prov == activeProvider;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              prov,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.nvidiaGreen.withValues(alpha: 0.2),
                            onSelected: (_) {
                              providerNotifier.value = prov;
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Scrollable Filtered Models List
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: searchNotifier,
                  builder: (context, searchQuery, _) {
                    return ValueListenableBuilder<String>(
                      valueListenable: providerNotifier,
                      builder: (context, activeProvider, _) {
                        final q = searchQuery.trim().toLowerCase();
                        final p = activeProvider.toLowerCase();

                        // Ensure currentModelId is always representable
                        final allModels = [...chatState.availableModels];
                        if (currentModelId.isNotEmpty &&
                            !allModels.any((m) => m.id == currentModelId)) {
                          allModels.insert(
                            0,
                            LlmModel(
                              id: currentModelId,
                              name: currentModelId.split('/').last,
                              ownedBy: currentModelId.contains('/')
                                  ? currentModelId.split('/').first
                                  : 'nvidia',
                            ),
                          );
                        }

                        final filtered = allModels.where((m) {
                          final matchesQuery = q.isEmpty ||
                              m.id.toLowerCase().contains(q) ||
                              m.name.toLowerCase().contains(q) ||
                              m.ownedBy.toLowerCase().contains(q);
                          if (!matchesQuery) return false;

                          if (p == 'all') return true;
                          if (p == 'moonshot') return m.id.toLowerCase().contains('moonshot');
                          if (p == 'meta') {
                            return m.id.toLowerCase().contains('meta') ||
                                m.id.toLowerCase().contains('llama');
                          }
                          if (p == 'mistral') {
                            return m.id.toLowerCase().contains('mistral') ||
                                m.id.toLowerCase().contains('mixtral');
                          }
                          if (p == 'deepseek') return m.id.toLowerCase().contains('deepseek');
                          if (p == 'nvidia') return m.id.toLowerCase().contains('nvidia');
                          return true;
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 36, color: colors?.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'No matching models found',
                                  style: TextStyle(fontSize: 13, color: colors?.textMuted),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ref.read(chatViewModelProvider.notifier).refreshModels();
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 14),
                                  label: const Text('Refresh from NVIDIA NIM'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final model = filtered[index];
                            final isSelected = model.id == currentModelId;

                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: AppTheme.nvidiaGreen.withValues(alpha: 0.1),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              leading: Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected ? AppTheme.nvidiaGreen : colors?.textMuted,
                              ),
                              title: Text(
                                model.id,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                'Provider: ${model.ownedBy} • ${model.contextLength ~/ 1024}k context',
                                style: TextStyle(fontSize: 11, color: colors?.textMuted),
                              ),
                              onTap: () => onSelected(model.id),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectSelectionDialog extends ConsumerWidget {
  const _ProjectSelectionDialog({
    required this.currentProject,
    required this.onProjectSelected,
  });

  final Project? currentProject;
  final ValueChanged<Project?> onProjectSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>();
    final projectsState = ref.watch(projectsViewModelProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: theme.colorScheme.surface,
      child: SizedBox(
        width: 520,
        height: 460,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_rounded, size: 20, color: AppTheme.nvidiaGreen),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select Project Workspace',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Attaching a project injects its custom system instructions and enabled files directly into the conversation context.',
                style: TextStyle(fontSize: 12, color: colors?.textMuted),
              ),
              const SizedBox(height: 12),

              // Option 1: None (Global Chat)
              ListTile(
                dense: true,
                selected: currentProject == null,
                selectedTileColor: AppTheme.nvidiaGreen.withValues(alpha: 0.1),
                leading: Icon(
                  currentProject == null ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  size: 18,
                  color: currentProject == null ? AppTheme.nvidiaGreen : colors?.textMuted,
                ),
                title: const Text('None (Global Chat)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('No project files or custom instructions attached', style: TextStyle(fontSize: 11, color: colors?.textMuted)),
                onTap: () => onProjectSelected(null),
              ),

              const Divider(),

              // Projects List
              if (projectsState.projects.isEmpty) ...[
                Expanded(
                  child: Center(
                    child: Text(
                      'No project workspaces created yet.',
                      style: TextStyle(fontSize: 12.5, color: colors?.textMuted),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ListView.separated(
                    itemCount: projectsState.projects.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final project = projectsState.projects[index];
                      final isSelected = currentProject?.id == project.id;

                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: AppTheme.nvidiaGreen.withValues(alpha: 0.1),
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.folder_rounded,
                          size: 18,
                          color: isSelected ? AppTheme.nvidiaGreen : colors?.textMuted,
                        ),
                        title: Text(
                          project.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: project.folderPath != null
                            ? Text(
                                project.folderPath!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: colors?.textMuted),
                              )
                            : (project.description.isNotEmpty
                                ? Text(
                                    project.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: colors?.textMuted),
                                  )
                                : null),
                        onTap: () => onProjectSelected(project),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/projects');
                    },
                    icon: const Icon(Icons.settings_rounded, size: 14),
                    label: const Text('Manage Projects'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.redAccent.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Colors.redAccent),
            ),
          ),
          IconButton(
            iconSize: 16,
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.onStarterSelected});

  final ValueChanged<String> onStarterSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.nvidiaGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.nvidiaGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 28,
                    color: AppTheme.nvidiaGreen,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'What would you like to build today?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Accelerated by NVIDIA NIM microservices. Enter a message below or pick a prompt starter to begin streaming high-throughput LLM responses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: colors?.textMuted,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _QuickStarterCard(
                    icon: Icons.code_rounded,
                    title: 'Explain clean architecture',
                    subtitle: 'Review MVVM separation in Flutter',
                    onTap: () => onStarterSelected(
                      'Explain the core benefits of MVVM architecture in Flutter desktop development.',
                    ),
                  ),
                  _QuickStarterCard(
                    icon: Icons.article_outlined,
                    title: 'Draft technical RFC',
                    subtitle: 'Create spec for streaming SSE',
                    onTap: () => onStarterSelected(
                      'Draft a technical design specification for high-throughput Server-Sent Events streaming in client applications.',
                    ),
                  ),
                  _QuickStarterCard(
                    icon: Icons.speed_rounded,
                    title: 'Optimize query throughput',
                    subtitle: 'Database index tuning & caching',
                    onTap: () => onStarterSelected(
                      'Provide concrete database tuning advice for SQLite indexing under high write concurrency.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStarterCard extends StatelessWidget {
  const _QuickStarterCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 205,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.nvidiaGreen),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: colors?.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  const _MessageItem({
    super.key,
    required this.message,
    required this.isLastAssistant,
    required this.isStreaming,
    required this.onDelete,
    this.onRegenerate,
    required this.onEditResend,
  });

  final ChatMessage message;
  final bool isLastAssistant;
  final bool isStreaming;
  final VoidCallback onDelete;
  final VoidCallback? onRegenerate;
  final ValueChanged<String> onEditResend;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final colors = Theme.of(context).extension<AppColorsExtension>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 12, top: 4),
              decoration: BoxDecoration(
                color: AppTheme.nvidiaGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(Icons.bolt_rounded, size: 18, color: Colors.black),
              ),
            ),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? (colors?.userBubbleBg ?? Theme.of(context).colorScheme.surface)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isUser
                          ? Border.all(
                              color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isUser)
                          SelectableText(
                            message.content,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          )
                        else
                          MarkdownMessageView(
                            content: message.content.isEmpty && isStreaming
                                ? '▌'
                                : message.content,
                            isStreaming: isStreaming,
                          ),

                        if (message.isError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 13, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Text(
                                  'Generation failed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.redAccent.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (message.isIncomplete)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 13, color: Colors.orangeAccent),
                                const SizedBox(width: 4),
                                Text(
                                  'Generation cancelled or interrupted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orangeAccent.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Message Action Bar
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Copy Message',
                          iconSize: 14,
                          splashRadius: 14,
                          icon: Icon(Icons.copy_rounded, color: colors?.textMuted),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: message.content));
                          },
                        ),
                        if (isUser) ...[
                          IconButton(
                            tooltip: 'Edit & Resend',
                            iconSize: 14,
                            splashRadius: 14,
                            icon: Icon(Icons.edit_outlined, color: colors?.textMuted),
                            onPressed: () {
                              _showEditDialog(context, message.content, onEditResend);
                            },
                          ),
                        ],
                        if (!isUser && onRegenerate != null && !isStreaming) ...[
                          IconButton(
                            tooltip: 'Regenerate Response',
                            iconSize: 14,
                            splashRadius: 14,
                            icon: Icon(Icons.refresh_rounded, color: colors?.textMuted),
                            onPressed: onRegenerate,
                          ),
                        ],
                        IconButton(
                          tooltip: 'Delete',
                          iconSize: 14,
                          splashRadius: 14,
                          icon: Icon(Icons.delete_outline_rounded, color: colors?.textMuted),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String initialText,
    ValueChanged<String> onConfirm,
  ) {
    final editController = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.nvidiaGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm(editController.text);
            },
            child: const Text('Resend'),
          ),
        ],
      ),
    );
  }
}

class _ChatInputDock extends StatelessWidget {
  const _ChatInputDock({
    required this.controller,
    required this.focusNode,
    required this.isStreaming,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      onSend();
                    }
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Message NVIDIA NIM model... (Enter sends, Shift+Enter newline)',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: colors?.textMuted.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isStreaming)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: IconButton(
                    tooltip: 'Stop generation',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    onPressed: onStop,
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: IconButton(
                    tooltip: 'Send message (Enter)',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.nvidiaGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    onPressed: onSend,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
