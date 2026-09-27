import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aigui/presentation/chat/view/chat_page.dart';
import 'package:aigui/presentation/projects/view/projects_page.dart';
import 'package:aigui/presentation/settings/view/settings_page.dart';
import 'package:aigui/presentation/shared/desktop_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _chatNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chat');
final _projectsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'projects');
final _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

/// Provider exposing the application's declarative GoRouter instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DesktopScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 1: Chat & Conversation Threads
          StatefulShellBranch(
            navigatorKey: _chatNavigatorKey,
            routes: [
              GoRoute(
                path: '/chat',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ChatPage(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id'];
                      return NoTransitionPage(
                        child: ChatPage(conversationId: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Contextual Projects
          StatefulShellBranch(
            navigatorKey: _projectsNavigatorKey,
            routes: [
              GoRoute(
                path: '/projects',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProjectsPage(),
                ),
              ),
            ],
          ),

          // Branch 3: Settings & Preferences
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsPage(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
