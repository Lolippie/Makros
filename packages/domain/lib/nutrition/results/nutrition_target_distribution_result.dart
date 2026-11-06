import '../config/nutrition_target_distribution_config.dart';

enum NutritionDistributionIssue {
  insufficientCaloriesForMacros,
  unrealisticFatEnergyShare,
  noCarbCyclingContrast,
  carbCyclingAmplitudeLimited,
}

class DailyNutritionTarget {
  const DailyNutritionTarget({
    required this.date,
    required this.hasActivity,
    required this.exerciseCaloriesKcal,
    required this.caloriesKcal,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbohydrateGrams,
  });

  final DateTime date;
  final bool hasActivity;
  final double exerciseCaloriesKcal;
  final double caloriesKcal;
  final double proteinGrams;
  final double fatGrams;
  final double carbohydrateGrams;
}

class NutritionTargetDistributionResult {
  NutritionTargetDistributionResult({
    required List<DailyNutritionTarget> days,
    required List<NutritionDistributionIssue> issues,
    required this.appliedRecommendation,
    required this.mode,
    required this.weeklyEnergyBudgetKcal,
  }) : days = List.unmodifiable(days),
       issues = List.unmodifiable(issues);

  final List<DailyNutritionTarget> days;
  final List<NutritionDistributionIssue> issues;
  final MacroRecommendation appliedRecommendation;
  final NutritionRecommendationMode mode;
  final double weeklyEnergyBudgetKcal;

  bool get isFeasible => !issues.contains(
    NutritionDistributionIssue.insufficientCaloriesForMacros,
  );

  double get weeklyCaloriesKcal =>
      days.fold(0.0, (sum, day) => sum + day.caloriesKcal);
  double get weeklyProteinGrams =>
      days.fold(0.0, (sum, day) => sum + day.proteinGrams);
  double get weeklyFatGrams => days.fold(0.0, (sum, day) => sum + day.fatGrams);
  double get weeklyCarbohydrateGrams =>
      days.fold(0.0, (sum, day) => sum + day.carbohydrateGrams);
}
