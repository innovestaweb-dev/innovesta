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
      final projects = await _projectService.getProjects();

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

  Future<void> _openEditProjectPage(AdminProject project) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminProjectFormPage(project: project)),
    );

    if (result == true && mounted) {
      await _loadProjects();
    }
  }

  Future<void> _deleteProject(AdminProject project) async {
    if (project.id == null) return;

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
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE58C83)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _projectService.deleteProject(project.id!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted successfully.')),
      );

      await _loadProjects();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
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
                  ),
                ),

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
            ),
            const SizedBox(height: 25),

            Row(
              children: [
                _StatCard(
                  title: 'Total Projects',
                  value: _projects.length.toString(),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  title: 'Published',
                  value: _projects
                      .where((project) => project.isPublished)
                      .length
                      .toString(),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  title: 'Drafts',
                  value: _projects
                      .where((project) => !project.isPublished)
                      .length
                      .toString(),
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

  Widget _buildProjectsContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _bronze));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE58C83), size: 38),
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

    return RefreshIndicator(
      color: _bronze,
      backgroundColor: _surface,
      onRefresh: _loadProjects,
      child: ListView.separated(
        itemCount: _projects.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final project = _projects[index];
          return _ProjectCard(
            project: project,
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

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: _bronze, fontSize: 23)),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final AdminProject project;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ProjectCard({
    required this.project,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 105,
              height: 85,
              child:
                  project.coverImage != null && project.coverImage!.isNotEmpty
                  ? Image.network(
                      project.coverImage!,
                      fit: BoxFit.cover,
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
                  style: const TextStyle(
                    color: _ivory,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  [
                    if (project.category?.isNotEmpty == true) project.category!,
                    if (project.location?.isNotEmpty == true) project.location!,
                    if (project.area?.isNotEmpty == true) project.area!,
                  ].join(' • '),
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 9),
                Text(
                  project.isPublished ? 'PUBLISHED' : 'DRAFT',
                  style: TextStyle(
                    color: project.isPublished
                        ? const Color(0xFF83B89A)
                        : _bronze,
                    fontSize: 9,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete project',
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE58C83)),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Edit project',
            icon: const Icon(Icons.edit_outlined, color: _bronze),
          ),
        ],
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
