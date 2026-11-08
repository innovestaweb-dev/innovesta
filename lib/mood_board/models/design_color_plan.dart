import 'color_allocation.dart';

class DesignColorPlan {
  final List<ColorAllocation> allocations;

  const DesignColorPlan({required this.allocations});

  double get totalPercentage {
    return allocations.fold(
      0.0,
      (total, allocation) => total + allocation.designPercentage,
    );
  }

  bool get isValid {
    return allocations.isNotEmpty && (totalPercentage - 100.0).abs() < 0.01;
  }
}
