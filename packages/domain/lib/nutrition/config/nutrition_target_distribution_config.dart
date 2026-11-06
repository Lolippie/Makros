/// Les valeurs « recommended » sont des valeurs de départ pour des adultes
/// pratiquant la musculation, pas des prescriptions médicales individuelles.
enum NutritionRecommendationMode { recommended, custom }

enum NutritionGoalType { cut, maintenance, bulk }

class MacroDistributionPreferences {
  const MacroDistributionPreferences({
    this.mode = NutritionRecommendationMode.recommended,
    this.proteinGramsPerKg,
    this.fatGramsPerKg,
    this.carbCyclingAmplitudePercentage = 20,
  });

  final NutritionRecommendationMode mode;
  final double? proteinGramsPerKg;
  final double? fatGramsPerKg;

  /// 20 signifie 20 %, et non 0,20.
  final double carbCyclingAmplitudePercentage;

  void validate() {
    if (!carbCyclingAmplitudePercentage.isFinite ||
        carbCyclingAmplitudePercentage < 0 ||
        carbCyclingAmplitudePercentage > 100) {
      throw ArgumentError.value(
        carbCyclingAmplitudePercentage,
        'carbCyclingAmplitudePercentage',
        'Doit être entre 0 et 100.',
      );
    }
    if (mode == NutritionRecommendationMode.custom &&
        (proteinGramsPerKg == null || fatGramsPerKg == null)) {
      throw ArgumentError('Les valeurs personnalisées doivent être fournies.');
    }
    for (final value in [proteinGramsPerKg, fatGramsPerKg]) {
      if (value != null && (!value.isFinite || value <= 0)) {
        throw ArgumentError(
          'Les quantités en g/kg doivent être finies et positives.',
        );
      }
    }
  }
}

class MacroRecommendation {
  const MacroRecommendation({
    required this.proteinGramsPerKg,
    required this.fatGramsPerKg,
    required this.referenceVersion,
  });

  final double proteinGramsPerKg;
  final double fatGramsPerKg;
  final String referenceVersion;
}

class NutritionTargetDistributionConfig {
  const NutritionTargetDistributionConfig({
    this.cut = const MacroRecommendation(
      proteinGramsPerKg: 2.0,
      fatGramsPerKg: 0.8,
      referenceVersion: 'makros-strength-v1',
    ),
    this.maintenance = const MacroRecommendation(
      proteinGramsPerKg: 1.8,
      fatGramsPerKg: 0.9,
      referenceVersion: 'makros-strength-v1',
    ),
    this.bulk = const MacroRecommendation(
      proteinGramsPerKg: 1.8,
      fatGramsPerKg: 1.0,
      referenceVersion: 'makros-strength-v1',
    ),
  });

  final MacroRecommendation cut;
  final MacroRecommendation maintenance;
  final MacroRecommendation bulk;

  void validate() {
    for (final recommendation in [cut, maintenance, bulk]) {
      if (!recommendation.proteinGramsPerKg.isFinite ||
          recommendation.proteinGramsPerKg <= 0 ||
          !recommendation.fatGramsPerKg.isFinite ||
          recommendation.fatGramsPerKg <= 0 ||
          recommendation.referenceVersion.trim().isEmpty) {
        throw ArgumentError('Recommandation nutritionnelle invalide.');
      }
    }
  }
}
