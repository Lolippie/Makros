/// Estimations énergétiques moyennes pour un planning de sept jours.
/// Les résultats ne sont pas des mesures individuelles de dépense énergétique.
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

  final double restingEnergyExpenditureKcal;
  final double dailyBaselineCaloriesKcal;
  final double weeklyExerciseCaloriesKcal;
  final double averageDailyExerciseCaloriesKcal;
  final double maintenanceCaloriesKcal;
  final double targetCaloriesKcal;

  /// Signé : négatif en cut, positif en bulk, nul en maintenance.
  final double adjustmentPercentage;
}
