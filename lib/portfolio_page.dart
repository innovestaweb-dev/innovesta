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
    setState(() {
      _isLoading = true;
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

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _text(String english, String arabic) {
    return AppLanguage.text(english, arabic);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLanguage.isArabic;

    return Scaffold(
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
              _text('BACK HOME', 'العودة للرئيسية'),
              style: const TextStyle(
                color: portfolioBronze,
                fontSize: 11,
                letterSpacing: 1,
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
                      _text('01 / SELECTED WORK', '01 / أعمال مختارة'),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Text(
                          _text(
                            'Spaces Worth Experiencing.',
                            'مساحات تستحق التجربة.',
                          ),
                          textAlign: isArabic
                              ? TextAlign.right
                              : TextAlign.left,
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
                      _text(
                        'A selection of architectural concepts, interior '
                            'spaces, and immersive environments.',
                        'مجموعة مختارة من المشاريع المعمارية والتصميمات '
                            'الداخلية والتجارب التفاعلية.',
                      ),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
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
                      _text(
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
                      _text(
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
                      child: Text(_text('BACK TO HOME', 'العودة للرئيسية')),
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
            final index = entry.key;
            final project = entry.value;

            return _ProjectCard(
              width: cardWidth,
              project: project,
              number: (index + 1).toString().padLeft(2, '0'),
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
            _text('Unable to load projects', 'تعذر تحميل المشاريع'),
            style: const TextStyle(color: portfolioIvory, fontSize: 17),
          ),
          const SizedBox(height: 10),
          Text(
            _text(
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
            label: Text(_text('TRY AGAIN', 'إعادة المحاولة')),
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
            _text('Projects Coming Soon', 'المشاريع قريباً'),
            style: const TextStyle(
              color: portfolioIvory,
              fontSize: 21,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _text(
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
      style: const TextStyle(
        color: portfolioBronze,
        fontSize: 10,
        letterSpacing: 2.2,
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
                  if (project.coverImage != null &&
                      project.coverImage!.trim().isNotEmpty)
                    Image.network(
                      project.coverImage!,
                      fit: BoxFit.cover,
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
                      errorBuilder: (_, _, _) => _imagePlaceholder(),
                    )
                  else
                    _imagePlaceholder(),
                  Positioned(
                    top: 16,
                    left: 16,
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
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      color: portfolioBackground.withValues(alpha: 0.85),
                      child: Text(
                        AppLanguage.text('VIEW PROJECT', 'عرض المشروع'),
                        style: const TextStyle(
                          color: portfolioIvory,
                          fontSize: 9,
                          letterSpacing: 1.2,
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
                style: const TextStyle(
                  color: portfolioBronze,
                  fontSize: 9,
                  letterSpacing: 1.8,
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

  String _text(String english, String arabic) {
    return AppLanguage.text(english, arabic);
  }

  String _value(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.join(', ');
    if (value is Map) return value.toString();
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

  Future<void> _openVideo(BuildContext context) async {
    final rawUrl = project.videoUrl?.trim() ?? '';

    if (rawUrl.isEmpty) return;

    final uri = Uri.tryParse(rawUrl);

    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_text('Invalid video URL.', 'رابط الفيديو غير صالح.')),
        ),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text('Unable to open the video.', 'تعذر فتح الفيديو.'),
            ),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text('Unable to open the video.', 'تعذر فتح الفيديو.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLanguage.isArabic;

    final gallery = project.gallery
        .where((url) => url.trim().isNotEmpty)
        .toList();

    final specifications = _visibleSpecifications();

    final category = project.category?.trim() ?? '';
    final location = project.location?.trim() ?? '';
    final area = project.area?.trim() ?? '';
    final description = project.description?.trim() ?? '';
    final coverImage = project.coverImage?.trim() ?? '';
    final videoUrl = project.videoUrl?.trim() ?? '';

    return Scaffold(
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
              _text('BACK TO PORTFOLIO', 'العودة للأعمال'),
              style: const TextStyle(
                color: portfolioBronze,
                fontSize: 10,
                letterSpacing: 1,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('PROJECT DETAILS', 'تفاصيل المشروع'),
                    style: const TextStyle(
                      color: portfolioBronze,
                      fontSize: 10,
                      letterSpacing: 2.2,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    project.title,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
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
                      style: const TextStyle(
                        color: portfolioBronze,
                        fontSize: 10,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  if (coverImage.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _detailImagePlaceholder(),
                        ),
                      ),
                    )
                  else
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _detailImagePlaceholder(),
                    ),

                  const SizedBox(height: 38),

                  if (location.isNotEmpty || area.isNotEmpty)
                    _buildProjectOverview(location: location, area: area),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 38),
                    _sectionHeading(_text('ABOUT THE PROJECT', 'عن المشروع')),
                    const SizedBox(height: 18),
                    Text(
                      description,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
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
                      _text('PROJECT INFORMATION', 'معلومات المشروع'),
                    ),
                    const SizedBox(height: 20),
                    _buildSpecifications(specifications),
                  ],

                  if (gallery.isNotEmpty) ...[
                    const SizedBox(height: 50),
                    _sectionHeading(
                      _text('PROJECT GALLERY', 'معرض صور المشروع'),
                    ),
                    const SizedBox(height: 22),
                    _buildGallery(gallery),
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
                            _text('PROJECT VIDEO', 'فيديو المشروع'),
                            style: const TextStyle(
                              color: portfolioBronze,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _text(
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
                            label: Text(_text('WATCH VIDEO', 'مشاهدة الفيديو')),
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
                    _text(
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
                    onPressed: () {
                      Navigator.pop(context);
                    },
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
                    child: Text(_text('BACK TO PORTFOLIO', 'العودة للأعمال')),
                  ),
                ],
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
      if (location.isNotEmpty) MapEntry(_text('LOCATION', 'الموقع'), location),
      if (area.isNotEmpty) MapEntry(_text('AREA', 'المساحة'), area),
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
                style: const TextStyle(
                  color: portfolioBronze,
                  fontSize: 9,
                  letterSpacing: 1.5,
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
                      style: const TextStyle(
                        color: portfolioBronze,
                        fontSize: 10,
                        letterSpacing: 1.2,
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

  Widget _buildGallery(List<String> gallery) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 600 ? 1 : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 18) / columns;

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: gallery.map((url) {
            return SizedBox(
              width: itemWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: AspectRatio(
                  aspectRatio: 1.28,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _detailImagePlaceholder(),
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
      style: const TextStyle(
        color: portfolioBronze,
        fontSize: 10,
        letterSpacing: 2,
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
