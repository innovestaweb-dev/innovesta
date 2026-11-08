import 'package:flutter_application_1/app_language.dart';

import '../services/color_extractor.dart';

enum ColorTemperature { warm, cool, neutral }

enum ColorTone { light, medium, dark }

class ExtractedColorAnalysis {
  final ExtractedColor sourceColor;

  final double hue;
  final double saturation;
  final double lightness;

  final ColorTemperature temperature;
  final ColorTone tone;

  const ExtractedColorAnalysis({
    required this.sourceColor,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.temperature,
    required this.tone,
  });

  String get temperatureLabel {
    switch (temperature) {
      case ColorTemperature.warm:
        return AppLanguage.text('Warm', 'دافئ');

      case ColorTemperature.cool:
        return AppLanguage.text('Cool', 'بارد');

      case ColorTemperature.neutral:
        return AppLanguage.text('Neutral', 'محايد');
    }
  }

  String get toneLabel {
    switch (tone) {
      case ColorTone.light:
        return AppLanguage.text('Light', 'فاتح');

      case ColorTone.medium:
        return AppLanguage.text('Medium', 'متوسط');

      case ColorTone.dark:
        return AppLanguage.text('Dark', 'غامق');
    }
  }
}
