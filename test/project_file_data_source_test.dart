import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aigui/data/datasources/local/project_file_data_source.dart';
import 'package:aigui/domain/entities/project_file.dart';

void main() {
  group('ProjectFileDataSource Context Budgeting', () {
    const dataSource = ProjectFileDataSource();
    late Directory tempDir;
    late File file1;
    late File file2;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aigui_test_');
      file1 = File('${tempDir.path}/a.dart');
      file2 = File('${tempDir.path}/b.dart');

      await file1.writeAsString('void main() { print("A"); }');
      await file2.writeAsString('void helper() { print("B"); }');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('formats enabled files into context string within character budget', () async {
      final projectFiles = [
        ProjectFile(
          id: '1',
          projectId: 'p1',
          filePath: file1.path,
          relativePath: 'a.dart',
          charCount: 26,
          isEnabled: true,
          lastModified: DateTime.now(),
        ),
        ProjectFile(
          id: '2',
          projectId: 'p1',
          filePath: file2.path,
          relativePath: 'b.dart',
          charCount: 28,
          isEnabled: true,
          lastModified: DateTime.now(),
        ),
      ];

      final result = await dataSource.buildFormattedContext(projectFiles, charBudget: 500);

      expect(result.isSuccess, isTrue);
      final contextText = result.dataOrNull!;
      expect(contextText, contains('--- File: a.dart ---'));
      expect(contextText, contains('print("A")'));
      expect(contextText, contains('--- File: b.dart ---'));
      expect(contextText, contains('print("B")'));
    });

    test('skips disabled files', () async {
      final projectFiles = [
        ProjectFile(
          id: '1',
          projectId: 'p1',
          filePath: file1.path,
          relativePath: 'a.dart',
          charCount: 26,
          isEnabled: false,
          lastModified: DateTime.now(),
        ),
        ProjectFile(
          id: '2',
          projectId: 'p1',
          filePath: file2.path,
          relativePath: 'b.dart',
          charCount: 28,
          isEnabled: true,
          lastModified: DateTime.now(),
        ),
      ];

      final result = await dataSource.buildFormattedContext(projectFiles, charBudget: 500);

      expect(result.isSuccess, isTrue);
      final contextText = result.dataOrNull!;
      expect(contextText.contains('a.dart'), isFalse);
      expect(contextText, contains('--- File: b.dart ---'));
    });
  });
}
