import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/config/daily_nutrition_config.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_day_status.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_goal_evaluator.dart';
import 'package:makros_nutrition/nutrition/nutrition_calendar.dart';
import 'package:makros_nutrition/nutrition/results/daily_nutrition_result.dart';
import 'package:makros_nutrition/nutrition/weekly_nutrition_service.dart';
import 'package:test/test.dart';

void main() {
  const target = Macros(
    calories: 2000,
    protein: 120,
    carbohydrates: 240,
    fat: 60,
    fiber: 0,
  );
  test('dates civiles et statuts partagés', () {
    expect(calendarDay(DateTime(2026, 11, 5, 23)), DateTime.utc(2026, 11, 5));
    expect(
      dayStatusFor(DateTime(2026, 11, 4), DateTime(2026, 11, 5)),
      DailyNutritionDayStatus.completed,
    );
    expect(
      dayStatusFor(DateTime(2026, 11, 5), DateTime(2026, 11, 5)),
      DailyNutritionDayStatus.inProgress,
    );
    expect(
      dayStatusFor(DateTime(2026, 11, 6), DateTime(2026, 11, 5)),
      DailyNutritionDayStatus.upcoming,
    );
  });

  test('fibres sans cible ne bloquent pas un verdict définitif', () {
    final consumed = target;
    final evaluation = const DailyNutritionGoalEvaluator(DailyNutritionConfig())
        .evaluate(
          consumed: consumed,
          target: target,
          dayStatus: DailyNutritionDayStatus.completed,
        );
    final result = DailyNutritionResult(
      userId: 'u',
      date: DateTime(2026, 11, 4),
      mealCount: 1,
      consumed: consumed,
      target: target,
      targetSource: DailyNutritionTargetSource.fallback,
      macroStatus: null,
      dayStatus: DailyNutritionDayStatus.completed,
      variance: NutritionVariance(target: target, consumed: consumed),
      achievement: evaluation.$2,
      goalStatuses: evaluation.$1,
    );
    expect(result.achievement!.fiber, isNull);
    expect(result.allGoalsReached, isTrue);
    final week = const WeeklyNutritionService().calculate(
      userId: 'u',
      dateInWeek: DateTime(2026, 11, 4),
      asOf: DateTime(2026, 11, 5),
      dailyResults: [result],
    );
    expect(week.successfulCompletedDays, 1);
  });

  test('évaluateur autonome rejette une configuration invalide', () {
    const evaluator = DailyNutritionGoalEvaluator(
      DailyNutritionConfig(caloriesToleranceFraction: -0.1),
    );
    expect(
      () => evaluator.evaluate(
        consumed: target,
        target: target,
        dayStatus: DailyNutritionDayStatus.completed,
      ),
      throwsArgumentError,
    );
  });

  test('fourchette atteinte pendant la journée reste provisoire', () {
    final evaluation = const DailyNutritionGoalEvaluator(DailyNutritionConfig())
        .evaluate(
          consumed: target,
          target: target,
          dayStatus: DailyNutritionDayStatus.inProgress,
        );
    expect(evaluation.$1.calories, NutritionGoalStatus.pending);
    expect(evaluation.$1.protein, NutritionGoalStatus.reached);
    expect(evaluation.$2.calories, isNull);
  });
}
