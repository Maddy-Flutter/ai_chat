/// Pure domain entity representing a persistent conversation thread.
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.projectId,
    required this.modelId,
    this.systemPrompt,
    this.temperature = 0.7,
    this.topP = 1.0,
    this.maxTokens = 4096,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final String? projectId;
  final String modelId;
  final String? systemPrompt;
  final double temperature;
  final double topP;
  final int maxTokens;

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    String? projectId,
    String? modelId,
    String? systemPrompt,
    double? temperature,
    double? topP,
    int? maxTokens,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      projectId: projectId ?? this.projectId,
      modelId: modelId ?? this.modelId,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          isPinned == other.isPinned &&
          projectId == other.projectId &&
          modelId == other.modelId;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      isPinned.hashCode ^
      projectId.hashCode ^
      modelId.hashCode;
}
