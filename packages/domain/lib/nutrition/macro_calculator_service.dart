import 'package:makros_models/models.dart';

import 'config/macro_calculation_config.dart';
import 'results/macro_calculation_result.dart';

class MacroCalculatorService {
  final MacroCalculationConfig config;

  const MacroCalculatorService({this.config = const MacroCalculationConfig()});

  static const double _proteinCaloriesPerGram = 4.0;
  static const double _carbohydrateCaloriesPerGram = 4.0;
  static const double _fatCaloriesPerGram = 9.0;

  /// Calcule les objectifs de macronutriments à partir :
  /// - du poids corporel ;
  /// - des calories journalières ;
  /// - du type d'objectif nutritionnel.
  ///
  /// Les protéines et les lipides sont déterminés en g/kg.
  /// Les glucides sont calculés à partir des calories restantes.
  MacroCalculationResult calculate({
    required double weightKg,
    required double targetCalories,
    required GoalType goalType,
  }) {
    _validatePositive(weightKg, 'Le poids');
    _validatePositive(targetCalories, 'Les calories cibles');

    _validateNonNegative(
      config.carbohydrateWarningPerKg,
      'Le seuil d’avertissement des glucides',
    );

    _validateNonNegative(config.calorieTolerance, 'La tolérance calorique');
    final coefficients = _getCoefficients(goalType);

    final proteinPerKg = coefficients.proteinPerKg;
    final fatPerKg = coefficients.fatPerKg;

    // 1. Calcul des protéines et des lipides.
    final protein = weightKg * proteinPerKg;
    final fat = weightKg * fatPerKg;

    final proteinCalories = protein * _proteinCaloriesPerGram;
    final fatCalories = fat * _fatCaloriesPerGram;

    // 2. Calories disponibles pour les glucides.
    final remainingCalories = targetCalories - proteinCalories - fatCalories;

    final issues = <MacroCalculationIssue>[];

    // 3. Vérification de la faisabilité mathématique.
    if (remainingCalories < -config.calorieTolerance) {
      return MacroCalculationResult(
        macros: null,
        proteinPerKg: proteinPerKg,
        fatPerKg: fatPerKg,
        status: MacroCalculationStatus.invalid,
        issues: const [MacroCalculationIssue.insufficientCalories],
      );
    }

    // 4. Calcul des glucides.
    final carbohydrates = remainingCalories <= 0
        ? 0.0
        : remainingCalories / _carbohydrateCaloriesPerGram;

    // 5. Vérification du repère minimal de glucides.
    final minimumCarbohydrates = weightKg * config.carbohydrateWarningPerKg;

    if (carbohydrates < minimumCarbohydrates) {
      issues.add(MacroCalculationIssue.lowCarbohydrates);
    }

    // 6. Construction du résultat.
    return MacroCalculationResult(
      macros: Macros(
        calories: targetCalories,
        protein: protein,
        carbohydrates: carbohydrates,
        fat: fat,
      ),
      proteinPerKg: proteinPerKg,
      fatPerKg: fatPerKg,
      status: issues.isEmpty
          ? MacroCalculationStatus.valid
          : MacroCalculationStatus.warning,
      issues: List.unmodifiable(issues),
    );
  }

  /// Calcule le minimum calorique nécessaire pour couvrir
  /// les protéines et les lipides définis par l'objectif.
  ///
  /// Ce minimum est uniquement mathématique.
  /// Il ne représente pas un apport calorique minimal
  /// recommandé pour la santé.
  double calculateMinimumCalories({
    required double weightKg,
    required GoalType goalType,
  }) {
    _validatePositive(weightKg, 'Le poids');
    _validateNonNegative(config.calorieTolerance, 'La tolérance calorique');

    final coefficients = _getCoefficients(goalType);

    final proteinCalories =
        weightKg * coefficients.proteinPerKg * _proteinCaloriesPerGram;

    final fatCalories = weightKg * coefficients.fatPerKg * _fatCaloriesPerGram;

    return proteinCalories + fatCalories;
  }

  /// Retourne les coefficients nutritionnels correspondant
  /// à l'objectif de l'utilisateur.
  ///
  /// Cette méthode centralise la configuration afin que
  /// tous les calculs utilisent les mêmes coefficients.
  ({double proteinPerKg, double fatPerKg}) _getCoefficients(GoalType goalType) {
    final double proteinPerKg;
    final double fatPerKg;

    switch (goalType) {
      case GoalType.cut:
        proteinPerKg = config.cutProteinPerKg;
        fatPerKg = config.cutFatPerKg;

      case GoalType.maintenance:
        proteinPerKg = config.maintenanceProteinPerKg;
        fatPerKg = config.maintenanceFatPerKg;

      case GoalType.bulk:
        proteinPerKg = config.bulkProteinPerKg;
        fatPerKg = config.bulkFatPerKg;
    }

    _validatePositive(proteinPerKg, 'Le coefficient de protéines');

    _validatePositive(fatPerKg, 'Le coefficient de lipides');

    return (proteinPerKg: proteinPerKg, fatPerKg: fatPerKg);
  }

  /// Vérifie qu'une valeur est strictement positive et finie.
  void _validatePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('$label doit être une valeur positive et valide.');
    }
  }

  void _validateNonNegative(double value, String label) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError(
        '$label doit être une valeur positive ou nulle et finie.',
      );
    }
  }
}
