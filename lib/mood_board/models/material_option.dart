import 'material_use.dart';
import 'design_context.dart';
import 'material_attributes.dart';

class MaterialOption {
  final String name;
  final String category;
  final String materialType;

  final String sampleImage;
  final String applicationImage;

  final String hex;
  final String colorFamily;

  final String placement;
  final String finish;
  final String texture;
  final String sheen;
  final String description;

  final List<MaterialUse> recommendedUses;
  final List<DesignStyle> styleCompatibility;

  final MaterialPriceLevel priceLevel;
  final MaterialDurability durability;
  final MaterialMaintenance maintenance;

  const MaterialOption({
    required this.name,
    required this.category,
    required this.materialType,
    required this.sampleImage,
    required this.applicationImage,
    required this.hex,
    required this.colorFamily,
    required this.placement,
    required this.finish,
    required this.texture,
    required this.sheen,
    required this.description,
    required this.recommendedUses,
    required this.styleCompatibility,
    required this.priceLevel,
    required this.durability,
    required this.maintenance,
  });
}
