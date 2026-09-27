import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aigui/app/router/app_router.dart';
import 'package:aigui/app/theme/app_theme.dart';
import 'package:aigui/app/theme/theme_provider.dart';
import 'package:aigui/core/constants/app_constants.dart';

/// Root application widget configuring routing, themes, and Material 3 desktop typography.
class DesktopApp extends ConsumerWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
