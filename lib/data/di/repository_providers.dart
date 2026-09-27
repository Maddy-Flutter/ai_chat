import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aigui/data/datasources/local/database/app_database.dart';
import 'package:aigui/data/datasources/local/project_file_data_source.dart';
import 'package:aigui/data/datasources/local/secure_storage_data_source.dart';
import 'package:aigui/data/datasources/remote/nvidia_api_data_source.dart';
import 'package:aigui/data/repositories/chat_repository_impl.dart';
import 'package:aigui/data/repositories/llm_repository_impl.dart';
import 'package:aigui/data/repositories/project_repository_impl.dart';
import 'package:aigui/data/repositories/settings_repository_impl.dart';
import 'package:aigui/domain/repositories/chat_repository.dart';
import 'package:aigui/domain/repositories/llm_repository.dart';
import 'package:aigui/domain/repositories/project_repository.dart';
import 'package:aigui/domain/repositories/settings_repository.dart';

/// Database singleton provider.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Secure storage provider.
final secureStorageDataSourceProvider = Provider<SecureStorageDataSource>((ref) {
  return SecureStorageDataSource();
});

/// Project file reader & chunker provider.
final projectFileDataSourceProvider = Provider<ProjectFileDataSource>((ref) {
  return const ProjectFileDataSource();
});

/// NVIDIA NIM API datasource provider.
final nvidiaApiDataSourceProvider = Provider<NvidiaApiDataSource>((ref) {
  return NvidiaApiDataSource();
});

/// LLM Repository provider.
final llmRepositoryProvider = Provider<LlmRepository>((ref) {
  return LlmRepositoryImpl(
    apiDataSource: ref.watch(nvidiaApiDataSourceProvider),
    secureStorage: ref.watch(secureStorageDataSourceProvider),
    database: ref.watch(appDatabaseProvider),
  );
});

/// Chat Repository provider.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
  );
});

/// Project Repository provider.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    fileDataSource: ref.watch(projectFileDataSourceProvider),
  );
});

/// Settings Repository provider.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(
    secureStorage: ref.watch(secureStorageDataSourceProvider),
    database: ref.watch(appDatabaseProvider),
  );
});
