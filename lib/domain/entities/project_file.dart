/// Pure domain entity representing a local code or markdown file linked to a Project.
class ProjectFile {
  const ProjectFile({
    required this.id,
    required this.projectId,
    required this.filePath,
    required this.relativePath,
    required this.charCount,
    this.isEnabled = true,
    required this.lastModified,
  });

  final String id;
  final String projectId;
  final String filePath;
  final String relativePath;
  final int charCount;
  final bool isEnabled;
  final DateTime lastModified;

  ProjectFile copyWith({
    String? id,
    String? projectId,
    String? filePath,
    String? relativePath,
    int? charCount,
    bool? isEnabled,
    DateTime? lastModified,
  }) {
    return ProjectFile(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      filePath: filePath ?? this.filePath,
      relativePath: relativePath ?? this.relativePath,
      charCount: charCount ?? this.charCount,
      isEnabled: isEnabled ?? this.isEnabled,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectFile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          filePath == other.filePath &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode => id.hashCode ^ filePath.hashCode ^ isEnabled.hashCode;
}
