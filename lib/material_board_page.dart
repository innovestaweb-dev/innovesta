import 'dart:ui' as ui;
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'mood_board/models/material_use.dart';
import 'app_language.dart';
import 'mood_board/widgets/image_upload_panel.dart';
import 'mood_board/widgets/design_context_selector.dart';
import 'mood_board/services/color_extractor.dart';
import 'mood_board/services/color_analyzer.dart';
import 'mood_board/services/color_allocation_engine.dart';
import 'mood_board/services/material_recommendation_engine.dart';
import 'mood_board/models/color_analysis.dart';
import 'mood_board/models/design_context.dart';
import 'mood_board/models/design_color_plan.dart';
import 'mood_board/models/material_recommendation.dart';
import 'mood_board/models/material_option.dart';
import 'material_library.dart';
import 'material_remote_source.dart';

const Color bgColor = Color(0xFF171717);
const Color surfaceColor = Color(0xFF222222);
const Color ivory = Color(0xFFF4EFE6);
const Color bronze = Color(0xFFB6A080);
const Color muted = Color(0xFFAAA69F);

class MaterialBoardPage extends StatefulWidget {
  const MaterialBoardPage({super.key});

  @override
  State<MaterialBoardPage> createState() => _MaterialBoardPageState();
}

String materialUseLabel(MaterialUse use) {
  switch (use) {
    case MaterialUse.wall:
      return AppLanguage.text('Wall', 'حائط');
    case MaterialUse.ceiling:
      return AppLanguage.text('Ceiling', 'سقف');
    case MaterialUse.flooring:
      return AppLanguage.text('Flooring', 'أرضيات');
    case MaterialUse.furniture:
      return AppLanguage.text('Furniture', 'أثاث');
    case MaterialUse.upholstery:
      return AppLanguage.text('Upholstery', 'تنجيد');
    case MaterialUse.curtains:
      return AppLanguage.text('Curtains', 'ستائر');
    case MaterialUse.accent:
      return AppLanguage.text('Accent Details', 'عناصر مميزة');
    case MaterialUse.countertop:
      return AppLanguage.text('Countertop', 'أسطح العمل');
    case MaterialUse.doors:
      return AppLanguage.text('Doors', 'أبواب');
    case MaterialUse.hardware:
      return AppLanguage.text('Hardware', 'إكسسوارات معدنية');
    case MaterialUse.fixtures:
      return AppLanguage.text('Fixtures', 'تجهيزات');
  }
}

class SelectedMaterial {
  final MaterialOption material;
  int percentage;
  String hex;
  String placement;

  SelectedMaterial({
    required this.material,
    required this.percentage,
    required this.hex,
    required this.placement,
  });
}

class _PercentSlot {
  final Object owner;
  final int Function() get;
  final void Function(int) set;

  _PercentSlot({required this.owner, required this.get, required this.set});
}

class _MaterialBoardPageState extends State<MaterialBoardPage> {
  static const int _maxMaterials = 6;

  /// Width at which the layout switches between mobile (stacked) and
  /// desktop (main content + side board panel).
  static const double _mobileBreakpoint = 900;

  /// Max width of the page content when there is no side panel.
  static const double _contentMaxWidth = 1100;

  final TextEditingController _projectController = TextEditingController(
    text: 'My Interior Project',
  );

  List<MaterialRecommendation> _recommendedMaterials = [];
  List<ExtractedColorAnalysis> _extractedColorAnalyses = [];

  DesignContext _designContext = const DesignContext(
    roomType: RoomType.livingRoom,
    designStyle: DesignStyle.modern,
    naturalLight: NaturalLightLevel.medium,
  );

  DesignColorPlan? _designColorPlan;

  final GlobalKey _boardKey = GlobalKey();
  final Map<String, int> _customColorPercentages = {};
  final List<SelectedMaterial> _selectedMaterials = [];
  final List<ExtractedColor> _customColors = [];

  /// Starts with the built-in library so the page works instantly (and offline),
  /// then switches to the materials managed from the admin panel (Supabase).
  List<MaterialOption> _materials = MaterialLibrary.materials;

  /// True only after the user uploaded an image and colors were extracted.
  bool get _hasUploadedImage => _extractedColorAnalyses.isNotEmpty;

  /// Results (distribution + recommendations) are displayed.
  bool get _showResults => _hasUploadedImage;

  /// The material board panel exists only once an image was added.
  bool get _showBoardPanel => _hasUploadedImage;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _colorFromHex(String hex) {
    try {
      final value = hex.replaceAll('#', '');
      return Color(int.parse('FF$value', radix: 16));
    } catch (_) {
      return bronze;
    }
  }

  String get _sampleLabel => AppLanguage.text('Sample', 'العينة');
  String get _applicationLabel => AppLanguage.text('Application', 'التطبيق');

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: surfaceColor),
    );
  }

  bool _isSelected(MaterialOption material) {
    return _selectedMaterials.any(
      (item) => item.material.name == material.name,
    );
  }

  // ---------------------------------------------------------------------------
  // Materials selection
  // ---------------------------------------------------------------------------

  void _toggleMaterial(MaterialOption material) {
    setState(() {
      final existingIndex = _selectedMaterials.indexWhere(
        (item) => item.material.name == material.name,
      );

      if (existingIndex != -1) {
        _selectedMaterials.removeAt(existingIndex);
        _redistributePercentages();
      } else if (_selectedMaterials.length < _maxMaterials) {
        _selectedMaterials.add(
          SelectedMaterial(
            material: material,
            percentage: 0,
            hex: material.hex,
            placement: material.placement,
          ),
        );
        _redistributePercentages();
      } else {
        _showMessage(
          AppLanguage.text(
            'You can select up to $_maxMaterials materials.',
            'يمكنك اختيار $_maxMaterials خامات كحد أقصى.',
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Colors & recommendations
  // ---------------------------------------------------------------------------

  void _handleExtractedColors(List<ExtractedColor> colors) {
    // Image removed / nothing extracted: clear everything that depends on it
    // so the board panel and recommendations disappear.
    if (colors.isEmpty) {
      setState(() {
        _extractedColorAnalyses = [];
        _designColorPlan = null;
        _recommendedMaterials = [];
      });
      return;
    }

    try {
      final analyses = ColorAnalyzer.analyze(colors);

      final plan = ColorAllocationEngine.generate(
        extractedColors: analyses,
        context: _designContext,
      );

      final recommendations = MaterialRecommendationEngine.recommend(
        allocations: plan.allocations,
        materials: _materials,
        context: _designContext,
      );

      // Everything is applied in one go so the layout stays stable.
      setState(() {
        _extractedColorAnalyses = analyses;
        _designColorPlan = plan;
        _recommendedMaterials = recommendations;
      });
    } catch (e) {
      debugPrint('Color processing error: $e');
    }
  }

  void _rebuildRecommendations() {
    if (_extractedColorAnalyses.isEmpty) return;

    final plan = ColorAllocationEngine.generate(
      extractedColors: _extractedColorAnalyses,
      context: _designContext,
    );

    final recommendations = MaterialRecommendationEngine.recommend(
      allocations: plan.allocations,
      materials: _materials,
      context: _designContext,
    );

    setState(() {
      _designColorPlan = plan;
      _recommendedMaterials = recommendations;
    });
  }

  void _addCustomColor(Color color) {
    final argb = color.toARGB32();

    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;

    final hex =
        '#${red.toRadixString(16).padLeft(2, '0')}'
                '${green.toRadixString(16).padLeft(2, '0')}'
                '${blue.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();

    setState(() {
      final alreadyExists = _customColors.any(
        (item) => item.hex.toUpperCase() == hex,
      );

      if (alreadyExists) return;

      _customColors.add(
        ExtractedColor(
          red: red,
          green: green,
          blue: blue,
          hex: hex,
          percentage: 0,
          pixelCount: 0,
        ),
      );

      _redistributePercentages();
    });
  }

  void _removeCustomColor(ExtractedColor color) {
    setState(() {
      _customColors.remove(color);
      _customColorPercentages.remove(color.hex.toUpperCase());
      _redistributePercentages();
    });
  }

  // ---------------------------------------------------------------------------
  // Percentage management
  // ---------------------------------------------------------------------------

  List<_PercentSlot> _allSlots() {
    return [
      ..._selectedMaterials.map(
        (item) => _PercentSlot(
          owner: item,
          get: () => item.percentage,
          set: (value) => item.percentage = value,
        ),
      ),
      ..._customColors.map((color) {
        final key = color.hex.toUpperCase();

        return _PercentSlot(
          owner: color,
          get: () => _customColorPercentages[key] ?? 0,
          set: (value) => _customColorPercentages[key] = value,
        );
      }),
    ];
  }

  int _customColorPercentage(ExtractedColor color) {
    return _customColorPercentages[color.hex.toUpperCase()] ?? 0;
  }

  void _applyPercentage(Object owner, int newPercentage) {
    setState(() {
      final slots = _allSlots();

      final selectedIndex = slots.indexWhere(
        (slot) => identical(slot.owner, owner),
      );

      if (selectedIndex == -1) return;

      final selected = slots[selectedIndex];
      final others = slots
          .where((slot) => !identical(slot.owner, owner))
          .toList();

      if (others.isEmpty) {
        selected.set(100);
        return;
      }

      final clamped = newPercentage.clamp(0, 100);
      final remaining = 100 - clamped;
      final oldPercentages = others.map((slot) => slot.get()).toList();
      final oldTotal = oldPercentages.fold<int>(0, (sum, value) => sum + value);

      selected.set(clamped);

      int distributed = 0;

      for (int i = 0; i < others.length; i++) {
        final value = oldTotal > 0
            ? (remaining * oldPercentages[i] / oldTotal).floor()
            : remaining ~/ others.length;

        others[i].set(value);
        distributed += value;
      }

      final difference = remaining - distributed;

      if (difference > 0) {
        others.first.set(others.first.get() + difference);
      }
    });
  }

  void _redistributePercentages() {
    final slots = _allSlots();

    if (slots.isEmpty) return;

    final base = 100 ~/ slots.length;
    final remainder = 100 % slots.length;

    for (int i = 0; i < slots.length; i++) {
      slots[i].set(base + (i < remainder ? 1 : 0));
    }
  }

  void _showPercentageDialog({
    required String title,
    required int currentValue,
    required void Function(int value) onSave,
  }) {
    final controller = TextEditingController(text: '$currentValue');

    void submit(BuildContext dialogContext) {
      final value = int.tryParse(controller.text);

      if (value == null || value < 0 || value > 100) {
        _showMessage(
          AppLanguage.text(
            'Enter a number between 0 and 100.',
            'أدخل رقمًا بين 0 و 100.',
          ),
        );
        return;
      }

      onSave(value);
      Navigator.pop(dialogContext);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          title: Text(title, style: const TextStyle(color: ivory)),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            style: const TextStyle(color: ivory),
            onSubmitted: (_) => submit(dialogContext),
            decoration: const InputDecoration(
              suffixText: '%',
              suffixStyle: TextStyle(color: bronze),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: bronze),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: ivory),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                AppLanguage.text('Cancel', 'إلغاء'),
                style: const TextStyle(color: muted),
              ),
            ),
            TextButton(
              onPressed: () => submit(dialogContext),
              child: Text(
                AppLanguage.text('Save', 'حفظ'),
                style: const TextStyle(color: bronze),
              ),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  void _showMaterialPercentageDialog(SelectedMaterial item) {
    _showPercentageDialog(
      title: AppLanguage.text('Edit Material Percentage', 'تعديل نسبة الخامة'),
      currentValue: item.percentage,
      onSave: (value) => _applyPercentage(item, value),
    );
  }

  void _showColorPercentageDialog(ExtractedColor color) {
    _showPercentageDialog(
      title: AppLanguage.text('Edit Color Percentage', 'تعديل نسبة اللون'),
      currentValue: _customColorPercentage(color),
      onSave: (value) => _applyPercentage(color, value),
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _exportBoard() async {
    try {
      final boundary =
          _boardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();

      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'image/png'),
      );

      final url = web.URL.createObjectURL(blob);

      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = 'INNOVISTA_Material_Board.png'
        ..style.display = 'none';

      web.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      web.URL.revokeObjectURL(url);
    } catch (e) {
      debugPrint('Export Error: $e');

      _showMessage(
        AppLanguage.text(
          'Export failed. Please try again.',
          'فشل التصدير. حاول مرة أخرى.',
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRemoteMaterials();
  }

  Future<void> _loadRemoteMaterials() async {
    final remote = await MaterialRemoteSource.loadActive();

    // Nothing usable from Supabase: keep the built-in library.
    if (remote.isEmpty || !mounted) return;

    setState(() => _materials = remote);

    // Refresh recommendations if the user already uploaded an image.
    _rebuildRecommendations();
  }

  @override
  void dispose() {
    _projectController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLanguage.isArabic;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        titleSpacing: 30,
        title: const Text(
          'INNOVISTA',
          style: TextStyle(
            color: ivory,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          TextButton(
            onPressed: AppLanguage.toggle,
            child: Text(
              isArabic ? 'EN' : 'عربي',
              style: const TextStyle(
                color: bronze,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < _mobileBreakpoint;
          final showBoard = _showBoardPanel;
          final showSidePanel = !isMobile && showBoard;

          // IMPORTANT: the widget tree keeps exactly the same structure
          // before and after an image is added (Row > Expanded > scroll view
          // > main column). Only the optional side panel is appended.
          // Switching to a different tree would destroy the state of
          // ImageUploadPanel and the selected image would disappear.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 40,
                    vertical: 32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _contentMaxWidth,
                      ),
                      // On mobile the board is placed inline under the upload.
                      child: _buildMainContent(
                        showInlineBoard: isMobile && showBoard,
                      ),
                    ),
                  ),
                ),
              ),

              // Desktop + image added: board panel = 1/3 of the screen,
              // full height, with its own scroll.
              if (showSidePanel)
                Container(
                  width: constraints.maxWidth / 3,
                  decoration: const BoxDecoration(
                    color: bgColor,
                    border: BorderDirectional(
                      start: BorderSide(color: Color(0xFF37332E)),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildBoardSection(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// All page sections share one column, so they always have the same
  /// width and alignment.
  Widget _buildMainContent({required bool showInlineBoard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),

        const SizedBox(height: 42),

        // 01 - Upload
        _buildUploadSection(),

        // 02 + 03 - Board (mobile only; on desktop it is the side panel)
        if (showInlineBoard) ...[
          const SizedBox(height: 30),
          _buildBoardSection(),
        ],

        const SizedBox(height: 45),

        // 04 - Design Context
        _sectionTitle(
          AppLanguage.text('Define Your Design Context', 'حدد سياق التصميم'),
        ),

        const SizedBox(height: 8),

        Text(
          AppLanguage.text(
            'Tell us about your space to generate more relevant material and color recommendations.',
            'حدد طبيعة المساحة والتصميم للحصول على اقتراحات أدق للألوان والخامات.',
          ),
          style: const TextStyle(color: muted, fontSize: 13, height: 1.7),
        ),

        const SizedBox(height: 18),

        _panel(
          child: DesignContextSelector(
            initialContext: _designContext,
            onChanged: (context) {
              setState(() {
                _designContext = context;
              });

              _rebuildRecommendations();
            },
          ),
        ),

        const SizedBox(height: 42),

        // 05 - Suggested Color Distribution
        _sectionTitle(
          AppLanguage.text(
            'Suggested Color Distribution',
            'توزيع الألوان المقترح',
          ),
        ),

        const SizedBox(height: 8),

        Text(
          AppLanguage.text(
            'A suggested balance of colors based on your reference image and design context.',
            'توزيع لوني مقترح بناءً على الصورة المرجعية وسياق التصميم.',
          ),
          style: const TextStyle(color: muted, fontSize: 13, height: 1.7),
        ),

        const SizedBox(height: 18),

        _buildDesignColorPlan(),

        // 06 - Recommended Materials
        // Always the LAST section, and only after an image was uploaded.
        if (_showResults && _recommendedMaterials.isNotEmpty) ...[
          const SizedBox(height: 48),
          _buildRecommendedMaterials(),
        ],

        const SizedBox(height: 60),

        _buildFooter(),
      ],
    );
  }

  /// Material board (02) + specifications (03) + export.
  Widget _buildBoardSection() => _buildPreview();

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          AppLanguage.text(
            'Upload & Extract Colors',
            'رفع الصورة واستخراج الألوان',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ImageUploadPanel(
            onColorsExtracted: _handleExtractedColors,
            onColorSelected: _addCustomColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FREE DESIGN TOOL / INNOVISTA',
          style: TextStyle(
            color: bronze,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLanguage.text(
            'Create Your Material Board.',
            'صمّم لوحة الخامات الخاصة بك.',
          ),
          style: const TextStyle(
            color: ivory,
            fontSize: 34,
            height: 1.2,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppLanguage.text(
            'Select real material references, define their colors and proportions, and export a professional specification board.',
            'اختر صور الخامات وحدد ألوانها ونسب استخدامها، ثم صدّر لوحة مواصفات احترافية.',
          ),
          style: const TextStyle(color: muted, fontSize: 14, height: 1.9),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Suggested color distribution
  // ---------------------------------------------------------------------------

  Widget _buildDesignColorPlan() {
    final plan = _designColorPlan;

    if (plan == null || plan.allocations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bronze.withValues(alpha: 0.2)),
        ),
        child: Text(
          AppLanguage.text(
            'Upload a reference image to generate your suggested color distribution.',
            'ارفع صورة مرجعية لإنشاء توزيع الألوان المقترح.',
          ),
          style: const TextStyle(color: muted, height: 1.6),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bronze.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  AppLanguage.text(
                    'Suggested Color Distribution',
                    'توزيع الألوان المقترح',
                  ),
                  style: const TextStyle(
                    color: ivory,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${plan.totalPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: bronze,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguage.text(
              'A visual design guideline, not a measurement of actual surface areas or purchase quantities.',
              'توزيع بصري إرشادي، وليس قياسًا لمساحات الأسطح أو كميات الشراء الفعلية.',
            ),
            style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 20),
          ...plan.allocations.map(_buildAllocationRow),
        ],
      ),
    );
  }

  Widget _buildAllocationRow(dynamic allocation) {
    final color = _colorFromHex(allocation.colorAnalysis.sourceColor.hex);
    final percentage = (allocation.designPercentage as num).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: ivory.withValues(alpha: 0.15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _useTitle(allocation.suggestedUse),
                      style: const TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${allocation.colorAnalysis.sourceColor.hex}  •  '
                      '${AppLanguage.text('In reference', 'في الصورة')}: '
                      '${allocation.colorAnalysis.sourceColor.percentage}%',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: bronze,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: bgColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            allocation.reasonLabel,
            style: const TextStyle(color: muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recommended materials (06 - last section, only after image upload)
  // ---------------------------------------------------------------------------

  Widget _buildRecommendedMaterials() {
    if (!_showResults || _recommendedMaterials.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          AppLanguage.text('Recommended Materials', 'الخامات المقترحة'),
        ),
        const SizedBox(height: 8),
        Text(
          AppLanguage.text(
            'Materials selected according to your reference colors, room type and design style.',
            'خامات تم ترشيحها بناءً على ألوان الصورة ونوع الغرفة والستايل المختار.',
          ),
          style: const TextStyle(color: muted, fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 22),
        ..._buildRecommendationGroups(),
      ],
    );
  }

  String _useTitle(MaterialUse use) {
    if (use == MaterialUse.wall) {
      return AppLanguage.text(
        'Wall / Main Surface',
        'الجدران / الأسطح الرئيسية',
      );
    }

    return materialUseLabel(use);
  }

  List<Widget> _buildRecommendationGroups() {
    final groups = <Object, List<MaterialRecommendation>>{};

    for (final match in _recommendedMaterials) {
      groups.putIfAbsent(match.allocation, () => []).add(match);
    }

    return groups.values.map((matches) {
      final first = matches.first;

      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _colorFromHex(first.sourceColorHex),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: ivory.withValues(alpha: 0.15)),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _useTitle(first.allocation.suggestedUse),
                    style: const TextStyle(
                      color: ivory,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${first.designPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: bronze,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppLanguage.text(
                'Pick one option for this share.',
                'اختر خامة واحدة لهذه النسبة.',
              ),
              style: const TextStyle(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (int i = 0; i < matches.length; i++)
                  SizedBox(
                    width: 250,
                    child: _buildRecommendationCard(matches[i], isBest: i == 0),
                  ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildRecommendationCard(
    MaterialRecommendation match, {
    required bool isBest,
  }) {
    final material = match.material;
    final isSelected = _isSelected(material);

    return Card(
      color: surfaceColor,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _materialImagePair(material, height: 135),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.name,
                  style: const TextStyle(
                    color: ivory,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isBest
                      ? AppLanguage.text('BEST MATCH', 'الأنسب')
                      : AppLanguage.text('ALTERNATIVE', 'بديل'),
                  style: const TextStyle(
                    color: bronze,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  match.reasonLabel,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _colorSwatch(
                        AppLanguage.text('Reference', 'اللون المرجعي'),
                        match.sourceColorHex,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _colorSwatch(
                        AppLanguage.text('Material', 'لون الخامة'),
                        match.materialHex,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  AppLanguage.text('Best Application', 'أفضل استخدام'),
                  style: const TextStyle(
                    color: bronze,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  material.placement,
                  style: const TextStyle(color: ivory, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '${material.category} • ${material.finish}',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _showMaterialDetails(material),
                        child: Text(AppLanguage.text('Details', 'التفاصيل')),
                      ),
                    ),
                    Expanded(
                      child: isSelected
                          ? OutlinedButton(
                              onPressed: () => _toggleMaterial(material),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: bronze,
                                side: const BorderSide(color: bronze),
                              ),
                              child: Text(
                                AppLanguage.text('Added ✓', 'تمت الإضافة ✓'),
                              ),
                            )
                          : FilledButton(
                              onPressed: () => _toggleMaterial(material),
                              child: Text(AppLanguage.text('Add', 'إضافة')),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorSwatch(String label, String hex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 10)),
        const SizedBox(height: 6),
        Container(
          height: 25,
          decoration: BoxDecoration(
            color: _colorFromHex(hex),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        Text(hex, style: const TextStyle(color: muted, fontSize: 10)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Preview + specifications
  // ---------------------------------------------------------------------------

  Widget _buildPreview() {
    final hasContent =
        _selectedMaterials.isNotEmpty || _customColors.isNotEmpty;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            AppLanguage.text('Material Board Preview', 'معاينة لوحة الخامات'),
          ),
          const SizedBox(height: 16),
          _fieldLabel(AppLanguage.text('Project Name', 'اسم المشروع')),
          const SizedBox(height: 7),
          TextField(
            controller: _projectController,
            style: const TextStyle(color: ivory, fontSize: 12),
            decoration: _inputDecoration(
              AppLanguage.text('My Interior Project', 'مشروعي الداخلي'),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: RepaintBoundary(
              key: _boardKey,
              // Only the board repaints while typing the project name,
              // instead of rebuilding the whole page on every keystroke.
              child: ListenableBuilder(
                listenable: _projectController,
                builder: (context, _) => _buildExportBoard(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLanguage.text(
              'Adjust each material percentage and its HEX color. The total is always 100%.',
              'عدّل نسبة كل خامة وكود اللون الخاص بها. إجمالي النسب يظل 100%.',
            ),
            style: const TextStyle(color: muted, fontSize: 12, height: 1.7),
          ),
          if (hasContent) ...[
            const SizedBox(height: 22),
            _sectionTitle(
              AppLanguage.text('Material Specifications', 'مواصفات الخامات'),
            ),
            const SizedBox(height: 15),
            ..._selectedMaterials.map(_buildMaterialEditor),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: hasContent ? _exportBoard : null,
              icon: const Icon(Icons.download_outlined, size: 19),
              label: Text(
                AppLanguage.text(
                  'EXPORT MATERIAL BOARD PNG',
                  'تحميل لوحة الخامات PNG',
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: bronze,
                foregroundColor: bgColor,
                disabledBackgroundColor: const Color(0xFF514A40),
                disabledForegroundColor: muted,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Material images
  // ---------------------------------------------------------------------------

  Widget _materialImagePair(MaterialOption material, {double? height}) {
    final pair = Row(
      children: [
        Expanded(
          child: _buildMaterialImage(
            material.sampleImage,
            material.hex,
            _sampleLabel,
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: _buildMaterialImage(
            material.applicationImage,
            material.hex,
            _applicationLabel,
          ),
        ),
      ],
    );

    if (height == null) return pair;

    return SizedBox(height: height, width: double.infinity, child: pair);
  }

  Widget _imageFallback(String hex, {double iconSize = 40}) {
    return Container(
      color: _colorFromHex(hex),
      child: Center(
        child: Icon(Icons.texture, color: Colors.white70, size: iconSize),
      ),
    );
  }

  Widget _networkImage(String url, String hex, {double iconSize = 40}) {
    if (url.isEmpty) return _imageFallback(hex, iconSize: iconSize);

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) =>
          _imageFallback(hex, iconSize: iconSize),
    );
  }

  Widget _buildMaterialImage(String imageUrl, String hex, String label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _networkImage(imageUrl, hex),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            color: Colors.black.withValues(alpha: 0.65),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Material details dialog
  // ---------------------------------------------------------------------------

  void _showMaterialDetails(MaterialOption material) {
    final isArabic = AppLanguage.isArabic;
    final alreadyAdded = _isSelected(material);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF49443E)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _materialImagePair(material, height: 180),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.name,
                          style: const TextStyle(
                            color: ivory,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${material.category}  •  ${material.finish}',
                          style: const TextStyle(color: bronze, fontSize: 12),
                        ),
                        const SizedBox(height: 22),
                        _materialDetailRow(
                          isArabic ? 'الملمس' : 'Texture',
                          material.texture,
                        ),
                        _materialDetailRow(
                          isArabic ? 'درجة اللمعان' : 'Sheen',
                          material.sheen,
                        ),
                        _materialDetailRow(
                          isArabic ? 'الاستخدام المناسب' : 'Best For',
                          material.placement,
                        ),
                        _materialDetailRow(
                          isArabic ? 'كود اللون' : 'Color HEX',
                          material.hex,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ivory,
                                  side: const BorderSide(color: bronze),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(isArabic ? 'إغلاق' : 'Close'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _toggleMaterial(material);
                                  Navigator.pop(dialogContext);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: bronze,
                                  foregroundColor: bgColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  alreadyAdded
                                      ? (isArabic
                                            ? 'إزالة من لوحتي'
                                            : 'Remove from Board')
                                      : (isArabic
                                            ? 'أضف إلى لوحتي'
                                            : 'Add to My Board'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _materialDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: ivory, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Export board
  // ---------------------------------------------------------------------------

  Widget _buildExportBoard() {
    final isArabic = AppLanguage.isArabic;
    final projectName = _projectController.text.trim();

    return Container(
      width: double.infinity,
      color: const Color(0xFFF0ECE3),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'INNOVISTA',
                style: TextStyle(
                  color: Color(0xFF403A32),
                  fontSize: 13,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                AppLanguage.text('MATERIAL SPECIFICATION', 'مواصفات الخامات'),
                style: const TextStyle(
                  color: Color(0xFF776D60),
                  fontSize: 7,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            projectName.isEmpty ? 'My Interior Project' : projectName,
            style: const TextStyle(
              color: Color(0xFF292723),
              fontSize: 23,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 22),
          if (_selectedMaterials.isEmpty && _customColors.isEmpty)
            Container(
              height: 190,
              width: double.infinity,
              color: const Color(0xFFE1D9CC),
              alignment: Alignment.center,
              child: Text(
                AppLanguage.text(
                  'Select materials to build your board',
                  'اختر الخامات لإنشاء لوحتك',
                ),
                style: const TextStyle(color: Color(0xFF776D60), fontSize: 11),
              ),
            )
          else ...[
            _buildPercentageBar(),
            const SizedBox(height: 20),
            if (_selectedMaterials.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedMaterials.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.91,
                ),
                itemBuilder: (context, index) {
                  return _buildBoardMaterialCard(_selectedMaterials[index]);
                },
              ),
            if (_customColors.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                AppLanguage.text(
                  'CUSTOM COLOR PALETTE',
                  'لوحة الألوان المخصصة',
                ),
                style: const TextStyle(
                  color: Color(0xFF776D60),
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _customColors.map(_buildCustomColorChip).toList(),
              ),
            ],
          ],
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFC8BBA8), thickness: 0.8),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'لوحة مواصفات الخامات' : 'MATERIAL CONCEPT BOARD',
                style: const TextStyle(
                  color: Color(0xFF776D60),
                  fontSize: 8,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'INNOVISTA  /  ${DateTime.now().year}',
                style: const TextStyle(color: Color(0xFF776D60), fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomColorChip(ExtractedColor color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 65,
              height: 55,
              decoration: BoxDecoration(
                color: Color.fromARGB(255, color.red, color.green, color.blue),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: InkWell(
                onTap: () => _removeCustomColor(color),
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: const BoxDecoration(
                    color: bronze,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 15, color: bgColor),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          color.hex.toUpperCase(),
          style: const TextStyle(color: Color(0xFF403A32), fontSize: 10),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _showColorPercentageDialog(color),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: bronze.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${_customColorPercentage(color)}%',
              style: const TextStyle(
                color: Color(0xFF403A32),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPercentageBar() {
    final List<Widget> segments = [];

    for (final item in _selectedMaterials) {
      if (item.percentage <= 0) continue;

      segments.add(
        Expanded(
          flex: item.percentage,
          child: Container(color: _colorFromHex(item.hex)),
        ),
      );
    }

    for (final color in _customColors) {
      final percentage = _customColorPercentage(color);

      if (percentage <= 0) continue;

      segments.add(
        Expanded(
          flex: percentage,
          child: Container(
            color: Color.fromARGB(255, color.red, color.green, color.blue),
          ),
        ),
      );
    }

    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(height: 13, child: Row(children: segments)),
    );
  }

  Widget _buildBoardMaterialCard(SelectedMaterial item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _networkImage(
                  item.material.sampleImage,
                  item.hex,
                  iconSize: 28,
                ),
                Positioned(
                  top: 7,
                  left: 7,
                  child: InkWell(
                    onTap: () => _showMaterialPercentageDialog(item),
                    child: Container(
                      color: const Color(0xEFFFFFFF),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${item.percentage}%',
                            style: const TextStyle(
                              color: Color(0xFF292723),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.edit,
                            size: 10,
                            color: Color(0xFF776D60),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.material.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF292723),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${item.hex.toUpperCase()}  /  ${item.placement}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF776D60),
            fontSize: 8,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Material editor
  // ---------------------------------------------------------------------------

  Widget _buildMaterialEditor(SelectedMaterial item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF393632)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 55,
                  height: 55,
                  child: _networkImage(
                    item.material.sampleImage,
                    item.hex,
                    iconSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.material.name,
                      style: const TextStyle(
                        color: ivory,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.material.category,
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _toggleMaterial(item.material),
                icon: const Icon(Icons.close, color: muted, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _fieldLabel(
                AppLanguage.text('Usage Percentage', 'نسبة الاستخدام'),
              ),
              Text(
                '${item.percentage}%',
                style: const TextStyle(
                  color: bronze,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: item.percentage.toDouble().clamp(0, 100),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: bronze,
            inactiveColor: const Color(0xFF49443E),
            onChanged: (value) => _applyPercentage(item, value.round()),
          ),
          const SizedBox(height: 8),
          _fieldLabel(AppLanguage.text('HEX COLOR', 'كود اللون HEX')),
          const SizedBox(height: 7),
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: _colorFromHex(item.hex),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: muted),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextFormField(
                  key: ValueKey('${item.material.name}_hex'),
                  initialValue: item.hex,
                  style: const TextStyle(color: ivory, fontSize: 12),
                  decoration: _inputDecoration('#HEX'),
                  onChanged: (value) {
                    final cleaned = value.trim().toUpperCase();

                    if (RegExp(r'^#?[0-9A-F]{6}$').hasMatch(cleaned)) {
                      setState(() {
                        item.hex = cleaned.startsWith('#')
                            ? cleaned
                            : '#$cleaned';
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _fieldLabel(AppLanguage.text('Application Area', 'مكان الاستخدام')),
          const SizedBox(height: 7),
          TextFormField(
            key: ValueKey('${item.material.name}_placement'),
            initialValue: item.placement,
            style: const TextStyle(color: ivory, fontSize: 12),
            decoration: _inputDecoration(
              AppLanguage.text(
                'Where will you use this material?',
                'مكان استخدام الخامة',
              ),
            ),
            onChanged: (value) => setState(() => item.placement = value),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared UI pieces
  // ---------------------------------------------------------------------------

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Color(0xFF393632)),
        const SizedBox(height: 22),
        const Text(
          'INNOVISTA',
          style: TextStyle(
            color: ivory,
            fontSize: 16,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLanguage.text(
            'Design it. See it. Experience it.',
            'صمّمه. شاهده. عِش التجربة.',
          ),
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF37332E)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: ivory,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: ivory,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF77716A), fontSize: 12),
      filled: true,
      fillColor: bgColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Color(0xFF49443E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: bronze),
      ),
    );
  }
}
