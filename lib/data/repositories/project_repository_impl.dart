import 'package:drift/drift.dart';

import 'package:aigui/core/errors/app_failure.dart';
import 'package:aigui/core/errors/result.dart';
import 'package:aigui/core/utils/app_logger.dart';
import 'package:aigui/data/datasources/local/database/app_database.dart';
import 'package:aigui/data/datasources/local/project_file_data_source.dart';
import 'package:aigui/domain/entities/project.dart';
import 'package:aigui/domain/entities/project_file.dart';
import 'package:aigui/domain/repositories/project_repository.dart';

/// Concrete implementation of [ProjectRepository] managing workspaces and contextual file chunks.
class ProjectRepositoryImpl implements ProjectRepository {
  const ProjectRepositoryImpl({
    required AppDatabase database,
    required ProjectFileDataSource fileDataSource,
  })  : _database = database,
        _fileDataSource = fileDataSource;

  final AppDatabase _database;
  final ProjectFileDataSource _fileDataSource;

  @override
  Stream<List<Project>> watchProjects() {
    return _database.watchAllProjects().map((rows) => rows.map(_mapProjectRow).toList());
  }

  @override
  Future<Result<Project?>> getProject(String id) async {
    try {
      final row = await _database.getProjectById(id);
      return Result.success(row != null ? _mapProjectRow(row) : null);
    } catch (e, st) {
      AppLogger.e('Error getting project $id: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> saveProject(Project project) async {
    try {
      await _database.upsertProject(
        ProjectsTableCompanion(
          id: Value(project.id),
          name: Value(project.name),
          description: Value(project.description),
          systemPrompt: Value(project.systemPrompt),
          folderPath: Value(project.folderPath),
          createdAt: Value(project.createdAt),
          updatedAt: Value(project.updatedAt),
          charBudget: Value(project.charBudget),
        ),
      );
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error saving project: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteProject(String id) async {
    try {
      await _database.deleteProjectCascade(id);
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error deleting project $id: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<ProjectFile>> watchProjectFiles(String projectId) {
    return _database
        .watchProjectFiles(projectId)
        .map((rows) => rows.map(_mapProjectFileRow).toList());
  }

  @override
  Future<Result<List<ProjectFile>>> scanFolder(
    String projectId,
    String folderPath,
  ) async {
    final scanResult = await _fileDataSource.scanFolder(projectId, folderPath);
    return scanResult.when(
      onSuccess: (files) async {
        try {
          final companions = files
              .map((f) => ProjectFilesTableCompanion(
                    id: Value(f.id),
                    projectId: Value(f.projectId),
                    filePath: Value(f.filePath),
                    relativePath: Value(f.relativePath),
                    charCount: Value(f.charCount),
                    isEnabled: Value(f.isEnabled),
                    lastModified: Value(f.lastModified),
                  ))
              .toList();

          await _database.replaceProjectFiles(projectId, companions);
          return Result.success(files);
        } catch (e, st) {
          AppLogger.e('Error caching scanned files: $e', e, st);
          return Result.failure(DatabaseFailure(message: e.toString()));
        }
      },
      onFailure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> toggleFileEnabled(String fileId, bool isEnabled) async {
    try {
      await _database.setFileEnabled(fileId, isEnabled);
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Error toggling file: $e', e, st);
      return Result.failure(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<String>> getProjectContext(
    String projectId, {
    int charBudget = 30000,
  }) async {
    try {
      final project = await _database.getProjectById(projectId);
      final filesData = await _database.projectFilesTable.select().get();
      final projectFiles = filesData
          .where((f) => f.projectId == projectId)
          .map(_mapProjectFileRow)
          .toList();

      final contextResult = await _fileDataSource.buildFormattedContext(
        projectFiles,
        charBudget: project?.charBudget ?? charBudget,
      );

      return contextResult.when(
        onSuccess: (contextContent) {
          final buffer = StringBuffer();
          if (project != null && project.systemPrompt.trim().isNotEmpty) {
            buffer.writeln('=== Project System Instructions ===');
            buffer.writeln(project.systemPrompt.trim());
            buffer.writeln();
          }

          if (contextContent.isNotEmpty) {
            buffer.writeln('=== Project Code & Document Context ===');
            buffer.write(contextContent);
          }

          return Result.success(buffer.toString());
        },
        onFailure: (failure) => Result.failure(failure),
      );
    } catch (e, st) {
      AppLogger.e('Error building project context: $e', e, st);
      return Result.failure(FileSystemFailure(message: e.toString()));
    }
  }

  Project _mapProjectRow(ProjectsTableData row) {
    return Project(
      id: row.id,
      name: row.name,
      description: row.description,
      systemPrompt: row.systemPrompt,
      folderPath: row.folderPath,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      charBudget: row.charBudget,
    );
  }

  ProjectFile _mapProjectFileRow(ProjectFilesTableData row) {
    return ProjectFile(
      id: row.id,
      projectId: row.projectId,
      filePath: row.filePath,
      relativePath: row.relativePath,
      charCount: row.charCount,
      isEnabled: row.isEnabled,
      lastModified: row.lastModified,
    );
  }
}
