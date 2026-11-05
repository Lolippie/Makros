import 'package:makros_models/models.dart';
import 'config/daily_nutrition_config.dart';
import 'daily_nutrition_day_status.dart';
import 'results/daily_nutrition_result.dart';

/// Évaluation pure des objectifs : les fourchettes restent provisoires
/// jusqu'à la fin du jour, même si elles sont actuellement respectées.
class DailyNutritionGoalEvaluator {
  final DailyNutritionConfig config;
  const DailyNutritionGoalEvaluator(this.config);

  (DailyNutritionGoalStatuses, DailyNutritionAchievement) evaluate({
    required Macros consumed,
    required Macros target,
    required DailyNutritionDayStatus dayStatus,
  }) {
    config.validate();
    final statuses = DailyNutritionGoalStatuses(
      calories: _rangeStatus(
        consumed.calories,
        target.calories,
        config.caloriesToleranceFraction,
        dayStatus,
      ),
      protein: _minimumStatus(consumed.protein, target.protein, dayStatus),
      carbohydrates: _rangeStatus(
        consumed.carbohydrates,
        target.carbohydrates,
        config.carbohydratesToleranceFraction,
        dayStatus,
        absolute: config.minimumCarbohydratesToleranceGrams,
      ),
      fat: _rangeStatus(
        consumed.fat,
        target.fat,
        config.fatToleranceFraction,
        dayStatus,
        absolute: config.minimumFatToleranceGrams,
      ),
      fiber: target.fiber > 0
          ? _minimumStatus(consumed.fiber, target.fiber, dayStatus)
          : null,
    );
    return (
      statuses,
      DailyNutritionAchievement(
        calories: _verdict(statuses.calories),
        protein: _verdict(statuses.protein),
        carbohydrates: _verdict(statuses.carbohydrates),
        fat: _verdict(statuses.fat),
        fiber: statuses.fiber == null ? null : _verdict(statuses.fiber!),
      ),
    );
  }

  NutritionGoalStatus _rangeStatus(
    double value,
    double target,
    double fraction,
    DailyNutritionDayStatus dayStatus, {
    double absolute = 0,
  }) {
    if (dayStatus == DailyNutritionDayStatus.upcoming) {
      return NutritionGoalStatus.pending;
    }
    final tolerance = target * fraction > absolute
        ? target * fraction
        : absolute;
    if (value > target + tolerance + config.comparisonEpsilon) {
      return NutritionGoalStatus.exceeded;
    }
    if (dayStatus == DailyNutritionDayStatus.inProgress) {
      return NutritionGoalStatus.pending;
    }
    if (value >= target - tolerance - config.comparisonEpsilon) {
      return NutritionGoalStatus.reached;
    }
    return NutritionGoalStatus.missed;
  }

  NutritionGoalStatus _minimumStatus(
    double value,
    double target,
    DailyNutritionDayStatus dayStatus,
  ) {
    if (dayStatus == DailyNutritionDayStatus.upcoming) {
      return NutritionGoalStatus.pending;
    }
    if (value + config.comparisonEpsilon >= target) {
      return NutritionGoalStatus.reached;
    }
    return dayStatus == DailyNutritionDayStatus.completed
        ? NutritionGoalStatus.missed
        : NutritionGoalStatus.pending;
  }

  bool? _verdict(NutritionGoalStatus status) => switch (status) {
    NutritionGoalStatus.pending => null,
    NutritionGoalStatus.reached => true,
    NutritionGoalStatus.exceeded || NutritionGoalStatus.missed => false,
  };
}
