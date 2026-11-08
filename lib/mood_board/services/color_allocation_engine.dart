import '../models/color_analysis.dart';
import '../models/color_allocation.dart';
import '../models/design_color_plan.dart';
import '../models/design_context.dart';
import '../models/material_use.dart';

class ColorAllocationEngine {
  // أوزان مبدئية حسب ترتيب اللون في الصورة.
  static const List<double> _baseWeights = [42.0, 22.0, 14.0, 10.0, 7.0, 5.0];

  static DesignColorPlan generate({
    required List<ExtractedColorAnalysis> extractedColors,
    required DesignContext context,
  }) {
    if (extractedColors.isEmpty) {
      return const DesignColorPlan(allocations: []);
    }

    // ترتيب الألوان حسب نسبة ظهورها في الصورة.
    final colors = [...extractedColors]
      ..sort(
        (a, b) => b.sourceColor.percentage.compareTo(a.sourceColor.percentage),
      );

    // -----------------------------------------------------------------
    // 1) تحديد الاستخدام المناسب لكل لون.
    // -----------------------------------------------------------------
    final uses = <MaterialUse>[];
    final assignedUseCounts = <MaterialUse, int>{};

    for (int i = 0; i < colors.length; i++) {
      final use = _getSuggestedUse(
        color: colors[i],
        context: context,
        index: i,
        assignedUseCounts: assignedUseCounts,
      );

      uses.add(use);
      assignedUseCounts.update(use, (count) => count + 1, ifAbsent: () => 1);
    }

    // -----------------------------------------------------------------
    // 2) حساب الأوزان: خصائص اللون + الإضاءة + الستايل + الغرفة.
    // -----------------------------------------------------------------
    final weights = <double>[];

    for (int i = 0; i < colors.length; i++) {
      final weight =
          _colorWeight(colors[i], i, context) *
          _styleUseWeight(context.designStyle, uses[i]) *
          _roomUseWeight(context.roomType, uses[i]);

      weights.add(weight);
    }

    final totalWeight = weights.fold<double>(0, (sum, value) => sum + value);

    var shares = weights.map((w) => w / totalWeight * 100).toList();

    // -----------------------------------------------------------------
    // 3) سقف النسبة لكل استخدام، حتى لا يأخذ الزجاج أو الإكسسوارات
    //    نسبة الأسطح الرئيسية. الزيادة توزع على باقي الاستخدامات.
    // -----------------------------------------------------------------
    final caps = <double>[
      for (int i = 0; i < colors.length; i++)
        _maxShare(uses[i]) / assignedUseCounts[uses[i]]!,
    ];

    shares = _applyCaps(shares, caps);

    final rounded = _roundToHundred(shares);

    final allocations = <ColorAllocation>[
      for (int i = 0; i < colors.length; i++)
        ColorAllocation(
          colorAnalysis: colors[i],
          suggestedUse: uses[i],
          designPercentage: rounded[i],
          reason: _getReason(colors[i]),
        ),
    ];

    return DesignColorPlan(allocations: allocations);
  }

  // ---------------------------------------------------------------------
  // الأوزان
  // ---------------------------------------------------------------------

  static double _colorWeight(
    ExtractedColorAnalysis color,
    int index,
    DesignContext context,
  ) {
    final weightIndex = index < _baseWeights.length
        ? index
        : _baseWeights.length - 1;

    double weight = _baseWeights[weightIndex];

    // الألوان شديدة التشبع لا تستخدم عادة في مساحات ضخمة.
    if (color.saturation >= 0.58) {
      weight *= 0.70;
    }

    if (color.tone == ColorTone.dark) {
      // تقليل الاعتماد على الألوان الداكنة.
      weight *= 0.78;

      if (context.roomArea != null && context.roomArea! < 12) {
        weight *= 0.82;
      }

      switch (context.naturalLight) {
        case NaturalLightLevel.low:
          weight *= 0.82;
        case NaturalLightLevel.medium:
          break;
        case NaturalLightLevel.high:
          // الإضاءة العالية تتحمل الدرجات الداكنة أكثر.
          weight *= 1.10;
      }
    }

    // الألوان الفاتحة والمحايدة مناسبة للقاعدة الرئيسية.
    if (color.tone == ColorTone.light && color.saturation < 0.20) {
      weight *= 1.12;

      // الإضاءة المنخفضة تحتاج قاعدة أفتح.
      if (context.naturalLight == NaturalLightLevel.low) {
        weight *= 1.08;
      }
    }

    return weight;
  }

  // تأثير الستايل على نسبة كل استخدام.
  static double _styleUseWeight(DesignStyle style, MaterialUse use) {
    final Map<MaterialUse, double> weights;

    switch (style) {
      case DesignStyle.japandi:
      case DesignStyle.scandinavian:
      case DesignStyle.minimalist:
        weights = {
          MaterialUse.accent: 0.60,
          MaterialUse.wall: 1.15,
          MaterialUse.flooring: 1.05,
        };

      case DesignStyle.modern:
      case DesignStyle.contemporary:
        weights = {
          MaterialUse.accent: 0.80,
          MaterialUse.wall: 1.05,
          MaterialUse.hardware: 0.90,
        };

      case DesignStyle.industrial:
        weights = {
          MaterialUse.hardware: 1.50,
          MaterialUse.flooring: 1.15,
          MaterialUse.accent: 0.90,
          MaterialUse.curtains: 0.80,
          MaterialUse.upholstery: 0.85,
        };

      case DesignStyle.classic:
      case DesignStyle.neoclassical:
        weights = {
          MaterialUse.upholstery: 1.20,
          MaterialUse.curtains: 1.20,
          MaterialUse.furniture: 1.10,
          MaterialUse.accent: 1.30,
          MaterialUse.wall: 0.95,
        };

      case DesignStyle.luxury:
      case DesignStyle.artDeco:
        weights = {
          MaterialUse.accent: 1.50,
          MaterialUse.upholstery: 1.20,
          MaterialUse.fixtures: 1.30,
          MaterialUse.hardware: 1.30,
          MaterialUse.furniture: 1.10,
        };

      case DesignStyle.bohemian:
        weights = {
          MaterialUse.accent: 1.40,
          MaterialUse.curtains: 1.20,
          MaterialUse.upholstery: 1.20,
          MaterialUse.wall: 0.90,
        };

      case DesignStyle.rustic:
      case DesignStyle.mediterranean:
        weights = {
          MaterialUse.flooring: 1.15,
          MaterialUse.furniture: 1.10,
          MaterialUse.wall: 1.05,
          MaterialUse.accent: 1.10,
        };

      case DesignStyle.transitional:
      case DesignStyle.other:
        weights = const {};
    }

    return weights[use] ?? 1.0;
  }

  // تأثير نوع الغرفة على نسبة كل استخدام.
  static double _roomUseWeight(RoomType room, MaterialUse use) {
    switch (room) {
      case RoomType.kitchen:
        return use == MaterialUse.countertop ? 1.15 : 1.0;

      case RoomType.bathroom:
        return use == MaterialUse.fixtures ? 1.15 : 1.0;

      case RoomType.bedroom:
      case RoomType.masterBedroom:
        return (use == MaterialUse.upholstery || use == MaterialUse.curtains)
            ? 1.10
            : 1.0;

      case RoomType.office:
      case RoomType.diningRoom:
        return use == MaterialUse.furniture ? 1.10 : 1.0;

      case RoomType.livingRoom:
      case RoomType.reception:
      case RoomType.other:
        return 1.0;
    }
  }

  // أقصى نسبة منطقية لكل استخدام (إجمالي كل الألوان المخصصة له).
  static double _maxShare(MaterialUse use) {
    switch (use) {
      case MaterialUse.wall:
        return 45;
      case MaterialUse.flooring:
        return 30;
      case MaterialUse.furniture:
        return 25;
      case MaterialUse.countertop:
        return 22;
      case MaterialUse.upholstery:
        return 20;
      case MaterialUse.ceiling:
        return 15;
      case MaterialUse.curtains:
        return 12;
      case MaterialUse.doors:
        return 12;
      case MaterialUse.accent:
        return 10;
      case MaterialUse.fixtures:
        return 8;
      case MaterialUse.hardware:
        return 6;
    }
  }

  // يقص النسب عند السقف ويوزع الزيادة على العناصر التي لم تصل للسقف.
  static List<double> _applyCaps(List<double> shares, List<double> caps) {
    final result = [...shares];

    for (int iteration = 0; iteration < 10; iteration++) {
      double excess = 0;
      final free = <int>[];

      for (int i = 0; i < result.length; i++) {
        if (result[i] > caps[i]) {
          excess += result[i] - caps[i];
          result[i] = caps[i];
        } else if (result[i] < caps[i] - 0.01) {
          free.add(i);
        }
      }

      if (excess < 0.01 || free.isEmpty) break;

      final freeTotal = free.fold<double>(0, (sum, i) => sum + result[i]);

      for (final i in free) {
        final portion = freeTotal > 0 ? result[i] / freeTotal : 1 / free.length;
        result[i] += excess * portion;
      }
    }

    // لو عدد الألوان قليل والسقوف كلها اتملت، نرجّع المجموع 100.
    final total = result.fold<double>(0, (sum, value) => sum + value);

    if (total > 0 && (total - 100).abs() > 0.01) {
      return result.map((value) => value / total * 100).toList();
    }

    return result;
  }

  // تقريب لرقم عشري واحد مع ضمان أن المجموع 100.0.
  static List<double> _roundToHundred(List<double> shares) {
    final rounded = shares
        .map((value) => double.parse(value.toStringAsFixed(1)))
        .toList();

    final difference = 100.0 - rounded.fold<double>(0, (sum, v) => sum + v);

    if (difference.abs() > 0.001) {
      int largest = 0;

      for (int i = 1; i < rounded.length; i++) {
        if (rounded[i] > rounded[largest]) largest = i;
      }

      rounded[largest] = double.parse(
        (rounded[largest] + difference).toStringAsFixed(1),
      );
    }

    return rounded;
  }

  // ---------------------------------------------------------------------
  // الاستخدامات
  // ---------------------------------------------------------------------

  // الاستخدامات المسموحة حسب نوع الغرفة.
  static List<MaterialUse> _getRoomUses(DesignContext context) {
    switch (context.roomType) {
      case RoomType.bedroom:
      case RoomType.masterBedroom:
        return [
          MaterialUse.wall,
          MaterialUse.upholstery,
          MaterialUse.furniture,
          MaterialUse.flooring,
          MaterialUse.curtains,
          MaterialUse.accent,
        ];

      case RoomType.kitchen:
        return [
          MaterialUse.wall,
          MaterialUse.countertop,
          MaterialUse.furniture,
          MaterialUse.flooring,
          MaterialUse.accent,
          MaterialUse.fixtures,
        ];

      case RoomType.bathroom:
        return [
          MaterialUse.wall,
          MaterialUse.flooring,
          MaterialUse.countertop,
          MaterialUse.fixtures,
          MaterialUse.accent,
          MaterialUse.ceiling,
        ];

      case RoomType.office:
        return [
          MaterialUse.wall,
          MaterialUse.furniture,
          MaterialUse.flooring,
          MaterialUse.upholstery,
          MaterialUse.accent,
          MaterialUse.hardware,
        ];

      case RoomType.diningRoom:
        return [
          MaterialUse.wall,
          MaterialUse.furniture,
          MaterialUse.upholstery,
          MaterialUse.flooring,
          MaterialUse.accent,
          MaterialUse.fixtures,
        ];

      case RoomType.livingRoom:
      case RoomType.reception:
      case RoomType.other:
        return [
          MaterialUse.wall,
          MaterialUse.upholstery,
          MaterialUse.flooring,
          MaterialUse.furniture,
          MaterialUse.accent,
          MaterialUse.curtains,
        ];
    }
  }

  static MaterialUse _getSuggestedUse({
    required ExtractedColorAnalysis color,
    required DesignContext context,
    required int index,
    required Map<MaterialUse, int> assignedUseCounts,
  }) {
    final allowedUses = _getRoomUses(context);

    final style = context.designStyle;
    final room = context.roomType;

    // ترتيب الاستخدامات المفضلة حسب نوع الغرفة.
    List<MaterialUse> roomPreferences() {
      switch (room) {
        case RoomType.bedroom:
        case RoomType.masterBedroom:
          return [
            MaterialUse.wall,
            MaterialUse.upholstery,
            MaterialUse.curtains,
            MaterialUse.furniture,
            MaterialUse.flooring,
            MaterialUse.accent,
          ];

        case RoomType.livingRoom:
        case RoomType.reception:
          return [
            MaterialUse.wall,
            MaterialUse.upholstery,
            MaterialUse.flooring,
            MaterialUse.curtains,
            MaterialUse.furniture,
            MaterialUse.accent,
          ];

        case RoomType.kitchen:
          return [
            MaterialUse.countertop,
            MaterialUse.wall,
            MaterialUse.furniture,
            MaterialUse.flooring,
            MaterialUse.fixtures,
            MaterialUse.accent,
          ];

        case RoomType.bathroom:
          return [
            MaterialUse.wall,
            MaterialUse.flooring,
            MaterialUse.countertop,
            MaterialUse.fixtures,
            MaterialUse.ceiling,
            MaterialUse.accent,
          ];

        case RoomType.office:
          return [
            MaterialUse.wall,
            MaterialUse.furniture,
            MaterialUse.flooring,
            MaterialUse.upholstery,
            MaterialUse.hardware,
            MaterialUse.accent,
          ];

        case RoomType.diningRoom:
          return [
            MaterialUse.wall,
            MaterialUse.furniture,
            MaterialUse.upholstery,
            MaterialUse.flooring,
            MaterialUse.fixtures,
            MaterialUse.accent,
          ];

        case RoomType.other:
          return allowedUses;
      }
    }

    // اختيار الاستخدام الأنسب مع تقليل التكرار.
    MaterialUse choose(List<MaterialUse> preferences) {
      final validUses = preferences
          .where((use) => allowedUses.contains(use))
          .toList();

      if (validUses.isEmpty) {
        return allowedUses[index % allowedUses.length];
      }

      final preferredRoomUses = roomPreferences();

      validUses.sort((a, b) {
        final countA = assignedUseCounts[a] ?? 0;
        final countB = assignedUseCounts[b] ?? 0;

        // الأولوية لتقليل تكرار الاستخدام.
        final countComparison = countA.compareTo(countB);

        if (countComparison != 0) {
          return countComparison;
        }

        // ثم أولوية الاستخدام حسب نوع الغرفة.
        final roomRankA = preferredRoomUses.indexOf(a);
        final roomRankB = preferredRoomUses.indexOf(b);

        final roomComparison = roomRankA.compareTo(roomRankB);

        if (roomComparison != 0) {
          return roomComparison;
        }

        // ثم أولوية اللون حسب خصائصه والستايل.
        return preferences.indexOf(a).compareTo(preferences.indexOf(b));
      });

      return validUses.first;
    }

    // الألوان شديدة التشبع: تفاصيل مميزة أو تنجيد.
    if (color.saturation >= 0.58) {
      return choose([
        MaterialUse.accent,
        MaterialUse.upholstery,
        MaterialUse.furniture,
      ]);
    }

    // الألوان الفاتحة والمحايدة: الأسطح الرئيسية.
    if (color.tone == ColorTone.light && color.saturation < 0.20) {
      return choose([
        MaterialUse.wall,
        MaterialUse.ceiling,
        MaterialUse.curtains,
      ]);
    }

    // الألوان الداكنة: حسب الستايل.
    if (color.tone == ColorTone.dark) {
      switch (style) {
        case DesignStyle.industrial:
          return choose([
            MaterialUse.hardware,
            MaterialUse.flooring,
            MaterialUse.furniture,
            MaterialUse.accent,
          ]);

        case DesignStyle.classic:
        case DesignStyle.neoclassical:
        case DesignStyle.luxury:
        case DesignStyle.artDeco:
          return choose([
            MaterialUse.furniture,
            MaterialUse.upholstery,
            MaterialUse.accent,
            MaterialUse.flooring,
          ]);

        case DesignStyle.japandi:
        case DesignStyle.scandinavian:
        case DesignStyle.minimalist:
          return choose([
            MaterialUse.furniture,
            MaterialUse.flooring,
            MaterialUse.accent,
          ]);

        default:
          return choose([
            MaterialUse.furniture,
            MaterialUse.flooring,
            MaterialUse.accent,
          ]);
      }
    }

    // الألوان الدافئة متوسطة الدرجة.
    if (color.temperature == ColorTemperature.warm) {
      switch (style) {
        case DesignStyle.japandi:
        case DesignStyle.scandinavian:
        case DesignStyle.rustic:
        case DesignStyle.mediterranean:
          return choose([
            MaterialUse.flooring,
            MaterialUse.furniture,
            MaterialUse.upholstery,
            MaterialUse.wall,
          ]);

        case DesignStyle.classic:
        case DesignStyle.neoclassical:
        case DesignStyle.luxury:
        case DesignStyle.artDeco:
          return choose([
            MaterialUse.upholstery,
            MaterialUse.furniture,
            MaterialUse.accent,
            MaterialUse.wall,
          ]);

        default:
          return choose([
            MaterialUse.furniture,
            MaterialUse.wall,
            MaterialUse.upholstery,
            MaterialUse.flooring,
          ]);
      }
    }

    // الألوان الباردة متوسطة الدرجة.
    switch (context.roomType) {
      case RoomType.kitchen:
        return choose([
          MaterialUse.countertop,
          MaterialUse.wall,
          MaterialUse.flooring,
        ]);

      case RoomType.bathroom:
        return choose([
          MaterialUse.wall,
          MaterialUse.flooring,
          MaterialUse.countertop,
        ]);

      case RoomType.office:
        return choose([
          MaterialUse.wall,
          MaterialUse.furniture,
          MaterialUse.flooring,
        ]);

      default:
        return choose([
          MaterialUse.wall,
          MaterialUse.upholstery,
          MaterialUse.curtains,
          MaterialUse.furniture,
        ]);
    }
  }

  static AllocationReason _getReason(ExtractedColorAnalysis color) {
    if (color.saturation >= 0.58) {
      return AllocationReason.saturatedAccent;
    }

    if (color.tone == ColorTone.dark) {
      return AllocationReason.darkAccent;
    }

    if (color.saturation < 0.12) {
      return AllocationReason.neutralBase;
    }

    if (color.tone == ColorTone.light) {
      return AllocationReason.lightNeutral;
    }

    if (color.temperature == ColorTemperature.warm) {
      return AllocationReason.warmNatural;
    }

    return AllocationReason.coolBalanced;
  }
}
