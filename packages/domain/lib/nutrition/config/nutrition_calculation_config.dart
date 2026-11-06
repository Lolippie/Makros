import 'package:makros_models/models.dart';

class NutritionCalculationConfig {
  const NutritionCalculationConfig({
    required this.nonExerciseActivityFactors,
    required this.sportMetValues,
    this.defaultCutDeficitPercentage = 15,
    this.defaultBulkSurplusPercentage = 10,
    this.maxCutDeficitPercentage = 30,
    this.maxBulkSurplusPercentage = 30,
  });

  /// Facteurs heuristiques de dépense habituelle HORS sport planifié.
  /// ATTENTION : les maps fournies au constructeur ne sont pas copiées.
  /// Ne pas les modifier après création ; validate() est appelé par le service.
  /// Les activités déjà incluses ici ne doivent pas être ajoutées à nouveau.
  final Map<ActivityLevel, double> nonExerciseActivityFactors;

  /// MET estimés par sport et intensité. Une configuration partielle est permise.
  /// Comme les facteurs, ces maps sont à traiter comme immuables.
  final Map<SportType, Map<ActivityIntensity, double>> sportMetValues;

  final double defaultCutDeficitPercentage;
  final double defaultBulkSurplusPercentage;

  /// Plafonds applicatifs configurables, non des prescriptions médicales.
  final double maxCutDeficitPercentage;
  final double maxBulkSurplusPercentage;

  void validate() {
    for (final entry in nonExerciseActivityFactors.entries) {
      if (!entry.value.isFinite || entry.value < 1) {
        throw ArgumentError.value(
          entry.value,
          'nonExerciseActivityFactors[${entry.key}]',
          'Le facteur doit être fini et supérieur ou égal à 1.',
        );
      }
    }

    for (final sportEntry in sportMetValues.entries) {
      for (final intensityEntry in sportEntry.value.entries) {
        if (!intensityEntry.value.isFinite || intensityEntry.value < 1) {
          throw ArgumentError.value(
            intensityEntry.value,
            'sportMetValues[${sportEntry.key}][${intensityEntry.key}]',
            'Le MET doit être fini et supérieur ou égal à 1.',
          );
        }
      }
    }

    _validatePercentage(maxCutDeficitPercentage, 'maxCutDeficitPercentage');
    if (maxCutDeficitPercentage >= 100) {
      throw ArgumentError.value(
        maxCutDeficitPercentage,
        'maxCutDeficitPercentage',
        'Le plafond de déficit doit être strictement inférieur à 100 %.',
      );
    }
    _validatePercentage(maxBulkSurplusPercentage, 'maxBulkSurplusPercentage');
    _validatePercentage(
      defaultCutDeficitPercentage,
      'defaultCutDeficitPercentage',
    );
    _validatePercentage(
      defaultBulkSurplusPercentage,
      'defaultBulkSurplusPercentage',
    );

    if (defaultCutDeficitPercentage > maxCutDeficitPercentage) {
      throw ArgumentError(
        'Le déficit par défaut dépasse le plafond de déficit.',
      );
    }
    if (defaultBulkSurplusPercentage > maxBulkSurplusPercentage) {
      throw ArgumentError(
        'Le surplus par défaut dépasse le plafond de surplus.',
      );
    }
  }

  static void _validatePercentage(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'Le pourcentage doit être fini et positif ou nul.',
      );
    }
  }
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
