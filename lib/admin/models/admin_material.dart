class AdminMaterial {
  final String id;

  // Names
  final String name;
  final String nameAr;
  final String nameEn;

  // Categories
  final String category;
  final String categoryAr;
  final String categoryEn;

  // Material types
  final String materialType;
  final String materialTypeAr;
  final String materialTypeEn;

  // Images and colors
  final String sampleImage;
  final String applicationImage;
  final String hex;
  final String colorFamily;

  // Properties
  final String placement;
  final String placementAr;
  final String placementEn;

  final String finish;
  final String finishAr;
  final String finishEn;

  final String texture;
  final String textureAr;
  final String textureEn;

  final String sheen;
  final String sheenAr;
  final String sheenEn;

  final String description;
  final String descriptionAr;
  final String descriptionEn;

  final List<String> recommendedUses;
  final List<String> styleCompatibility;

  final String priceLevel;
  final String durability;
  final String maintenance;

  final bool isActive;
  final int displayOrder;

  const AdminMaterial({
    required this.id,
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    required this.category,
    this.categoryAr = '',
    this.categoryEn = '',
    required this.materialType,
    this.materialTypeAr = '',
    this.materialTypeEn = '',
    this.sampleImage = '',
    this.applicationImage = '',
    this.hex = '',
    this.colorFamily = '',
    this.placement = '',
    this.placementAr = '',
    this.placementEn = '',
    this.finish = '',
    this.finishAr = '',
    this.finishEn = '',
    this.texture = '',
    this.textureAr = '',
    this.textureEn = '',
    this.sheen = '',
    this.sheenAr = '',
    this.sheenEn = '',
    this.description = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.recommendedUses = const [],
    this.styleCompatibility = const [],
    this.priceLevel = 'midRange',
    this.durability = 'medium',
    this.maintenance = 'medium',
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory AdminMaterial.fromMap(Map<String, dynamic> map) {
    final nameEn = map['name_en']?.toString() ?? map['name']?.toString() ?? '';

    final categoryEn =
        map['category_en']?.toString() ?? map['category']?.toString() ?? '';

    final typeEn =
        map['material_type_en']?.toString() ??
        map['material_type']?.toString() ??
        '';

    final descriptionEn =
        map['description_en']?.toString() ??
        map['description']?.toString() ??
        '';

    return AdminMaterial(
      id: map['id']?.toString() ?? '',
      name: nameEn,
      nameAr: map['name_ar']?.toString() ?? '',
      nameEn: nameEn,
      category: categoryEn,
      categoryAr: map['category_ar']?.toString() ?? '',
      categoryEn: categoryEn,
      materialType: typeEn,
      materialTypeAr: map['material_type_ar']?.toString() ?? '',
      materialTypeEn: typeEn,
      sampleImage: map['sample_image']?.toString() ?? '',
      applicationImage: map['application_image']?.toString() ?? '',
      hex: map['hex']?.toString() ?? '',
      colorFamily: map['color_family']?.toString() ?? '',
      placement:
          map['placement_en']?.toString() ?? map['placement']?.toString() ?? '',
      placementAr: map['placement_ar']?.toString() ?? '',
      placementEn:
          map['placement_en']?.toString() ?? map['placement']?.toString() ?? '',
      finish: map['finish_en']?.toString() ?? map['finish']?.toString() ?? '',
      finishAr: map['finish_ar']?.toString() ?? '',
      finishEn: map['finish_en']?.toString() ?? map['finish']?.toString() ?? '',
      texture:
          map['texture_en']?.toString() ?? map['texture']?.toString() ?? '',
      textureAr: map['texture_ar']?.toString() ?? '',
      textureEn:
          map['texture_en']?.toString() ?? map['texture']?.toString() ?? '',
      sheen: map['sheen_en']?.toString() ?? map['sheen']?.toString() ?? '',
      sheenAr: map['sheen_ar']?.toString() ?? '',
      sheenEn: map['sheen_en']?.toString() ?? map['sheen']?.toString() ?? '',
      description: descriptionEn,
      descriptionAr: map['description_ar']?.toString() ?? '',
      descriptionEn: descriptionEn,
      recommendedUses: List<String>.from(map['recommended_uses'] ?? []),
      styleCompatibility: List<String>.from(map['style_compatibility'] ?? []),
      priceLevel: map['price_level']?.toString() ?? 'midRange',
      durability: map['durability']?.toString() ?? 'medium',
      maintenance: map['maintenance']?.toString() ?? 'medium',
      isActive: map['is_active'] as bool? ?? true,
      displayOrder: map['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameEn.isNotEmpty ? nameEn : name,
      'name_ar': nameAr,
      'name_en': nameEn.isNotEmpty ? nameEn : name,
      'category': categoryEn.isNotEmpty ? categoryEn : category,
      'category_ar': categoryAr,
      'category_en': categoryEn.isNotEmpty ? categoryEn : category,
      'material_type': materialTypeEn.isNotEmpty
          ? materialTypeEn
          : materialType,
      'material_type_ar': materialTypeAr,
      'material_type_en': materialTypeEn.isNotEmpty
          ? materialTypeEn
          : materialType,
      'sample_image': sampleImage,
      'application_image': applicationImage,
      'hex': hex,
      'color_family': colorFamily,
      'placement': placementEn.isNotEmpty ? placementEn : placement,
      'placement_ar': placementAr,
      'placement_en': placementEn.isNotEmpty ? placementEn : placement,
      'finish': finishEn.isNotEmpty ? finishEn : finish,
      'finish_ar': finishAr,
      'finish_en': finishEn.isNotEmpty ? finishEn : finish,
      'texture': textureEn.isNotEmpty ? textureEn : texture,
      'texture_ar': textureAr,
      'texture_en': textureEn.isNotEmpty ? textureEn : texture,
      'sheen': sheenEn.isNotEmpty ? sheenEn : sheen,
      'sheen_ar': sheenAr,
      'sheen_en': sheenEn.isNotEmpty ? sheenEn : sheen,
      'description': descriptionEn.isNotEmpty ? descriptionEn : description,
      'description_ar': descriptionAr,
      'description_en': descriptionEn.isNotEmpty ? descriptionEn : description,
      'recommended_uses': recommendedUses,
      'style_compatibility': styleCompatibility,
      'price_level': priceLevel,
      'durability': durability,
      'maintenance': maintenance,
      'is_active': isActive,
      'display_order': displayOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
