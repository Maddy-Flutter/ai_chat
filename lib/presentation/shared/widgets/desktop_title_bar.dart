import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:aigui/app/theme/app_theme.dart';
import 'package:aigui/app/theme/theme_provider.dart';
import 'package:aigui/core/constants/app_constants.dart';

/// Draggable custom desktop title bar with window management controls.
class DesktopTitleBar extends ConsumerWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show window controls if running on desktop OS targets
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final colors = Theme.of(context).extension<AppColorsExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: colors?.sidebarBg ?? Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          // Draggable window area with brand icon and title
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppTheme.nvidiaGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      AppConstants.appTitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.nvidiaGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NIM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.nvidiaGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Theme quick toggle
          IconButton(
            iconSize: 15,
            splashRadius: 16,
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: colors?.textMuted,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),

          // Custom desktop window control buttons (Windows/Linux style)
          if (isDesktop && defaultTargetPlatform != TargetPlatform.macOS) ...[
            _WindowButton(
              icon: Icons.remove,
              tooltip: 'Minimize',
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon: Icons.crop_square_rounded,
              tooltip: 'Maximize / Restore',
              onPressed: () async {
                final isMax = await windowManager.isMaximized();
                if (isMax) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              isClose: true,
              onPressed: () => windowManager.close(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose
            ? Colors.redAccent.withValues(alpha: 0.85)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        child: SizedBox(
          width: 44,
          height: 38,
          child: Center(
            child: Icon(
              icon,
              size: 14,
              color: isClose ? null : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
