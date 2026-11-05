class NutritionPlanningConfig {
  final double maxDailyVariationFraction;
  final double maxDailyVariationCalories;
  final double maxActivityScore;
  final double referenceDurationMinutes;
  final int defaultActivityDurationMinutes;
  final double caloriesPerActivityScorePoint;
  final double gymWeight;
  final double runningWeight;
  final double walkingWeight;
  final double cyclingWeight;
  final double swimmingWeight;
  final double cardioWeight;
  final double otherWeight;

  const NutritionPlanningConfig({
    this.maxDailyVariationFraction = 0.10,
    this.maxDailyVariationCalories = 250.0,
    this.maxActivityScore = 2.0,
    this.referenceDurationMinutes = 60.0,
    this.defaultActivityDurationMinutes = 60,
    this.gymWeight = 1.0,
    this.runningWeight = 1.3,
    this.walkingWeight = 0.5,
    this.cyclingWeight = 1.0,
    this.swimmingWeight = 1.2,
    this.cardioWeight = 1.2,
    this.otherWeight = 1.0,
    this.caloriesPerActivityScorePoint = 150.0,
  });

  /// Erreur de programmation : une configuration invalide n'est pas une
  /// insuffisance nutritionnelle à signaler à l'utilisateur.
  void validate() {
    if (!maxDailyVariationFraction.isFinite ||
        maxDailyVariationFraction < 0 ||
        maxDailyVariationFraction > 1 ||
        !maxDailyVariationCalories.isFinite ||
        maxDailyVariationCalories < 0 ||
        !maxActivityScore.isFinite ||
        maxActivityScore <= 0 ||
        !referenceDurationMinutes.isFinite ||
        referenceDurationMinutes <= 0 ||
        defaultActivityDurationMinutes <= 0 ||
        !caloriesPerActivityScorePoint.isFinite ||
        caloriesPerActivityScorePoint < 0) {
      throw ArgumentError('Configuration du planning nutritionnel invalide.');
    }
    final weights = [
      gymWeight,
      runningWeight,
      walkingWeight,
      cyclingWeight,
      swimmingWeight,
      cardioWeight,
      otherWeight,
    ];
    if (weights.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError(
        'Les coefficients sportifs doivent être finis et positifs ou nuls.',
      );
    }
  }
}
