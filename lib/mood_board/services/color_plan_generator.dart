import '../models/color_analysis.dart';
import '../models/color_allocation.dart';
import '../models/design_color_plan.dart';
import '../models/design_context.dart';
import '../models/material_use.dart';

class ColorPlanGenerator {
  static DesignColorPlan generate({
    required List<ExtractedColorAnalysis> colors,
    required DesignContext context,
  }) {
    if (colors.isEmpty) {
      return const DesignColorPlan(allocations: []);
    }

    final allocations = <ColorAllocation>[];

    final uses = colors.map((color) {
      return _suggestUse(color, context);
    }).toList();

    final weights = <double>[];

    for (var i = 0; i < colors.length; i++) {
      final color = colors[i];

      // نسبة ظهور اللون عامل مؤثر، لكنها ليست نسبة استخدامه النهائية.
      final sourceWeight = color.sourceColor.percentage
          .clamp(1, 100)
          .toDouble();

      final contextWeight = _contextWeight(
        color: color,
        use: uses[i],
        context: context,
      );

      weights.add(sourceWeight * contextWeight);
    }

    final totalWeight = weights.fold<double>(
      0,
      (total, weight) => total + weight,
    );

    double allocated = 0;

    for (var i = 0; i < colors.length; i++) {
      final double percentage;

      if (i == colors.length - 1) {
        // تصحيح التقريب لضمان أن المجموع النهائي يساوي 100%.
        percentage = double.parse((100 - allocated).toStringAsFixed(1));
      } else {
        percentage = double.parse(
          ((weights[i] / totalWeight) * 100).toStringAsFixed(1),
        );
        allocated += percentage;
      }

      allocations.add(
        ColorAllocation(
          colorAnalysis: colors[i],
          suggestedUse: uses[i],
          designPercentage: percentage,
          reason: _getReason(colors[i]),
        ),
      );
    }

    return DesignColorPlan(allocations: allocations);
  }

  static MaterialUse _suggestUse(
    ExtractedColorAnalysis color,
    DesignContext context,
  ) {
    final room = context.roomType;
    final style = context.designStyle;

    final isLight = color.tone == ColorTone.light;
    final isDark = color.tone == ColorTone.dark;
    final isNeutral = color.temperature == ColorTemperature.neutral;
    final isWarm = color.temperature == ColorTemperature.warm;
    final isSaturated = color.saturation >= 0.45;

    // الألوان الداكنة أو شديدة التشبع غالبًا عناصر إبراز.
    if (isDark || isSaturated) {
      if (room == RoomType.kitchen && isDark) {
        return MaterialUse.countertop;
      }

      if (style == DesignStyle.industrial || style == DesignStyle.artDeco) {
        return MaterialUse.accent;
      }

      return MaterialUse.accent;
    }

    // الألوان الفاتحة والمحايدة مناسبة للأسطح الواسعة.
    if (isLight && isNeutral) {
      if (room == RoomType.bathroom) {
        return MaterialUse.wall;
      }

      if (room == RoomType.kitchen) {
        return MaterialUse.wall;
      }

      if (room == RoomType.office) {
        return MaterialUse.wall;
      }

      return MaterialUse.wall;
    }

    // الدرجات الدافئة الطبيعية.
    if (isWarm) {
      switch (room) {
        case RoomType.bedroom:
        case RoomType.masterBedroom:
          return MaterialUse.upholstery;

        case RoomType.livingRoom:
        case RoomType.reception:
          return MaterialUse.furniture;

        case RoomType.kitchen:
          return MaterialUse.furniture;

        case RoomType.diningRoom:
          return MaterialUse.furniture;

        case RoomType.bathroom:
          return MaterialUse.accent;

        case RoomType.office:
          return MaterialUse.furniture;

        case RoomType.other:
          return MaterialUse.furniture;
      }
    }

    // الدرجات الباردة.
    if (color.temperature == ColorTemperature.cool) {
      if (style == DesignStyle.scandinavian ||
          style == DesignStyle.japandi ||
          style == DesignStyle.minimalist) {
        return MaterialUse.wall;
      }

      return MaterialUse.accent;
    }

    // المحايد المتوسط.
    return MaterialUse.wall;
  }

  static double _contextWeight({
    required ExtractedColorAnalysis color,
    required MaterialUse use,
    required DesignContext context,
  }) {
    double weight = 1.0;

    // تأثير الستايل المعماري على توزيع الأدوار.
    switch (context.designStyle) {
      case DesignStyle.japandi:
      case DesignStyle.scandinavian:
      case DesignStyle.minimalist:
        if (use == MaterialUse.wall ||
            use == MaterialUse.flooring ||
            use == MaterialUse.furniture) {
          weight *= 1.25;
        }
        if (use == MaterialUse.accent) weight *= 0.75;
        break;

      case DesignStyle.classic:
      case DesignStyle.neoclassical:
      case DesignStyle.luxury:
        if (use == MaterialUse.accent ||
            use == MaterialUse.furniture ||
            use == MaterialUse.upholstery) {
          weight *= 1.2;
        }
        break;

      case DesignStyle.industrial:
      case DesignStyle.artDeco:
        if (use == MaterialUse.accent ||
            use == MaterialUse.countertop ||
            use == MaterialUse.hardware) {
          weight *= 1.2;
        }
        break;

      case DesignStyle.rustic:
      case DesignStyle.mediterranean:
      case DesignStyle.bohemian:
        if (color.temperature == ColorTemperature.warm) {
          weight *= 1.2;
        }
        break;

      case DesignStyle.modern:
      case DesignStyle.contemporary:
      case DesignStyle.transitional:
      case DesignStyle.other:
        break;
    }

    // تأثير نوع الغرفة.
    switch (context.roomType) {
      case RoomType.bedroom:
      case RoomType.masterBedroom:
        if (use == MaterialUse.upholstery || use == MaterialUse.wall) {
          weight *= 1.15;
        }
        break;

      case RoomType.kitchen:
        if (use == MaterialUse.countertop || use == MaterialUse.wall) {
          weight *= 1.15;
        }
        break;

      case RoomType.bathroom:
        if (use == MaterialUse.wall || use == MaterialUse.flooring) {
          weight *= 1.15;
        }
        break;

      case RoomType.livingRoom:
      case RoomType.reception:
        if (use == MaterialUse.furniture || use == MaterialUse.upholstery) {
          weight *= 1.1;
        }
        break;

      case RoomType.diningRoom:
        if (use == MaterialUse.furniture) {
          weight *= 1.15;
        }
        break;

      case RoomType.office:
      case RoomType.other:
        break;
    }

    // الغرف ذات الإضاءة الطبيعية الضعيفة تحتاج توازنًا أكبر مع الدرجات الفاتحة.
    if (context.naturalLight == NaturalLightLevel.low) {
      if (color.tone == ColorTone.light) {
        weight *= 1.2;
      } else if (color.tone == ColorTone.dark) {
        weight *= 0.8;
      }
    }

    // الإضاءة القوية تسمح بوجود درجات أعمق دون أن تبدو الغرفة معتمة.
    if (context.naturalLight == NaturalLightLevel.high &&
        color.tone == ColorTone.dark) {
      weight *= 1.1;
    }

    return weight;
  }

  static AllocationReason _getReason(ExtractedColorAnalysis color) {
    if (color.saturation >= 0.45) {
      return AllocationReason.saturatedAccent;
    }

    if (color.tone == ColorTone.dark) {
      return AllocationReason.darkAccent;
    }

    if (color.temperature == ColorTemperature.warm) {
      return AllocationReason.warmNatural;
    }

    if (color.temperature == ColorTemperature.cool) {
      return AllocationReason.coolBalanced;
    }

    if (color.tone == ColorTone.light) {
      return AllocationReason.lightNeutral;
    }

    return AllocationReason.neutralBase;
  }
}
