import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aigui/app/theme/app_theme.dart';
import 'package:aigui/domain/entities/conversation.dart';
import 'package:aigui/presentation/chat/viewmodel/chat_viewmodel.dart';
import 'package:aigui/presentation/history/viewmodel/history_viewmodel.dart';
import 'package:aigui/presentation/shared/providers/sidebar_provider.dart';

/// Left sidebar navigation panel for desktop chat, projects, and live conversation history.
class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key, required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(sidebarExpandedProvider);
    final historyState = ref.watch(historyViewModelProvider);
    final colors = Theme.of(context).extension<AppColorsExtension>();

    // Determine current active conversation ID from URL path
    String? activeConversationId;
    if (currentPath.startsWith('/chat/')) {
      activeConversationId = currentPath.substring('/chat/'.length);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isExpanded ? 260 : 64,
      decoration: BoxDecoration(
        color: colors?.sidebarBg ?? Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header action: New Chat button & collapse toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: isExpanded
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.nvidiaGreen,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            ref.read(chatViewModelProvider.notifier).startNewChat(
                              project: ref.read(chatViewModelProvider).activeProject,
                            );
                            context.go('/chat');
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'New Chat',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : IconButton(
                          tooltip: 'New Chat',
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.nvidiaGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            ref.read(chatViewModelProvider.notifier).startNewChat(
                              project: ref.read(chatViewModelProvider).activeProject,
                            );
                            context.go('/chat');
                          },
                          icon: const Icon(Icons.add_rounded, size: 20),
                        ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
                  iconSize: 18,
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_double_arrow_left_rounded
                        : Icons.keyboard_double_arrow_right_rounded,
                    color: colors?.textMuted,
                  ),
                  onPressed: () {
                    ref.read(sidebarExpandedProvider.notifier).toggle();
                  },
                ),
              ],
            ),
          ),

          const Divider(),

          // Main Navigation Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  isSelected: currentPath.startsWith('/chat'),
                  isExpanded: isExpanded,
                  onTap: () => context.go('/chat'),
                ),
                const SizedBox(height: 2),
                _NavTile(
                  icon: Icons.folder_open_rounded,
                  activeIcon: Icons.folder_rounded,
                  label: 'Projects',
                  isSelected: currentPath.startsWith('/projects'),
                  isExpanded: isExpanded,
                  onTap: () => context.go('/projects'),
                ),
                const SizedBox(height: 2),
                _NavTile(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: currentPath.startsWith('/settings'),
                  isExpanded: isExpanded,
                  onTap: () => context.go('/settings'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Search Field & Conversation History
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
                  ),
                ),
                child: TextField(
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    hintStyle: TextStyle(fontSize: 12, color: colors?.textMuted),
                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: colors?.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) {
                    ref.read(historyViewModelProvider.notifier).search(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // History List
          Expanded(
            child: isExpanded
                ? historyState.isSearching
                    ? _SearchResultsList(
                        results: historyState.searchResults,
                        activeId: activeConversationId,
                      )
                    : _GroupedHistoryList(
                        state: historyState,
                        activeId: activeConversationId,
                      )
                : const SizedBox.shrink(),
          ),

          const Divider(),

          // Bottom API status banner
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.nvidiaGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'NVIDIA NIM Ready',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: colors?.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedHistoryList extends StatelessWidget {
  const _GroupedHistoryList({required this.state, required this.activeId});

  final HistoryState state;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();

    final hasAny = state.pinned.isNotEmpty ||
        state.today.isNotEmpty ||
        state.yesterday.isNotEmpty ||
        state.previous7Days.isNotEmpty ||
        state.older.isNotEmpty;

    if (!hasAny) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No conversations yet',
            style: TextStyle(fontSize: 12, color: colors?.textMuted),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      children: [
        if (state.pinned.isNotEmpty) ...[
          const _SectionLabel(label: 'PINNED'),
          for (final c in state.pinned)
            _ConversationTile(conversation: c, isSelected: c.id == activeId),
        ],
        if (state.today.isNotEmpty) ...[
          const _SectionLabel(label: 'TODAY'),
          for (final c in state.today)
            _ConversationTile(conversation: c, isSelected: c.id == activeId),
        ],
        if (state.yesterday.isNotEmpty) ...[
          const _SectionLabel(label: 'YESTERDAY'),
          for (final c in state.yesterday)
            _ConversationTile(conversation: c, isSelected: c.id == activeId),
        ],
        if (state.previous7Days.isNotEmpty) ...[
          const _SectionLabel(label: 'PREVIOUS 7 DAYS'),
          for (final c in state.previous7Days)
            _ConversationTile(conversation: c, isSelected: c.id == activeId),
        ],
        if (state.older.isNotEmpty) ...[
          const _SectionLabel(label: 'OLDER'),
          for (final c in state.older)
            _ConversationTile(conversation: c, isSelected: c.id == activeId),
        ],
      ],
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.results, required this.activeId});

  final List<Conversation> results;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No matching conversations',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final c = results[index];
        return _ConversationTile(conversation: c, isSelected: c.id == activeId);
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: colors?.textMuted,
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
  });

  final Conversation conversation;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>();

    return Material(
      color: isSelected
          ? AppTheme.nvidiaGreen.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => context.go('/chat/${conversation.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(
                conversation.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 14,
                color: isSelected ? AppTheme.nvidiaGreen : colors?.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.onSurface : colors?.textMuted,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                iconSize: 14,
                padding: EdgeInsets.zero,
                tooltip: 'Options',
                icon: Icon(Icons.more_vert_rounded, size: 14, color: colors?.textMuted),
                onSelected: (action) {
                  if (action == 'pin') {
                    ref.read(historyViewModelProvider.notifier).togglePin(conversation.id);
                  } else if (action == 'rename') {
                    _showRenameDialog(context, ref, conversation);
                  } else if (action == 'delete') {
                    ref.read(historyViewModelProvider.notifier).delete(conversation.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(conversation.isPinned ? 'Unpin' : 'Pin to top'),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Conversation c) {
    final controller = TextEditingController(text: c.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.nvidiaGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(historyViewModelProvider.notifier).rename(c.id, newTitle);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>();

    return Tooltip(
      message: isExpanded ? '' : label,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: isSelected
            ? AppTheme.nvidiaGreen.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment:
                  isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 18,
                  color: isSelected ? AppTheme.nvidiaGreen : colors?.textMuted,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : colors?.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
