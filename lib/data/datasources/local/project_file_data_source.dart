import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:aigui/core/errors/app_failure.dart';
import 'package:aigui/core/errors/result.dart';
import 'package:aigui/core/utils/app_logger.dart';
import 'package:aigui/domain/entities/project_file.dart';

/// Supported text/code extensions indexed for context injection.
const _supportedExtensions = {
  '.dart',
  '.md',
  '.txt',
  '.json',
  '.yaml',
  '.yml',
  '.csv',
  '.py',
  '.js',
  '.ts',
  '.html',
  '.css',
  '.sql',
  '.sh',
  '.bat',
  '.c',
  '.cpp',
  '.h',
  '.rs',
  '.go',
};

/// Directories ignored when scanning workspace folders.
const _ignoredDirectories = {
  '.git',
  '.dart_tool',
  '.idea',
  'build',
  'node_modules',
  '.gradle',
  '.vscode',
};

/// Local filesystem data source scanning, reading, and formatting project files for LLM context.
class ProjectFileDataSource {
  const ProjectFileDataSource();

  /// Recursively indexes valid text files within [folderPath].
  Future<Result<List<ProjectFile>>> scanFolder(
    String projectId,
    String folderPath,
  ) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        return Result.failure(FileSystemFailure(
          message: 'Directory does not exist: $folderPath',
        ));
      }

      final files = <ProjectFile>[];
      const uuid = Uuid();

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        // Skip ignored directories
        final pathParts = p.split(entity.path);
        if (pathParts.any((part) => _ignoredDirectories.contains(part))) {
          continue;
        }

        final ext = p.extension(entity.path).toLowerCase();
        if (!_supportedExtensions.contains(ext)) continue;

        // Skip excessively large individual files (> 500 KB)
        final stat = await entity.stat();
        if (stat.size > 512 * 1024) continue;

        try {
          final content = await entity.readAsString();
          final relativePath = p.relative(entity.path, from: folderPath);

          files.add(ProjectFile(
            id: uuid.v4(),
            projectId: projectId,
            filePath: entity.path,
            relativePath: relativePath,
            charCount: content.length,
            isEnabled: true,
            lastModified: stat.modified,
          ));
        } catch (_) {
          // File might be binary with a misleading extension or inaccessible
          continue;
        }
      }

      return Result.success(files);
    } catch (e, st) {
      AppLogger.e('Error scanning project folder: $e', e, st);
      return Result.failure(FileSystemFailure(
        message: 'Failed to scan project folder: $e',
      ));
    }
  }

  /// Reads enabled project files and formats them into a bounded context string.
  Future<Result<String>> buildFormattedContext(
    List<ProjectFile> files, {
    int charBudget = 30000,
  }) async {
    try {
      final buffer = StringBuffer();
      int currentChars = 0;

      for (final file in files) {
        if (!file.isEnabled) continue;

        final localFile = File(file.filePath);
        if (!await localFile.exists()) continue;

        String content;
        try {
          content = await localFile.readAsString();
        } catch (_) {
          continue;
        }

        final fileHeader = '\n--- File: ${file.relativePath} ---\n';
        final headerLength = fileHeader.length;

        if (currentChars + headerLength + content.length <= charBudget) {
          buffer.write(fileHeader);
          buffer.write(content);
          currentChars += headerLength + content.length;
        } else {
          // Truncate remainder of file to fit budget
          final remainingBudget = charBudget - currentChars - headerLength;
          if (remainingBudget > 200) {
            buffer.write(fileHeader);
            buffer.write(content.substring(0, remainingBudget));
            buffer.write('\n... [Content truncated to meet context budget]');
          }
          break;
        }
      }

      return Result.success(buffer.toString());
    } catch (e, st) {
      AppLogger.e('Error building project context: $e', e, st);
      return Result.failure(FileSystemFailure(
        message: 'Could not assemble project context: $e',
      ));
    }
  }
}
