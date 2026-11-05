import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_day_status.dart';
import 'package:makros_nutrition/nutrition/results/daily_nutrition_result.dart';
import 'package:makros_nutrition/nutrition/weekly_nutrition_service.dart';
import 'package:test/test.dart';

void main() {
  const service = WeeklyNutritionService();
  const target = Macros(
    calories: 2000,
    protein: 120,
    carbohydrates: 240,
    fat: 60,
    fiber: 25,
  );

  DailyNutritionResult day(
    int d, {
    required DailyNutritionDayStatus status,
    bool manual = false,
    bool hasMeal = false,
    bool? reached,
  }) => DailyNutritionResult(
    userId: 'u',
    date: DateTime(2026, 11, d),
    mealCount: hasMeal ? 1 : 0,
    isManuallyValidated: manual,
    consumed: Macros(
      calories: hasMeal ? 2000 : 0,
      protein: hasMeal ? 120 : 0,
      carbohydrates: hasMeal ? 240 : 0,
      fat: hasMeal ? 60 : 0,
      fiber: hasMeal ? 25 : 0,
    ),
    target: target,
    targetSource: DailyNutritionTargetSource.fallback,
    macroStatus: null,
    dayStatus: status,
    variance: null,
    achievement: hasMeal
        ? DailyNutritionAchievement(
            calories: reached,
            protein: reached,
            carbohydrates: reached,
            fat: reached,
            fiber: reached,
          )
        : null,
  );

  test('jours futurs et en cours non classés comme oubliés', () {
    final result = service.calculate(
      userId: 'u',
      dateInWeek: DateTime(2026, 11, 5),
      asOf: DateTime(2026, 11, 5),
      dailyResults: [
        day(2, status: DailyNutritionDayStatus.completed),
        day(5, status: DailyNutritionDayStatus.inProgress),
        day(6, status: DailyNutritionDayStatus.upcoming),
      ],
    );
    expect(result.unknownDates, [DateTime.utc(2026, 11, 2)]);
    expect(result.unknownDayCount, 3); // 2, 3 et 4 novembre.
  });

  test('validation manuelle traitée mais exclue du taux nutritionnel', () {
    final result = service.calculate(
      userId: 'u',
      dateInWeek: DateTime(2026, 11, 5),
      asOf: DateTime(2026, 11, 5),
      dailyResults: [
        day(2, status: DailyNutritionDayStatus.completed, manual: true),
        day(
          3,
          status: DailyNutritionDayStatus.completed,
          hasMeal: true,
          reached: true,
        ),
        day(
          4,
          status: DailyNutritionDayStatus.completed,
          hasMeal: true,
          reached: false,
        ),
      ],
    );
    expect(result.manuallyValidatedDayCount, 1);
    expect(result.documentedCompletedDayCount, 3);
    expect(result.evaluatedCompletedDays, 2);
    expect(result.successfulCompletedDays, 1);
    expect(result.failedCompletedDays, 1);
    expect(result.completedSuccessRate, 50);
    expect(result.evaluationCoverageRate, closeTo(200 / 3, 0.00001));
  });
}
