import 'package:aigui/core/errors/result.dart';
import 'package:aigui/domain/entities/project.dart';
import 'package:aigui/domain/entities/project_file.dart';

/// Abstract contract for managing project workspaces, directory binding, and context extraction.
abstract class ProjectRepository {
  /// Emits real-time updates for all registered projects.
  Stream<List<Project>> watchProjects();

  /// Retrieves a project by its unique identifier.
  Future<Result<Project?>> getProject(String id);

  /// Saves or updates a project definition.
  Future<Result<void>> saveProject(Project project);

  /// Deletes a project and disassociates its tracked files.
  Future<Result<void>> deleteProject(String id);

  /// Emits real-time updates of files tracked under a project.
  Stream<List<ProjectFile>> watchProjectFiles(String projectId);

  /// Scans a linked local folder and indexes supported source/markdown files.
  Future<Result<List<ProjectFile>>> scanFolder(String projectId, String folderPath);

  /// Toggles whether a tracked file is included in LLM context.
  Future<Result<void>> toggleFileEnabled(String fileId, bool isEnabled);

  /// Builds a combined, character-budgeted context string from all enabled project files.
  Future<Result<String>> getProjectContext(String projectId, {int charBudget = 30000});
}
