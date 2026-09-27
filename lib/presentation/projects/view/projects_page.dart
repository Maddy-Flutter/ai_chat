import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aigui/app/theme/app_theme.dart';
import 'package:aigui/domain/entities/project.dart';
import 'package:aigui/presentation/chat/viewmodel/chat_viewmodel.dart';
import 'package:aigui/presentation/projects/viewmodel/projects_viewmodel.dart';

/// Workspace management screen for creating projects, linking directories, and inspecting context injection.
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectsViewModelProvider);
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>();

    return Scaffold(
      backgroundColor: colors?.chatBg ?? theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Left Projects Navigation List
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: colors?.subtleBorder ?? theme.dividerColor,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colors?.subtleBorder ?? theme.dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Projects',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Create Project',
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.nvidiaGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(6),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        onPressed: () => _showCreateProjectDialog(context, ref),
                      ),
                    ],
                  ),
                ),

                // Projects List
                Expanded(
                  child: state.projects.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder_open_rounded,
                                  size: 32,
                                  color: colors?.textMuted.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No projects yet',
                                  style: TextStyle(fontSize: 12.5, color: colors?.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: state.projects.length,
                          itemBuilder: (context, index) {
                            final project = state.projects[index];
                            final isSelected = project.id == state.selectedProject?.id;

                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: AppTheme.nvidiaGreen.withValues(alpha: 0.12),
                              leading: Icon(
                                Icons.folder_rounded,
                                size: 18,
                                color: isSelected ? AppTheme.nvidiaGreen : colors?.textMuted,
                              ),
                              title: Text(
                                project.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              subtitle: project.folderPath != null
                                  ? Text(
                                      project.folderPath!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: colors?.textMuted),
                                    )
                                  : null,
                              onTap: () {
                                ref
                                    .read(projectsViewModelProvider.notifier)
                                    .selectProject(project.id);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Right Project Detail Pane
          Expanded(
            child: state.selectedProject == null
                ? Center(
                    child: Text(
                      'Select or create a project to inspect local code context',
                      style: TextStyle(fontSize: 13, color: colors?.textMuted),
                    ),
                  )
                : _ProjectDetailView(project: state.selectedProject!),
          ),
        ],
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final promptController = TextEditingController();
    final folderPathNotifier = ValueNotifier<String?>(null);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Project'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'e.g. Flutter Chat App',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Project System Prompt Instructions',
                    hintText: 'e.g. You are working inside this codebase...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<String?>(
                  valueListenable: folderPathNotifier,
                  builder: (context, folderPath, _) {
                    return Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final path = await FilePicker.platform.getDirectoryPath();
                            if (path != null) {
                              folderPathNotifier.value = path;
                            }
                          },
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Link Folder'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            folderPath ?? 'No folder selected',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.nvidiaGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                ref.read(projectsViewModelProvider.notifier).createProject(
                      name: name,
                      description: descController.text.trim(),
                      systemPrompt: promptController.text.trim(),
                      folderPath: folderPathNotifier.value,
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _ProjectDetailView extends ConsumerWidget {
  const _ProjectDetailView({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectsViewModelProvider);
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>();

    final totalChars = state.projectFiles
        .where((f) => f.isEnabled)
        .fold<int>(0, (sum, f) => sum + f.charCount);

    final budgetPercent = (totalChars / project.charBudget).clamp(0.0, 1.0);

    return Column(
      children: [
        // Detail Header
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors?.subtleBorder ?? theme.dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (project.description.isNotEmpty)
                      Text(
                        project.description,
                        style: TextStyle(fontSize: 11.5, color: colors?.textMuted),
                      ),
                  ],
                ),
              ),

              // Action buttons: Launch Chat and Delete
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.nvidiaGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () {
                  ref.read(chatViewModelProvider.notifier).startNewChat(project: project);
                  context.go('/chat');
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Chat in Project', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Delete Project',
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () {
                  ref.read(projectsViewModelProvider.notifier).deleteProject(project.id);
                },
              ),
            ],
          ),
        ),

        // Context Budget & Linked Folder Summary Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: theme.colorScheme.surface.withValues(alpha: 0.5),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Context Budget: $totalChars / ${project.charBudget} chars (~${totalChars ~/ 4} tokens)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: budgetPercent > 0.9 ? Colors.orangeAccent : colors?.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(budgetPercent * 100).toInt()}% used',
                          style: TextStyle(fontSize: 11, color: colors?.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: budgetPercent,
                        minHeight: 5,
                        backgroundColor: colors?.subtleBorder ?? theme.dividerColor,
                        valueColor: AlwaysStoppedAnimation(
                          budgetPercent > 0.9 ? Colors.orangeAccent : AppTheme.nvidiaGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final path = await FilePicker.platform.getDirectoryPath();
                  if (path != null) {
                    await ref.read(projectsViewModelProvider.notifier).scanFolder(project.id, path);
                  }
                },
                icon: const Icon(Icons.folder_rounded, size: 16),
                label: Text(project.folderPath != null ? 'Rescan Folder' : 'Link Folder'),
              ),
            ],
          ),
        ),

        const Divider(),

        // Tracked Files Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
          child: Row(
            children: [
              const Text(
                'TRACKED PROJECT FILES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.7),
              ),
              const Spacer(),
              Text(
                '${state.projectFiles.where((f) => f.isEnabled).length} of ${state.projectFiles.length} included',
                style: TextStyle(fontSize: 11.5, color: colors?.textMuted),
              ),
            ],
          ),
        ),

        // Files Table / List
        Expanded(
          child: state.isScanning
              ? const Center(child: CircularProgressIndicator())
              : state.projectFiles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          project.folderPath == null
                              ? 'No folder linked yet. Click "Link Folder" to index local code and docs.'
                              : 'No supported code files found in linked directory.',
                          style: TextStyle(fontSize: 13, color: colors?.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                      itemCount: state.projectFiles.length,
                      itemBuilder: (context, index) {
                        final file = state.projectFiles[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: file.isEnabled,
                                  activeColor: AppTheme.nvidiaGreen,
                                  onChanged: (val) {
                                    ref
                                        .read(projectsViewModelProvider.notifier)
                                        .toggleFileEnabled(file.id, val ?? false);
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        file.relativePath,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        '${file.charCount} chars (~${file.charCount ~/ 4} tokens)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors?.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
