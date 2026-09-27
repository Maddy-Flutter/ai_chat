import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:aigui/presentation/shared/widgets/desktop_shortcuts.dart';
import 'package:aigui/presentation/shared/widgets/desktop_sidebar.dart';
import 'package:aigui/presentation/shared/widgets/desktop_title_bar.dart';

/// Top-level desktop shell providing window frame title bar, navigation sidebar, and main body.
class DesktopScaffold extends StatelessWidget {
  const DesktopScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // Current URI path to highlight sidebar active states
    final location = GoRouterState.of(context).uri.toString();

    return DesktopShortcuts(
      child: Scaffold(
        body: Column(
          children: [
            // Native-feel desktop draggable title bar
            const DesktopTitleBar(),

            // Main horizontal desktop layout: sidebar + active screen
            Expanded(
              child: Row(
                children: [
                  DesktopSidebar(currentPath: location),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
