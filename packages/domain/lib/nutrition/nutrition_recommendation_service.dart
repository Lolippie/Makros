import 'config/nutrition_target_distribution_config.dart';

/// Paramètres par défaut informés par les plages de la littérature sportive.
/// Ils ne remplacent pas un suivi nutritionnel individualisé.
class NutritionRecommendationService {
  const NutritionRecommendationService({
    this.config = const NutritionTargetDistributionConfig(),
  });

  final NutritionTargetDistributionConfig config;

  MacroRecommendation recommend(NutritionGoalType goal) {
    config.validate();
    return switch (goal) {
      NutritionGoalType.cut => config.cut,
      NutritionGoalType.maintenance => config.maintenance,
      NutritionGoalType.bulk => config.bulk,
    };
  }

  MacroRecommendation resolve({
    required NutritionGoalType goal,
    required MacroDistributionPreferences preferences,
  }) {
    preferences.validate();
    final recommended = recommend(goal);
    if (preferences.mode == NutritionRecommendationMode.recommended) {
      return recommended;
    }
    return MacroRecommendation(
      proteinGramsPerKg: preferences.proteinGramsPerKg!,
      fatGramsPerKg: preferences.fatGramsPerKg!,
      referenceVersion: 'custom',
    );
  }
}
