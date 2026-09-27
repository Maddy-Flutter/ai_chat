import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aigui/app/app.dart';

void main() {
  testWidgets('DesktopApp launches and displays shell and navigation tabs',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: DesktopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify top-level desktop scaffold and navigation bar elements render
    expect(find.text('New Chat'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('ChatPage model and project selection dialogs open without intrinsic viewport errors',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: DesktopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Open Model Selection Dialog
    final modelFinder = find.byIcon(Icons.memory_rounded);
    expect(modelFinder, findsWidgets);
    await tester.tap(modelFinder.first);
    await tester.pumpAndSettle();

    // Verify dialog opened cleanly without RenderViewport intrinsic errors
    expect(find.text('Select AI Model'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Close Model Dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Select AI Model'), findsNothing);

    // 2. Open Project Selection Dialog
    final projectPillFinder = find.text('Attach Project');
    expect(projectPillFinder, findsOneWidget);
    await tester.tap(projectPillFinder);
    await tester.pumpAndSettle();

    // Verify dialog opened cleanly
    expect(find.text('Select Project Workspace'), findsOneWidget);
    expect(find.text('None (Global Chat)'), findsOneWidget);

    // Select None / Close dialog
    await tester.tap(find.text('None (Global Chat)'));
    await tester.pumpAndSettle();
    expect(find.text('Select Project Workspace'), findsNothing);
  });
}

