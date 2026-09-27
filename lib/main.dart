import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:aigui/app/app.dart';
import 'package:aigui/core/constants/app_constants.dart';
import 'package:aigui/core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window initialization and constraint bounds
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(
          AppConstants.windowDefaultWidth,
          AppConstants.windowDefaultHeight,
        ),
        minimumSize: Size(
          AppConstants.windowMinWidth,
          AppConstants.windowMinHeight,
        ),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: AppConstants.appTitle,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e, st) {
      // Graceful fallback if window_manager cannot attach in test or headless modes
      AppLogger.e('Failed to initialize desktop windowManager: $e', e, st);
    }
  }

  runApp(
    const ProviderScope(
      child: DesktopApp(),
    ),
  );
}
