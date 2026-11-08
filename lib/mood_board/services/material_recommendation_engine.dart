import 'dart:math' as math;

import '../models/material_option.dart';
import '../models/material_use.dart';
import '../models/color_allocation.dart';
import '../models/design_context.dart';
import '../models/material_recommendation.dart';

/// الدور الفعلي للخامة (حجر، خشب، قماش...) مستنتج من الاسم والتصنيف.
enum _Role { stone, tile, wood, textile, leather, metal, glass, plaster, other }

class MaterialRecommendationEngine {
  // حدود مطابقة اللون للأسطح الرئيسية والتفاصيل (Accent).
  static const double _maxDeltaEMain = 32;
  static const double _maxLightnessDiffMain = 22;
  static const double _maxDeltaEAccent = 55;
  static const double _maxLightnessDiffAccent = 40;

  static List<MaterialRecommendation> recommend({
    required List<ColorAllocation> allocations,
    required List<MaterialOption> materials,
    required DesignContext context,
    int candidatesPerColor = 3,
  }) {
    if (allocations.isEmpty || materials.isEmpty || candidatesPerColor <= 0) {
      return [];
    }

    final results = <MaterialRecommendation>[];

    // الخامات اللي اتقترحت قبل كده، عشان ما تتكررش بين الاستخدامات.
    final usedMaterials = <String>{};

    for (final allocation in allocations) {
      final scored = <_ScoredMaterial>[];

      for (final material in materials) {
        // استبعاد الخامات غير المعتمدة لهذا الاستخدام.
        if (!material.recommendedUses.contains(allocation.suggestedUse)) {
          continue;
        }

        // استبعاد الخامات ذات HEX غير صالح.
        if (_hexToRgb(material.hex) == null) continue;

        final evaluation = _evaluate(
          allocation: allocation,
          material: material,
          context: context,
        );

        scored.add(
          _ScoredMaterial(
            material: material,
            score: evaluation.score,
            reason: evaluation.reason,
            deltaE: evaluation.deltaE,
            lightnessDiff: evaluation.lightnessDiff,
          ),
        );
      }

      if (scored.isEmpty) continue;

      scored.sort((a, b) {
        final comparison = b.score.compareTo(a.score);

        if (comparison != 0) return comparison;

        return a.material.name.compareTo(b.material.name);
      });

      // فلتر اللون: الخامة لازم تكون قريبة فعلاً من اللون المرجعي.
      final isAccent = allocation.suggestedUse == MaterialUse.accent;

      final maxDeltaE = isAccent ? _maxDeltaEAccent : _maxDeltaEMain;
      final maxLightnessDiff = isAccent
          ? _maxLightnessDiffAccent
          : _maxLightnessDiffMain;

      var pool = scored
          .where(
            (item) =>
                item.deltaE <= maxDeltaE &&
                item.lightnessDiff <= maxLightnessDiff,
          )
          .toList();

      // لو مفيش أي خامة مطابقة، نعرض أقرب خامة متاحة فقط.
      if (pool.isEmpty) {
        final closest = [...scored]
          ..sort((a, b) => a.deltaE.compareTo(b.deltaE));

        pool = [closest.first];
      }

      // تجنب تكرار نفس الخامة في أكتر من استخدام.
      final fresh = pool
          .where((item) => !usedMaterials.contains(item.material.name))
          .toList();

      final chosen = (fresh.isNotEmpty ? fresh : pool)
          .take(candidatesPerColor)
          .toList();

      for (final candidate in chosen) {
        usedMaterials.add(candidate.material.name);

        results.add(
          MaterialRecommendation(
            allocation: allocation,
            material: candidate.material,
            reason: candidate.reason,
          ),
        );
      }
    }

    return results;
  }

  // ---------------------------------------------------------
  // Main material evaluation
  // ---------------------------------------------------------

  static _Evaluation _evaluate({
    required ColorAllocation allocation,
    required MaterialOption material,
    required DesignContext context,
  }) {
    final source = allocation.colorAnalysis.sourceColor;
    final materialRgb = _hexToRgb(material.hex);

    if (materialRgb == null) {
      return const _Evaluation(
        score: 0,
        reason: MaterialMatchReason.functionalUse,
        deltaE: 999,
        lightnessDiff: 999,
      );
    }

    final use = allocation.suggestedUse;
    final isAccent = use == MaterialUse.accent;

    final sourceLab = _rgbToLab(source.red, source.green, source.blue);

    final materialLab = _rgbToLab(
      materialRgb[0],
      materialRgb[1],
      materialRgb[2],
    );

    final deltaE = _deltaE(sourceLab, materialLab);
    final lightnessDiff = (sourceLab[0] - materialLab[0]).abs();

    final description = _description(material);

    final functionalScore = _functionalScore(
      use: use,
      material: material,
      prominence: allocation.designPercentage,
    );

    final styleScore = _styleScore(
      material: material,
      style: context.designStyle,
      description: description,
    );

    final colorScore = _colorScore(
      deltaE: deltaE,
      lightnessDiff: lightnessDiff,
      use: use,
      sourceSaturation: allocation.colorAnalysis.saturation,
    );

    final finishScore = _finishScore(
      use: use,
      material: material,
      description: description,
    );

    final lightingScore = _lightingScore(
      materialLightness: materialLab[0],
      use: use,
      material: material,
      context: context,
      description: description,
    );

    // الأسطح الرئيسية: اللون أهم. التفاصيل (Accent): الوظيفة والستايل أهم.
    // كل مجموعة أوزان مجموعها 1.0.
    final double totalScore = isAccent
        ? functionalScore * 0.35 +
              styleScore * 0.25 +
              colorScore * 0.20 +
              finishScore * 0.12 +
              lightingScore * 0.08
        : functionalScore * 0.28 +
              styleScore * 0.20 +
              colorScore * 0.32 +
              finishScore * 0.10 +
              lightingScore * 0.10;

    final reason = _selectReason(
      use: use,
      deltaE: deltaE,
      styleMatches: material.styleCompatibility.contains(context.designStyle),
    );

    return _Evaluation(
      score: totalScore.clamp(0, 100).toDouble(),
      reason: reason,
      deltaE: deltaE,
      lightnessDiff: lightnessDiff,
    );
  }

  // ---------------------------------------------------------
  // 1. Functional suitability (role-based)
  // ---------------------------------------------------------

  static const Map<MaterialUse, Map<_Role, double>> _roleFitTable = {
    MaterialUse.wall: {
      _Role.plaster: 100,
      _Role.stone: 90,
      _Role.tile: 80,
      _Role.wood: 80,
      _Role.other: 60,
      _Role.textile: 40,
      _Role.leather: 35,
      _Role.glass: 30,
      _Role.metal: 25,
    },
    MaterialUse.ceiling: {
      _Role.plaster: 100,
      _Role.wood: 70,
      _Role.other: 45,
      _Role.stone: 25,
      _Role.tile: 20,
      _Role.metal: 20,
      _Role.textile: 15,
      _Role.leather: 10,
      _Role.glass: 15,
    },
    MaterialUse.flooring: {
      _Role.tile: 100,
      _Role.stone: 100,
      _Role.wood: 100,
      _Role.plaster: 80,
      _Role.other: 45,
      _Role.metal: 15,
      _Role.glass: 10,
      _Role.textile: 10,
      _Role.leather: 5,
    },
    MaterialUse.furniture: {
      _Role.wood: 100,
      _Role.leather: 90,
      _Role.textile: 85,
      _Role.metal: 70,
      _Role.other: 55,
      _Role.stone: 55,
      _Role.glass: 45,
      _Role.tile: 20,
      _Role.plaster: 10,
    },
    MaterialUse.upholstery: {
      _Role.textile: 100,
      _Role.leather: 100,
      _Role.other: 20,
      _Role.wood: 5,
      _Role.stone: 5,
      _Role.tile: 5,
      _Role.plaster: 5,
      _Role.metal: 5,
      _Role.glass: 5,
    },
    MaterialUse.curtains: {
      _Role.textile: 100,
      _Role.other: 20,
      _Role.leather: 10,
      _Role.wood: 5,
      _Role.stone: 5,
      _Role.tile: 5,
      _Role.plaster: 5,
      _Role.metal: 5,
      _Role.glass: 5,
    },
    MaterialUse.accent: {
      _Role.metal: 95,
      _Role.stone: 90,
      _Role.glass: 85,
      _Role.wood: 85,
      _Role.tile: 80,
      _Role.textile: 75,
      _Role.leather: 75,
      _Role.plaster: 70,
      _Role.other: 70,
    },
    MaterialUse.countertop: {
      _Role.stone: 100,
      _Role.tile: 90,
      _Role.wood: 60,
      _Role.metal: 60,
      _Role.plaster: 55,
      _Role.other: 50,
      _Role.glass: 40,
      _Role.textile: 0,
      _Role.leather: 0,
    },
    MaterialUse.doors: {
      _Role.wood: 100,
      _Role.glass: 85,
      _Role.metal: 80,
      _Role.other: 40,
      _Role.plaster: 20,
      _Role.stone: 20,
      _Role.tile: 15,
      _Role.textile: 10,
      _Role.leather: 10,
    },
    MaterialUse.hardware: {
      _Role.metal: 100,
      _Role.glass: 40,
      _Role.other: 30,
      _Role.wood: 10,
      _Role.stone: 10,
      _Role.tile: 10,
      _Role.plaster: 10,
      _Role.textile: 10,
      _Role.leather: 10,
    },
    MaterialUse.fixtures: {
      _Role.metal: 100,
      _Role.glass: 40,
      _Role.other: 30,
      _Role.wood: 10,
      _Role.stone: 10,
      _Role.tile: 10,
      _Role.plaster: 10,
      _Role.textile: 10,
      _Role.leather: 10,
    },
  };

  static double _functionalScore({
    required MaterialUse use,
    required MaterialOption material,
    required double prominence,
  }) {
    if (!material.recommendedUses.contains(use)) {
      return 0;
    }

    final role = _role(material);

    double score = _roleFitTable[use]?[role] ?? 40;

    // الزجاج والمعدن لا يصلحوا يكونوا خامة رئيسية بنسبة كبيرة.
    if (prominence >= 15 && (role == _Role.glass || role == _Role.metal)) {
      score *= 0.7;
    }

    return score;
  }

  static _Role _role(MaterialOption material) {
    final byName = _roleFromText(material.name.toLowerCase());

    if (byName != null) return byName;

    final byType = _roleFromText(
      '${material.materialType} ${material.category}'.toLowerCase(),
    );

    return byType ?? _Role.other;
  }

  static _Role? _roleFromText(String text) {
    if (_has(text, ['glass'])) return _Role.glass;

    if (_has(text, ['leather', 'suede'])) return _Role.leather;

    if (_has(text, [
      'fabric',
      'linen',
      'velvet',
      'boucle',
      'chenille',
      'textile',
      'wool',
      'cotton',
    ])) {
      return _Role.textile;
    }

    if (_has(text, [
      'wood',
      'oak',
      'walnut',
      'rattan',
      'teak',
      'timber',
      'bamboo',
    ])) {
      return _Role.wood;
    }

    if (_has(text, [
      'brass',
      'metal',
      'steel',
      'chrome',
      'bronze',
      'gold',
      'copper',
      'aluminium',
      'aluminum',
    ])) {
      return _Role.metal;
    }

    if (_has(text, ['tile', 'porcelain', 'terrazzo', 'ceramic', 'zellige'])) {
      return _Role.tile;
    }

    if (_has(text, ['plaster', 'microcement', 'cement', 'paint', 'venetian'])) {
      return _Role.plaster;
    }

    if (_has(text, [
      'stone',
      'marble',
      'travertine',
      'granite',
      'quartz',
      'onyx',
      'limestone',
      'slate',
    ])) {
      return _Role.stone;
    }

    return null;
  }

  // ---------------------------------------------------------
  // 2. Architectural style compatibility
  // ---------------------------------------------------------

  static double _styleScore({
    required MaterialOption material,
    required DesignStyle style,
    required String description,
  }) {
    if (material.styleCompatibility.contains(style)) {
      return 100;
    }

    if (material.styleCompatibility.isNotEmpty) {
      return 35;
    }

    final preferences = _stylePreferences(style);

    if (preferences.isEmpty) return 65;

    final matchedKeywords = preferences
        .where((keyword) => description.contains(keyword))
        .length;

    if (matchedKeywords == 0) return 40;

    final matchRatio = matchedKeywords / preferences.length;

    return (50 + matchRatio * 50).clamp(0, 100).toDouble();
  }

  static List<String> _stylePreferences(DesignStyle style) {
    switch (style) {
      case DesignStyle.modern:
        return ['matte', 'black', 'marble', 'smooth', 'minimal'];

      case DesignStyle.contemporary:
        return ['marble', 'wood', 'metal', 'linen', 'neutral'];

      case DesignStyle.classic:
        return ['marble', 'brass', 'walnut', 'polished', 'classic'];

      case DesignStyle.neoclassical:
        return ['marble', 'brass', 'walnut', 'ivory', 'polished'];

      case DesignStyle.japandi:
        return ['oak', 'linen', 'natural', 'matte', 'beige', 'wood'];

      case DesignStyle.scandinavian:
        return ['oak', 'linen', 'natural', 'beige', 'light', 'wood'];

      case DesignStyle.minimalist:
        return ['matte', 'smooth', 'neutral', 'minimal', 'stone'];

      case DesignStyle.industrial:
        return ['black', 'metal', 'dark', 'stone', 'concrete'];

      case DesignStyle.luxury:
        return ['marble', 'brass', 'gold', 'polished', 'walnut'];

      case DesignStyle.bohemian:
        return ['natural', 'linen', 'fabric', 'textured', 'wood'];

      case DesignStyle.mediterranean:
        return ['travertine', 'stone', 'natural', 'warm', 'wood'];

      case DesignStyle.artDeco:
        return ['marble', 'brass', 'gold', 'polished', 'black'];

      case DesignStyle.rustic:
        return ['wood', 'oak', 'natural', 'textured', 'stone'];

      case DesignStyle.transitional:
        return ['marble', 'wood', 'linen', 'neutral', 'brass'];

      case DesignStyle.other:
        return [];
    }
  }

  // ---------------------------------------------------------
  // 3. Color harmony using CIELAB
  // ---------------------------------------------------------

  static double _colorScore({
    required double deltaE,
    required double lightnessDiff,
    required MaterialUse use,
    required double sourceSaturation,
  }) {
    // Base color similarity using CIE76 Delta E.
    double score = 100 * math.exp(-deltaE / 38);

    if (use == MaterialUse.accent) {
      // Accent materials benefit from controlled contrast.
      if (deltaE >= 15 && deltaE <= 30) {
        score += 12;
      } else if (deltaE > 30 && deltaE <= 45) {
        score += 6;
      } else if (deltaE > 55) {
        score -= 12;
      }
    } else {
      // Main surfaces must stay close to the reference color.
      if (deltaE > 45) {
        score -= 10;
      }

      // Penalize big lightness gaps (a dark material for a light surface).
      if (lightnessDiff > 10) {
        score -= (lightnessDiff - 10) * 0.8;
      }
    }

    // Highly saturated source colors allow some flexibility.
    if (sourceSaturation > 0.58) {
      if (deltaE > 20 && deltaE <= 40) {
        score += 5;
      }

      if (deltaE > 55) {
        score -= 8;
      }
    }

    return score.clamp(0, 100).toDouble();
  }

  // ---------------------------------------------------------
  // 4. Finish and texture suitability
  // ---------------------------------------------------------

  static double _finishScore({
    required MaterialUse use,
    required MaterialOption material,
    required String description,
  }) {
    final finish = material.finish.toLowerCase();
    final texture = material.texture.toLowerCase();
    final sheen = material.sheen.toLowerCase();

    final materialDetails = [
      material.name,
      material.category,
      material.materialType,
      material.placement,
      material.description,
      description,
    ].join(' ').toLowerCase();

    double score = 75;

    switch (use) {
      case MaterialUse.upholstery:
      case MaterialUse.curtains:
        if (_has(materialDetails, [
          'linen',
          'fabric',
          'textile',
          'woven',
          'velvet',
          'boucle',
          'chenille',
          'leather',
          'suede',
        ])) {
          score += 20;
        }

        if (_has(materialDetails, ['stone', 'marble', 'metal', 'porcelain'])) {
          score -= 35;
        }

      case MaterialUse.flooring:
      case MaterialUse.countertop:
        if (_has(materialDetails, [
          'stone',
          'marble',
          'travertine',
          'wood',
          'porcelain',
          'terrazzo',
          'microcement',
          'granite',
          'quartz',
        ])) {
          score += 15;
        }

        if (_has(finish, [
          'honed',
          'matte',
          'polished',
          'brushed',
          'natural',
        ])) {
          score += 5;
        }

      case MaterialUse.hardware:
      case MaterialUse.fixtures:
        if (_has(materialDetails, [
          'brass',
          'metal',
          'steel',
          'chrome',
          'bronze',
          'gold',
        ])) {
          score += 20;
        }

      case MaterialUse.wall:
      case MaterialUse.ceiling:
        if (_has(finish, [
          'matte',
          'satin',
          'honed',
          'natural',
          'plaster',
          'brushed',
        ])) {
          score += 12;
        }

      case MaterialUse.furniture:
      case MaterialUse.doors:
      case MaterialUse.accent:
        if (_has(materialDetails, [
          'wood',
          'walnut',
          'oak',
          'brass',
          'fabric',
          'leather',
          'glass',
          'rattan',
          'metal',
        ])) {
          score += 12;
        }
    }

    // Evaluate surface reflectivity according to its application.
    if (_has(sheen, ['high gloss', 'mirror'])) {
      if (use == MaterialUse.wall || use == MaterialUse.ceiling) {
        score -= 8;
      }

      if (use == MaterialUse.flooring) {
        score -= 3;
      }
    }

    if (_has(sheen, ['matte', 'low sheen'])) {
      if (use == MaterialUse.upholstery || use == MaterialUse.furniture) {
        score += 3;
      }
    }

    // Reward complete material surface information.
    if (texture.trim().isNotEmpty) {
      score += 3;
    }

    return score.clamp(0, 100).toDouble();
  }

  // ---------------------------------------------------------
  // 5. Natural lighting suitability
  // ---------------------------------------------------------

  static double _lightingScore({
    required double materialLightness,
    required MaterialUse use,
    required MaterialOption material,
    required DesignContext context,
    required String description,
  }) {
    double score = 80;

    // Determine darkness/lightness from the actual material Lab value.
    final isDark = materialLightness < 40;
    final isLight = materialLightness >= 70;
    final isAccent = use == MaterialUse.accent;

    final isMainSurface =
        use == MaterialUse.wall ||
        use == MaterialUse.ceiling ||
        use == MaterialUse.flooring ||
        use == MaterialUse.countertop;

    final surfaceDetails = [
      material.finish,
      material.texture,
      material.sheen,
      material.description,
      description,
    ].join(' ').toLowerCase();

    final isGlossy = _has(surfaceDetails, [
      'gloss',
      'high gloss',
      'polished',
      'reflective',
    ]);

    final isMatte = _has(surfaceDetails, ['matte', 'matt', 'low sheen']);

    switch (context.naturalLight) {
      case NaturalLightLevel.low:
        // الإضاءة الضعيفة: نفضّل الدرجات الفاتحة ونتجنب الداكنة.
        if (isDark && !isAccent) {
          score -= 25;
        }

        if (isLight) {
          score += 12;
        }

        if (isGlossy && !isDark) {
          score += 4;
        }

      case NaturalLightLevel.medium:
        if (isDark && !isAccent) {
          score -= 8;
        }

        if (isLight) {
          score += 3;
        }

      case NaturalLightLevel.high:
        // الإضاءة العالية: الداكن مقبول كتفصيلة، واللمعان على الأسطح
        // الكبيرة يعمل انعكاس مزعج.
        if (isDark && isAccent) {
          score += 6;
        }

        if (isGlossy && isMainSurface) {
          score -= 8;
        }

        if (isMatte && isMainSurface) {
          score += 4;
        }
    }

    // Small rooms need more careful use of dark surfaces.
    if (context.roomArea != null && context.roomArea! < 12) {
      if (isDark && !isAccent) {
        score -= 10;
      }
    }

    return score.clamp(0, 100).toDouble();
  }

  // ---------------------------------------------------------
  // 6. Explanation selection
  // ---------------------------------------------------------

  static MaterialMatchReason _selectReason({
    required MaterialUse use,
    required double deltaE,
    required bool styleMatches,
  }) {
    if (use == MaterialUse.accent && deltaE >= 15 && deltaE <= 55) {
      return MaterialMatchReason.balancedContrast;
    }

    if (deltaE <= 15) {
      return MaterialMatchReason.tonalHarmony;
    }

    if (styleMatches) {
      return MaterialMatchReason.styleCharacter;
    }

    if (deltaE <= 28) {
      return MaterialMatchReason.tonalHarmony;
    }

    return MaterialMatchReason.functionalUse;
  }

  // ---------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------

  static String _description(MaterialOption material) {
    return [
      material.name,
      material.category,
      material.materialType,
      material.placement,
      material.finish,
      material.texture,
      material.sheen,
      material.description,
    ].join(' ').toLowerCase();
  }

  static bool _has(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  // Supports #RGB and #RRGGBB.
  static List<int>? _hexToRgb(String hex) {
    try {
      var value = hex.replaceAll('#', '').trim();

      if (value.length == 3) {
        value = value.split('').map((c) => '$c$c').join();
      }

      if (value.length != 6) return null;

      final number = int.parse(value, radix: 16);

      return [(number >> 16) & 0xFF, (number >> 8) & 0xFF, number & 0xFF];
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------
  // RGB -> CIELAB (D65)
  // ---------------------------------------------------------

  static List<double> _rgbToLab(int red, int green, int blue) {
    double linearize(int value) {
      final v = value.clamp(0, 255) / 255.0;

      return v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize(red);
    final g = linearize(green);
    final b = linearize(blue);

    final x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;

    final y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750;

    final z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883;

    double transform(double value) {
      const delta = 6 / 29;

      return value > delta * delta * delta
          ? math.pow(value, 1 / 3).toDouble()
          : value / (3 * delta * delta) + 4 / 29;
    }

    final fx = transform(x);
    final fy = transform(y);
    final fz = transform(z);

    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  // CIE76 Delta E.
  static double _deltaE(List<double> first, List<double> second) {
    final dl = first[0] - second[0];
    final da = first[1] - second[1];
    final db = first[2] - second[2];

    return math.sqrt(dl * dl + da * da + db * db);
  }
}

// ---------------------------------------------------------
// Internal evaluation models
// ---------------------------------------------------------

class _Evaluation {
  final double score;
  final MaterialMatchReason reason;
  final double deltaE;
  final double lightnessDiff;

  const _Evaluation({
    required this.score,
    required this.reason,
    required this.deltaE,
    required this.lightnessDiff,
  });
}

class _ScoredMaterial {
  final MaterialOption material;
  final double score;
  final MaterialMatchReason reason;
  final double deltaE;
  final double lightnessDiff;

  const _ScoredMaterial({
    required this.material,
    required this.score,
    required this.reason,
    required this.deltaE,
    required this.lightnessDiff,
  });
}
