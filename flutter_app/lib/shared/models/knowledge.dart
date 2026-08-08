/// 知识条目模型
class KnowledgeEntry {
  final int id;
  final String entryType; // 'disease' | 'crop' | 'general' | 'faq'
  final String titleZh;
  final String titleLo;
  final String? contentZh;
  final String? contentLo;
  final List<String> tags;
  final int? cropId;
  final int? diseaseId;

  const KnowledgeEntry({
    required this.id,
    required this.entryType,
    required this.titleZh,
    required this.titleLo,
    this.contentZh,
    this.contentLo,
    this.tags = const [],
    this.cropId,
    this.diseaseId,
  });

  factory KnowledgeEntry.fromJson(Map<String, dynamic> json) {
    return KnowledgeEntry(
      id: json['id'] as int,
      entryType: json['entry_type'] as String? ?? 'general',
      titleZh: json['title_zh'] as String? ?? '',
      titleLo: json['title_lo'] as String? ?? '',
      contentZh: json['content_zh'] as String?,
      contentLo: json['content_lo'] as String?,
      tags: (json['tags'] as String?)?.split(',').map((t) => t.trim()).toList() ?? [],
      cropId: json['crop_id'] as int?,
      diseaseId: json['disease_id'] as int?,
    );
  }
}

/// 通用API响应包装
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  bool get isSuccess => code == 200;
}
