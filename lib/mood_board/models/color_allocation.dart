import 'color_analysis.dart';
import '../../app_language.dart';
import 'material_use.dart';

enum AllocationReason {
  lightNeutral,
  warmNatural,
  darkAccent,
  coolBalanced,
  saturatedAccent,
  neutralBase,
}

class ColorAllocation {
  final ExtractedColorAnalysis colorAnalysis;
  final MaterialUse suggestedUse;
  final double designPercentage;
  final AllocationReason reason;

  const ColorAllocation({
    required this.colorAnalysis,
    required this.suggestedUse,
    required this.designPercentage,
    required this.reason,
  });

  String get reasonLabel {
    switch (reason) {
      case AllocationReason.lightNeutral:
        return AppLanguage.text(
          'Light neutral colors create a calm base for large surfaces.',
          'الألوان الفاتحة والمحايدة توفر قاعدة هادئة للمساحات الكبيرة.',
        );

      case AllocationReason.warmNatural:
        return AppLanguage.text(
          'Warm tones add natural warmth to furniture and interior elements.',
          'الدرجات الدافئة تضيف إحساسًا طبيعيًا للأثاث والعناصر الداخلية.',
        );

      case AllocationReason.darkAccent:
        return AppLanguage.text(
          'Dark tones create visual depth when used selectively.',
          'الدرجات الداكنة تضيف عمقًا بصريًا عند استخدامها بشكل محدود.',
        );

      case AllocationReason.coolBalanced:
        return AppLanguage.text(
          'Cool tones help create a balanced and refreshing atmosphere.',
          'الدرجات الباردة تساعد على خلق أجواء متوازنة ومنعشة.',
        );

      case AllocationReason.saturatedAccent:
        return AppLanguage.text(
          'Strong saturated colors work best as controlled visual accents.',
          'الألوان عالية التشبع تناسب العناصر المميزة عند استخدامها باعتدال.',
        );

      case AllocationReason.neutralBase:
        return AppLanguage.text(
          'Neutral tones provide flexibility when combining different materials.',
          'الدرجات المحايدة توفر مرونة عند دمج خامات مختلفة.',
        );
    }
  }
}
