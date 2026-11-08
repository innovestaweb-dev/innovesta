import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_project.dart';

class ProjectService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'projects';

  // Get all projects
  Future<List<AdminProject>> getProjects() async {
    final response = await _supabase
        .from(_table)
        .select()
        .order('display_order', ascending: true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => AdminProject.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Add a new project
  Future<void> addProject(AdminProject project) async {
    await _supabase.from(_table).insert(project.toMap());
  }

  // Update an existing project
  Future<void> updateProject(AdminProject project) async {
    if (project.id == null) {
      throw Exception('Project ID is missing.');
    }

    await _supabase
        .from(_table)
        .update({
          ...project.toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', project.id!);
  }

  // Delete a project
  Future<void> deleteProject(String id) async {
    await _supabase.from(_table).delete().eq('id', id);
  }

  // Get published projects for the public website
  Future<List<AdminProject>> getPublishedProjects() async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('is_published', true)
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => AdminProject.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
