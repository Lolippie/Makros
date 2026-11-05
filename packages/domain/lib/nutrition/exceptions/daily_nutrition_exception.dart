enum DailyNutritionErrorCode {
  duplicateMeal,
  duplicateDailyResult,
  invalidDailyResult,
  staleDailyResult,
  invalidMeal,
  invalidMealItem,
  invalidMacros,
  invalidTarget,
  invalidPlanning,
  invalidManualValidation,
}

/// Erreur de données récupérable, à traduire dans la couche UI.
class DailyNutritionException implements Exception {
  final DailyNutritionErrorCode code;
  final String context;
  const DailyNutritionException(this.code, [this.context = '']);
  @override
  String toString() => 'DailyNutritionException($code, $context)';
}
