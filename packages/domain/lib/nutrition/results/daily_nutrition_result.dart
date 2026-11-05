import 'package:makros_models/models.dart';

import '../daily_nutrition_day_status.dart';
import 'macro_calculation_result.dart';

enum DailyNutritionTargetSource { plannedDay, fallback, none }

/// `reached` pour une fourchette n'est possible qu'après la fin du jour.
/// Les objectifs minimums peuvent être atteints pendant la journée.
enum NutritionGoalStatus { pending, reached, exceeded, missed }

class DailyNutritionAchievement {
  final bool? calories;
  final bool? protein;
  final bool? carbohydrates;
  final bool? fat;
  final bool? fiber;

  const DailyNutritionAchievement({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });

  /// Attention : `fiber == null` ne distingue pas absence de cible et attente.
  /// Utiliser `DailyNutritionResult.allGoalsReached` pour le bilan complet.
  bool? get allReached {
    final values = [calories, protein, carbohydrates, fat, fiber];
    if (values.any((value) => value == false)) return false;
    if (values.take(4).any((value) => value == null)) return null;
    return true;
  }
}

class DailyNutritionGoalStatuses {
  final NutritionGoalStatus calories;
  final NutritionGoalStatus protein;
  final NutritionGoalStatus carbohydrates;
  final NutritionGoalStatus fat;
  final NutritionGoalStatus? fiber;

  const DailyNutritionGoalStatuses({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });
}

class DailyNutritionResult {
  final String userId;
  final DateTime date;
  final int mealCount;

  /// Journée déclarée traitée sans repas ; aucune réussite nutritionnelle mesurée.
  final bool isManuallyValidated;
  final Macros consumed;
  final Macros? target;
  final DailyNutritionTargetSource targetSource;
  final MacroCalculationStatus? macroStatus;
  final DailyNutritionDayStatus dayStatus;
  final NutritionVariance? variance;
  final DailyNutritionAchievement? achievement;
  final DailyNutritionGoalStatuses? goalStatuses;

  const DailyNutritionResult({
    required this.userId,
    required this.date,
    required this.mealCount,
    this.isManuallyValidated = false,
    required this.consumed,
    required this.target,
    required this.targetSource,
    required this.macroStatus,
    required this.dayStatus,
    required this.variance,
    required this.achievement,
    this.goalStatuses,
  });

  bool get hasTarget => target != null;
  bool get hasKnownConsumption => mealCount > 0;
  bool get hasInvalidPlanning => macroStatus == MacroCalculationStatus.invalid;
  bool get hasPlanningWarning => macroStatus == MacroCalculationStatus.warning;

  /// `null` : résultat encore indécidable ou absence de cible.
  /// Les fibres sont ignorées seulement si leur cible est absente (<= 0).
  bool? get allGoalsReached {
    // Une validation manuelle clôture la saisie, sans verdict nutritionnel.
    if (isManuallyValidated) return null;
    if (mealCount == 0) return null;
    final a = achievement;
    if (a == null) return null;
    final values = [a.calories, a.protein, a.carbohydrates, a.fat];
    if (target != null && target!.fiber > 0) values.add(a.fiber);
    if (values.any((value) => value == false)) return false;
    if (values.any((value) => value == null)) return null;
    return true;
  }

  double? get caloriesProgress =>
      _progress(consumed.calories, target?.calories);
  double? get proteinProgress => _progress(consumed.protein, target?.protein);
  double? get carbohydratesProgress =>
      _progress(consumed.carbohydrates, target?.carbohydrates);
  double? get fatProgress => _progress(consumed.fat, target?.fat);
  double? get fiberProgress => _progress(consumed.fiber, target?.fiber);

  double? _progress(double value, double? goal) =>
      !hasKnownConsumption || goal == null || goal <= 0
      ? null
      : value / goal * 100;
}
