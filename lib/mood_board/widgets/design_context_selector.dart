import 'package:flutter/material.dart';

import '../../app_language.dart';
import '../models/design_context.dart';

// --------------------------------------------------
// Localized labels
// --------------------------------------------------

extension RoomTypeSelectorLabels on RoomType {
  String get selectorLabel {
    switch (this) {
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
        return AppLanguage.text('Office', 'مكتب');
      case RoomType.reception:
        return AppLanguage.text('Reception', 'استقبال');
      case RoomType.other:
        return AppLanguage.text('Other', 'أخرى');
    }
  }
}

extension DesignStyleSelectorLabels on DesignStyle {
  String get selectorLabel {
    switch (this) {
      case DesignStyle.modern:
        return 'Modern';
      case DesignStyle.contemporary:
        return 'Contemporary';
      case DesignStyle.classic:
        return AppLanguage.text('Classic', 'كلاسيك');
      case DesignStyle.neoclassical:
        return AppLanguage.text('Neoclassical', 'نيو كلاسيك');
      case DesignStyle.japandi:
        return AppLanguage.text('Japandi', 'ياباندي');
      case DesignStyle.scandinavian:
        return 'Scandinavian';
      case DesignStyle.minimalist:
        return AppLanguage.text('Minimalist', 'مينيمال');
      case DesignStyle.industrial:
        return AppLanguage.text('Industrial', 'صناعي');
      case DesignStyle.luxury:
        return AppLanguage.text('Luxury', 'فاخر');
      case DesignStyle.bohemian:
        return AppLanguage.text('Bohemian', 'بوهيمي');
      case DesignStyle.mediterranean:
        return AppLanguage.text('Mediterranean', 'متوسطي');
      case DesignStyle.artDeco:
        return 'Art Deco';
      case DesignStyle.rustic:
        return AppLanguage.text('Rustic', 'ريفي');
      case DesignStyle.transitional:
        return AppLanguage.text('Transitional', 'انتقالي');
      case DesignStyle.other:
        return AppLanguage.text('Other', 'أخرى');
    }
  }
}

extension NaturalLightSelectorLabels on NaturalLightLevel {
  String get selectorLabel {
    switch (this) {
      case NaturalLightLevel.low:
        return AppLanguage.text('Low', 'منخفضة');
      case NaturalLightLevel.medium:
        return AppLanguage.text('Medium', 'متوسطة');
      case NaturalLightLevel.high:
        return AppLanguage.text('High', 'مرتفعة');
    }
  }
}

// --------------------------------------------------
// Design Context Selector
// --------------------------------------------------

class DesignContextSelector extends StatefulWidget {
  final ValueChanged<DesignContext> onChanged;
  final DesignContext? initialContext;

  const DesignContextSelector({
    super.key,
    required this.onChanged,
    this.initialContext,
  });

  @override
  State<DesignContextSelector> createState() => _DesignContextSelectorState();
}

class _DesignContextSelectorState extends State<DesignContextSelector> {
  late RoomType _roomType;
  late DesignStyle _designStyle;
  late NaturalLightLevel _naturalLight;

  late TextEditingController _areaController;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialContext;

    _roomType = initial?.roomType ?? RoomType.livingRoom;
    _designStyle = initial?.designStyle ?? DesignStyle.modern;
    _naturalLight = initial?.naturalLight ?? NaturalLightLevel.medium;

    _areaController = TextEditingController(
      text: initial?.roomArea?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  void _emitContext() {
    final area = double.tryParse(
      _areaController.text.trim().replaceAll(',', '.'),
    );

    widget.onChanged(
      DesignContext(
        roomType: _roomType,
        designStyle: _designStyle,
        naturalLight: _naturalLight,
        roomArea: area != null && area > 0 ? area : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.locale,
      builder: (context, locale, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFB6A080).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLanguage.text(
                  'Room Design Context',
                  'بيانات الغرفة والتصميم',
                ),
                style: const TextStyle(
                  color: Color(0xFFF4EFE6),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                AppLanguage.text(
                  'These details help us recommend suitable colors and materials.',
                  'البيانات دي بتساعدنا نختار الألوان والخامات المناسبة للغرفة.',
                ),
                style: const TextStyle(
                  color: Color(0xFFAAA69F),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              _buildDropdown<RoomType>(
                label: AppLanguage.text('Room Type', 'نوع الغرفة'),
                value: _roomType,
                items: RoomType.values.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item.selectorLabel),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() => _roomType = value);
                  _emitContext();
                },
              ),

              const SizedBox(height: 16),

              _buildDropdown<DesignStyle>(
                label: AppLanguage.text(
                  'Architectural Style',
                  'الستايل المعماري',
                ),
                value: _designStyle,
                items: DesignStyle.values.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item.selectorLabel),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() => _designStyle = value);
                  _emitContext();
                },
              ),

              const SizedBox(height: 16),

              _buildDropdown<NaturalLightLevel>(
                label: AppLanguage.text('Natural Lighting', 'الإضاءة الطبيعية'),
                value: _naturalLight,
                items: NaturalLightLevel.values.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item.selectorLabel),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() => _naturalLight = value);
                  _emitContext();
                },
              ),

              const SizedBox(height: 16),

              Text(
                AppLanguage.text(
                  'Room Area (Optional)',
                  'مساحة الغرفة (اختياري)',
                ),
                style: const TextStyle(color: Color(0xFFF4EFE6), fontSize: 14),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _areaController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => _emitContext(),
                style: const TextStyle(color: Color(0xFFF4EFE6)),
                decoration: InputDecoration(
                  hintText: AppLanguage.text('Example: 25', 'مثال: 25'),
                  hintStyle: const TextStyle(color: Color(0xFF777777)),
                  suffixText: 'm²',
                  suffixStyle: const TextStyle(color: Color(0xFFB6A080)),
                  filled: true,
                  fillColor: const Color(0xFF171717),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                AppLanguage.text(
                  'Area is a design consideration, not an exact material quantity.',
                  'المساحة عامل مساعد في التوصيات وليست حسابًا دقيقًا لكميات الخامات.',
                ),
                style: const TextStyle(
                  color: Color(0xFFAAA69F),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFF4EFE6), fontSize: 14),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF222222),
          style: const TextStyle(color: Color(0xFFF4EFE6), fontSize: 14),
          iconEnabledColor: const Color(0xFFB6A080),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF171717),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
