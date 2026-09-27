import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:aigui/data/di/repository_providers.dart';
import 'package:aigui/domain/entities/project.dart';
import 'package:aigui/domain/entities/project_file.dart';
import 'package:aigui/domain/repositories/project_repository.dart';

/// Immutable UI state for the Projects workspace view.
class ProjectsState {
  const ProjectsState({
    this.projects = const [],
    this.selectedProject,
    this.projectFiles = const [],
    this.isScanning = false,
    this.errorMessage,
  });

  final List<Project> projects;
  final Project? selectedProject;
  final List<ProjectFile> projectFiles;
  final bool isScanning;
  final String? errorMessage;

  ProjectsState copyWith({
    List<Project>? projects,
    Project? Function()? selectedProject,
    List<ProjectFile>? projectFiles,
    bool? isScanning,
    String? Function()? errorMessage,
  }) {
    return ProjectsState(
      projects: projects ?? this.projects,
      selectedProject: selectedProject != null ? selectedProject() : this.selectedProject,
      projectFiles: projectFiles ?? this.projectFiles,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

/// Pure Riverpod ViewModel managing project CRUD, folder scanning, and file context toggling.
class ProjectsViewModel extends Notifier<ProjectsState> {
  StreamSubscription<List<Project>>? _projectsSub;
  StreamSubscription<List<ProjectFile>>? _filesSub;
  final _uuid = const Uuid();

  ProjectRepository get _projectRepo => ref.read(projectRepositoryProvider);

  @override
  ProjectsState build() {
    ref.onDispose(() {
      _projectsSub?.cancel();
      _filesSub?.cancel();
    });

    _projectsSub = _projectRepo.watchProjects().listen((projects) {
      state = state.copyWith(projects: projects);
      if (state.selectedProject == null && projects.isNotEmpty) {
        selectProject(projects.first.id);
      }
    });

    return const ProjectsState();
  }

  Future<void> selectProject(String projectId) async {
    final project = state.projects.where((p) => p.id == projectId).firstOrNull;
    if (project == null) return;

    state = state.copyWith(selectedProject: () => project);

    await _filesSub?.cancel();
    _filesSub = _projectRepo.watchProjectFiles(projectId).listen((files) {
      state = state.copyWith(projectFiles: files);
    });
  }

  Future<void> createProject({
    required String name,
    String description = '',
    String systemPrompt = '',
    String? folderPath,
  }) async {
    final newProject = Project(
      id: _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      systemPrompt: systemPrompt.trim(),
      folderPath: folderPath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _projectRepo.saveProject(newProject);
    await selectProject(newProject.id);

    if (folderPath != null && folderPath.isNotEmpty) {
      await scanFolder(newProject.id, folderPath);
    }
  }

  Future<void> scanFolder(String projectId, String folderPath) async {
    state = state.copyWith(isScanning: true, errorMessage: () => null);

    final result = await _projectRepo.scanFolder(projectId, folderPath);
    result.when(
      onSuccess: (_) {
        state = state.copyWith(isScanning: false);
      },
      onFailure: (failure) {
        state = state.copyWith(
          isScanning: false,
          errorMessage: () => failure.message,
        );
      },
    );
  }

  Future<void> toggleFileEnabled(String fileId, bool isEnabled) async {
    await _projectRepo.toggleFileEnabled(fileId, isEnabled);
  }

  Future<void> deleteProject(String projectId) async {
    await _projectRepo.deleteProject(projectId);
    if (state.selectedProject?.id == projectId) {
      state = state.copyWith(
        selectedProject: () => null,
        projectFiles: const [],
      );
    }
  }
}

/// Provider exposing [ProjectsViewModel] and its state.
final projectsViewModelProvider =
    NotifierProvider<ProjectsViewModel, ProjectsState>(ProjectsViewModel.new);
