import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_project.dart';
import '../services/project_service.dart';

// -----------------------------------------------------------------------------
// Theme
// -----------------------------------------------------------------------------

const Color _background = Color(0xFF171717);
const Color _surface = Color(0xFF222222);
const Color _ivory = Color(0xFFF4EFE6);
const Color _bronze = Color(0xFFB6A080);
const Color _muted = Color(0xFFAAA69F);
const Color _border = Color(0xFF393733);
const Color _error = Color(0xFF8B3939);

// -----------------------------------------------------------------------------
// Config
// -----------------------------------------------------------------------------

const String _storageBucket = 'project-media';

/// Name of the projects table in Supabase (used for the slug uniqueness check).
/// Change it if your table has a different name.
const String _projectsTable = 'projects';

const int _maxImageInputBytes = 20 * 1024 * 1024; // before compression
const int _maxImageUploadBytes = 8 * 1024 * 1024; // after compression
const int _maxVideoBytes = 50 * 1024 * 1024;
const int _maxImageDimension = 1920;
const int _jpegQuality = 85;
const int _maxGalleryImages = 30;

const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
const Set<String> _videoExtensions = {'mp4', 'webm', 'mov', 'm4v'};

const List<String> _defaultCategories = [
  'Interior',
  'Exterior',
  'Residential',
  'Commercial',
];

// Keys stored inside `specifications` for data that has no column of its own.
// Keys starting with "_" are internal: hide them on the public website.
const String _kYear = 'Year';
const String _kClient = 'Client';
const String _kDesigner = 'Designer';
const String _kTools = 'Tools';
const String _kMetaTitle = '_meta_title';
const String _kMetaDescription = '_meta_description';
const String _kAltCover = '_alt_cover';
const String _kAltGalleryPrefix = '_alt_gallery_';

// Which public page the project belongs to. Stored as `_section` inside
// `specifications`. A project WITHOUT this key (every project created before
// this feature) is treated as "portfolio", so old projects are not affected.
const String _kSection = '_section';
const String _sectionPortfolio = 'portfolio';
const String _sectionInteractive = 'interactive';

// -----------------------------------------------------------------------------
// Image compression (top-level so it can run through `compute`)
// -----------------------------------------------------------------------------

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

_ProcessedImage _compressImage(_ImageJob job) {
  final original = _ProcessedImage(job.bytes, job.extension);

  // Animated GIFs would lose their animation, so leave them untouched.
  if (job.extension == 'gif') return original;

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

    final outBytes = Uint8List.fromList(encoded);

    if (!needsResize && outBytes.length >= job.bytes.length) return original;

    return _ProcessedImage(outBytes, keepPng ? 'png' : 'jpg');
  } catch (_) {
    return original;
  }
}

// -----------------------------------------------------------------------------
// Gallery item
// -----------------------------------------------------------------------------

class _GalleryItem {
  _GalleryItem({
    this.url,
    this.bytes,
    this.extension = 'jpg',
    this.fileName,
    String altText = '',
  }) : alt = TextEditingController(text: altText),
       key = UniqueKey();

  final Key key;
  final TextEditingController alt;
  String? url;
  Uint8List? bytes;
  String extension;
  String? fileName;

  bool get isLocal => bytes != null;

  void dispose() => alt.dispose();
}

// -----------------------------------------------------------------------------
// Page
// -----------------------------------------------------------------------------

class AdminProjectFormPage extends StatefulWidget {
  final AdminProject? project;

  const AdminProjectFormPage({super.key, this.project});

  @override
  State<AdminProjectFormPage> createState() => _AdminProjectFormPageState();
}

class _AdminProjectFormPageState extends State<AdminProjectFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ProjectService _service = ProjectService();

  // Text controllers
  late final TextEditingController _titleController;
  late final TextEditingController _slugController;
  late final TextEditingController _locationController;
  late final TextEditingController _areaController;
  late final TextEditingController _yearController;
  late final TextEditingController _clientController;
  late final TextEditingController _designerController;
  late final TextEditingController _toolsController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _specificationsController;
  late final TextEditingController _coverController;
  late final TextEditingController _coverAltController;
  late final TextEditingController _videoController;
  late final TextEditingController _seoTitleController;
  late final TextEditingController _seoDescriptionController;
  late final TextEditingController _orderController;
  final TextEditingController _galleryUrlController = TextEditingController();

  // Category
  String? _category;
  late List<String> _categories;

  // Which public page the project is shown on (portfolio / interactive)
  String _displaySection = _sectionPortfolio;

  // Cover image (local, compressed)
  Uint8List? _coverImageBytes;
  String _coverExtension = 'jpg';
  String? _coverFileName;

  // Gallery
  final List<_GalleryItem> _gallery = [];

  // Video (local)
  PlatformFile? _videoFile;
  Uint8List? _videoBytes;

  // State
  bool _isPublished = false;
  bool _isSaving = false;
  bool _isProcessingImages = false;
  bool _isDirty = false;
  bool _slugEditedManually = false;
  String? _progress;

  // Housekeeping
  Timer? _draftTimer;
  Timer? _urlDebounce;
  final List<String> _uploadedPaths = [];
  late final Set<String> _originalUrls;

  bool get _isEditing => widget.project != null;

  String get _draftKey => 'admin_project_draft_${widget.project?.id ?? 'new'}';

  List<TextEditingController> get _allControllers => [
    _titleController,
    _slugController,
    _locationController,
    _areaController,
    _yearController,
    _clientController,
    _designerController,
    _toolsController,
    _descriptionController,
    _specificationsController,
    _coverController,
    _coverAltController,
    _videoController,
    _seoTitleController,
    _seoDescriptionController,
    _orderController,
  ];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    final project = widget.project;

    // Pull the "hidden" values out of specifications so they get their own
    // fields, and leave only the free-form specs for the text area.
    final specs = Map<String, dynamic>.from(project?.specifications ?? {});
    String take(String key) => (specs.remove(key) ?? '').toString();

    final year = take(_kYear);
    final client = take(_kClient);
    final designer = take(_kDesigner);
    final tools = take(_kTools);
    final metaTitle = take(_kMetaTitle);
    final metaDescription = take(_kMetaDescription);
    final coverAlt = take(_kAltCover);
    final section = take(_kSection);

    final galleryUrls = project?.gallery ?? const <String>[];
    for (var i = 0; i < galleryUrls.length; i++) {
      _gallery.add(
        _GalleryItem(
          url: galleryUrls[i],
          altText: take('$_kAltGalleryPrefix$i'),
        ),
      );
    }

    specs.removeWhere((key, _) => key.startsWith('_'));

    _titleController = TextEditingController(text: project?.title ?? '');
    _slugController = TextEditingController(text: project?.slug ?? '');
    _locationController = TextEditingController(text: project?.location ?? '');
    _areaController = TextEditingController(text: project?.area ?? '');
    _yearController = TextEditingController(text: year);
    _clientController = TextEditingController(text: client);
    _designerController = TextEditingController(text: designer);
    _toolsController = TextEditingController(text: tools);
    _descriptionController = TextEditingController(
      text: project?.description ?? '',
    );
    _specificationsController = TextEditingController(
      text: specs.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
    );
    _coverController = TextEditingController(text: project?.coverImage ?? '');
    _coverAltController = TextEditingController(text: coverAlt);
    _videoController = TextEditingController(text: project?.videoUrl ?? '');
    _seoTitleController = TextEditingController(text: metaTitle);
    _seoDescriptionController = TextEditingController(text: metaDescription);
    _orderController = TextEditingController(
      text: (project?.displayOrder ?? 0).toString(),
    );

    final existingCategory = (project?.category ?? '').trim();
    _categories = [..._defaultCategories];
    if (existingCategory.isNotEmpty &&
        !_categories.any(
          (c) => c.toLowerCase() == existingCategory.toLowerCase(),
        )) {
      _categories.add(existingCategory);
    }
    _category = existingCategory.isEmpty ? null : existingCategory;

    // Old projects have no `_section` key, so they stay in "portfolio".
    _displaySection = section == _sectionInteractive
        ? _sectionInteractive
        : _sectionPortfolio;

    _isPublished = project?.isPublished ?? false;
    _slugEditedManually = (project?.slug ?? '').isNotEmpty;

    _originalUrls = {
      if ((project?.coverImage ?? '').isNotEmpty) project!.coverImage!,
      ...galleryUrls,
      if ((project?.videoUrl ?? '').isNotEmpty) project!.videoUrl!,
    };

    for (final controller in _allControllers) {
      controller.addListener(_touch);
    }

    _titleController.addListener(_syncSlugWithTitle);
    _slugController.addListener(_onSlugChanged);
    _coverController.addListener(_onMediaUrlChanged);
    _videoController.addListener(_onMediaUrlChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraftRestore());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _urlDebounce?.cancel();

    for (final controller in _allControllers) {
      controller.dispose();
    }
    _galleryUrlController.dispose();

    for (final item in _gallery) {
      item.dispose();
    }

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Listeners / dirty tracking
  // ---------------------------------------------------------------------------

  void _touch() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    } else {
      _isDirty = true;
    }
    _scheduleDraftSave();
  }

  void _syncSlugWithTitle() {
    if (_slugEditedManually) return;

    final generated = _generateSlug(_titleController.text);
    if (_slugController.text != generated) {
      _slugController.text = generated;
    }
  }

  void _onSlugChanged() {
    if (_slugController.text != _generateSlug(_titleController.text)) {
      _slugEditedManually = _slugController.text.isNotEmpty;
    }
  }

  void _onMediaUrlChanged() {
    _urlDebounce?.cancel();
    _urlDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() {});
    });
  }

  // ---------------------------------------------------------------------------
  // Draft auto-save
  // ---------------------------------------------------------------------------

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 1500), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (!_isDirty || _isSaving) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final data = <String, dynamic>{
        'title': _titleController.text,
        'slug': _slugController.text,
        'slugManual': _slugEditedManually,
        'category': _category,
        'section': _displaySection,
        'location': _locationController.text,
        'area': _areaController.text,
        'year': _yearController.text,
        'client': _clientController.text,
        'designer': _designerController.text,
        'tools': _toolsController.text,
        'description': _descriptionController.text,
        'specifications': _specificationsController.text,
        'cover': _coverController.text,
        'coverAlt': _coverAltController.text,
        'video': _videoController.text,
        'seoTitle': _seoTitleController.text,
        'seoDescription': _seoDescriptionController.text,
        'order': _orderController.text,
        'published': _isPublished,
        // Only gallery images that already have a URL can be kept in a draft.
        'gallery': [
          for (final item in _gallery)
            if (item.url != null) {'url': item.url, 'alt': item.alt.text},
        ],
      };

      await prefs.setString(_draftKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Draft save failed: $e');
    }
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _offerDraftRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || !mounted) return;

      final restore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Restore unsaved draft?',
            style: TextStyle(color: _ivory, fontSize: 16),
          ),
          content: const Text(
            'We found an unsaved draft of this project from a previous session. '
            'Images picked from your device are not part of drafts.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'DISCARD DRAFT',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('RESTORE', style: TextStyle(color: _bronze)),
            ),
          ],
        ),
      );

      if (restore == true) {
        _applyDraft(jsonDecode(raw) as Map<String, dynamic>);
      } else if (restore == false) {
        await _clearDraft();
      }
    } catch (e) {
      debugPrint('Draft restore failed: $e');
    }
  }

  void _applyDraft(Map<String, dynamic> data) {
    String s(String key) => (data[key] ?? '').toString();

    setState(() {
      _titleController.text = s('title');
      _slugController.text = s('slug');
      _slugEditedManually = data['slugManual'] == true;
      _locationController.text = s('location');
      _areaController.text = s('area');
      _yearController.text = s('year');
      _clientController.text = s('client');
      _designerController.text = s('designer');
      _toolsController.text = s('tools');
      _descriptionController.text = s('description');
      _specificationsController.text = s('specifications');
      _coverController.text = s('cover');
      _coverAltController.text = s('coverAlt');
      _videoController.text = s('video');
      _seoTitleController.text = s('seoTitle');
      _seoDescriptionController.text = s('seoDescription');
      _orderController.text = s('order');
      _isPublished = data['published'] == true;

      // Drafts saved before this feature have no section: keep the current one.
      final draftSection = s('section');
      if (draftSection == _sectionInteractive ||
          draftSection == _sectionPortfolio) {
        _displaySection = draftSection;
      }

      final category = (data['category'] ?? '').toString();
      _category = category.isEmpty ? null : category;
      if (_category != null &&
          !_categories.any(
            (c) => c.toLowerCase() == _category!.toLowerCase(),
          )) {
        _categories.add(_category!);
      }

      for (final item in _gallery) {
        item.dispose();
      }
      _gallery.clear();

      final gallery = data['gallery'];
      if (gallery is List) {
        for (final entry in gallery) {
          if (entry is Map) {
            _gallery.add(
              _GalleryItem(
                url: entry['url']?.toString(),
                altText: (entry['alt'] ?? '').toString(),
              ),
            );
          }
        }
      }

      _isDirty = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _error : null,
        ),
      );
  }

  String _generateSlug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _extensionOf(String fileName, {String fallback = 'jpg'}) {
    return fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : fallback;
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'jpg' || 'jpeg' => 'image/jpeg',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      _ => 'application/octet-stream',
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _isValidUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Map<String, dynamic> _parseSpecifications() {
    final result = <String, dynamic>{};

    for (final line in _specificationsController.text.split('\n')) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;

      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();

      // Keys starting with "_" are reserved for internal data.
      if (key.isNotEmpty && value.isNotEmpty && !key.startsWith('_')) {
        result[key] = value;
      }
    }

    return result;
  }

  /// Everything shown as "specifications" on the site (extra fields + free text).
  Map<String, dynamic> _visibleSpecifications() {
    final specs = <String, dynamic>{};

    void put(String key, String value) {
      if (value.trim().isNotEmpty) specs[key] = value.trim();
    }

    put(_kYear, _yearController.text);
    put(_kClient, _clientController.text);
    put(_kDesigner, _designerController.text);
    put(_kTools, _toolsController.text);

    _parseSpecifications().forEach((key, value) {
      specs.putIfAbsent(key, () => value);
    });

    return specs;
  }

  /// Returns the storage path of a file in our bucket, or null for other URLs.
  String? _storagePathFromUrl(String url) {
    final marker = '/object/public/$_storageBucket/';
    final index = url.indexOf(marker);
    if (index == -1) return null;

    final raw = url.substring(index + marker.length).split('?').first;
    return Uri.decodeComponent(raw);
  }

  String? _youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.replaceFirst('www.', '');

    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }

    if (host == 'youtube.com' || host == 'm.youtube.com') {
      if (uri.queryParameters['v'] != null) return uri.queryParameters['v'];
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'embed' ||
              uri.pathSegments.first == 'shorts')) {
        return uri.pathSegments[1];
      }
    }

    return null;
  }

  bool _isVimeo(String url) {
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
    return host == 'vimeo.com' || host == 'player.vimeo.com';
  }

  // ---------------------------------------------------------------------------
  // Image handling
  // ---------------------------------------------------------------------------

  /// Validates, reads and compresses a picked image. Returns null on failure.
  Future<_ProcessedImage?> _readAndProcessImage(PlatformFile file) async {
    final extension = _extensionOf(file.name);

    if (!_imageExtensions.contains(extension)) {
      _showSnack(
        'Unsupported format (.$extension). Use JPG, PNG, WEBP or GIF.',
        isError: true,
      );
      return null;
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      _showSnack('"${file.name}" is empty.', isError: true);
      return null;
    }

    if (bytes.length > _maxImageInputBytes) {
      _showSnack(
        '"${file.name}" is too large (${_formatBytes(bytes.length)}). '
        'Maximum is ${_formatBytes(_maxImageInputBytes)}.',
        isError: true,
      );
      return null;
    }

    final result = await compute(_compressImage, _ImageJob(bytes, extension));

    if (result.bytes.length > _maxImageUploadBytes) {
      _showSnack(
        '"${file.name}" is still too large after compression '
        '(${_formatBytes(result.bytes.length)}).',
        isError: true,
      );
      return null;
    }

    return result;
  }

  Future<void> _pickCoverImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;

      setState(() => _isProcessingImages = true);

      final file = files.first;
      final processed = await _readAndProcessImage(file);

      if (!mounted) return;

      if (processed != null) {
        setState(() {
          _coverImageBytes = processed.bytes;
          _coverExtension = processed.extension;
          _coverFileName = file.name;
        });
        _touch();
      }
    } catch (e) {
      _showSnack('Failed to select image: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingImages = false);
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverImageBytes = null;
      _coverFileName = null;
      _coverController.clear();
      _coverAltController.clear();
    });
    _touch();
  }

  Future<void> _pickGalleryImages() async {
    final remaining = _maxGalleryImages - _gallery.length;
    if (remaining <= 0) {
      _showSnack(
        'Gallery is limited to $_maxGalleryImages images.',
        isError: true,
      );
      return;
    }

    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;

      setState(() => _isProcessingImages = true);

      var added = 0;

      for (final file in files.take(remaining)) {
        final processed = await _readAndProcessImage(file);
        if (processed == null) continue;

        _gallery.add(
          _GalleryItem(
            bytes: processed.bytes,
            extension: processed.extension,
            fileName: file.name,
          ),
        );
        added++;
      }

      if (files.length > remaining) {
        _showSnack('Only the first $remaining images were added (limit).');
      } else if (added > 0) {
        _showSnack('$added image(s) added to the gallery.');
      }

      if (mounted) setState(() {});
      if (added > 0) _touch();
    } catch (e) {
      _showSnack('Failed to select images: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingImages = false);
    }
  }

  void _addGalleryUrl() {
    final url = _galleryUrlController.text.trim();

    if (!_isValidUrl(url)) {
      _showSnack('Enter a valid image URL.', isError: true);
      return;
    }

    if (_gallery.length >= _maxGalleryImages) {
      _showSnack(
        'Gallery is limited to $_maxGalleryImages images.',
        isError: true,
      );
      return;
    }

    setState(() {
      _gallery.add(_GalleryItem(url: url));
      _galleryUrlController.clear();
    });
    _touch();
  }

  void _removeGalleryItem(int index) {
    setState(() {
      final item = _gallery.removeAt(index);
      item.dispose();
    });
    _touch();
  }

  void _reorderGallery(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _gallery.removeAt(oldIndex);
      _gallery.insert(newIndex, item);
    });
    _touch();
  }

  // ---------------------------------------------------------------------------
  // Video handling
  // ---------------------------------------------------------------------------

  Future<void> _pickVideo() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.video);
      if (files.isEmpty) return;

      final file = files.first;
      final extension = _extensionOf(file.name, fallback: '');

      if (!_videoExtensions.contains(extension)) {
        _showSnack(
          'Unsupported video format. Use MP4, WEBM, MOV or M4V.',
          isError: true,
        );
        return;
      }

      final bytes = await file.readAsBytes();

      if (bytes.length > _maxVideoBytes) {
        _showSnack(
          'Video is too large (${_formatBytes(bytes.length)}). '
          'Maximum is ${_formatBytes(_maxVideoBytes)}. '
          'For bigger videos use a YouTube or Vimeo link.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _videoFile = file;
        _videoBytes = bytes;
        _videoController.clear();
      });
      _touch();
    } catch (e) {
      _showSnack('Failed to select video: $e', isError: true);
    }
  }

  void _removeVideo() {
    setState(() {
      _videoFile = null;
      _videoBytes = null;
      _videoController.clear();
    });
    _touch();
  }

  // ---------------------------------------------------------------------------
  // Storage
  // ---------------------------------------------------------------------------

  Future<String> _uploadBytes(
    String path,
    Uint8List bytes,
    String extension,
  ) async {
    final storage = Supabase.instance.client.storage.from(_storageBucket);

    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: _contentTypeFor(extension),
      ),
    );

    _uploadedPaths.add(path);

    return storage.getPublicUrl(path);
  }

  /// Removes files uploaded during a save that then failed.
  Future<void> _rollbackUploads() async {
    if (_uploadedPaths.isEmpty) return;

    try {
      await Supabase.instance.client.storage
          .from(_storageBucket)
          .remove(List<String>.from(_uploadedPaths));
    } catch (e) {
      debugPrint('Rollback failed: $e');
    } finally {
      _uploadedPaths.clear();
    }
  }

  /// Removes files that were part of the project before but are no longer used.
  Future<void> _deleteUnusedFiles(Set<String> finalUrls) async {
    final paths = _originalUrls
        .difference(finalUrls)
        .map(_storagePathFromUrl)
        .whereType<String>()
        .toList();

    if (paths.isEmpty) return;

    try {
      await Supabase.instance.client.storage.from(_storageBucket).remove(paths);
    } catch (e) {
      // Not critical: the project is already saved.
      debugPrint('Failed to delete old files: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Slug
  // ---------------------------------------------------------------------------

  Future<String> _resolveUniqueSlug(String title) async {
    var base = _generateSlug(_slugController.text);
    if (base.isEmpty) base = _generateSlug(title);

    // Arabic-only titles produce no latin characters.
    if (base.isEmpty) {
      return 'project-${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      final rows = await Supabase.instance.client
          .from(_projectsTable)
          .select('id, slug')
          .ilike('slug', '$base%');

      final ownId = widget.project?.id?.toString();
      final taken = <String>{};

      for (final row in rows) {
        if (ownId != null && row['id']?.toString() == ownId) continue;
        taken.add((row['slug'] ?? '').toString());
      }

      if (!taken.contains(base)) return base;

      var n = 2;
      while (taken.contains('$base-$n')) {
        n++;
      }
      return '$base-$n';
    } catch (e) {
      debugPrint('Slug check failed (check _projectsTable): $e');
      return base;
    }
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  void _setProgress(String? value) {
    if (mounted) setState(() => _progress = value);
  }

  Future<void> _saveProject() async {
    if (_isSaving || _isProcessingImages) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _progress = 'Checking slug...';
    });

    _uploadedPaths.clear();

    try {
      final title = _titleController.text.trim();
      final slug = await _resolveUniqueSlug(title);

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final folder = widget.project?.id ?? 'new_$stamp';
      final base = 'projects/$folder';

      // Cover
      var coverUrl = _coverController.text.trim();
      if (_coverImageBytes != null) {
        _setProgress('Uploading cover...');
        coverUrl = await _uploadBytes(
          '$base/cover_$stamp.$_coverExtension',
          _coverImageBytes!,
          _coverExtension,
        );
      }

      // Gallery
      final galleryUrls = <String>[];
      final localCount = _gallery.where((g) => g.isLocal).length;
      var uploaded = 0;

      for (var i = 0; i < _gallery.length; i++) {
        final item = _gallery[i];

        if (item.isLocal) {
          uploaded++;
          _setProgress('Uploading gallery $uploaded/$localCount...');
          galleryUrls.add(
            await _uploadBytes(
              '$base/gallery_${stamp}_$i.${item.extension}',
              item.bytes!,
              item.extension,
            ),
          );
        } else if (item.url != null) {
          galleryUrls.add(item.url!);
        } else {
          galleryUrls.add('');
        }
      }

      // Video
      var videoUrl = _videoController.text.trim();
      if (_videoBytes != null && _videoFile != null) {
        _setProgress('Uploading video...');
        final extension = _extensionOf(_videoFile!.name, fallback: 'mp4');
        videoUrl = await _uploadBytes(
          '$base/video_$stamp.$extension',
          _videoBytes!,
          extension,
        );
      }

      _setProgress('Saving project...');

      // Specifications + hidden data (alt texts, SEO, display section)
      final specs = _visibleSpecifications();

      void putHidden(String key, String value) {
        if (value.trim().isNotEmpty) specs[key] = value.trim();
      }

      if (coverUrl.isNotEmpty) putHidden(_kAltCover, _coverAltController.text);

      for (var i = 0; i < _gallery.length; i++) {
        putHidden('$_kAltGalleryPrefix$i', _gallery[i].alt.text);
      }

      putHidden(_kMetaTitle, _seoTitleController.text);
      putHidden(_kMetaDescription, _seoDescriptionController.text);

      // Which public page this project belongs to.
      putHidden(_kSection, _displaySection);

      final project = AdminProject(
        id: widget.project?.id,
        title: title,
        slug: slug,
        category: _category ?? '',
        location: _locationController.text.trim(),
        area: _areaController.text.trim(),
        description: _descriptionController.text.trim(),
        specifications: specs,
        coverImage: coverUrl,
        gallery: galleryUrls,
        videoUrl: videoUrl,
        isPublished: _isPublished,
        displayOrder: int.tryParse(_orderController.text.trim()) ?? 0,
      );

      if (_isEditing) {
        await _service.updateProject(project);
      } else {
        await _service.addProject(project);
      }

      // Saved: clean up files that are no longer used and the local draft.
      _uploadedPaths.clear();
      await _deleteUnusedFiles({
        if (coverUrl.isNotEmpty) coverUrl,
        ...galleryUrls,
        if (videoUrl.isNotEmpty) videoUrl,
      });
      await _clearDraft();

      if (!mounted) return;

      _isDirty = false;

      _showSnack(
        _isEditing
            ? 'Project updated successfully.'
            : 'Project added successfully.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      await _rollbackUploads();
      _showSnack('Failed to save project: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _progress = null;
        });
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text(
          'Discard changes?',
          style: TextStyle(color: _ivory, fontSize: 16),
        ),
        content: const Text(
          'You have unsaved changes. If you leave now they will be lost.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP EDITING', style: TextStyle(color: _bronze)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DISCARD',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    return discard ?? false;
  }

  // ---------------------------------------------------------------------------
  // Category
  // ---------------------------------------------------------------------------

  Future<void> _addCustomCategory() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => const _CustomCategoryDialog(),
    );

    if (value == null || value.trim().isEmpty || !mounted) return;

    final name = value.trim();

    setState(() {
      final existing = _categories.where(
        (c) => c.toLowerCase() == name.toLowerCase(),
      );
      if (existing.isEmpty) {
        _categories.add(name);
        _category = name;
      } else {
        _category = existing.first;
      }
    });
    _touch();
  }

  // ---------------------------------------------------------------------------
  // Preview
  // ---------------------------------------------------------------------------

  void _showPreview() {
    final specs = _visibleSpecifications();
    final description = _descriptionController.text.trim();
    final title = _titleController.text.trim();
    final coverUrl = _coverController.text.trim();
    final videoUrl = _videoController.text.trim();

    final meta = [
      _locationController.text.trim(),
      _areaController.text.trim(),
    ].where((e) => e.isNotEmpty).join('  •  ');

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _background,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Text(
                      _isPublished
                          ? 'PREVIEW  •  PUBLISHED'
                          : 'PREVIEW  •  DRAFT (HIDDEN FROM SITE)',
                      style: const TextStyle(
                        color: _bronze,
                        fontSize: 11,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: _ivory),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: _surface,
                          child: _imageFrom(
                            bytes: _coverImageBytes,
                            url: coverUrl,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _displaySection == _sectionInteractive
                            ? 'SHOWN ON: INTERACTIVE PAGE'
                            : 'SHOWN ON: SELECTED WORK PAGE',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_category != null)
                        Text(
                          _category!.toUpperCase(),
                          style: const TextStyle(
                            color: _bronze,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        title.isEmpty ? 'Untitled project' : title,
                        style: const TextStyle(
                          color: _ivory,
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          meta,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          description,
                          style: const TextStyle(
                            color: _ivory,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                      if (specs.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        for (final entry in specs.entries)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: _border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value.toString(),
                                    style: const TextStyle(
                                      color: _ivory,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (_gallery.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final item in _gallery)
                              SizedBox(
                                width: 200,
                                height: 135,
                                child: Container(
                                  color: _surface,
                                  child: _imageFrom(
                                    bytes: item.bytes,
                                    url: item.url,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (_videoFile != null || videoUrl.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _buildVideoPreview(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI building blocks
  // ---------------------------------------------------------------------------

  InputDecoration _decoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 11),
      counterStyle: const TextStyle(color: _muted, fontSize: 10),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.all(15),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(3),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(3),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _bronze),
        borderRadius: BorderRadius.circular(3),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(3),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    int? maxLength,
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String value)? extraValidator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _ivory, fontSize: 12)),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          enabled: !_isSaving,
          style: const TextStyle(color: _ivory, fontSize: 13),
          validator: (value) {
            final text = (value ?? '').trim();

            if (required && text.isEmpty) return 'This field is required.';
            if (text.isEmpty) return null;

            return extraValidator?.call(text);
          },
          decoration: _decoration(hint),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 18),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: _bronze,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  ButtonStyle _outlinedStyle(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    );
  }

  Widget _previewMessage(IconData icon, String message, {String? details}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _muted, size: 38),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            if (details != null) ...[
              const SizedBox(height: 6),
              Text(
                details,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Generic image (local bytes or network URL) that fills its parent.
  Widget _imageFrom({Uint8List? bytes, String? url}) {
    const fallback = Center(
      child: Icon(Icons.broken_image_outlined, color: _muted),
    );

    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => fallback,
      );
    }

    if (url != null && _isValidUrl(url)) {
      return Image.network(
        url,
        key: ValueKey(url),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stack) => fallback,
      );
    }

    return fallback;
  }

  Widget _buildCoverPreview() {
    final bytes = _coverImageBytes;
    final url = _coverController.text.trim();

    if (bytes != null) {
      return Image.memory(
        bytes,
        key: ValueKey('cover_${_coverFileName}_${bytes.length}'),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Cover preview error: $error');

          return _previewMessage(
            Icons.broken_image_outlined,
            'This image cannot be previewed.\n'
            'It will still upload, but the format may not be supported by the browser.',
            details:
                '${_coverFileName ?? ''} • ${_formatBytes(bytes.length)}\n$error',
          );
        },
      );
    }

    if (url.isNotEmpty) {
      if (!_isValidUrl(url)) {
        return _previewMessage(Icons.link_off, 'Invalid image URL');
      }

      return Image.network(
        url,
        key: ValueKey(url),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          final total = progress.expectedTotalBytes;

          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _bronze,
              value: total == null
                  ? null
                  : progress.cumulativeBytesLoaded / total,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _previewMessage(
            Icons.broken_image_outlined,
            'Image preview unavailable',
          );
        },
      );
    }

    return _previewMessage(Icons.image_outlined, 'No cover image selected');
  }

  // One selectable card of the "Display Section" picker.
  Widget _sectionOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _displaySection == value;

    return InkWell(
      onTap: _isSaving
          ? null
          : () {
              setState(() => _displaySection = value);
              _touch();
            },
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A2621) : _surface,
          border: Border.all(
            color: selected ? _bronze : _border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? _bronze : _muted, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? _ivory : _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: _bronze, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySectionPicker() {
    final portfolio = _sectionOption(
      value: _sectionPortfolio,
      icon: Icons.image_outlined,
      title: 'Selected Work (Renders)',
      subtitle: 'Still renders and animation. Shown on the Selected Work page.',
    );

    final interactive = _sectionOption(
      value: _sectionInteractive,
      icon: Icons.view_in_ar_outlined,
      title: 'Interactive Experience',
      subtitle:
          'Interactive walkthroughs and VR. Shown on the Interactive page.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where should this project appear? *',
          style: TextStyle(color: _ivory, fontSize: 12),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 620) {
              return Column(
                children: [portfolio, const SizedBox(height: 10), interactive],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: portfolio),
                const SizedBox(width: 12),
                Expanded(child: interactive),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(color: _ivory, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in _categories)
              ChoiceChip(
                label: Text(category),
                selected: _category == category,
                showCheckmark: false,
                selectedColor: _bronze,
                backgroundColor: _surface,
                side: const BorderSide(color: _border),
                labelStyle: TextStyle(
                  color: _category == category ? _background : _ivory,
                  fontSize: 12,
                ),
                onSelected: _isSaving
                    ? null
                    : (selected) {
                        setState(() => _category = selected ? category : null);
                        _touch();
                      },
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: _bronze),
              label: const Text('Custom'),
              backgroundColor: _surface,
              side: const BorderSide(color: _border),
              labelStyle: const TextStyle(color: _bronze, fontSize: 12),
              onPressed: _isSaving ? null : _addCustomCategory,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoverImagePicker() {
    final hasSelectedImage = _coverImageBytes != null;
    final hasAnyImage =
        hasSelectedImage || _coverController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover Image',
          style: TextStyle(color: _ivory, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 230,
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(3),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildCoverPreview(),
        ),
        if (hasSelectedImage) ...[
          const SizedBox(height: 8),
          Text(
            '${_coverFileName ?? ''} • ${_formatBytes(_coverImageBytes!.length)} (optimized)',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: (_isSaving || _isProcessingImages)
                  ? null
                  : _pickCoverImage,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(
                hasSelectedImage ? 'CHANGE COVER IMAGE' : 'CHOOSE COVER IMAGE',
              ),
              style: _outlinedStyle(_bronze),
            ),
            if (hasAnyImage)
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _removeCoverImage,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('REMOVE'),
                style: _outlinedStyle(Colors.redAccent),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'JPG, PNG, WEBP or GIF. Images are resized to ${_maxImageDimension}px '
          'and compressed automatically. Uploaded when you save.',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        const SizedBox(height: 18),
        _field(
          'Cover Alt Text',
          _coverAltController,
          hint: 'Describe the cover image (for SEO and accessibility)',
        ),
      ],
    );
  }

  Widget _buildGalleryItem(int index) {
    final item = _gallery[index];

    return Container(
      key: item.key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.drag_indicator, color: _muted),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 100,
            height: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: _imageFrom(bytes: item.bytes, url: item.url),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.isLocal
                      ? '${item.fileName ?? 'New image'} • ${_formatBytes(item.bytes!.length)}  (new)'
                      : (item.url ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: item.alt,
                  enabled: !_isSaving,
                  style: const TextStyle(color: _ivory, fontSize: 12),
                  decoration: _decoration('Alt text').copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: _isSaving ? null : () => _removeGalleryItem(index),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gallery Images (${_gallery.length}/$_maxGalleryImages)',
          style: const TextStyle(color: _ivory, fontSize: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          'Drag the handle to reorder. The first image appears first on the site.',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
        const SizedBox(height: 10),
        if (_gallery.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Column(
              children: [
                Icon(Icons.photo_library_outlined, color: _muted, size: 34),
                SizedBox(height: 8),
                Text(
                  'No gallery images yet',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _gallery.length,
            onReorderItem: _reorderGallery,
            proxyDecorator: (child, index, animation) =>
                Material(color: Colors.transparent, child: child),
            itemBuilder: (context, index) => _buildGalleryItem(index),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: (_isSaving || _isProcessingImages)
              ? null
              : _pickGalleryImages,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('ADD IMAGES FROM DEVICE'),
          style: _outlinedStyle(_bronze),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _galleryUrlController,
                enabled: !_isSaving,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: _ivory, fontSize: 13),
                onSubmitted: (_) => _addGalleryUrl(),
                decoration: _decoration('Or paste an image URL and press Add'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _isSaving ? null : _addGalleryUrl,
              style: _outlinedStyle(_bronze),
              child: const Text('ADD'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    final url = _videoController.text.trim();

    Widget card({
      required IconData icon,
      required String title,
      String? subtitle,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Icon(icon, color: _bronze, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: _ivory, fontSize: 13),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_videoFile != null && _videoBytes != null) {
      return card(
        icon: Icons.movie_outlined,
        title: _videoFile!.name,
        subtitle:
            '${_formatBytes(_videoBytes!.length)} • will be uploaded on save',
      );
    }

    if (url.isEmpty) return const SizedBox.shrink();

    if (!_isValidUrl(url)) {
      return card(icon: Icons.link_off, title: 'Invalid video URL');
    }

    final youtubeId = _youtubeId(url);

    if (youtubeId != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: _surface,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
                    key: ValueKey('yt_$youtubeId'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Center(
                      child: Icon(Icons.broken_image_outlined, color: _muted),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white70,
                      size: 58,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'YouTube video',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      );
    }

    if (_isVimeo(url)) {
      return card(
        icon: Icons.play_circle_outline,
        title: 'Vimeo video',
        subtitle: url,
      );
    }

    return card(
      icon: Icons.play_circle_outline,
      title: 'Video link',
      subtitle: url,
    );
  }

  Widget _buildVideoSection() {
    final hasVideo =
        _videoFile != null || _videoController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          'Video URL (YouTube / Vimeo / direct link)',
          _videoController,
          hint: 'https://...',
          keyboardType: TextInputType.url,
          extraValidator: (v) => _isValidUrl(v) ? null : 'Enter a valid URL.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickVideo,
              icon: const Icon(Icons.video_file_outlined, size: 18),
              label: Text(
                _videoFile == null
                    ? 'UPLOAD VIDEO FROM DEVICE'
                    : 'CHANGE VIDEO',
              ),
              style: _outlinedStyle(_bronze),
            ),
            if (hasVideo)
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _removeVideo,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('REMOVE VIDEO'),
                style: _outlinedStyle(Colors.redAccent),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'MP4, WEBM, MOV or M4V up to ${_formatBytes(_maxVideoBytes)}. '
          'For larger videos use a YouTube or Vimeo link.',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        if (hasVideo) ...[const SizedBox(height: 14), _buildVideoPreview()],
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _showPreview,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('PREVIEW'),
            style: _outlinedStyle(_bronze),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_isSaving || _isProcessingImages)
                  ? null
                  : _saveProject,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bronze,
                foregroundColor: _background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              child: _isSaving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _background,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          (_progress ?? 'Saving...').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _isEditing ? 'SAVE CHANGES' : 'CREATE PROJECT',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty && !_isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isSaving) return;

        final discard = await _confirmDiscard();

        if (discard && context.mounted) {
          await _clearDraft();
          setState(() => _isDirty = false);
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _ivory,
          title: Text(
            _isEditing ? 'Edit Project' : 'Add New Project',
            style: const TextStyle(fontSize: 17),
          ),
          bottom: _isProcessingImages
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: _bronze,
                    backgroundColor: _border,
                  ),
                )
              : null,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Display Section'),
                    _buildDisplaySectionPicker(),

                    _sectionTitle('Basic Information'),
                    _field(
                      'Project Name *',
                      _titleController,
                      hint: 'Modern Luxury Villa',
                      required: true,
                    ),
                    const SizedBox(height: 18),
                    _field(
                      'URL Slug',
                      _slugController,
                      hint: 'modern-luxury-villa (generated automatically)',
                    ),
                    const SizedBox(height: 18),
                    _buildCategoryPicker(),
                    const SizedBox(height: 18),
                    _field(
                      'Location',
                      _locationController,
                      hint: 'New Cairo, Egypt',
                    ),
                    const SizedBox(height: 18),
                    _field('Area', _areaController, hint: '250 m²'),

                    _sectionTitle('Project Details'),
                    _field(
                      'Year',
                      _yearController,
                      hint: '2025',
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      extraValidator: (v) => RegExp(r'^\d{4}$').hasMatch(v)
                          ? null
                          : 'Enter a 4-digit year.',
                    ),
                    const SizedBox(height: 18),
                    _field('Client', _clientController, hint: 'Client name'),
                    const SizedBox(height: 18),
                    _field(
                      'Designer',
                      _designerController,
                      hint: 'Lead designer / architect',
                    ),
                    const SizedBox(height: 18),
                    _field(
                      'Tools Used',
                      _toolsController,
                      hint: 'Blender, 3ds Max, Photoshop...',
                    ),

                    _sectionTitle('Project Description'),
                    _field(
                      'Description',
                      _descriptionController,
                      hint: 'Describe the project...',
                      maxLines: 5,
                    ),
                    const SizedBox(height: 18),
                    _field(
                      'Specifications',
                      _specificationsController,
                      hint: 'Bedrooms: 4\nBathrooms: 3\nFloors: 2',
                      maxLines: 5,
                    ),

                    _sectionTitle('Media'),
                    _buildCoverImagePicker(),
                    const SizedBox(height: 22),
                    _field(
                      'Cover Image URL (optional)',
                      _coverController,
                      hint: 'https://...',
                      keyboardType: TextInputType.url,
                      extraValidator: (v) =>
                          _isValidUrl(v) ? null : 'Enter a valid URL.',
                    ),
                    const SizedBox(height: 26),
                    _buildGallerySection(),
                    const SizedBox(height: 26),
                    _buildVideoSection(),

                    _sectionTitle('SEO'),
                    _field(
                      'Meta Title',
                      _seoTitleController,
                      hint: 'Shown in Google results (about 60 characters)',
                      maxLength: 70,
                    ),
                    const SizedBox(height: 18),
                    _field(
                      'Meta Description',
                      _seoDescriptionController,
                      hint: 'Short summary for search engines (about 160 characters)',
                      maxLines: 3,
                      maxLength: 170,
                    ),

                    _sectionTitle('Publishing'),
                    _field(
                      'Display Order',
                      _orderController,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      extraValidator: (v) => int.tryParse(v) == null
                          ? 'Enter a whole number.'
                          : null,
                    ),
                    const SizedBox(height: 15),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Publish Project',
                        style: TextStyle(color: _ivory, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Published projects can appear on the public website.',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                      activeThumbColor: _bronze,
                      value: _isPublished,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() => _isPublished = value);
                              _touch();
                            },
                    ),
                    const SizedBox(height: 30),
                    _buildActions(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Custom category dialog (owns its controller so it is disposed correctly)
// -----------------------------------------------------------------------------

class _CustomCategoryDialog extends StatefulWidget {
  const _CustomCategoryDialog();

  @override
  State<_CustomCategoryDialog> createState() => _CustomCategoryDialogState();
}

class _CustomCategoryDialogState extends State<_CustomCategoryDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      title: const Text(
        'New category',
        style: TextStyle(color: _ivory, fontSize: 16),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: _ivory, fontSize: 13),
        onSubmitted: (value) => Navigator.pop(context, value),
        decoration: InputDecoration(
          hintText: 'e.g. Hospitality',
          hintStyle: const TextStyle(color: _muted, fontSize: 12),
          filled: true,
          fillColor: _background,
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _border),
            borderRadius: BorderRadius.circular(3),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _bronze),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: _muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('ADD', style: TextStyle(color: _bronze)),
        ),
      ],
    );
  }
}
