import '../../app_language.dart';

enum RoomType {
  livingRoom,
  bedroom,
  masterBedroom,
  kitchen,
  diningRoom,
  bathroom,
  office,
  reception,
  other,
}

enum DesignStyle {
  modern,
  contemporary,
  classic,
  neoclassical,
  minimalist,
  industrial,
  scandinavian,
  luxury,
  bohemian,
  japandi,
  mediterranean,
  artDeco,
  rustic,
  transitional,
  other,
}

enum NaturalLightLevel { low, medium, high }

String roomTypeLabel(RoomType type) {
  switch (type) {
    case RoomType.livingRoom:
      return AppLanguage.text('Living Room', 'غرفة معيشة');
    case RoomType.bedroom:
      return AppLanguage.text('Bedroom', 'غرفة نوم');
    case RoomType.masterBedroom:
      return AppLanguage.text('Master Bedroom', 'غرفة نوم رئيسية');
    case RoomType.kitchen:
      return AppLanguage.text('Kitchen', 'مطبخ');
    case RoomType.diningRoom:
      return AppLanguage.text('Dining Room', 'غرفة طعام');
    case RoomType.bathroom:
      return AppLanguage.text('Bathroom', 'حمام');
    case RoomType.office:
      return AppLanguage.text('Home Office', 'مكتب منزلي');
    case RoomType.reception:
      return AppLanguage.text('Reception', 'استقبال');
    case RoomType.other:
      return AppLanguage.text('Other', 'أخرى');
  }
}

String designStyleLabel(DesignStyle style) {
  switch (style) {
    case DesignStyle.modern:
      return AppLanguage.text('Modern', 'مودرن');
    case DesignStyle.contemporary:
      return AppLanguage.text('Contemporary', 'معاصر');
    case DesignStyle.classic:
      return AppLanguage.text('Classic', 'كلاسيك');
    case DesignStyle.neoclassical:
      return AppLanguage.text('Neoclassical', 'نيو كلاسيك');
    case DesignStyle.minimalist:
      return AppLanguage.text('Minimalist', 'مينيمال');
    case DesignStyle.industrial:
      return AppLanguage.text('Industrial', 'صناعي');
    case DesignStyle.scandinavian:
      return AppLanguage.text('Scandinavian', 'اسكندنافي');
    case DesignStyle.luxury:
      return AppLanguage.text('Luxury', 'فاخر');
    case DesignStyle.bohemian:
      return AppLanguage.text('Bohemian', 'بوهو');
    case DesignStyle.japandi:
      return AppLanguage.text('Japandi', 'جاباندي');

    case DesignStyle.mediterranean:
      return AppLanguage.text('Mediterranean', 'متوسطي');

    case DesignStyle.artDeco:
      return AppLanguage.text('Art Deco', 'آرت ديكو');

    case DesignStyle.rustic:
      return AppLanguage.text('Rustic', 'ريفي');

    case DesignStyle.transitional:
      return AppLanguage.text('Transitional', 'انتقالي');
    case DesignStyle.other:
      return AppLanguage.text('Other', 'أخرى');
  }
}

String naturalLightLabel(NaturalLightLevel level) {
  switch (level) {
    case NaturalLightLevel.low:
      return AppLanguage.text('Low', 'ضعيفة');
    case NaturalLightLevel.medium:
      return AppLanguage.text('Medium', 'متوسطة');
    case NaturalLightLevel.high:
      return AppLanguage.text('High', 'قوية');
  }
}

class DesignContext {
  final RoomType roomType;
  final DesignStyle designStyle;
  final NaturalLightLevel naturalLight;
  final double? roomArea;

  const DesignContext({
    required this.roomType,
    required this.designStyle,
    required this.naturalLight,
    this.roomArea,
  });
}
