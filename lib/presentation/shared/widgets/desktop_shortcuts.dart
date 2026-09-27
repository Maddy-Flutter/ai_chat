import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aigui/presentation/chat/viewmodel/chat_viewmodel.dart';
import 'package:aigui/presentation/shared/providers/sidebar_provider.dart';

/// Global keyboard shortcut bindings for desktop productivity.
class DesktopShortcuts extends ConsumerWidget {
  const DesktopShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        // Ctrl+N / Cmd+N -> Start New Chat
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          ref.read(chatViewModelProvider.notifier).loadConversation(null);
          context.go('/chat');
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          ref.read(chatViewModelProvider.notifier).loadConversation(null);
          context.go('/chat');
        },

        // Ctrl+B / Cmd+B -> Toggle Sidebar
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          ref.read(sidebarExpandedProvider.notifier).toggle();
        },
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
          ref.read(sidebarExpandedProvider.notifier).toggle();
        },

        // Ctrl+, / Cmd+, -> Open Settings
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          context.go('/settings');
        },
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () {
          context.go('/settings');
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
