import 'package:makros_models/models.dart';

class NutritionCalculationConfig {
  const NutritionCalculationConfig({
    required this.nonExerciseActivityFactors,
    required this.sportMetValues,
    this.defaultCutDeficitPercentage = 15,
    this.defaultBulkSurplusPercentage = 10,
  });

  /// Coefficients estimant les dépenses quotidiennes habituelles
  /// HORS séances de sport planifiées.
  ///
  /// Ce sont des valeurs initiales heuristiques, à calibrer avec
  /// les données réelles des utilisateurs.
  final Map<ActivityLevel, double> nonExerciseActivityFactors;

  /// Valeurs MET estimées selon le sport et son intensité.
  final Map<SportType, Map<ActivityIntensity, double>> sportMetValues;

  /// Pourcentage de déficit par défaut.
  final double defaultCutDeficitPercentage;

  /// Pourcentage de surplus par défaut.
  final double defaultBulkSurplusPercentage;
}

const defaultNutritionCalculationConfig = NutritionCalculationConfig(
  nonExerciseActivityFactors: {
    ActivityLevel.sedentary: 1.20,
    ActivityLevel.lightlyActive: 1.30,
    ActivityLevel.moderatelyActive: 1.40,
    ActivityLevel.veryActive: 1.50,
    ActivityLevel.extraActive: 1.60,
  },
  sportMetValues: {
    SportType.gym: {
      ActivityIntensity.low: 3.5,
      ActivityIntensity.moderate: 5.0,
      ActivityIntensity.high: 6.0,
    },
    SportType.running: {
      ActivityIntensity.low: 6.0,
      ActivityIntensity.moderate: 8.0,
      ActivityIntensity.high: 11.0,
    },
    SportType.walking: {
      ActivityIntensity.low: 2.5,
      ActivityIntensity.moderate: 3.5,
      ActivityIntensity.high: 5.0,
    },
    SportType.cycling: {
      ActivityIntensity.low: 3.5,
      ActivityIntensity.moderate: 6.8,
      ActivityIntensity.high: 10.0,
    },
    SportType.swimming: {
      ActivityIntensity.low: 4.0,
      ActivityIntensity.moderate: 6.0,
      ActivityIntensity.high: 9.0,
    },
    SportType.cardio: {
      ActivityIntensity.low: 3.5,
      ActivityIntensity.moderate: 6.0,
      ActivityIntensity.high: 9.0,
    },
    SportType.other: {
      ActivityIntensity.low: 3.0,
      ActivityIntensity.moderate: 5.0,
      ActivityIntensity.high: 7.0,
    },
  },
);
