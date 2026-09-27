import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Table storing conversation threads and per-conversation hyperparameters.
class ConversationsTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get projectId => text().nullable()();
  TextColumn get modelId => text()();
  TextColumn get systemPrompt => text().nullable()();
  RealColumn get temperature => real().withDefault(const Constant(0.7))();
  RealColumn get topP => real().withDefault(const Constant(1.0))();
  IntColumn get maxTokens => integer().withDefault(const Constant(4096))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table storing user and assistant conversational turns.
class MessagesTable extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isIncomplete => boolean().withDefault(const Constant(false))();
  BoolColumn get isError => boolean().withDefault(const Constant(false))();
  IntColumn get tokenCount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table storing project workspaces and system instructions.
class ProjectsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  TextColumn get folderPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get charBudget => integer().withDefault(const Constant(30000))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table tracking files indexed from a project's linked directory.
class ProjectFilesTable extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get filePath => text()();
  TextColumn get relativePath => text()();
  IntColumn get charCount => integer()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table caching models retrieved dynamically from the NVIDIA NIM endpoint.
class CachedModelsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get ownedBy => text().withDefault(const Constant('nvidia'))();
  IntColumn get contextLength => integer().withDefault(const Constant(131072))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  ConversationsTable,
  MessagesTable,
  ProjectsTable,
  ProjectFilesTable,
  CachedModelsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'nvidia_ai_desktop_db');
  }

  // --- Convenience Conversation Operations ---

  Stream<List<ConversationsTableData>> watchAllConversations() {
    return (select(conversationsTable)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  Future<ConversationsTableData?> getConversationById(String id) {
    return (select(conversationsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertConversation(ConversationsTableCompanion companion) {
    return into(conversationsTable).insertOnConflictUpdate(companion);
  }

  Future<void> deleteConversationCascade(String conversationId) async {
    await transaction(() async {
      await (delete(messagesTable)
            ..where((t) => t.conversationId.equals(conversationId)))
          .go();
      await (delete(conversationsTable)..where((t) => t.id.equals(conversationId)))
          .go();
    });
  }

  // --- Convenience Message Operations ---

  Stream<List<MessagesTableData>> watchMessagesForConversation(
      String conversationId) {
    return (select(messagesTable)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<MessagesTableData>> getMessagesForConversation(
      String conversationId) {
    return (select(messagesTable)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> upsertMessage(MessagesTableCompanion companion) {
    return into(messagesTable).insertOnConflictUpdate(companion);
  }

  Future<void> deleteMessageById(String messageId) {
    return (delete(messagesTable)..where((t) => t.id.equals(messageId))).go();
  }

  Future<List<MessagesTableData>> searchMessages(String query) {
    return (select(messagesTable)
          ..where((t) => t.content.like('%$query%'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // --- Convenience Project Operations ---

  Stream<List<ProjectsTableData>> watchAllProjects() {
    return (select(projectsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<ProjectsTableData?> getProjectById(String id) {
    return (select(projectsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertProject(ProjectsTableCompanion companion) {
    return into(projectsTable).insertOnConflictUpdate(companion);
  }

  Future<void> deleteProjectCascade(String projectId) async {
    await transaction(() async {
      await (delete(projectFilesTable)..where((t) => t.projectId.equals(projectId)))
          .go();
      await (delete(projectsTable)..where((t) => t.id.equals(projectId))).go();
    });
  }

  Stream<List<ProjectFilesTableData>> watchProjectFiles(String projectId) {
    return (select(projectFilesTable)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.relativePath)]))
        .watch();
  }

  Future<void> replaceProjectFiles(
      String projectId, List<ProjectFilesTableCompanion> files) async {
    await transaction(() async {
      await (delete(projectFilesTable)..where((t) => t.projectId.equals(projectId)))
          .go();
      for (final file in files) {
        await into(projectFilesTable).insert(file);
      }
    });
  }

  Future<void> setFileEnabled(String fileId, bool isEnabled) {
    return (update(projectFilesTable)..where((t) => t.id.equals(fileId))).write(
      ProjectFilesTableCompanion(isEnabled: Value(isEnabled)),
    );
  }

  // --- Convenience Model Cache Operations ---

  Future<List<CachedModelsTableData>> getAllCachedModels() {
    return select(cachedModelsTable).get();
  }

  Stream<List<CachedModelsTableData>> watchAllCachedModels() {
    return (select(cachedModelsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  Future<void> replaceCachedModels(
      List<CachedModelsTableCompanion> models) async {
    await transaction(() async {
      await delete(cachedModelsTable).go();
      for (final model in models) {
        await into(cachedModelsTable).insert(model);
      }
    });
  }

  Future<void> clearEntireDatabase() async {
    await transaction(() async {
      await delete(messagesTable).go();
      await delete(conversationsTable).go();
      await delete(projectFilesTable).go();
      await delete(projectsTable).go();
      await delete(cachedModelsTable).go();
    });
  }
}
