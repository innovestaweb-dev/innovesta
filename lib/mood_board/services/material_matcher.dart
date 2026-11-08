import 'dart:math' as math;

import 'color_extractor.dart';

import '../models/material_option.dart';
import '../models/material_use.dart';
import '../models/color_allocation.dart';

class MaterialMatch {
  final MaterialOption material;
  final double score;
  final String reason;

  const MaterialMatch({
    required this.material,
    required this.score,
    required this.reason,
  });
}

class _ColorAnalysis {
  final double hue;
  final double saturation;
  final double lightness;

  const _ColorAnalysis({
    required this.hue,
    required this.saturation,
    required this.lightness,
  });
}

class MaterialMatcher {
  static List<MaterialMatch> recommend({
    required List<ExtractedColor> extractedColors,
    required List<MaterialOption> materials,
    List<ColorAllocation> allocations = const [],
    int limit = 6,
  }) {
    if (extractedColors.isEmpty || materials.isEmpty || limit <= 0) {
      return [];
    }

    final results = <MaterialMatch>[];

    for (final color in extractedColors) {
      final analysis = _analyzeColor(color);
      final rules = _getDesignRules(analysis);

      // البحث عن توزيع التصميم المرتبط بهذا اللون.
      final allocation = _findAllocation(color, allocations);

      final suggestedUse = allocation?.suggestedUse;

      for (final material in materials) {
        // عند وجود توزيع، لا نقبل خامة غير مناسبة للاستخدام المحدد.
        if (suggestedUse != null &&
            !material.recommendedUses.contains(suggestedUse)) {
          continue;
        }

        final suitability = _getMaterialSuitability(
          material: material,
          color: analysis,
          suggestedUse: suggestedUse,
        );

        if (suitability <= 0) continue;

        final score = suitability * (color.percentage / 100.0);

        results.add(
          MaterialMatch(
            material: material,
            score: score.clamp(0.0, 10.0).toDouble(),
            reason: rules.join(' • '),
          ),
        );
      }
    }

    // منع تكرار نفس الخامة في النتائج.
    final uniqueResults = <String, MaterialMatch>{};

    for (final result in results) {
      final key =
          '${result.material.category.toLowerCase()}_${result.material.name.toLowerCase()}';

      final existing = uniqueResults[key];

      if (existing == null || result.score > existing.score) {
        uniqueResults[key] = result;
      }
    }

    final sortedResults = uniqueResults.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return sortedResults.take(math.min(limit, sortedResults.length)).toList();
  }

  // ربط اللون بتوزيع الاستخدام الخاص به.
  static ColorAllocation? _findAllocation(
    ExtractedColor color,
    List<ColorAllocation> allocations,
  ) {
    for (final allocation in allocations) {
      if (_normalizeHex(allocation.colorAnalysis.sourceColor.hex) ==
          _normalizeHex(color.hex)) {
        return allocation;
      }
    }

    return null;
  }

  static String _normalizeHex(String hex) {
    return hex.replaceAll('#', '').toUpperCase();
  }

  // تحليل اللون باستخدام HSL.
  static _ColorAnalysis _analyzeColor(ExtractedColor color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;

    final maxValue = [r, g, b].reduce(math.max);
    final minValue = [r, g, b].reduce(math.min);

    final delta = maxValue - minValue;

    double hue = 0;
    double saturation = 0;

    final lightness = (maxValue + minValue) / 2;

    if (delta != 0) {
      saturation = delta / (1 - (2 * lightness - 1).abs());

      if (maxValue == r) {
        hue = 60 * (((g - b) / delta) % 6);
      } else if (maxValue == g) {
        hue = 60 * (((b - r) / delta) + 2);
      } else {
        hue = 60 * (((r - g) / delta) + 4);
      }
    }

    if (hue < 0) {
      hue += 360;
    }

    return _ColorAnalysis(
      hue: hue,
      saturation: saturation,
      lightness: lightness,
    );
  }

  // تحديد القواعد التصميمية المرتبطة باللون.
  static List<String> _getDesignRules(_ColorAnalysis color) {
    final rules = <String>[];

    if (color.lightness >= 0.78) {
      rules.add('Suitable for large walls and ceilings');
    } else if (color.lightness <= 0.28) {
      rules.add('Best for accent walls and small details');
    } else {
      rules.add('Suitable for flooring and large furniture');
    }

    if (color.saturation < 0.18) {
      rules.add('Neutral palette');
    } else if (color.hue <= 70 || color.hue >= 330) {
      rules.add('Warm palette: wood and fabrics');
    } else if (color.hue >= 160 && color.hue <= 280) {
      rules.add('Cool palette: marble and metals');
    } else {
      rules.add('Balanced decorative palette');
    }

    return rules;
  }

  // تقييم مدى ملاءمة الخامة للون والاستخدام.
  static double _getMaterialSuitability({
    required MaterialOption material,
    required _ColorAnalysis color,
    MaterialUse? suggestedUse,
  }) {
    final category = material.category.toLowerCase();
    final placement = material.placement.toLowerCase();
    final name = material.name.toLowerCase();
    final finish = material.finish.toLowerCase();
    final texture = material.texture.toLowerCase();
    final sheen = material.sheen.toLowerCase();

    double score = 0;

    final isWarm = color.hue <= 70 || color.hue >= 330;
    final isCool = color.hue >= 160 && color.hue <= 280;
    final isNeutral = color.saturation < 0.18;

    // 1. توافق الاستخدام الوظيفي.
    if (suggestedUse != null &&
        material.recommendedUses.contains(suggestedUse)) {
      score += 2.5;
    }

    // 2. توافق درجة اللون مع مكان الاستخدام.
    if (color.lightness >= 0.78) {
      if (placement.contains('wall') ||
          placement.contains('surface') ||
          placement.contains('ceiling')) {
        score += 2.0;
      }

      if (name.contains('beige') ||
          name.contains('travertine') ||
          name.contains('ivory')) {
        score += 1.0;
      }
    } else if (color.lightness <= 0.28) {
      if (placement.contains('accent') ||
          placement.contains('wall') ||
          placement.contains('furniture') ||
          placement.contains('details') ||
          placement.contains('door')) {
        score += 2.0;
      }

      if (name.contains('dark') ||
          name.contains('black') ||
          name.contains('olive')) {
        score += 1.0;
      }
    } else {
      if (placement.contains('floor') || placement.contains('furniture')) {
        score += 2.0;
      }

      if (category.contains('stone') || category.contains('wood')) {
        score += 1.0;
      }
    }

    // 3. توافق درجة حرارة اللون مع نوع الخامة.
    if (isWarm) {
      if (category.contains('wood') || category.contains('fabric')) {
        score += 2.0;
      }

      if (name.contains('beige') ||
          name.contains('travertine') ||
          name.contains('ivory')) {
        score += 1.0;
      }
    }

    if (isCool) {
      if (category.contains('stone') || category.contains('metal')) {
        score += 2.0;
      }

      if (name.contains('marble') || name.contains('black')) {
        score += 1.0;
      }
    }

    if (isNeutral) {
      if (category.contains('stone') ||
          category.contains('wood') ||
          category.contains('fabric')) {
        score += 1.5;
      }
    }

    // 4. توافق التشطيب مع طبيعة اللون.
    if (color.lightness <= 0.28) {
      if (finish.contains('matte') ||
          finish.contains('honed') ||
          finish.contains('brushed')) {
        score += 0.5;
      }
    } else if (color.lightness >= 0.78) {
      if (finish.contains('polished') ||
          finish.contains('glossy') ||
          finish.contains('satin')) {
        score += 0.5;
      }
    }

    // 5. توافق درجة اللمعان مع طبيعة اللون.
    if (color.lightness <= 0.28) {
      if (sheen.contains('matte') || sheen.contains('satin')) {
        score += 0.5;
      }
    } else if (color.lightness >= 0.78) {
      if (sheen.contains('gloss') ||
          sheen.contains('polished') ||
          sheen.contains('satin')) {
        score += 0.5;
      }
    }

    // 6. توافق الملمس مع طبيعة اللون.
    if (isWarm &&
        (texture.contains('natural') ||
            texture.contains('grain') ||
            texture.contains('wood'))) {
      score += 0.5;
    }

    if (isCool &&
        (texture.contains('vein') ||
            texture.contains('smooth') ||
            texture.contains('stone'))) {
      score += 0.5;
    }

    // 6. مقارنة اللون المستخرج بلون الخامة.
    score += _getColorSimilarity(material.hex, color);

    return score;
  }

  // مقارنة اللونين وإرجاع نتيجة من صفر إلى 2.
  static double _getColorSimilarity(String materialHex, _ColorAnalysis color) {
    final materialRgb = _parseHexColor(materialHex);

    if (materialRgb == null) {
      return 0;
    }

    final materialAnalysis = _analyzeRgb(
      materialRgb[0],
      materialRgb[1],
      materialRgb[2],
    );

    final hueDifference = math.min(
      (color.hue - materialAnalysis.hue).abs(),
      360 - (color.hue - materialAnalysis.hue).abs(),
    );

    final hueSimilarity = 1.0 - (hueDifference / 180.0);

    final saturationDifference =
        (color.saturation - materialAnalysis.saturation).abs();

    final saturationSimilarity = 1.0 - saturationDifference;

    final lightnessDifference = (color.lightness - materialAnalysis.lightness)
        .abs();

    final lightnessSimilarity = 1.0 - lightnessDifference;

    final similarity =
        (hueSimilarity * 0.30 +
        saturationSimilarity * 0.25 +
        lightnessSimilarity * 0.45);

    return similarity.clamp(0.0, 1.0).toDouble() * 2.0;
  }

  // تحويل HEX إلى RGB.
  static List<int>? _parseHexColor(String hex) {
    try {
      String value = hex.replaceAll('#', '').trim();

      if (value.length == 3) {
        value = value.split('').map((c) => '$c$c').join();
      }

      if (value.length != 6) {
        return null;
      }

      return [
        int.parse(value.substring(0, 2), radix: 16),
        int.parse(value.substring(2, 4), radix: 16),
        int.parse(value.substring(4, 6), radix: 16),
      ];
    } catch (_) {
      return null;
    }
  }

  static _ColorAnalysis _analyzeRgb(int red, int green, int blue) {
    final r = red / 255.0;
    final g = green / 255.0;
    final b = blue / 255.0;

    final maxValue = [r, g, b].reduce(math.max);
    final minValue = [r, g, b].reduce(math.min);

    final delta = maxValue - minValue;

    double hue = 0;
    double saturation = 0;

    final lightness = (maxValue + minValue) / 2;

    if (delta != 0) {
      saturation = delta / (1 - (2 * lightness - 1).abs());

      if (maxValue == r) {
        hue = 60 * (((g - b) / delta) % 6);
      } else if (maxValue == g) {
        hue = 60 * (((b - r) / delta) + 2);
      } else {
        hue = 60 * (((r - g) / delta) + 4);
      }
    }

    if (hue < 0) {
      hue += 360;
    }

    return _ColorAnalysis(
      hue: hue,
      saturation: saturation,
      lightness: lightness,
    );
  }
}
