import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'admin/models/admin_project.dart';
import 'admin/services/project_service.dart';

// Safely handles nullable text fields from AdminProject.
String _safeText(String? value) => value?.trim() ?? '';

class InteractivePage extends StatefulWidget {
  const InteractivePage({super.key});

  @override
  State<InteractivePage> createState() => _InteractivePageState();
}

class _InteractivePageState extends State<InteractivePage> {
  static const Color background = Color(0xFF171717);
  static const Color surface = Color(0xFF20201E);
  static const Color ivory = Color(0xFFF4EFE6);
  static const Color bronze = Color(0xFFB6A080);
  static const Color muted = Color(0xFFAAA69F);

  late Future<List<AdminProject>> _projectsFuture;

  List<AdminProject> _projects = [];
  AdminProject? _selectedProject;

  final GlobalKey _projectsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
  }

  Future<List<AdminProject>> _loadProjects() async {
    final allProjects = await ProjectService().getPublishedProjects();

    final videoProjects = allProjects.where((project) {
      return _safeText(project.videoUrl).isNotEmpty;
    }).toList();

    if (mounted) {
      setState(() {
        _projects = videoProjects;

        _selectedProject = videoProjects.isNotEmpty
            ? videoProjects.first
            : null;
      });
    }

    return videoProjects;
  }

  void _refreshProjects() {
    setState(() {
      _projects = [];
      _selectedProject = null;
      _projectsFuture = _loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: ivory,
        elevation: 0,
        title: const Text(
          'INNOVISTA',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'BACK HOME',
              style: TextStyle(color: bronze, fontSize: 11, letterSpacing: 1),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _hero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 80,
            vertical: isMobile ? 65 : 95,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('INTERACTIVE ARCHITECTURE / 01'),
              const SizedBox(height: 26),
              Text(
                'Don’t Just See It.\nExperience It.',
                style: TextStyle(
                  color: ivory,
                  fontSize: isMobile ? 43 : 76,
                  height: 1.12,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: const Text(
                  'Step beyond traditional architectural renders. '
                  'Explore spaces, experience lighting, and discover '
                  'design possibilities through real-time interactive '
                  'experiences and cinematic architectural walkthroughs.',
                  style: TextStyle(color: muted, fontSize: 15, height: 1.9),
                ),
              ),
              const SizedBox(height: 34),
              OutlinedButton(
                onPressed: () {
                  final target = _projectsKey.currentContext;

                  if (target != null) {
                    Scrollable.ensureVisible(
                      target,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: ivory,
                  side: const BorderSide(color: bronze),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 19,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text(
                  'EXPLORE PROJECTS',
                  style: TextStyle(letterSpacing: 1),
                ),
              ),
            ],
          ),
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
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 75),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: FutureBuilder<List<AdminProject>>(
            future: _projectsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loadingState();
              }

              if (snapshot.hasError) {
                return _errorState();
              }

              if (_projects.isEmpty) {
                return _emptyState();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('SELECTED EXPERIENCES'),
                  const SizedBox(height: 18),
                  const Text(
                    'Explore Our Projects.',
                    style: TextStyle(
                      color: ivory,
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Discover architectural spaces through interactive '
                    'walkthroughs and cinematic presentations.',
                    style: TextStyle(color: muted, fontSize: 14, height: 1.8),
                  ),
                  const SizedBox(height: 42),

                  // Main video player
                  if (_selectedProject != null) ...[
                    _MainVideoPlayer(
                      key: ValueKey(_selectedProject!.id),
                      project: _selectedProject!,
                    ),
                    const SizedBox(height: 22),
                    _selectedProjectInformation(_selectedProject!),
                  ],

                  const SizedBox(height: 48),
                  const Divider(color: Color(0xFF41403D)),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MORE EXPERIENCES',
                        style: TextStyle(
                          color: bronze,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        '${_projects.length} PROJECT${_projects.length == 1 ? '' : 'S'}',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _projectGrid(),
                ],
              );
            },
          ),
        ),
      ),
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
                color: ivory,
                fontSize: 25,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            if (projectDetails.isNotEmpty)
              Text(
                projectDetails,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
          ],
        );

        final descriptionWidget = Text(
          description.isNotEmpty
              ? description
              : 'Explore this architectural project through its '
                    'visual presentation.',
          textAlign: isMobile ? TextAlign.left : TextAlign.right,
          style: const TextStyle(color: muted, fontSize: 13, height: 1.8),
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
            final isSelected = _selectedProject?.id == project.id;

            return SizedBox(
              width: itemWidth,
              child: _ProjectVideoCard(
                project: project,
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedProject = project;
                  });
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _loadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 90),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: bronze),
            SizedBox(height: 22),
            Text(
              'Loading interactive projects...',
              style: TextStyle(color: muted),
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
            const Icon(Icons.error_outline, color: bronze, size: 42),
            const SizedBox(height: 18),
            const Text(
              'Unable to load projects.',
              style: TextStyle(color: ivory, fontSize: 20),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please try again in a moment.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: _refreshProjects,
              style: OutlinedButton.styleFrom(
                foregroundColor: bronze,
                side: const BorderSide(color: bronze),
              ),
              child: const Text('TRY AGAIN'),
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
            const Icon(Icons.video_library_outlined, color: bronze, size: 52),
            const SizedBox(height: 22),
            const Text(
              'New Experiences Are Coming.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ivory,
                fontSize: 27,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Our interactive and cinematic projects will appear here '
              'once they are published.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 14, height: 1.8),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: _refreshProjects,
              style: OutlinedButton.styleFrom(
                foregroundColor: bronze,
                side: const BorderSide(color: bronze),
              ),
              child: const Text('REFRESH'),
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
              _label('BEYOND TRADITIONAL VISUALIZATION'),
              const SizedBox(height: 20),
              const Text(
                'Architecture becomes an experience.',
                style: TextStyle(
                  color: ivory,
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Give clients a clearer understanding of their future '
                'spaces through real-time exploration and carefully '
                'crafted visual presentations.',
                style: TextStyle(color: muted, fontSize: 14, height: 1.9),
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
                        title: 'Free Exploration',
                        description:
                            'Navigate through rooms and understand '
                            'the layout before construction.',
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.light_mode_outlined,
                        title: 'Lighting Control',
                        description:
                            'Compare lighting conditions and discover '
                            'how light transforms each space.',
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.palette_outlined,
                        title: 'Material Customization',
                        description:
                            'Explore different finishes, colors, and '
                            'material combinations.',
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.layers_outlined,
                        title: 'Multi-Floor Navigation',
                        description:
                            'Move between different levels of a building '
                            'within supported interactive projects.',
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.movie_outlined,
                        title: 'Cinematic Walkthroughs',
                        description:
                            'Present architectural spaces through '
                            'carefully composed cinematic sequences.',
                      ),
                      _feature(
                        width: itemWidth,
                        icon: Icons.view_in_ar_outlined,
                        title: 'Virtual Reality',
                        description:
                            'Take architectural exploration further '
                            'with immersive VR experiences.',
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
          Icon(icon, color: bronze, size: 29),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: ivory, fontSize: 19)),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(
                    color: muted,
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
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 75),
      child: Column(
        children: [
          const Text(
            'Ready to Experience Your Project?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ivory,
              fontSize: 32,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Let’s bring your architectural vision to life.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 14, height: 1.8),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: ivory,
              side: const BorderSide(color: bronze),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 21),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text(
              'EXPLORE INNOVISTA',
              style: TextStyle(letterSpacing: 1),
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
      color: background,
      child: const Text(
        'INNOVISTA     —     Design it. See it. Experience it.',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(color: bronze, fontSize: 10, letterSpacing: 2),
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
  static const Color ivory = Color(0xFFF4EFE6);
  static const Color bronze = Color(0xFFB6A080);
  static const Color muted = Color(0xFFAAA69F);

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

      setState(() {
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = 'This video could not be loaded.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    final hours = duration.inHours;

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }

    return '$minutes:$seconds';
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: bronze),
            SizedBox(height: 16),
            Text(
              'Preparing experience...',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null || _controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: bronze, size: 42),
            const SizedBox(height: 15),
            Text(
              _error ?? 'Video unavailable.',
              style: const TextStyle(color: muted),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller!,
      builder: (context, value, child) {
        if (value.hasError) {
          return const Center(
            child: Text(
              'Unable to play this video.',
              style: TextStyle(color: muted),
            ),
          );
        }

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                },
                child: VideoPlayer(_controller!),
              ),
            ),

            // Dark control background
            Container(
              height: 65,
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

            // Controls
            Positioned(
              left: 14,
              right: 14,
              bottom: 10,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    },
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: ivory,
                      size: 27,
                    ),
                  ),
                  Text(
                    _formatDuration(value.position),
                    style: const TextStyle(color: ivory, fontSize: 10),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      colors: const VideoProgressColors(
                        playedColor: bronze,
                        bufferedColor: Color(0xFF77736D),
                        backgroundColor: Color(0xFF45433F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDuration(value.duration),
                    style: const TextStyle(color: ivory, fontSize: 10),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    onPressed: () {
                      final volume = value.volume > 0 ? 0.0 : 1.0;
                      _controller!.setVolume(volume);
                    },
                    icon: Icon(
                      value.volume > 0
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: ivory,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),

            if (!value.isPlaying && value.position == Duration.zero)
              Center(
                child: GestureDetector(
                  onTap: () => _controller!.play(),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: bronze.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 42,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

  static const Color ivory = Color(0xFFF4EFE6);
  static const Color bronze = Color(0xFFB6A080);
  static const Color muted = Color(0xFFAAA69F);

  @override
  Widget build(BuildContext context) {
    final imageUrl = _safeText(project.coverImage);

    final projectDetails = [
      _safeText(project.category),
      _safeText(project.location),
    ].where((item) => item.isNotEmpty).join('  •  ');

    return Material(
      color: const Color(0xFF171717),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? bronze : const Color(0xFF373633),
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

                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        color: Colors.black.withValues(alpha: 0.75),
                        child: const Text(
                          'VIDEO PROJECT',
                          style: TextStyle(
                            color: ivory,
                            fontSize: 9,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    if (selected)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: bronze,
                          child: const Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              letterSpacing: 1,
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
                      style: const TextStyle(color: ivory, fontSize: 17),
                    ),
                    const SizedBox(height: 9),
                    if (projectDetails.isNotEmpty)
                      Text(
                        projectDetails,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: bronze,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          selected ? 'Currently selected' : 'Watch project',
                          style: const TextStyle(
                            color: bronze,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward,
                          color: bronze,
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
        child: Icon(Icons.architecture_outlined, color: bronze, size: 42),
      ),
    );
  }
}
