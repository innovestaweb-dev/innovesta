import '../../app_language.dart';
import 'color_allocation.dart';
import '../models/material_option.dart';

enum MaterialMatchReason {
  functionalUse,
  tonalHarmony,
  styleCharacter,
  balancedContrast,
}

class MaterialRecommendation {
  final ColorAllocation allocation;
  final MaterialOption material;
  final MaterialMatchReason reason;

  const MaterialRecommendation({
    required this.allocation,
    required this.material,
    required this.reason,
  });

  double get designPercentage => allocation.designPercentage;

  String get sourceColorHex => allocation.colorAnalysis.sourceColor.hex;

  String get materialHex => material.hex;

  String get reasonLabel {
    switch (reason) {
      case MaterialMatchReason.functionalUse:
        return AppLanguage.text(
          'Selected because its properties suit the intended architectural use.',
          'تم اختيارها لأن خصائصها مناسبة للاستخدام المعماري المقترح.',
        );

      case MaterialMatchReason.tonalHarmony:
        return AppLanguage.text(
          'Its color tone creates harmony with the reference palette.',
          'درجتها اللونية تحقق تناغمًا مع لوحة ألوان الصورة المرجعية.',
        );

      case MaterialMatchReason.styleCharacter:
        return AppLanguage.text(
          'Its texture and finish support the selected design style.',
          'ملمسها وتشطيبها يدعمان الستايل المعماري المختار.',
        );

      case MaterialMatchReason.balancedContrast:
        return AppLanguage.text(
          'It introduces a controlled contrast without disrupting the palette.',
          'تضيف تباينًا محسوبًا دون الإخلال بتناسق لوحة الألوان.',
        );
    }
  }
}
