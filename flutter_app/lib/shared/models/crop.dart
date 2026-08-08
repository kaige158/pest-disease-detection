/// 作物数据模型
class Crop {
  final int id;
  final String nameZh;
  final String nameLo;
  final String? category;
  final String? scientificName;
  final String? descriptionZh;
  final String? descriptionLo;
  final String? iconUrl;
  final int diseaseCount;

  const Crop({
    required this.id,
    required this.nameZh,
    required this.nameLo,
    this.category,
    this.scientificName,
    this.descriptionZh,
    this.descriptionLo,
    this.iconUrl,
    this.diseaseCount = 0,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'] as int,
      nameZh: json['name_zh'] as String? ?? '',
      nameLo: json['name_lo'] as String? ?? '',
      category: json['category'] as String?,
      scientificName: json['scientific_name'] as String?,
      descriptionZh: json['description_zh'] as String?,
      descriptionLo: json['description_lo'] as String?,
      iconUrl: json['icon_url'] as String?,
      diseaseCount: json['disease_count'] as int? ?? 0,
    );
  }
}

/// 作物分类模型
class CropCategory {
  final int id;
  final String nameZh;
  final String nameLo;
  final int? parentId;
  final String? iconUrl;
  final List<CropCategory> children;

  const CropCategory({
    required this.id,
    required this.nameZh,
    required this.nameLo,
    this.parentId,
    this.iconUrl,
    this.children = const [],
  });

  factory CropCategory.fromJson(Map<String, dynamic> json) {
    return CropCategory(
      id: json['id'] as int,
      nameZh: json['name_zh'] as String? ?? '',
      nameLo: json['name_lo'] as String? ?? '',
      parentId: json['parent_id'] as int?,
      iconUrl: json['icon_url'] as String?,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => CropCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
