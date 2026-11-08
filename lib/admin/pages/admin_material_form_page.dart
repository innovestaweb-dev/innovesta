import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_material.dart';
import '../services/material_service.dart';

// -----------------------------------------------------------------------------
// Image upload config
// -----------------------------------------------------------------------------

const String _storageBucket = 'project-media';
const String _storageFolder = 'materials';
const int _maxInputBytes = 15 * 1024 * 1024; // before compression
const int _maxUploadBytes = 1024 * 1024; // after compression
const int _maxImageDimension = 1200;
const int _jpegQuality = 82;
const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

class _ImageJob {
  final Uint8List bytes;
  final String extension;
  const _ImageJob(this.bytes, this.extension);
}

class _ProcessedImage {
  final Uint8List bytes;
  final String extension;
  const _ProcessedImage(this.bytes, this.extension);
}

// Top-level so it can run through `compute`.
_ProcessedImage _compressImage(_ImageJob job) {
  final original = _ProcessedImage(job.bytes, job.extension);

  try {
    final decoded = img.decodeImage(job.bytes);
    if (decoded == null) return original;

    var image = decoded;

    if (job.extension == 'jpg' || job.extension == 'jpeg') {
      image = img.bakeOrientation(image);
    }

    final longest = image.width > image.height ? image.width : image.height;
    final needsResize = longest > _maxImageDimension;

    if (needsResize) {
      image = image.width >= image.height
          ? img.copyResize(image, width: _maxImageDimension)
          : img.copyResize(image, height: _maxImageDimension);
    }

    // Keep PNGs that have transparency as PNG, everything else becomes JPG.
    final keepPng = job.extension == 'png' && image.numChannels == 4;

    final encoded = keepPng
        ? img.encodePng(image)
        : img.encodeJpg(image, quality: _jpegQuality);

    final out = Uint8List.fromList(encoded);

    if (!needsResize && out.length >= job.bytes.length) return original;

    return _ProcessedImage(out, keepPng ? 'png' : 'jpg');
  } catch (_) {
    return original;
  }
}

String _contentTypeFor(String extension) {
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class AdminMaterialFormPage extends StatefulWidget {
  final AdminMaterial? material;

  const AdminMaterialFormPage({super.key, this.material});

  @override
  State<AdminMaterialFormPage> createState() => _AdminMaterialFormPageState();
}

class _AdminMaterialFormPageState extends State<AdminMaterialFormPage> {
  final _formKey = GlobalKey<FormState>();
  final MaterialService _service = MaterialService();

  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();

  final _categoryArController = TextEditingController();
  final _categoryEnController = TextEditingController();

  final _typeArController = TextEditingController();
  final _typeEnController = TextEditingController();

  final _descriptionArController = TextEditingController();
  final _descriptionEnController = TextEditingController();

  final _sampleImageController = TextEditingController();
  final _applicationImageController = TextEditingController();
  final _hexController = TextEditingController();
  final _colorFamilyController = TextEditingController();
  final _placementController = TextEditingController();
  final _finishController = TextEditingController();
  final _textureController = TextEditingController();
  final _sheenController = TextEditingController();
  final _orderController = TextEditingController(text: '0');

  final List<String> _uses = [
    'wall',
    'ceiling',
    'flooring',
    'furniture',
    'upholstery',
    'curtains',
    'accent',
    'countertop',
    'doors',
    'hardware',
    'fixtures',
  ];

  final List<String> _styles = [
    'modern',
    'contemporary',
    'classic',
    'neoclassical',
    'minimalist',
    'industrial',
    'scandinavian',
    'luxury',
    'bohemian',
    'japandi',
    'mediterranean',
    'artDeco',
    'rustic',
    'transitional',
    'other',
  ];

  final Set<String> _selectedUses = {};
  final Set<String> _selectedStyles = {};

  String _priceLevel = 'midRange';
  String _durability = 'medium';
  String _maintenance = 'medium';

  bool _isActive = true;
  bool _isSaving = false;

  /// Label of the image field currently uploading (null when idle).
  String? _uploadingTarget;

  bool get _isEditing => widget.material != null;

  @override
  void initState() {
    super.initState();

    final material = widget.material;

    if (material != null) {
      _nameArController.text = material.nameAr;
      _nameEnController.text = material.nameEn;

      _categoryArController.text = material.categoryAr;
      _categoryEnController.text = material.categoryEn;

      _typeArController.text = material.materialTypeAr;
      _typeEnController.text = material.materialTypeEn;

      _descriptionArController.text = material.descriptionAr;
      _descriptionEnController.text = material.descriptionEn;

      _sampleImageController.text = material.sampleImage;
      _applicationImageController.text = material.applicationImage;
      _hexController.text = material.hex;
      _colorFamilyController.text = material.colorFamily;

      _placementController.text = material.placement;
      _finishController.text = material.finish;
      _textureController.text = material.texture;
      _sheenController.text = material.sheen;

      _orderController.text = material.displayOrder.toString();

      _selectedUses.addAll(material.recommendedUses);
      _selectedStyles.addAll(material.styleCompatibility);

      _priceLevel = material.priceLevel;
      _durability = material.durability;
      _maintenance = material.maintenance;
      _isActive = material.isActive;
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();

    _categoryArController.dispose();
    _categoryEnController.dispose();

    _typeArController.dispose();
    _typeEnController.dispose();

    _descriptionArController.dispose();
    _descriptionEnController.dispose();

    _sampleImageController.dispose();
    _applicationImageController.dispose();
    _hexController.dispose();
    _colorFamilyController.dispose();

    _placementController.dispose();
    _finishController.dispose();
    _textureController.dispose();
    _sheenController.dispose();

    _orderController.dispose();

    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF8B3939) : null,
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    String label,
    TextEditingController controller,
  ) async {
    if (_uploadingTarget != null) return;

    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;

      final file = files.first;
      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';

      if (!_imageExtensions.contains(extension)) {
        _showSnack(
          'Unsupported format (.$extension). Use JPG, PNG or WEBP.',
          isError: true,
        );
        return;
      }

      setState(() => _uploadingTarget = label);

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        _showSnack('"${file.name}" is empty.', isError: true);
        return;
      }

      if (bytes.length > _maxInputBytes) {
        _showSnack(
          '"${file.name}" is too large (${_formatBytes(bytes.length)}). '
          'Maximum is ${_formatBytes(_maxInputBytes)}.',
          isError: true,
        );
        return;
      }

      final processed = await compute(
        _compressImage,
        _ImageJob(bytes, extension),
      );

      if (processed.bytes.length > _maxUploadBytes) {
        _showSnack(
          '"${file.name}" is still too large after compression '
          '(${_formatBytes(processed.bytes.length)}). Use a smaller image.',
          isError: true,
        );
        return;
      }

      final suffix = Random().nextInt(0x7fffffff).toRadixString(36);
      final path =
          '$_storageFolder/${DateTime.now().millisecondsSinceEpoch}-$suffix.${processed.extension}';

      final storage = Supabase.instance.client.storage.from(_storageBucket);

      await storage.uploadBinary(
        path,
        processed.bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: _contentTypeFor(processed.extension),
        ),
      );

      controller.text = storage.getPublicUrl(path);

      _showSnack('Image uploaded (${_formatBytes(processed.bytes.length)}).');
    } catch (e, stackTrace) {
      debugPrint('Material image upload error: $e');
      debugPrintStack(stackTrace: stackTrace);

      _showSnack('Image upload failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingTarget = null);
    }
  }

  Future<void> _saveMaterial() async {
    if (_uploadingTarget != null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final material = AdminMaterial(
        id: widget.material?.id ?? '',

        name: _nameEnController.text.trim(),
        nameEn: _nameEnController.text.trim(),
        nameAr: _nameArController.text.trim(),

        category: _categoryEnController.text.trim(),
        categoryEn: _categoryEnController.text.trim(),
        categoryAr: _categoryArController.text.trim(),

        materialType: _typeEnController.text.trim(),
        materialTypeEn: _typeEnController.text.trim(),
        materialTypeAr: _typeArController.text.trim(),

        description: _descriptionEnController.text.trim(),
        descriptionEn: _descriptionEnController.text.trim(),
        descriptionAr: _descriptionArController.text.trim(),

        sampleImage: _sampleImageController.text.trim(),
        applicationImage: _applicationImageController.text.trim(),

        hex: _hexController.text.trim().toUpperCase(),
        colorFamily: _colorFamilyController.text.trim(),

        placement: _placementController.text.trim(),
        finish: _finishController.text.trim(),
        texture: _textureController.text.trim(),
        sheen: _sheenController.text.trim(),

        recommendedUses: _selectedUses.toList(),
        styleCompatibility: _selectedStyles.toList(),

        priceLevel: _priceLevel,
        durability: _durability,
        maintenance: _maintenance,

        isActive: _isActive,
        displayOrder: int.parse(_orderController.text.trim()),
      );

      if (_isEditing) {
        await _service.updateMaterial(material);
      } else {
        await _service.addMaterial(material);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Material updated successfully.'
                : 'Material added successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e, stackTrace) {
      debugPrint('Material save error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save material. Please check your data and try again.',
          ),
          backgroundColor: Color(0xFF8B3939),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String?)? customValidator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFF4EFE6), fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFFF4EFE6)),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }

            if (customValidator != null) {
              return customValidator(value);
            }

            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF77736D)),
            filled: true,
            fillColor: const Color(0xFF222222),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF39352F)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF39352F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFB6A080)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFB94A48)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFB94A48)),
            ),
          ),
        ),
      ],
    );
  }

  String? _validateOptionalUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    return ok ? null : 'Enter a valid image URL or upload an image.';
  }

  Widget _imageField(String label, TextEditingController controller) {
    final isUploading = _uploadingTarget == label;
    final busy = _uploadingTarget != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          label,
          controller,
          hint: 'https://...',
          customValidator: _validateOptionalUrl,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _pickAndUploadImage(label, controller),
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFB6A080),
                      ),
                    )
                  : const Icon(Icons.upload_rounded, size: 18),
              label: Text(isUploading ? 'Uploading...' : 'Upload image'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB6A080),
                side: const BorderSide(color: Color(0xFF39352F)),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: busy ? null : controller.clear,
              child: const Text(
                'Clear',
                style: TextStyle(color: Color(0xFFAAA69F)),
              ),
            ),
          ],
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final url = value.text.trim();

            if (_validateOptionalUrl(url) != null || url.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 140,
                    height: 140,
                    color: const Color(0xFF222222),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF77736D),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFF4EFE6), fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: const Color(0xFF222222),
          style: const TextStyle(color: Color(0xFFF4EFE6)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF222222),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF39352F)),
            ),
          ),
          items: options.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _multiSelect(
    String title,
    List<String> options,
    Set<String> selected,
  ) {
    return FormField<Set<String>>(
      initialValue: Set<String>.from(selected),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select at least one option.';
        }
        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF4EFE6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selected.contains(option);

                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFFB6A080),
                  backgroundColor: const Color(0xFF222222),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF171717)
                        : const Color(0xFFAAA69F),
                    fontSize: 12,
                  ),
                  side: const BorderSide(color: Color(0xFF39352F)),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selected.add(option);
                      } else {
                        selected.remove(option);
                      }

                      field.didChange(Set<String>.from(selected));
                    });
                  },
                );
              }).toList(),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 8),
              Text(
                field.errorText!,
                style: const TextStyle(color: Color(0xFFCF6679), fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF39352F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFB6A080),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 18);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171717),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: const Color(0xFFF4EFE6),
        title: Text(_isEditing ? 'Edit Material' : 'Add Material'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _section('Basic Information', [
              _field(
                'Material Name (English)',
                _nameEnController,
                required: true,
              ),
              _gap(),
              _field('اسم الخامة (عربي)', _nameArController, required: true),
              _gap(),
              _field(
                'Category (English)',
                _categoryEnController,
                required: true,
              ),
              _gap(),
              _field('الفئة (عربي)', _categoryArController, required: true),
              _gap(),
              _field(
                'Material Type (English)',
                _typeEnController,
                required: true,
              ),
              _gap(),
              _field('نوع الخامة (عربي)', _typeArController, required: true),
              _gap(),
              _field(
                'Description (English)',
                _descriptionEnController,
                maxLines: 3,
              ),
              _gap(),
              _field('الوصف (عربي)', _descriptionArController, maxLines: 3),
            ]),
            _gap(),
            _section('Images & Color', [
              _imageField('Sample Image', _sampleImageController),
              _gap(),
              _imageField('Application Image', _applicationImageController),
              _gap(),
              _field(
                'HEX Color',
                _hexController,
                hint: '#D8CBB8',
                required: true,
                customValidator: (value) {
                  final hex = value?.trim() ?? '';

                  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
                    return 'Enter a valid HEX color, e.g. #D8CBB8';
                  }

                  return null;
                },
              ),
              _gap(),
              _field(
                'Color Family',
                _colorFamilyController,
                hint: 'Warm Beige, Cool Grey...',
              ),
            ]),
            _gap(),
            _section('Physical Properties', [
              _field(
                'Placement',
                _placementController,
                hint: 'Interior walls, floors...',
              ),
              _gap(),
              _field(
                'Finish',
                _finishController,
                hint: 'Polished, Matte, Brushed...',
              ),
              _gap(),
              _field('Texture', _textureController),
              _gap(),
              _field(
                'Sheen',
                _sheenController,
                hint: 'Matte, Satin, Glossy...',
              ),
            ]),
            _gap(),
            _section('Recommended Uses', [
              _multiSelect(
                'Select suitable uses (at least one)',
                _uses,
                _selectedUses,
              ),
            ]),
            _gap(),
            _section('Style Compatibility', [
              _multiSelect(
                'Select compatible styles (at least one)',
                _styles,
                _selectedStyles,
              ),
            ]),
            _gap(),
            _section('Performance & Cost', [
              _dropdown('Price Level', _priceLevel, [
                'budget',
                'midRange',
                'premium',
              ], (value) => setState(() => _priceLevel = value!)),
              _gap(),
              _dropdown('Durability', _durability, [
                'low',
                'medium',
                'high',
                'veryHigh',
              ], (value) => setState(() => _durability = value!)),
              _gap(),
              _dropdown('Maintenance', _maintenance, [
                'low',
                'medium',
                'high',
              ], (value) => setState(() => _maintenance = value!)),
            ]),
            _gap(),
            _section('Publishing & Ordering', [
              _field(
                'Display Order',
                _orderController,
                keyboardType: TextInputType.number,
                required: true,
                customValidator: (value) {
                  final order = int.tryParse(value?.trim() ?? '');

                  if (order == null) {
                    return 'Enter a valid whole number.';
                  }

                  if (order < 0) {
                    return 'Display order cannot be negative.';
                  }

                  return null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Active Material',
                  style: TextStyle(color: Color(0xFFF4EFE6)),
                ),
                subtitle: const Text(
                  'Inactive materials will not appear in the Material Board.',
                  style: TextStyle(color: Color(0xFFAAA69F)),
                ),
                activeThumbColor: const Color(0xFFB6A080),
                value: _isActive,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
              ),
            ]),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSaving || _uploadingTarget != null)
                    ? null
                    : _saveMaterial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB6A080),
                  foregroundColor: const Color(0xFF171717),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Color(0xFF171717))
                    : Text(
                        _isEditing ? 'Save Changes' : 'Add Material',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
