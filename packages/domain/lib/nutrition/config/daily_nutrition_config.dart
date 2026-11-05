/// Paramètres des comparaisons nutritionnelles.
///
/// [validate] lève ArgumentError en cas de configuration de programmation
/// invalide, même lorsque les assertions Dart sont désactivées.
class DailyNutritionConfig {
  final double caloriesToleranceFraction;
  final double carbohydratesToleranceFraction;
  final double fatToleranceFraction;
  final double minimumCarbohydratesToleranceGrams;
  final double minimumFatToleranceGrams;
  final double comparisonEpsilon;

  const DailyNutritionConfig({
    this.caloriesToleranceFraction = 0.05,
    this.carbohydratesToleranceFraction = 0.10,
    this.fatToleranceFraction = 0.10,
    this.minimumCarbohydratesToleranceGrams = 0,
    this.minimumFatToleranceGrams = 0,
    this.comparisonEpsilon = 0.000001,
  });

  void validate() {
    final fractions = [
      caloriesToleranceFraction,
      carbohydratesToleranceFraction,
      fatToleranceFraction,
    ];
    final absolute = [
      minimumCarbohydratesToleranceGrams,
      minimumFatToleranceGrams,
    ];
    if (fractions.any((v) => !v.isFinite || v < 0 || v > 1) ||
        absolute.any((v) => !v.isFinite || v < 0) ||
        !comparisonEpsilon.isFinite ||
        comparisonEpsilon < 0) {
      throw ArgumentError('La configuration nutritionnelle est invalide.');
    }
  }
}
