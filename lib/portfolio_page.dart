import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin/models/admin_project.dart';
import 'admin/services/project_service.dart';
import 'app_language.dart';

const Color portfolioBackground = Color(0xFF171717);
const Color portfolioSurface = Color(0xFF222222);
const Color portfolioIvory = Color(0xFFF4EFE6);
const Color portfolioBronze = Color(0xFFB6A080);
const Color portfolioMuted = Color(0xFFAAA69F);
const Color portfolioBorder = Color(0xFF393733);

String _t(String english, String arabic) => AppLanguage.text(english, arabic);

// Letter spacing breaks Arabic letter joining, so it is disabled for Arabic.
double _ls(double value) => AppLanguage.isArabic ? 0 : value;

TextDirection get _direction =>
    AppLanguage.isArabic ? TextDirection.rtl : TextDirection.ltr;

// Network image with a loading spinner and an icon fallback.
Widget _portfolioImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  IconData placeholderIcon = Icons.architecture,
}) {
  Widget placeholder() => Container(
    color: portfolioSurface,
    child: Center(
      child: Icon(placeholderIcon, color: portfolioBronze, size: 42),
    ),
  );

  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;

      return Container(
        color: portfolioSurface,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: portfolioBronze,
          strokeWidth: 2,
        ),
      );
    },
    errorBuilder: (_, _, _) => placeholder(),
  );
}

// -----------------------------------------------------------------------------
// Portfolio Page
// -----------------------------------------------------------------------------

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  final ProjectService _projectService = ProjectService();

  List<AdminProject> _projects = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    // Keep the existing list on screen while refreshing.
    setState(() {
      _isLoading = _projects.isEmpty;
      _error = null;
    });

    try {
      final projects = await _projectService.getPublishedProjects();

      if (!mounted) return;

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final hadProjects = _projects.isNotEmpty;

      setState(() {
        _isLoading = false;
        // With cached projects, keep showing them and just notify the user.
        _error = hadProjects ? null : e.toString();
      });

      if (hadProjects) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('Unable to refresh projects.', 'تعذر تحديث المشاريع.'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _direction,
      child: Scaffold(
        backgroundColor: portfolioBackground,
        appBar: AppBar(
          backgroundColor: portfolioBackground,
          foregroundColor: portfolioIvory,
          elevation: 0,
          title: const Text(
            'INNOVISTA',
            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _t('BACK HOME', 'العودة للرئيسية'),
                style: TextStyle(
                  color: portfolioBronze,
                  fontSize: 11,
                  letterSpacing: _ls(1),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: RefreshIndicator(
          color: portfolioBronze,
          backgroundColor: portfolioSurface,
          onRefresh: _loadProjects,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(
                        _t('01 / SELECTED WORK', '01 / أعمال مختارة'),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Text(
                            _t(
                              'Spaces Worth Experiencing.',
                              'مساحات تستحق التجربة.',
                            ),
                            style: TextStyle(
                              color: portfolioIvory,
                              fontSize: constraints.maxWidth < 600 ? 32 : 46,
                              fontWeight: FontWeight.w300,
                              height: 1.3,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _t(
                          'A selection of architectural concepts, interior '
                              'spaces, and immersive environments.',
                          'مجموعة مختارة من المشاريع المعمارية والتصميمات '
                              'الداخلية والتجارب التفاعلية.',
                        ),
                        style: const TextStyle(
                          color: portfolioMuted,
                          fontSize: 13,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 42),
                      _buildProjectsContent(),
                      const SizedBox(height: 60),
                      const Divider(color: portfolioBorder),
                      const SizedBox(height: 24),
                      Text(
                        _t(
                          'Have a project in mind?',
                          'هل لديك مشروع ترغب في تنفيذه؟',
                        ),
                        style: const TextStyle(
                          color: portfolioIvory,
                          fontSize: 25,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t(
                          'Contact us to discuss your next project.',
                          'تواصل معنا لمناقشة مشروعك القادم.',
                        ),
                        style: const TextStyle(
                          color: portfolioMuted,
                          fontSize: 13,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: portfolioBronze,
                          side: const BorderSide(color: portfolioBronze),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: Text(_t('BACK TO HOME', 'العودة للرئيسية')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: portfolioBronze)),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_projects.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final int columns = width < 600 ? 1 : 2;

        final cardWidth = (width - (columns - 1) * 28) / columns;

        return Wrap(
          spacing: 28,
          runSpacing: 42,
          children: _projects.asMap().entries.map((entry) {
            return _ProjectCard(
              width: cardWidth,
              project: entry.value,
              number: (entry.key + 1).toString().padLeft(2, '0'),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 55),
      decoration: BoxDecoration(
        color: portfolioSurface,
        border: Border.all(color: portfolioBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: portfolioBronze,
            size: 42,
          ),
          const SizedBox(height: 18),
          Text(
            _t('Unable to load projects', 'تعذر تحميل المشاريع'),
            style: const TextStyle(color: portfolioIvory, fontSize: 17),
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              'Please check your connection and try again.',
              'يرجى التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: portfolioMuted,
              fontSize: 12,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _loadProjects,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(_t('TRY AGAIN', 'إعادة المحاولة')),
            style: OutlinedButton.styleFrom(
              foregroundColor: portfolioBronze,
              side: const BorderSide(color: portfolioBronze),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 65),
      decoration: BoxDecoration(
        color: portfolioSurface,
        border: Border.all(color: portfolioBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.architecture_outlined,
            color: portfolioBronze,
            size: 48,
          ),
          const SizedBox(height: 20),
          Text(
            _t('Projects Coming Soon', 'المشاريع قريباً'),
            style: const TextStyle(
              color: portfolioIvory,
              fontSize: 21,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'Our selected architectural visualization projects '
                  'will be showcased here.',
              'سيتم عرض مجموعة مشاريعنا المختارة في التصور المعماري هنا.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: portfolioMuted,
              fontSize: 12,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: portfolioBronze,
        fontSize: 10,
        letterSpacing: _ls(2.2),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Project Card
// -----------------------------------------------------------------------------

class _ProjectCard extends StatelessWidget {
  final double width;
  final AdminProject project;
  final String number;

  const _ProjectCard({
    required this.width,
    required this.project,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final category = project.category?.trim() ?? '';
    final location = project.location?.trim() ?? '';
    final area = project.area?.trim() ?? '';
    final coverImage = project.coverImage?.trim() ?? '';

    final details = [
      if (location.isNotEmpty) location,
      if (area.isNotEmpty) area,
    ].join(' • ');

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectDetailsPage(project: project),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.28,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverImage.isNotEmpty)
                    _portfolioImage(coverImage)
                  else
                    _imagePlaceholder(),
                  PositionedDirectional(
                    top: 16,
                    start: 16,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: portfolioBackground.withValues(alpha: 0.85),
                      child: Text(
                        number,
                        style: const TextStyle(
                          color: portfolioBronze,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      color: portfolioBackground.withValues(alpha: 0.85),
                      child: Text(
                        _t('VIEW PROJECT', 'عرض المشروع'),
                        style: TextStyle(
                          color: portfolioIvory,
                          fontSize: 9,
                          letterSpacing: _ls(1.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (category.isNotEmpty) ...[
              Text(
                category.toUpperCase(),
                style: TextStyle(
                  color: portfolioBronze,
                  fontSize: 9,
                  letterSpacing: _ls(1.8),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              project.title,
              style: const TextStyle(
                color: portfolioIvory,
                fontSize: 22,
                fontWeight: FontWeight.w300,
                height: 1.4,
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                details,
                style: const TextStyle(
                  color: portfolioMuted,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: portfolioSurface,
      child: const Center(
        child: Icon(Icons.architecture, color: portfolioBronze, size: 42),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Project Details Page
// -----------------------------------------------------------------------------

class ProjectDetailsPage extends StatelessWidget {
  final AdminProject project;

  const ProjectDetailsPage({super.key, required this.project});

  String _value(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.join(', ');
    return value.toString();
  }

  List<MapEntry<String, String>> _visibleSpecifications() {
    return project.specifications.entries
        .where((entry) {
          final key = entry.key.trim();
          final value = _value(entry.value).trim();

          return key.isNotEmpty && !key.startsWith('_') && value.isNotEmpty;
        })
        .map((entry) => MapEntry(entry.key, _value(entry.value).trim()))
        .toList();
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openVideo(BuildContext context) async {
    final rawUrl = project.videoUrl?.trim() ?? '';

    if (rawUrl.isEmpty) return;

    final uri = Uri.tryParse(rawUrl);

    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showMessage(context, _t('Invalid video URL.', 'رابط الفيديو غير صالح.'));
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        _showMessage(
          context,
          _t('Unable to open the video.', 'تعذر فتح الفيديو.'),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        _t('Unable to open the video.', 'تعذر فتح الفيديو.'),
      );
    }
  }

  void _openGallery(BuildContext context, List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _GalleryViewer(images: images, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallery = project.gallery
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();

    final specifications = _visibleSpecifications();

    final category = project.category?.trim() ?? '';
    final location = project.location?.trim() ?? '';
    final area = project.area?.trim() ?? '';
    final description = project.description?.trim() ?? '';
    final coverImage = project.coverImage?.trim() ?? '';
    final videoUrl = project.videoUrl?.trim() ?? '';

    return Directionality(
      textDirection: _direction,
      child: Scaffold(
        backgroundColor: portfolioBackground,
        appBar: AppBar(
          backgroundColor: portfolioBackground,
          foregroundColor: portfolioIvory,
          elevation: 0,
          title: const Text(
            'INNOVISTA',
            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _t('BACK TO PORTFOLIO', 'العودة للأعمال'),
                style: TextStyle(
                  color: portfolioBronze,
                  fontSize: 10,
                  letterSpacing: _ls(1),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1250),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 45,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('PROJECT DETAILS', 'تفاصيل المشروع'),
                      style: TextStyle(
                        color: portfolioBronze,
                        fontSize: 10,
                        letterSpacing: _ls(2.2),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      project.title,
                      style: const TextStyle(
                        color: portfolioIvory,
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        height: 1.3,
                      ),
                    ),

                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: portfolioBronze,
                          fontSize: 10,
                          letterSpacing: _ls(1.8),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: coverImage.isNotEmpty
                            ? _portfolioImage(
                                coverImage,
                                placeholderIcon: Icons.image_outlined,
                              )
                            : _detailImagePlaceholder(),
                      ),
                    ),

                    const SizedBox(height: 38),

                    if (location.isNotEmpty || area.isNotEmpty)
                      _buildProjectOverview(location: location, area: area),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 38),
                      _sectionHeading(_t('ABOUT THE PROJECT', 'عن المشروع')),
                      const SizedBox(height: 18),
                      Text(
                        description,
                        style: const TextStyle(
                          color: portfolioMuted,
                          fontSize: 14,
                          height: 2,
                        ),
                      ),
                    ],

                    if (specifications.isNotEmpty) ...[
                      const SizedBox(height: 45),
                      _sectionHeading(
                        _t('PROJECT INFORMATION', 'معلومات المشروع'),
                      ),
                      const SizedBox(height: 20),
                      _buildSpecifications(specifications),
                    ],

                    if (gallery.isNotEmpty) ...[
                      const SizedBox(height: 50),
                      _sectionHeading(
                        _t('PROJECT GALLERY', 'معرض صور المشروع'),
                      ),
                      const SizedBox(height: 22),
                      _buildGallery(context, gallery),
                    ],

                    if (videoUrl.isNotEmpty) ...[
                      const SizedBox(height: 45),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: portfolioSurface,
                          border: Border.all(color: portfolioBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('PROJECT VIDEO', 'فيديو المشروع'),
                              style: TextStyle(
                                color: portfolioBronze,
                                fontSize: 10,
                                letterSpacing: _ls(2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _t(
                                'Explore the project in motion.',
                                'شاهد المشروع من خلال الفيديو.',
                              ),
                              style: const TextStyle(
                                color: portfolioMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: () => _openVideo(context),
                              icon: const Icon(
                                Icons.play_circle_outline,
                                size: 19,
                              ),
                              label: Text(_t('WATCH VIDEO', 'مشاهدة الفيديو')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: portfolioBronze,
                                side: const BorderSide(color: portfolioBronze),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 55),

                    const Divider(color: portfolioBorder),

                    const SizedBox(height: 25),

                    Text(
                      _t(
                        'Have a project in mind?',
                        'هل لديك مشروع ترغب في تنفيذه؟',
                      ),
                      style: const TextStyle(
                        color: portfolioIvory,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 18),

                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: portfolioBronze,
                        side: const BorderSide(color: portfolioBronze),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: Text(_t('BACK TO PORTFOLIO', 'العودة للأعمال')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectOverview({
    required String location,
    required String area,
  }) {
    final items = <MapEntry<String, String>>[
      if (location.isNotEmpty) MapEntry(_t('LOCATION', 'الموقع'), location),
      if (area.isNotEmpty) MapEntry(_t('AREA', 'المساحة'), area),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: items.map((item) {
        return Container(
          constraints: const BoxConstraints(minWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          decoration: BoxDecoration(
            color: portfolioSurface,
            border: Border.all(color: portfolioBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.key,
                style: TextStyle(
                  color: portfolioBronze,
                  fontSize: 9,
                  letterSpacing: _ls(1.5),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                item.value,
                style: const TextStyle(color: portfolioIvory, fontSize: 13),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecifications(List<MapEntry<String, String>> specifications) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 600 ? 1 : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 14) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: specifications.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: portfolioSurface,
                  border: Border.all(color: portfolioBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.key,
                      style: TextStyle(
                        color: portfolioBronze,
                        fontSize: 10,
                        letterSpacing: _ls(1.2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.value,
                      style: const TextStyle(
                        color: portfolioIvory,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGallery(BuildContext context, List<String> gallery) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 600 ? 1 : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 18) / columns;

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: gallery.asMap().entries.map((entry) {
            return SizedBox(
              width: itemWidth,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _openGallery(context, gallery, entry.key),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: AspectRatio(
                      aspectRatio: 1.28,
                      child: _portfolioImage(
                        entry.value,
                        placeholderIcon: Icons.image_outlined,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _sectionHeading(String title) {
    return Text(
      title,
      style: TextStyle(
        color: portfolioBronze,
        fontSize: 10,
        letterSpacing: _ls(2),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _detailImagePlaceholder() {
    return Container(
      color: portfolioSurface,
      child: const Center(
        child: Icon(Icons.image_outlined, color: portfolioBronze, size: 42),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Fullscreen gallery viewer (swipe + pinch to zoom)
// -----------------------------------------------------------------------------

class _GalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _GalleryViewer({required this.images, required this.initialIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.images.length) return;

    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Directionality(
      textDirection: _direction,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: portfolioIvory,
          elevation: 0,
          title: Text(
            '${_index + 1} / $total',
            style: const TextStyle(fontSize: 14, color: portfolioMuted),
          ),
          actions: [
            if (total > 1) ...[
              IconButton(
                onPressed: _index > 0 ? () => _go(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: _index < total - 1 ? () => _go(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: total,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, i) {
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;

                    return const Center(
                      child: CircularProgressIndicator(
                        color: portfolioBronze,
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: portfolioMuted,
                    size: 48,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
