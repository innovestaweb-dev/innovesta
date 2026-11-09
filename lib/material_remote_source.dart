import 'package:flutter/foundation.dart';

import 'admin/models/admin_material.dart';
import 'admin/services/material_service.dart';
import 'mood_board/models/design_context.dart';
import 'mood_board/models/material_attributes.dart';
import 'mood_board/models/material_option.dart';
import 'mood_board/models/material_use.dart';

/// Loads the active materials from Supabase and converts them to the
/// [MaterialOption] model used by the Material Board.
///
/// Returns an empty list when nothing could be loaded (network error, RLS
/// blocking public reads, empty table). The caller keeps the built-in library
/// in that case.
class MaterialRemoteSource {
  MaterialRemoteSource._();

  static Future<List<MaterialOption>> loadActive() async {
    try {
      final rows = await MaterialService().getActiveMaterials();

      final result = <MaterialOption>[];

      for (final row in rows) {
        final option = _toOption(row);
        if (option != null) result.add(option);
      }

      return result;
    } catch (e) {
      debugPrint('Failed to load materials from Supabase: $e');
      return const [];
    }
  }

  static MaterialOption? _toOption(AdminMaterial m) {
    final name = m.nameEn.trim().isNotEmpty ? m.nameEn.trim() : m.name.trim();
    final hex = m.hex.trim();

    // A material needs a name and a valid color to be recommended.
    if (name.isEmpty || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return null;
    }

    final uses = <MaterialUse>[];
    for (final value in m.recommendedUses) {
      final use = _byName(MaterialUse.values, value);
      if (use != null && !uses.contains(use)) uses.add(use);
    }

    final styles = <DesignStyle>[];
    for (final value in m.styleCompatibility) {
      final style = _byName(DesignStyle.values, value);
      if (style != null && !styles.contains(style)) styles.add(style);
    }

    return MaterialOption(
      name: name,
      category: m.categoryEn.isNotEmpty ? m.categoryEn : m.category,
      materialType: m.materialTypeEn.isNotEmpty
          ? m.materialTypeEn
          : m.materialType,
      sampleImage: m.sampleImage,
      applicationImage: m.applicationImage,
      hex: hex.toUpperCase(),
      colorFamily: m.colorFamily,
      placement: m.placementEn.isNotEmpty ? m.placementEn : m.placement,
      finish: m.finishEn.isNotEmpty ? m.finishEn : m.finish,
      texture: m.textureEn.isNotEmpty ? m.textureEn : m.texture,
      sheen: m.sheenEn.isNotEmpty ? m.sheenEn : m.sheen,
      description: m.descriptionEn.isNotEmpty ? m.descriptionEn : m.description,
      recommendedUses: uses,
      styleCompatibility: styles,
      priceLevel:
          _byName(MaterialPriceLevel.values, m.priceLevel) ??
          MaterialPriceLevel.midRange,
      durability:
          _byName(MaterialDurability.values, m.durability) ??
          MaterialDurability.medium,
      maintenance:
          _byName(MaterialMaintenance.values, m.maintenance) ??
          MaterialMaintenance.medium,
    );
  }

  static T? _byName<T extends Enum>(List<T> values, String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
