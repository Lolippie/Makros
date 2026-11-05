class NutritionPlanningConfig {
  /// Variation maximale par rapport aux calories de référence.
  final double maxDailyVariationFraction;

  /// Variation maximale absolue en kcal.
  final double maxDailyVariationCalories;

  /// Score maximal attribuable à une journée.
  final double maxActivityScore;

  /// Durée de référence d'une activité en minutes.
  final double referenceDurationMinutes;

  /// Durée utilisée lorsqu'une activité est prévue
  /// mais que sa durée n'est pas renseignée.
  final int defaultActivityDurationMinutes;

final double caloriesPerActivityScorePoint;
  /// Coefficients par type de sport.
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
    this.caloriesPerActivityScorePoint = 150.0
      });
}