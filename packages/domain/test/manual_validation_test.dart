import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_service.dart';
import 'package:makros_nutrition/nutrition/exceptions/daily_nutrition_exception.dart';
import 'package:makros_nutrition/nutrition/weekly_nutrition_service.dart';
import 'package:test/test.dart';

void main() {
  const daily = DailyNutritionService();
  const weekly = WeeklyNutritionService();
  final date = DateTime(2026, 11, 2);
  final asOf = DateTime(2026, 11, 5);
  const target = Macros(
    calories: 2000,
    protein: 120,
    carbohydrates: 240,
    fat: 60,
    fiber: 25,
  );

  test('sans repas, non validé : bilan inconnu', () {
    final result = daily.calculate(
      userId: 'u',
      date: date,
      asOf: asOf,
      meals: [],
      fallbackTarget: target,
    );
    expect(result.allGoalsReached, isNull);
    expect(result.achievement, isNull);
    expect(result.variance, isNull);
  });

  test('sans repas, validé : traité sans réussite nutritionnelle inventée', () {
    final result = daily.calculate(
      userId: 'u',
      date: date,
      asOf: asOf,
      meals: [],
      fallbackTarget: target,
      manualValidation: DailyNutritionValidation(
        userId: 'u',
        date: date,
        manuallyValidated: true,
      ),
    );
    expect(result.allGoalsReached, isNull);
    expect(result.achievement, isNull);
    expect(result.variance, isNull);
    expect(result.consumed.calories, 0);
    final week = weekly.calculate(
      userId: 'u',
      dateInWeek: date,
      asOf: asOf,
      dailyResults: [result],
    );
    expect(week.successfulCompletedDays, 0);
    expect(week.completedSuccessRate, isNull);
    expect(week.documentedCompletedDayCount, 1);
    expect(week.manuallyValidatedDayCount, 1);
    expect(week.consumptionDayCount, 0);
    expect(week.comparableDayCount, 0);
    expect(week.unknownDates, isEmpty);
  });

  test('validation future ignorée sans exception', () {
    final future = DateTime(2026, 11, 7);
    final result = daily.calculate(
      userId: 'u',
      date: future,
      asOf: asOf,
      meals: [],
      manualValidation: DailyNutritionValidation(
        userId: 'u',
        date: future,
        manuallyValidated: true,
      ),
    );
    expect(result.isManuallyValidated, isFalse);
    expect(result.allGoalsReached, isNull);
  });

  test('une validation pour un autre jour est interdite', () {
    expect(
      () => daily.calculate(
        userId: 'u',
        date: date,
        asOf: asOf,
        meals: [],
        manualValidation: DailyNutritionValidation(
          userId: 'u',
          date: DateTime(2026, 11, 3),
          manuallyValidated: true,
        ),
      ),
      throwsA(isA<DailyNutritionException>()),
    );
  });
}
