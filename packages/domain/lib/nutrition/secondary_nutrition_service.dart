import 'package:makros_models/models.dart';

import 'config/secondary_nutrition_config.dart';

class SecondaryNutritionService {
  final SecondaryNutritionConfig config;

  const SecondaryNutritionService({
    this.config = const SecondaryNutritionConfig(),
  });

  /// Calcule les repères nutritionnels journaliers.
  ///
  /// Les champs du résultat représentent des valeurs de référence,
  /// et non des quantités consommées.
  SecondaryNutrients calculate({
    required double targetCalories,
  }) {
    if (!targetCalories.isFinite || targetCalories <= 0) {
      throw ArgumentError(
        'Les calories cibles doivent être positives et valides.',
      );
    }

    return SecondaryNutrients(
      fiber: config.fiberGrams,

      // Aucun plafond déduit automatiquement pour les sucres totaux.
      sugars: null,

      freeSugars:
          targetCalories * config.maxFreeSugarsEnergyFraction / 4,

      saturatedFat:
          targetCalories * config.maxSaturatedFatEnergyFraction / 9,

      transFat:
          targetCalories * config.maxTransFatEnergyFraction / 9,

      salt: config.maxSaltGrams,

      potassium: config.potassiumMilligrams,
    );
  }

  /// Compare une consommation à une référence.
  NutritionComparison compareToReference({
    required double? consumed,
    required double? reference,
  }) {
    if (consumed == null || reference == null) {
      return NutritionComparison.unknown;
    }

    if (!consumed.isFinite || !reference.isFinite) {
      return NutritionComparison.unknown;
    }

    if (consumed < reference) {
      return NutritionComparison.below;
    }

    if (consumed > reference) {
      return NutritionComparison.exceeded;
    }

    return NutritionComparison.reached;
  }

  /// Vérifie si un minimum nutritionnel est atteint.
  ///
  /// Exemple : fibres ou potassium.
  bool? isMinimumAchieved({
    required double? consumed,
    required double? reference,
  }) {
    final comparison = compareToReference(
      consumed: consumed,
      reference: reference,
    );

    switch (comparison) {
      case NutritionComparison.below:
        return false;

      case NutritionComparison.reached:
      case NutritionComparison.exceeded:
        return true;

      case NutritionComparison.unknown:
        return null;
    }
  }

  /// Vérifie si une limite nutritionnelle est respectée.
  ///
  /// Exemple : sel, sucres libres ou acides gras saturés.
  bool? isMaximumRespected({
    required double? consumed,
    required double? reference,
  }) {
    final comparison = compareToReference(
      consumed: consumed,
      reference: reference,
    );

    switch (comparison) {
      case NutritionComparison.below:
      case NutritionComparison.reached:
        return true;

      case NutritionComparison.exceeded:
        return false;

      case NutritionComparison.unknown:
        return null;
    }
  }
}