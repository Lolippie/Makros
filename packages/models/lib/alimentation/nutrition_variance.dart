
import 'macros.dart';

class NutritionVariance {
  final Macros target;
  final Macros consumed;

  const NutritionVariance({
    required this.target,
    required this.consumed,
  });

  Macros get difference => Macros(
    calories: consumed.calories - target.calories,
    protein: consumed.protein - target.protein,
    carbohydrates: consumed.carbohydrates - target.carbohydrates,
    fat: consumed.fat - target.fat,
    fiber: consumed.fiber - target.fiber,
  );

  bool get caloriesReached => consumed.calories >= target.calories;

  bool get proteinReached => consumed.protein >= target.protein;

  bool get carbohydratesReached =>
      consumed.carbohydrates >= target.carbohydrates;

  bool get fatReached => consumed.fat >= target.fat;

  bool get fiberReached => consumed.fiber >= target.fiber;
}