import 'package:aigui/domain/entities/llm_model.dart';

/// Data transfer object for NVIDIA NIM model metadata.
class NvidiaModelDto {
  const NvidiaModelDto({
    required this.id,
    this.ownedBy = 'nvidia',
    this.created,
  });

  factory NvidiaModelDto.fromJson(Map<String, dynamic> json) {
    return NvidiaModelDto(
      id: json['id'] as String? ?? '',
      ownedBy: json['owned_by'] as String? ?? 'nvidia',
      created: json['created'] as int?,
    );
  }

  final String id;
  final String ownedBy;
  final int? created;

  LlmModel toDomain() {
    // Clean up model name for UI presentation
    final displayName = id.contains('/') ? id.split('/').last : id;

    return LlmModel(
      id: id,
      name: displayName,
      ownedBy: ownedBy,
      contextLength: 131072,
      description: 'NVIDIA NIM hosted model ($id)',
    );
  }
}
