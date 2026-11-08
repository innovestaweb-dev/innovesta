import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_material.dart';

class MaterialService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'materials';

  // تحميل جميع الخامات
  Future<List<AdminMaterial>> getMaterials() async {
    final response = await _supabase
        .from(_table)
        .select()
        .order('display_order', ascending: true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => AdminMaterial.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // إضافة خامة جديدة
  Future<void> addMaterial(AdminMaterial material) async {
    await _supabase.from(_table).insert(material.toMap());
  }

  // تعديل خامة
  Future<void> updateMaterial(AdminMaterial material) async {
    await _supabase.from(_table).update(material.toMap()).eq('id', material.id);
  }

  // حذف خامة
  Future<void> deleteMaterial(String id) async {
    await _supabase.from(_table).delete().eq('id', id);
  }

  // تحميل الخامات النشطة فقط للـ Material Board
  Future<List<AdminMaterial>> getActiveMaterials() async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => AdminMaterial.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
