import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:file_picker/file_picker.dart';

import '../../app_language.dart';
import '../services/color_extractor.dart';
import 'color_harmony_panel.dart';

class ImageUploadPanel extends StatefulWidget {
  final ValueChanged<Color>? onColorSelected;
  final ValueChanged<List<ExtractedColor>>? onColorsExtracted;
  const ImageUploadPanel({
    super.key,
    this.onColorSelected,
    this.onColorsExtracted,
  });

  @override
  State<ImageUploadPanel> createState() => _ImageUploadPanelState();
}

class _ImageUploadPanelState extends State<ImageUploadPanel> {
  /// Max height of the preview. The image is never cropped: it is scaled
  /// down to fit (BoxFit.contain) and keeps its original aspect ratio.
  static const double _maxPreviewHeight = 600;

  Uint8List? _imageBytes;

  List<ExtractedColor> _colors = [];

  Color? _selectedColor;

  bool _isLoading = false;
  String? _errorMessage;

  // Uses the same language switch as the rest of the page.
  bool get _isArabic => AppLanguage.isArabic;

  // اختيار صورة من الجهاز
  Future<void> _pickImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);

      if (files.isEmpty) return;

      final pickedFile = files.first;
      final bytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      // Show the image right away.
      setState(() {
        _imageBytes = bytes;
        _colors = [];
        _selectedColor = null;
        _errorMessage = null;
      });
      widget.onColorsExtracted?.call([]);
      await _extractColors();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _isArabic
            ? 'حدث خطأ أثناء اختيار الصورة.'
            : 'An error occurred while selecting the image.';
      });

      debugPrint('Image picker error: $e');
    }
  }

  // استخراج الألوان من الصورة
  Future<void> _extractColors() async {
    if (_imageBytes == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _colors = [];
      _selectedColor = null;
    });

    // Let Flutter paint the image first, then run the (heavier) extraction,
    // so the picture appears instantly instead of after the analysis.
    await SchedulerBinding.instance.endOfFrame;

    if (!mounted) return;

    try {
      final extractedColors = await ColorExtractor.extractColors(
        _imageBytes!,
        colorCount: 6,
      );

      if (!mounted) return;

      setState(() {
        _colors = extractedColors;
        _isLoading = false;

        if (_colors.isNotEmpty) {
          _selectedColor = _toColor(_colors.first);
        }
      });
      widget.onColorsExtracted?.call(extractedColors);

      if (_colors.isNotEmpty) {
        widget.onColorSelected?.call(_selectedColor!);
      } else {
        setState(() {
          _errorMessage = _isArabic
              ? 'لم نتمكن من استخراج الألوان من هذه الصورة.'
              : 'Could not extract colors from this image.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _isArabic
            ? 'حدث خطأ أثناء تحليل الصورة.'
            : 'An error occurred while analyzing the image.';
      });

      debugPrint('Color extraction error: $e');
    }
  }

  // تحويل اللون المستخرج إلى Flutter Color
  Color _toColor(ExtractedColor item) {
    return Color.fromARGB(255, item.red, item.green, item.blue);
  }

  // اختيار لون أساسي
  void _selectColor(ExtractedColor item) {
    final color = _toColor(item);

    setState(() {
      _selectedColor = color;
    });

    widget.onColorSelected?.call(color);
  }

  @override
  Widget build(BuildContext context) {
    const ivory = Color(0xFFF4EFE6);
    const bronze = Color(0xFFB6A080);
    const surface = Color(0xFF222222);
    const muted = Color(0xFFAAA69F);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isArabic ? 'ارفع صورة للإلهام' : 'Upload Inspiration Image',
                style: const TextStyle(
                  color: ivory,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isArabic
                    ? 'اختر صورة غرفة أو خامة أو لوحة فنية لاستخراج ألوانها.'
                    : 'Choose a room, material or artwork image to extract its colors.',
                style: const TextStyle(color: muted, fontSize: 13),
              ),

              const SizedBox(height: 20),

              if (_imageBytes == null)
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: bronze.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: bronze,
                          size: 42,
                        ),

                        const SizedBox(height: 12),

                        Text(
                          _isArabic
                              ? 'اضغط لاختيار صورة'
                              : 'Click to upload an image',
                          style: const TextStyle(color: ivory, fontSize: 14),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'JPG, PNG, WEBP',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Full image, never cropped, original aspect ratio.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF171717),
                    constraints: const BoxConstraints(
                      maxHeight: _maxPreviewHeight,
                    ),
                    child: Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),

              if (_imageBytes != null) ...[
                const SizedBox(height: 14),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_isArabic ? 'تغيير الصورة' : 'Change Image'),
                    ),

                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _extractColors,
                      icon: const Icon(Icons.color_lens_outlined),
                      label: Text(
                        _isLoading
                            ? (_isArabic ? 'جاري التحليل...' : 'Analyzing...')
                            : (_isArabic
                                  ? 'استخراج الألوان'
                                  : 'Extract Colors'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bronze,
                        foregroundColor: const Color(0xFF171717),
                      ),
                    ),
                  ],
                ),
              ],

              if (_isLoading) ...[
                const SizedBox(height: 18),

                const LinearProgressIndicator(
                  color: bronze,
                  backgroundColor: Colors.white12,
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),

                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),

        if (_colors.isNotEmpty) ...[
          const SizedBox(height: 24),

          Text(
            _isArabic ? 'الألوان المستخرجة' : 'Extracted Colors',
            style: const TextStyle(
              color: ivory,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _isArabic
                ? 'اختر اللون الأساسي لتوليد مجموعات متناسقة.'
                : 'Select a base color to generate harmonious combinations.',
            style: const TextStyle(color: muted, fontSize: 12),
          ),

          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 450 ? 2 : 3;
              const spacing = 12.0;

              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _colors.map((item) {
                  final selected = _selectedColor == _toColor(item);

                  return SizedBox(
                    width: itemWidth,
                    child: InkWell(
                      onTap: () => _selectColor(item),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? bronze : Colors.white12,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 55,
                              decoration: BoxDecoration(
                                color: _toColor(item),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),

                            const SizedBox(height: 9),

                            Text(
                              item.hex,
                              style: const TextStyle(
                                color: ivory,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),

                            Text(
                              item.rgb,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 10,
                              ),
                            ),

                            const SizedBox(height: 8),

                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: item.percentage / 100,
                                minHeight: 5,
                                color: bronze,
                                backgroundColor: Colors.white12,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              '${item.percentage}%',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 10,
                              ),
                            ),

                            if (selected)
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.check_circle,
                                  color: bronze,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          if (_selectedColor != null)
            ColorHarmonyPanel(
              baseColor: _selectedColor!,
              onColorSelected: widget.onColorSelected,
            ),
        ],
      ],
    );
  }
}
