import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_day_status.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_goal_evaluator.dart';
import 'package:makros_nutrition/nutrition/config/daily_nutrition_config.dart';
import 'package:makros_nutrition/nutrition/results/daily_nutrition_result.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = DailyNutritionGoalEvaluator(DailyNutritionConfig());
  const target = Macros(
    calories: 2000,
    protein: 130,
    carbohydrates: 250,
    fat: 60,
    fiber: 30,
  );
  test('fourchettes provisoires en cours de journee', () {
    final (statuses, achievement) = evaluator.evaluate(
      consumed: target,
      target: target,
      dayStatus: DailyNutritionDayStatus.inProgress,
    );
    expect(statuses.calories, NutritionGoalStatus.pending);
    expect(statuses.carbohydrates, NutritionGoalStatus.pending);
    expect(statuses.fat, NutritionGoalStatus.pending);
    expect(achievement.calories, isNull);
    expect(statuses.protein, NutritionGoalStatus.reached);
    expect(statuses.fiber, NutritionGoalStatus.reached);
  });
  test('jour termine : fourchettes atteintes', () {
    final (statuses, achievement) = evaluator.evaluate(
      consumed: target,
      target: target,
      dayStatus: DailyNutritionDayStatus.completed,
    );
    expect(statuses.calories, NutritionGoalStatus.reached);
    expect(achievement.calories, isTrue);
  });
  test('jour futur : aucun verdict definitif', () {
    final (statuses, achievement) = evaluator.evaluate(
      consumed: target,
      target: target,
      dayStatus: DailyNutritionDayStatus.upcoming,
    );
    expect(statuses.protein, NutritionGoalStatus.pending);
    expect(achievement.calories, isNull);
  });
}
