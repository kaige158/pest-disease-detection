/// 病虫害数据模型
class Disease {
  final int id;
  final String nameZh;
  final String nameLo;
  final String? scientificName;
  final String type; // 'disease' | 'pest'
  final String? symptomsZh;
  final String? symptomsLo;
  final String? conditionsZh;
  final String? conditionsLo;
  final String? severityLevel;
  final List<String> imageUrls;

  const Disease({
    required this.id,
    required this.nameZh,
    required this.nameLo,
    this.scientificName,
    required this.type,
    this.symptomsZh,
    this.symptomsLo,
    this.conditionsZh,
    this.conditionsLo,
    this.severityLevel,
    this.imageUrls = const [],
  });

  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      id: json['id'] as int,
      nameZh: json['name_zh'] as String? ?? '',
      nameLo: json['name_lo'] as String? ?? '',
      scientificName: json['scientific_name'] as String?,
      type: json['type'] as String? ?? 'disease',
      symptomsZh: json['symptoms_zh'] as String?,
      symptomsLo: json['symptoms_lo'] as String?,
      conditionsZh: json['conditions_zh'] as String?,
      conditionsLo: json['conditions_lo'] as String?,
      severityLevel: json['severity_level'] as String?,
      imageUrls: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// 识别结果模型
class RecognitionResult {
  final int rank;
  final String diseaseNameZh;
  final String diseaseNameLo;
  final double confidence;
  final String type;
  final String? severity;
  final String? descriptionZh;
  final String? descriptionLo;
  final Map<String, dynamic>? preventionPlan;

  const RecognitionResult({
    required this.rank,
    required this.diseaseNameZh,
    required this.diseaseNameLo,
    required this.confidence,
    required this.type,
    this.severity,
    this.descriptionZh,
    this.descriptionLo,
    this.preventionPlan,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      rank: json['rank'] as int? ?? 1,
      diseaseNameZh: json['disease_name_zh'] as String? ?? '',
      diseaseNameLo: json['disease_name_lo'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'disease',
      severity: json['severity'] as String?,
      descriptionZh: json['description_zh'] as String?,
      descriptionLo: json['description_lo'] as String?,
      preventionPlan: json['prevention_plan'] as Map<String, dynamic>?,
    );
  }
}
