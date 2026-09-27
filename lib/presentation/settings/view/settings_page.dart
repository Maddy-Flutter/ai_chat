import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aigui/app/theme/app_theme.dart';
import 'package:aigui/app/theme/theme_provider.dart';
import 'package:aigui/presentation/settings/viewmodel/settings_viewmodel.dart';

/// Application settings view for managing NVIDIA NIM API keys, model preferences, and persistence.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Allowed controller lifecycles only — business state remains strictly in Riverpod
  late final TextEditingController _keyController;
  late final TextEditingController _promptController;
  final ValueNotifier<bool> _obscureKeyNotifier = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
    _promptController = TextEditingController();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _promptController.dispose();
    _obscureKeyNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsViewModelProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colors = Theme.of(context).extension<AppColorsExtension>();

    // Synchronize controller text once state loads if controller is empty
    if (_keyController.text.isEmpty && state.apiKey != null) {
      _keyController.text = state.apiKey!;
    }
    if (_promptController.text.isEmpty && state.defaultSystemPrompt.isNotEmpty) {
      _promptController.text = state.defaultSystemPrompt;
    }

    return Scaffold(
      backgroundColor: colors?.chatBg ?? Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Settings & Preferences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Status & Error Banners
          if (state.statusMessage != null)
            Container(
              width: double.infinity,
              color: AppTheme.nvidiaGreen.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: AppTheme.nvidiaGreen),
                  const SizedBox(width: 8),
                  Text(
                    state.statusMessage!,
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.nvidiaGreen),
                  ),
                ],
              ),
            ),

          if (state.errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.redAccent.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(fontSize: 12.5, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),

          // Settings Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: API Configuration
                      const _SectionHeader(
                        title: 'NVIDIA NIM API Configuration',
                        subtitle:
                            'Enter your personal NVIDIA NIM API key to connect to hosted OpenAI-compatible inference endpoints.',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
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
                            const Text(
                              'NVIDIA API Key',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<bool>(
                              valueListenable: _obscureKeyNotifier,
                              builder: (context, obscure, _) {
                                return TextField(
                                  controller: _keyController,
                                  obscureText: obscure,
                                  decoration: InputDecoration(
                                    hintText: 'nvapi-...',
                                    prefixIcon: const Icon(Icons.key_rounded, size: 18),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _obscureKeyNotifier.value = !obscure;
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colors?.subtleBorder ??
                                            Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.nvidiaGreen,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(settingsViewModelProvider.notifier)
                                        .saveApiKey(_keyController.text);
                                  },
                                  icon: const Icon(Icons.save_rounded, size: 16),
                                  label: const Text('Save Key',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: state.isTestingKey
                                      ? null
                                      : () {
                                          ref
                                              .read(settingsViewModelProvider.notifier)
                                              .testApiKey(_keyController.text);
                                        },
                                  icon: state.isTestingKey
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.network_check_rounded, size: 16),
                                  label: const Text('Test Connection'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Stored securely in local OS credential vault via flutter_secure_storage. Never transmitted to third parties.',
                              style: TextStyle(fontSize: 11.5, color: colors?.textMuted),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Section 2: Model & Prompt Defaults
                      const _SectionHeader(
                        title: 'Model & Default Instructions',
                        subtitle:
                            'Select your preferred default LLM and global system instructions.',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
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
                            Row(
                              children: [
                                const Text(
                                  'Default Model',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Refresh models from NVIDIA NIM',
                                  iconSize: 16,
                                  icon: const Icon(Icons.refresh_rounded),
                                  onPressed: () {
                                    ref
                                        .read(settingsViewModelProvider.notifier)
                                        .refreshModels();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: state.availableModels
                                          .any((m) => m.id == state.defaultModel)
                                      ? state.defaultModel
                                      : null,
                                  hint: Text(state.defaultModel,
                                      style: const TextStyle(fontSize: 13)),
                                  items: state.availableModels.map((m) {
                                    return DropdownMenuItem<String>(
                                      value: m.id,
                                      child: Text(m.id, style: const TextStyle(fontSize: 13)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref
                                          .read(settingsViewModelProvider.notifier)
                                          .setDefaultModel(val);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Global System Prompt',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _promptController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Enter global system prompt instructions...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: colors?.subtleBorder ??
                                        Theme.of(context).dividerColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                ref
                                    .read(settingsViewModelProvider.notifier)
                                    .setDefaultSystemPrompt(_promptController.text.trim());
                              },
                              child: const Text('Save Prompt'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Section 3: Appearance & Theme
                      const _SectionHeader(
                        title: 'Appearance',
                        subtitle: 'Customize desktop visual theme mode.',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Interface Theme',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Switch between Dark, Light, or follow System OS preference',
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(Icons.dark_mode_outlined, size: 16),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(Icons.light_mode_outlined, size: 16),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                  icon: Icon(Icons.brightness_auto_outlined, size: 16),
                                ),
                              ],
                              selected: {themeMode},
                              onSelectionChanged: (Set<ThemeMode> newSelection) {
                                ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(newSelection.first);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Section 4: Data & Storage
                      const _SectionHeader(
                        title: 'Data & Privacy',
                        subtitle:
                            'All chat histories and indexed projects remain strictly on your local disk.',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors?.subtleBorder ?? Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clear Local Database',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Permanently remove all conversations and stored workspace metadata',
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _showClearDataConfirmDialog(context, ref);
                              },
                              child: const Text('Delete All Data'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This will permanently delete all conversation threads, messages, and indexed project metadata from your local database. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(settingsViewModelProvider.notifier).clearAllData();
              Navigator.pop(ctx);
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: colors?.textMuted),
        ),
      ],
    );
  }
}
