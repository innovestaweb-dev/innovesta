import 'dart:math' as math;

import '../models/color_analysis.dart';
import 'color_extractor.dart';

class ColorAnalyzer {
  static List<ExtractedColorAnalysis> analyze(List<ExtractedColor> colors) {
    return colors.map(_analyzeSingleColor).toList();
  }

  static ExtractedColorAnalysis _analyzeSingleColor(ExtractedColor color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;

    final maxValue = math.max(r, math.max(g, b));
    final minValue = math.min(r, math.min(g, b));

    final delta = maxValue - minValue;

    final lightness = (maxValue + minValue) / 2.0;

    double hue = 0;
    double saturation = 0;

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

    // تحديد حرارة اللون.
    // نعطي الأولوية للتشبع المنخفض حتى لا نصنف الرمادي كدافئ.
    final ColorTemperature temperature;

    if (saturation < 0.12) {
      temperature = ColorTemperature.neutral;
    } else if (hue <= 70 || hue >= 330) {
      temperature = ColorTemperature.warm;
    } else if (hue >= 160 && hue <= 280) {
      temperature = ColorTemperature.cool;
    } else {
      temperature = ColorTemperature.neutral;
    }

    // تحديد درجة الإضاءة.
    final ColorTone tone;

    if (lightness >= 0.70) {
      tone = ColorTone.light;
    } else if (lightness <= 0.30) {
      tone = ColorTone.dark;
    } else {
      tone = ColorTone.medium;
    }

    return ExtractedColorAnalysis(
      sourceColor: color,
      hue: hue,
      saturation: saturation,
      lightness: lightness,
      temperature: temperature,
      tone: tone,
    );
  }
}
