import 'package:makros_models/models.dart';
import 'exceptions/daily_nutrition_exception.dart';

/// Validation commune des valeurs nutritionnelles, sans messages d'interface.
void validateNutritionMacros(Macros macros, String context) {
  final values = [
    macros.calories,
    macros.protein,
    macros.carbohydrates,
    macros.fat,
    macros.fiber,
  ];
  if (values.any((value) => !value.isFinite || value < 0)) {
    throw DailyNutritionException(
      DailyNutritionErrorCode.invalidMacros,
      context,
    );
  }
}

void validateNutritionTarget(Macros target, String context) {
  validateNutritionMacros(target, context);
  if (target.calories <= 0 || target.protein <= 0) {
    throw DailyNutritionException(
      DailyNutritionErrorCode.invalidTarget,
      context,
    );
  }
}
