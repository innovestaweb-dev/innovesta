import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'admin/models/admin_project.dart';
import 'admin/services/project_service.dart';
import 'app_language.dart';

const Color _bg = Color(0xFF171717);
const Color _surface = Color(0xFF20201E);
const Color _ivory = Color(0xFFF4EFE6);
const Color _bronze = Color(0xFFB6A080);
const Color _muted = Color(0xFFAAA69F);

// -----------------------------------------------------------------------------
// Hero background video (5 seconds, muted, looping).
//
// 1) Compress it:  ffmpeg -i in.mp4 -vf "scale=-2:720" -c:v libx264 -crf 27 \
//                  -preset slow -movflags +faststart -an hero.mp4
// 2) Upload hero.mp4 (and an optional hero.webp poster) to your Supabase bucket.
// 3) Paste the public URLs below. Leave _heroVideoUrl empty to disable it.
// -----------------------------------------------------------------------------
const String _heroVideoUrl = '';
const String _heroPosterUrl = '';

// Safely handles nullable text fields from AdminProject.
String _safeText(String? value) => value?.trim() ?? '';

String _t(String english, String arabic) => AppLanguage.text(english, arabic);

// Letter spacing breaks Arabic letter joining, so it is disabled for Arabic.
double _ls(double value) => AppLanguage.isArabic ? 0 : value;

class InteractivePage extends StatefulWidget {
  const InteractivePage({super.key});

  @override
  State<InteractivePage> createState() => _InteractivePageState();
}

class _InteractivePageState extends State<InteractivePage> {
  final ProjectService _projectService = ProjectService();

  List<AdminProject> _projects = [];
  AdminProject? _selectedProject;

  bool _isLoading = true;
  bool _hasError = false;

  // Guards against out-of-order responses when refresh is tapped repeatedly.
  int _loadId = 0;

  final GlobalKey _projectsKey = GlobalKey();
  final GlobalKey _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    final requestId = ++_loadId;

    try {
      final allProjects = await _projectService.getPublishedProjects();

      if (!mounted || requestId != _loadId) return;

      final videoProjects = allProjects
          .where((project) => _safeText(project.videoUrl).isNotEmpty)
          .toList();

      // Keep the previously selected project when it still exists.
      final previousId = _selectedProject?.id;
      AdminProject? selected;

      if (videoProjects.isNotEmpty) {
        selected = videoProjects.firstWhere(
          (project) => previousId != null && project.id == previousId,
          orElse: () => videoProjects.first,
        );
      }

      setState(() {
        _projects = videoProjects;
        _selectedProject = selected;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || requestId != _loadId) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _refreshProjects() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _fetchProjects();
  }

  void _selectProject(AdminProject project) {
    final alreadySelected =
        project.id != null && project.id == _selectedProject?.id;

    if (!alreadySelected) {
      setState(() => _selectedProject = project);
    }

    // On long pages the player is far above the grid, so bring it into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _playerKey.currentContext;
      if (target == null || !mounted) return;

      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    });
  }

  void _scrollToProjects() {
    final target = _projectsKey.currentContext;
    if (target == null) return;

    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLanguage.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: _ivory,
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
                  color: _bronze,
                  fontSize: 11,
                  letterSpacing: _ls(1),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(),
              _projectsSection(),
              _experienceDetails(),
              _callToAction(context),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _hero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Stack(
          children: [
            // Background video. It only fills the space; the Container below
            // decides the hero height.
            const Positioned.fill(child: _HeroVideoBackground()),

            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 80,
                vertical: isMobile ? 65 : 95,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(
                    _t('INTERACTIVE ARCHITECTURE / 01', 'عمارة تفاعلية / 01'),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    _t(
                      'Don’t Just See It.\nExperience It.',
                      'لا تكتفِ بالمشاهدة.\nعِش التجربة.',
                    ),
                    style: TextStyle(
                      color: _ivory,
                      fontSize: isMobile ? 43 : 76,
                      height: 1.12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Text(
                      _t(
                        'Step beyond traditional architectural renders. '
                            'Explore spaces, experience lighting, and discover '
                            'design possibilities through real-time interactive '
                            'experiences and cinematic architectural walkthroughs.',
                        'تجاوز الصور المعمارية التقليدية. استكشف المساحات، '
                            'وجرّب الإضاءة، واكتشف إمكانيات التصميم من خلال '
                            'تجارب تفاعلية لحظية وجولات معمارية سينمائية.',
                      ),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 15,
                        height: 1.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  OutlinedButton(
                    onPressed: _scrollToProjects,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ivory,
                      side: const BorderSide(color: _bronze),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 19,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Text(
                      _t('EXPLORE PROJECTS', 'استكشف المشاريع'),
                      style: TextStyle(letterSpacing: _ls(1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Projects and video player
  // ---------------------------------------------------------------------------

  Widget _projectsSection() {
    return Container(
      key: _projectsKey,
      width: double.infinity,
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 75),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _projectsContent(),
        ),
      ),
    );
  }

  Widget _projectsContent() {
    if (_isLoading) return _loadingState();
    if (_hasError) return _errorState();
    if (_projects.isEmpty) return _emptyState();

    final selected = _selectedProject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_t('SELECTED EXPERIENCES', 'تجارب مختارة')),
        const SizedBox(height: 18),
        Text(
          _t('Explore Our Projects.', 'استكشف مشاريعنا.'),
          style: const TextStyle(
            color: _ivory,
            fontSize: 36,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _t(
            'Discover architectural spaces through interactive '
                'walkthroughs and cinematic presentations.',
            'اكتشف المساحات المعمارية من خلال جولات تفاعلية '
                'وعروض سينمائية.',
          ),
          style: const TextStyle(color: _muted, fontSize: 14, height: 1.8),
        ),
        const SizedBox(height: 42),

        if (selected != null)
          Column(
            key: _playerKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MainVideoPlayer(
                key: ValueKey(selected.id ?? selected.title),
                project: selected,
              ),
              const SizedBox(height: 22),
              _selectedProjectInformation(selected),
            ],
          ),

        const SizedBox(height: 48),
        const Divider(color: Color(0xFF41403D)),
        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t('MORE EXPERIENCES', 'المزيد من التجارب'),
              style: TextStyle(
                color: _bronze,
                fontSize: 11,
                letterSpacing: _ls(2),
              ),
            ),
            Text(
              _t(
                '${_projects.length} PROJECT${_projects.length == 1 ? '' : 'S'}',
                '${_projects.length} مشروع',
              ),
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                letterSpacing: _ls(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _projectGrid(),
      ],
    );
  }

  Widget _selectedProjectInformation(AdminProject project) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        final projectDetails = [
          _safeText(project.category),
          _safeText(project.location),
          _safeText(project.area),
        ].where((item) => item.isNotEmpty).join('  •  ');

        final description = _safeText(project.description);

        final information = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.title,
              style: const TextStyle(
                color: _ivory,
                fontSize: 25,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            if (projectDetails.isNotEmpty)
              Text(
                projectDetails,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
          ],
        );

        final descriptionWidget = Text(
          description.isNotEmpty
              ? description
              : _t(
                  'Explore this architectural project through its '
                      'visual presentation.',
                  'استكشف هذا المشروع المعماري من خلال عرضه المرئي.',
                ),
          textAlign: isMobile ? TextAlign.start : TextAlign.end,
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.8),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              information,
              const SizedBox(height: 18),
              descriptionWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: information),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: descriptionWidget),
          ],
        );
      },
    );
  }

  Widget _projectGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 3 : (width >= 580 ? 2 : 1);
        const spacing = 20.0;

        final itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 24,
          children: _projects.map((project) {
            final isSelected =
                project.id != null && _selectedProject?.id == project.id;

            return SizedBox(
              width: itemWidth,
              child: _ProjectVideoCard(
                project: project,
                selected: isSelected,
                onTap: () => _selectProject(project),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _loadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 90),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: _bronze),
            const SizedBox(height: 22),
            Text(
              _t('Loading interactive projects...', 'جاري تحميل المشاريع...'),
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 75),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: _bronze, size: 42),
            const SizedBox(height: 18),
            Text(
              _t('Unable to load projects.', 'تعذر تحميل المشاريع.'),
              style: const TextStyle(color: _ivory, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              _t(
                'Please try again in a moment.',
                'يرجى المحاولة مرة أخرى بعد قليل.',
              ),
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: _refreshProjects,
              style: OutlinedButton.styleFrom(
                foregroundColor: _bronze,
                side: const BorderSide(color: _bronze),
              ),
              child: Text(_t('TRY AGAIN', 'إعادة المحاولة')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 75),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.video_library_outlined, color: _bronze, size: 52),
            const SizedBox(height: 22),
            Text(
              _t('New Experiences Are Coming.', 'تجارب جديدة قريباً.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ivory,
                fontSize: 27,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _t(
                'Our interactive and cinematic projects will appear here '
                    'once they are published.',
                'ستظهر مشاريعنا التفاعلية والسينمائية هنا بمجرد نشرها.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.8),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: _refreshProjects,
              style: OutlinedButton.styleFrom(
                foregroundColor: _bronze,
                side: const BorderSide(color: _bronze),
              ),
              child: Text(_t('REFRESH', 'تحديث')),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Experience details
  // ---------------------------------------------------------------------------

  Widget _experienceDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(
                _t(
                  'BEYOND TRADITIONAL VISUALIZATION',
                  'ما بعد التصور التقليدي',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _t(
                  'Architecture becomes an experience.',
                  'العمارة تتحول إلى تجربة.',
                ),
                style: const TextStyle(
                  color: _ivory,
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t(
                  'Give clients a clearer understanding of their future '
                      'spaces through real-time exploration and carefully '
                      'crafted visual presentations.',
                  'امنح عملاءك فهماً أوضح لمساحاتهم المستقبلية من خلال '
                      'الاستكشاف اللحظي وعروض بصرية مصنوعة بعناية.',
                ),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 42),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 650 ? 1 : 2;

                  final itemWidth =
                      (constraints.maxWidth - (columns - 1) * 30) / columns;

                  return Wrap(
                    spacing: 30,
                    runSpacing: 38,
                    children: [
                      _feature(
                        width: itemWidth,
                        icon: Icons.explore_outlined,
                        title: _t('Free Exploration', 'استكشاف حر'),
                        description: _t(
                          'Navigate through rooms and understand '
                              'the layout before construction.',
                          'تنقّل بين الغرف وافهم التوزيع قبل البناء.',
                        ),
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.light_mode_outlined,
                        title: _t('Lighting Control', 'التحكم في الإضاءة'),
                        description: _t(
                          'Compare lighting conditions and discover '
                              'how light transforms each space.',
                          'قارن ظروف الإضاءة واكتشف كيف يغيّر الضوء '
                              'كل مساحة.',
                        ),
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.palette_outlined,
                        title: _t('Material Customization', 'تخصيص الخامات'),
                        description: _t(
                          'Explore different finishes, colors, and '
                              'material combinations.',
                          'استكشف تشطيبات وألوان وتوليفات خامات مختلفة.',
                        ),
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.layers_outlined,
                        title: _t(
                          'Multi-Floor Navigation',
                          'التنقل بين الأدوار',
                        ),
                        description: _t(
                          'Move between different levels of a building '
                              'within supported interactive projects.',
                          'انتقل بين أدوار المبنى المختلفة داخل المشاريع '
                              'التفاعلية المدعومة.',
                        ),
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.movie_outlined,
                        title: _t('Cinematic Walkthroughs', 'جولات سينمائية'),
                        description: _t(
                          'Present architectural spaces through '
                              'carefully composed cinematic sequences.',
                          'اعرض المساحات المعمارية من خلال مشاهد '
                              'سينمائية مُعدّة بعناية.',
                        ),
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.view_in_ar_outlined,
                        title: _t('Virtual Reality', 'الواقع الافتراضي'),
                        description: _t(
                          'Take architectural exploration further '
                              'with immersive VR experiences.',
                          'خُذ الاستكشاف المعماري لمستوى أبعد بتجارب '
                              'واقع افتراضي غامرة.',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feature({
    required double width,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _bronze, size: 29),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: _ivory, fontSize: 19),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Call to action and footer
  // ---------------------------------------------------------------------------

  Widget _callToAction(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 75),
      child: Column(
        children: [
          Text(
            _t('Ready to Experience Your Project?', 'مستعد لتعيش مشروعك؟'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ivory,
              fontSize: 32,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _t(
              'Let’s bring your architectural vision to life.',
              'لنحوّل رؤيتك المعمارية إلى واقع.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.8),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ivory,
              side: const BorderSide(color: _bronze),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 21),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: Text(
              _t('EXPLORE INNOVISTA', 'استكشف INNOVISTA'),
              style: TextStyle(letterSpacing: _ls(1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      color: _bg,
      child: Text(
        _t(
          'INNOVISTA     —     Design it. See it. Experience it.',
          'INNOVISTA     —     صمّمه. شاهده. عِشه.',
        ),
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 11, letterSpacing: _ls(1)),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(color: _bronze, fontSize: 10, letterSpacing: _ls(2)),
    );
  }
}

// =============================================================================
// Hero background video (muted, looping, behind the hero text)
// =============================================================================

class _HeroVideoBackground extends StatefulWidget {
  const _HeroVideoBackground();

  @override
  State<_HeroVideoBackground> createState() => _HeroVideoBackgroundState();
}

class _HeroVideoBackgroundState extends State<_HeroVideoBackground> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_heroVideoUrl.isEmpty) return;

    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(_heroVideoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      await controller.initialize();

      // Browsers only allow autoplay when the video is muted.
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();

      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // If the video fails, the poster / plain background stays visible.
      _controller = null;
      controller?.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _bg),

          // Light poster shows immediately while the video is loading.
          if (_heroPosterUrl.isNotEmpty)
            Image.network(
              _heroPosterUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),

          if (controller != null && _ready)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),

          // Dark overlay so the hero text stays readable.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.55), _bg],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Main inline video player
// =============================================================================

class _MainVideoPlayer extends StatefulWidget {
  final AdminProject project;

  const _MainVideoPlayer({super.key, required this.project});

  @override
  State<_MainVideoPlayer> createState() => _MainVideoPlayerState();
}

class _MainVideoPlayerState extends State<_MainVideoPlayer> {
  VideoPlayerController? _controller;

  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    VideoPlayerController? controller;

    try {
      final url = _safeText(widget.project.videoUrl);

      if (url.isEmpty) {
        throw Exception('No video URL is available.');
      }

      final uri = Uri.tryParse(url);

      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw Exception('Invalid video URL.');
      }

      controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();

      if (!mounted) return;

      await controller.setLooping(false);
      await controller.setVolume(1);

      if (!mounted) return;

      setState(() => _initializing = false);
    } catch (_) {
      if (!mounted) return;

      // Release the failed controller so a retry starts clean.
      _controller = null;
      controller?.dispose();

      setState(() {
        _initializing = false;
        _error = _t(
          'This video could not be loaded.',
          'تعذر تحميل هذا الفيديو.',
        );
      });
    }
  }

  void _retry() {
    setState(() {
      _initializing = true;
      _error = null;
    });
    _initializeVideo();
  }

  void _openFullscreen() {
    final controller = _controller;
    if (controller == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(controller: controller),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF111110),
      child: AspectRatio(aspectRatio: 16 / 9, child: _buildPlayerContent()),
    );
  }

  Widget _buildPlayerContent() {
    if (_initializing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _bronze),
            const SizedBox(height: 16),
            Text(
              _t('Preparing experience...', 'جاري تجهيز التجربة...'),
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final controller = _controller;

    if (_error != null || controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: _bronze, size: 42),
            const SizedBox(height: 15),
            Text(
              _error ?? _t('Video unavailable.', 'الفيديو غير متاح.'),
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _retry,
              child: Text(
                _t('TRY AGAIN', 'إعادة المحاولة'),
                style: const TextStyle(color: _bronze),
              ),
            ),
          ],
        ),
      );
    }

    return _VideoSurface(
      controller: controller,
      isFullscreen: false,
      onToggleFullscreen: _openFullscreen,
    );
  }
}

// =============================================================================
// Video surface (video + controls), shared by inline and fullscreen players
// =============================================================================

class _VideoSurface extends StatelessWidget {
  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const _VideoSurface({
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  bool _isEnded(VideoPlayerValue value) {
    return value.duration > Duration.zero && value.position >= value.duration;
  }

  Future<void> _togglePlay(VideoPlayerValue value) async {
    if (value.isPlaying) {
      await controller.pause();
      return;
    }

    if (_isEnded(value)) {
      await controller.seekTo(Duration.zero);
    }

    await controller.play();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;

    if (hours > 0) return '$hours:$minutes:$seconds';

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Player controls stay left-to-right in every language.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          if (value.hasError) {
            return Center(
              child: Text(
                _t('Unable to play this video.', 'تعذر تشغيل هذا الفيديو.'),
                style: const TextStyle(color: _muted),
              ),
            );
          }

          final ended = _isEnded(value);
          final showBigButton =
              !value.isPlaying && (value.position == Duration.zero || ended);
          final aspect = value.isInitialized && value.aspectRatio > 0
              ? value.aspectRatio
              : 16 / 9;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Video, letterboxed so it is never stretched.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _togglePlay(value),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),

              // Dark gradient behind controls (does not block taps).
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 65,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Buffering indicator.
              if (value.isBuffering && value.isPlaying)
                const Center(
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      color: _bronze,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),

              // Controls.
              Positioned(
                left: 14,
                right: 14,
                bottom: 10,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _togglePlay(value),
                      tooltip: value.isPlaying
                          ? _t('Pause', 'إيقاف مؤقت')
                          : _t('Play', 'تشغيل'),
                      icon: Icon(
                        ended
                            ? Icons.replay_rounded
                            : (value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                        color: _ivory,
                        size: 27,
                      ),
                    ),
                    Text(
                      _formatDuration(value.position),
                      style: const TextStyle(color: _ivory, fontSize: 10),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        colors: const VideoProgressColors(
                          playedColor: _bronze,
                          bufferedColor: Color(0xFF77736D),
                          backgroundColor: Color(0xFF45433F),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatDuration(value.duration),
                      style: const TextStyle(color: _ivory, fontSize: 10),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      onPressed: () {
                        controller.setVolume(value.volume > 0 ? 0.0 : 1.0);
                      },
                      tooltip: _t('Mute', 'كتم الصوت'),
                      icon: Icon(
                        value.volume > 0
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: _ivory,
                        size: 21,
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleFullscreen,
                      tooltip: isFullscreen
                          ? _t('Exit fullscreen', 'إنهاء ملء الشاشة')
                          : _t('Fullscreen', 'ملء الشاشة'),
                      icon: Icon(
                        isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: _ivory,
                        size: 23,
                      ),
                    ),
                  ],
                ),
              ),

              if (showBigButton)
                Center(
                  child: GestureDetector(
                    onTap: () => _togglePlay(value),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _bronze.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ended ? Icons.replay_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 42,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// Fullscreen player page (re-uses the same controller)
// =============================================================================

class _FullscreenVideoPage extends StatelessWidget {
  final VideoPlayerController controller;

  const _FullscreenVideoPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _VideoSurface(
                controller: controller,
                isFullscreen: true,
                onToggleFullscreen: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: _ivory),
                tooltip: _t('Close', 'إغلاق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Project selection card
// =============================================================================

class _ProjectVideoCard extends StatelessWidget {
  final AdminProject project;
  final bool selected;
  final VoidCallback onTap;

  const _ProjectVideoCard({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _safeText(project.coverImage);

    final projectDetails = [
      _safeText(project.category),
      _safeText(project.location),
    ].where((item) => item.isNotEmpty).join('  •  ');

    return Material(
      color: _bg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? _bronze : const Color(0xFF373633),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        // Decode at card size instead of the full 1920px image.
                        cacheWidth: 800,
                        errorBuilder: (_, _, _) => _imageFallback(),
                      )
                    else
                      _imageFallback(),

                    Container(color: Colors.black.withValues(alpha: 0.22)),

                    const Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),

                    PositionedDirectional(
                      start: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        color: Colors.black.withValues(alpha: 0.75),
                        child: Text(
                          _t('VIDEO PROJECT', 'مشروع فيديو'),
                          style: TextStyle(
                            color: _ivory,
                            fontSize: 9,
                            letterSpacing: _ls(1),
                          ),
                        ),
                      ),
                    ),

                    if (selected)
                      PositionedDirectional(
                        end: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: _bronze,
                          child: Text(
                            _t('NOW PLAYING', 'يعمل الآن'),
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              letterSpacing: _ls(1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ivory, fontSize: 17),
                    ),
                    const SizedBox(height: 9),
                    if (projectDetails.isNotEmpty)
                      Text(
                        projectDetails,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: _bronze,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          selected
                              ? _t('Currently selected', 'قيد التشغيل')
                              : _t('Watch project', 'شاهد المشروع'),
                          style: TextStyle(
                            color: _bronze,
                            fontSize: 11,
                            letterSpacing: _ls(0.5),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward,
                          color: _bronze,
                          size: 16,
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
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xFF292824),
      child: const Center(
        child: Icon(Icons.architecture_outlined, color: _bronze, size: 42),
      ),
    );
  }
}
