import 'package:flutter/material.dart';

import 'admin_project_form_page.dart';
import '../models/admin_project.dart';
import '../services/project_service.dart';

const Color _background = Color(0xFF171717);
const Color _surface = Color(0xFF222222);
const Color _ivory = Color(0xFFF4EFE6);
const Color _bronze = Color(0xFFB6A080);
const Color _muted = Color(0xFFAAA69F);
const Color _border = Color(0xFF393733);
const Color _danger = Color(0xFFE58C83);
const Color _success = Color(0xFF83B89A);

enum _ProjectFilter { all, published, drafts }

class AdminProjectsPage extends StatefulWidget {
  const AdminProjectsPage({super.key});

  @override
  State<AdminProjectsPage> createState() => _AdminProjectsPageState();
}

class _AdminProjectsPageState extends State<AdminProjectsPage> {
  final ProjectService _projectService = ProjectService();

  List<AdminProject> _projects = [];
  bool _isLoading = true;
  String? _error;

  _ProjectFilter _filter = _ProjectFilter.all;

  // Ids of projects currently being deleted (prevents double taps).
  final Set<Object> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    // Keep the list on screen while refreshing so pull-to-refresh keeps working.
    setState(() {
      _isLoading = _projects.isEmpty;
      _error = null;
    });

    try {
      final projects = await _projectService.getProjects();

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
        _error = hadProjects ? null : e.toString();
      });

      if (hadProjects) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
      }
    }
  }

  Future<void> _openEditProjectPage(AdminProject project) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminProjectFormPage(project: project)),
    );

    if (result == true && mounted) {
      await _loadProjects();
    }
  }

  Future<void> _openAddProjectPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminProjectFormPage()),
    );

    if (result == true && mounted) {
      await _loadProjects();
    }
  }

  Future<void> _deleteProject(AdminProject project) async {
    final id = project.id;

    if (id == null || _deletingIds.contains(id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Delete Project', style: TextStyle(color: _ivory)),
        content: Text(
          'Are you sure you want to delete "${project.title}"?',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(id));

    try {
      await _projectService.deleteProject(id);

      if (!mounted) return;

      // Remove locally instead of reloading the whole list.
      setState(() {
        _deletingIds.remove(id);
        _projects = _projects.where((p) => p.id != id).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _deletingIds.remove(id));

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  List<AdminProject> get _visibleProjects {
    switch (_filter) {
      case _ProjectFilter.published:
        return _projects.where((p) => p.isPublished).toList();
      case _ProjectFilter.drafts:
        return _projects.where((p) => !p.isPublished).toList();
      case _ProjectFilter.all:
        return _projects;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    final publishedCount = _projects.where((p) => p.isPublished).length;
    final draftCount = _projects.length - publishedCount;

    return Container(
      color: _background,
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 16 : 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 25),

            Row(
              children: [
                _StatCard(
                  title: 'Total Projects',
                  value: _projects.length.toString(),
                  selected: _filter == _ProjectFilter.all,
                  onTap: () => setState(() => _filter = _ProjectFilter.all),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  title: 'Published',
                  value: publishedCount.toString(),
                  selected: _filter == _ProjectFilter.published,
                  onTap: () =>
                      setState(() => _filter = _ProjectFilter.published),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  title: 'Drafts',
                  value: draftCount.toString(),
                  selected: _filter == _ProjectFilter.drafts,
                  onTap: () => setState(() => _filter = _ProjectFilter.drafts),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Expanded(child: _buildProjectsContent()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;

        const titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projects',
              style: TextStyle(
                color: _ivory,
                fontSize: 26,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Manage your architectural visualization projects.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _openAddProjectPage,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Project'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _bronze,
                foregroundColor: _background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _isLoading ? null : _loadProjects,
              icon: const Icon(Icons.refresh, color: _bronze),
              tooltip: 'Refresh projects',
            ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 16), actions],
          );
        }

        return Row(
          children: [
            const Expanded(child: titleBlock),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildProjectsContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _bronze));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _danger, size: 38),
            const SizedBox(height: 12),
            const Text(
              'Unable to load projects',
              style: TextStyle(color: _ivory, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _error!,
              style: const TextStyle(color: _muted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: _loadProjects,
              child: const Text('Try Again', style: TextStyle(color: _bronze)),
            ),
          ],
        ),
      );
    }

    if (_projects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_outlined, color: _bronze, size: 48),
            SizedBox(height: 15),
            Text(
              'No projects yet',
              style: TextStyle(color: _ivory, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Your projects will appear here.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final visible = _visibleProjects;

    if (visible.isEmpty) {
      return RefreshIndicator(
        color: _bronze,
        backgroundColor: _surface,
        onRefresh: _loadProjects,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 70),
            Center(
              child: Text(
                'No projects in this filter.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _bronze,
      backgroundColor: _surface,
      onRefresh: _loadProjects,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final project = visible[index];
          final busy =
              project.id != null && _deletingIds.contains(project.id as Object);

          return _ProjectCard(
            project: project,
            busy: busy,
            onDelete: () => _deleteProject(project),
            onEdit: () => _openEditProjectPage(project),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: _surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? _bronze : _border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(color: _bronze, fontSize: 23),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final AdminProject project;
  final bool busy;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ProjectCard({
    required this.project,
    required this.busy,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final coverImage = project.coverImage?.trim() ?? '';
    final hasVideo = (project.videoUrl?.trim() ?? '').isNotEmpty;

    // Projects created before the "Display Section" feature have no
    // `_section` value, so they count as normal (render) projects.
    final Map<String, dynamic> specs = project.specifications;
    final isInteractive = specs['_section']?.toString() == 'interactive';

    final details = [
      if (project.category?.trim().isNotEmpty == true) project.category!.trim(),
      if (project.location?.trim().isNotEmpty == true) project.location!.trim(),
      if (project.area?.trim().isNotEmpty == true) project.area!.trim(),
    ].join(' • ');

    return Material(
      color: _surface,
      child: InkWell(
        onTap: busy ? null : onEdit,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: _border)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 105,
                  height: 85,
                  child: coverImage.isNotEmpty
                      ? Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          // Decode at thumbnail size, not full 1920px.
                          cacheWidth: 320,
                          errorBuilder: (_, _, _) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ivory,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          project.isPublished ? 'PUBLISHED' : 'DRAFT',
                          style: TextStyle(
                            color: project.isPublished ? _success : _bronze,
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Which public page this project appears on.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isInteractive ? _bronze : _border,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            isInteractive ? 'INTERACTIVE' : 'RENDER',
                            style: TextStyle(
                              color: isInteractive ? _bronze : _muted,
                              fontSize: 9,
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (hasVideo)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_outlined,
                                color: _muted,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'VIDEO',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 9,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _danger,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete project',
                  icon: const Icon(Icons.delete_outline, color: _danger),
                ),
              IconButton(
                onPressed: busy ? null : onEdit,
                tooltip: 'Edit project',
                icon: const Icon(Icons.edit_outlined, color: _bronze),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFF302E2B),
      child: const Icon(Icons.image_outlined, color: _muted, size: 30),
    );
  }
}
