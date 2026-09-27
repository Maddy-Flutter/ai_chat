/// Pure domain entity representing a project workspace with system instructions and linked local files.
class Project {
  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.systemPrompt = '',
    this.folderPath,
    required this.createdAt,
    required this.updatedAt,
    this.charBudget = 30000,
  });

  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String? folderPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int charBudget;

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
    String? folderPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? charBudget,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      folderPath: folderPath ?? this.folderPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      charBudget: charBudget ?? this.charBudget,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          folderPath == other.folderPath;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ folderPath.hashCode;
}
