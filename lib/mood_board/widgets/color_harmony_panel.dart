import 'package:flutter/material.dart';

const Color _bg = Color(0xFF171717);
const Color _surface = Color(0xFF222222);
const Color _ivory = Color(0xFFF4EFE6);
const Color _bronze = Color(0xFFB6A080);
const Color _muted = Color(0xFFAAA69F);

enum HarmonyType { analogous, complementary, neutral }

class ColorHarmonyPanel extends StatefulWidget {
  final Color baseColor;
  final ValueChanged<Color>? onColorSelected;

  const ColorHarmonyPanel({
    super.key,
    required this.baseColor,
    this.onColorSelected,
  });

  @override
  State<ColorHarmonyPanel> createState() => _ColorHarmonyPanelState();
}

class _ColorHarmonyPanelState extends State<ColorHarmonyPanel> {
  HarmonyType _selectedType = HarmonyType.analogous;

  bool get _isArabic =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar';

  String _label(HarmonyType type) {
    switch (type) {
      case HarmonyType.analogous:
        return _isArabic ? 'ألوان متقاربة' : 'Analogous';
      case HarmonyType.complementary:
        return _isArabic ? 'ألوان متكاملة' : 'Complementary';
      case HarmonyType.neutral:
        return _isArabic ? 'ألوان محايدة' : 'Neutral';
    }
  }

  List<Color> _generateColors() {
    final hsl = HSLColor.fromColor(widget.baseColor);
    final hue = hsl.hue;
    final saturation = hsl.saturation;
    final lightness = hsl.lightness;

    switch (_selectedType) {
      case HarmonyType.analogous:
        return [
          _makeColor(hue - 30, saturation, lightness),
          _makeColor(hue - 15, saturation, lightness),
          widget.baseColor,
          _makeColor(hue + 15, saturation, lightness),
          _makeColor(hue + 30, saturation, lightness),
        ];

      case HarmonyType.complementary:
        final oppositeHue = (hue + 180) % 360;

        return [
          widget.baseColor,
          _makeColor(oppositeHue, saturation, lightness),
          _makeColor(
            oppositeHue,
            saturation * 0.65,
            (lightness + 0.15).clamp(0.0, 1.0),
          ),
          _makeColor(
            hue,
            saturation * 0.65,
            (lightness + 0.20).clamp(0.0, 1.0),
          ),
          _makeColor(
            oppositeHue,
            saturation * 0.45,
            (lightness + 0.30).clamp(0.0, 1.0),
          ),
        ];

      case HarmonyType.neutral:
        return [
          _makeColor(hue, saturation * 0.15, 0.94),
          _makeColor(hue, saturation * 0.20, 0.82),
          widget.baseColor,
          _makeColor(hue, saturation * 0.25, 0.55),
          _makeColor(hue, saturation * 0.30, 0.30),
        ];
    }
  }

  Color _makeColor(double hue, double saturation, double lightness) {
    return HSLColor.fromAHSL(
      1,
      (hue % 360 + 360) % 360,
      saturation.clamp(0.0, 1.0),
      lightness.clamp(0.0, 1.0),
    ).toColor();
  }

  String _hex(Color color) {
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  String _rgb(Color color) {
    final value = color.toARGB32();

    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;

    return 'RGB($r, $g, $b)';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _generateColors();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic ? 'اقتراح ألوان متناسقة' : 'Color Harmony',
            style: const TextStyle(
              color: _ivory,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _isArabic
                ? 'اختر اتجاه الألوان المناسب لفكرتك.'
                : 'Explore color combinations for your design.',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HarmonyType.values.map((type) {
              final selected = _selectedType == type;

              return ChoiceChip(
                label: Text(_label(type)),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedType = type;
                  });
                },
                selectedColor: _bronze,
                backgroundColor: _bg,
                labelStyle: TextStyle(
                  color: selected ? _bg : _ivory,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(color: selected ? _bronze : Colors.white12),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          Text(
            _isArabic ? 'الألوان المقترحة' : 'Suggested Colors',
            style: const TextStyle(
              color: _ivory,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 32) / 5;

              return Wrap(
                spacing: 8,
                runSpacing: 14,
                children: colors.map((color) {
                  return SizedBox(
                    width: itemWidth,
                    child: GestureDetector(
                      onTap: () {
                        widget.onColorSelected?.call(color);
                      },
                      child: Column(
                        children: [
                          AspectRatio(
                            aspectRatio: 0.85,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hex(color),
                            style: const TextStyle(
                              color: _ivory,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _rgb(color),
                            style: const TextStyle(color: _muted, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),

          Text(
            _isArabic
                ? 'اضغط على أي لون لإضافته إلى لوحة الإلهام.'
                : 'Click a color to add it to your mood board.',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
