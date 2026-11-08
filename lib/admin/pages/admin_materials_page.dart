import 'package:flutter/material.dart';

import 'admin_material_form_page.dart';
import '../models/admin_material.dart';
import '../services/material_service.dart';

class AdminMaterialsPage extends StatefulWidget {
  const AdminMaterialsPage({super.key});

  @override
  State<AdminMaterialsPage> createState() => _AdminMaterialsPageState();
}

class _AdminMaterialsPageState extends State<AdminMaterialsPage> {
  final MaterialService _service = MaterialService();

  List<AdminMaterial> _materials = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final materials = await _service.getMaterials();

      if (!mounted) return;

      setState(() {
        _materials = materials;
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

  Future<void> _openMaterialForm({AdminMaterial? material}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminMaterialFormPage(material: material),
      ),
    );

    if (result == true && mounted) {
      await _loadMaterials();
    }
  }

  Future<void> _deleteMaterial(AdminMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text(
          'Delete Material',
          style: TextStyle(color: Color(0xFFF4EFE6)),
        ),
        content: Text(
          'Are you sure you want to delete "${material.name}"?',
          style: const TextStyle(color: Color(0xFFAAA69F)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFB65C5C)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteMaterial(material.id);

      if (!mounted) return;

      setState(() {
        _materials.removeWhere((item) => item.id == material.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF171717),
      padding: const EdgeInsets.all(28),
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
                      'Material Library',
                      style: TextStyle(
                        color: Color(0xFFF4EFE6),
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Manage your architectural materials collection.',
                      style: TextStyle(color: Color(0xFFAAA69F), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openMaterialForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Material'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB6A080),
                      foregroundColor: const Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _loadMaterials,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh, color: Color(0xFFB6A080)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFB6A080)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB65C5C), size: 36),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFAAA69F)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMaterials,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_materials.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, color: Color(0xFFB6A080), size: 48),
            SizedBox(height: 14),
            Text(
              'No materials yet',
              style: TextStyle(color: Color(0xFFF4EFE6), fontSize: 18),
            ),
            SizedBox(height: 6),
            Text(
              'Add your first material to build the library.',
              style: TextStyle(color: Color(0xFFAAA69F)),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 650
            ? 2
            : 1;

        return GridView.builder(
          itemCount: _materials.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            mainAxisExtent: 230,
          ),
          itemBuilder: (context, index) {
            final material = _materials[index];
            return _buildMaterialCard(material);
          },
        );
      },
    );
  }

  Widget _buildMaterialCard(AdminMaterial material) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF39352F)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (material.sampleImage.isNotEmpty)
                  Image.network(
                    material.sampleImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildColorPreview(material),
                  )
                else
                  _buildColorPreview(material),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: material.isActive
                          ? const Color(0xFF315B45)
                          : const Color(0xFF654343),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      material.isActive ? 'Active' : 'Inactive',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF4EFE6),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${material.category} • ${material.materialType}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFAAA69F),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openMaterialForm(material: material),
                  tooltip: 'Edit',
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFFB6A080),
                    size: 19,
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteMaterial(material),
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFB65C5C),
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPreview(AdminMaterial material) {
    final hex = material.hex.replaceAll('#', '');

    Color color = const Color(0xFF39352F);

    if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      color = Color(int.parse('FF$hex', radix: 16));
    }

    return Container(color: color);
  }
}
