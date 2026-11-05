class NutritionCalculationResult {
  const NutritionCalculationResult({
    required this.restingEnergyExpenditureKcal,
    required this.dailyBaselineCaloriesKcal,
    required this.weeklyExerciseCaloriesKcal,
    required this.averageDailyExerciseCaloriesKcal,
    required this.maintenanceCaloriesKcal,
    required this.targetCaloriesKcal,
    required this.adjustmentPercentage,
  });

  /// Dépense énergétique de repos estimée.
  final double restingEnergyExpenditureKcal;

  /// Dépense quotidienne estimée hors sport planifié.
  final double dailyBaselineCaloriesKcal;

  /// Dépense sportive estimée sur la semaine.
  final double weeklyExerciseCaloriesKcal;

  /// Moyenne quotidienne de la dépense sportive.
  final double averageDailyExerciseCaloriesKcal;

  /// Maintien calorique moyen sur la semaine.
  final double maintenanceCaloriesKcal;

  /// Objectif calorique moyen après application du cut/bulk.
  final double targetCaloriesKcal;

  /// Ajustement appliqué : négatif pour un cut, positif pour un bulk.
  final double adjustmentPercentage;
}
