/// Pure domain entity representing an LLM available on the NVIDIA NIM platform.
class LlmModel {
  const LlmModel({
    required this.id,
    required this.name,
    this.ownedBy = 'nvidia',
    this.contextLength = 131072,
    this.description = '',
  });

  final String id;
  final String name;
  final String ownedBy;
  final int contextLength;
  final String description;

  LlmModel copyWith({
    String? id,
    String? name,
    String? ownedBy,
    int? contextLength,
    String? description,
  }) {
    return LlmModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownedBy: ownedBy ?? this.ownedBy,
      contextLength: contextLength ?? this.contextLength,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LlmModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
