import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_day_status.dart';

import 'package:makros_nutrition/nutrition/daily_nutrition_service.dart';
import 'package:makros_nutrition/nutrition/exceptions/daily_nutrition_exception.dart';
import 'package:makros_nutrition/nutrition/config/daily_nutrition_config.dart';
import 'package:makros_nutrition/nutrition/results/daily_nutrition_result.dart';
import 'package:makros_nutrition/nutrition/results/macro_calculation_result.dart';

import 'package:test/test.dart';

void main() {
  const service = DailyNutritionService();

  final date = DateTime(2026, 11, 5);

  const target = Macros(
    calories: 2000,
    protein: 130,
    carbohydrates: 250,
    fat: 60,
    fiber: 30,
  );

  DailyMeal createMeal({
    String id = 'meal-1',
    String userId = 'user-1',
    DateTime? mealDate,
  }) {
    return DailyMeal(
      id: id,
      userId: userId,
      date: mealDate ?? date,
      type: MealType.values.first,
      items: const [],
      createdAt: date,
      updatedAt: date,
    );
  }

  DailyMeal createMealWithMacros({
    required Macros macrosPer100g,
    double quantity = 100,
    String id = 'meal-1',
    String userId = 'user-1',
    DateTime? mealDate,
  }) {
    final food = Food(id: 'food-$id', name: 'Test food', macros: macrosPer100g);

    return DailyMeal(
      id: id,
      userId: userId,
      date: mealDate ?? date,
      type: MealType.values.first,
      items: [MealItem(id: 'item-$id', food: food, quantity: quantity)],
      createdAt: date,
      updatedAt: date,
    );
  }

  PlannedActiveDay createPlannedDay({
    DateTime? plannedDate,
    Macros? targetMacros,
  }) {
    return PlannedActiveDay(
      id: 'day-1',
      weekPlanId: 'week-1',
      date: plannedDate ?? date,
      hasActivity: false,
      targetMacros: targetMacros,
    );
  }

  DailyNutritionResult calculate({
    List<DailyMeal> meals = const [],
    PlannedActiveDay? plannedDay,
    Macros? fallbackTarget,
    String userId = 'user-1',
    DateTime? requestedDate,
    DailyNutritionService calculator = service,
    MacroCalculationStatus? macroStatus,
    DailyNutritionValidation? manualValidation,
    DateTime? asOf,
  }) {
    return calculator.calculate(
      userId: userId,
      date: requestedDate ?? date,
      meals: meals,
      plannedDay: plannedDay,
      fallbackTarget: fallbackTarget,
      macroStatus: macroStatus,
      manualValidation: manualValidation,
      asOf: asOf ?? DateTime(2026, 11, 6),
    );
  }

  group('DailyNutritionService - consommations', () {
    test('returns zero consumption when no meals exist', () {
      final result = calculate();

      expect(result.mealCount, 0);
      expect(result.consumed.calories, 0);
      expect(result.consumed.protein, 0);
      expect(result.consumed.carbohydrates, 0);
      expect(result.consumed.fat, 0);
      expect(result.consumed.fiber, 0);
    });

    test('counts only meals belonging to the user and date', () {
      final meals = [
        createMeal(id: '1'),
        createMeal(id: '2'),
        createMeal(id: '3', userId: 'another-user'),
        createMeal(id: '4', mealDate: DateTime(2026, 11, 6)),
      ];

      final result = calculate(meals: meals);

      expect(result.mealCount, 2);
    });

    test('ignores the time of day when filtering meals', () {
      final result = calculate(
        meals: [createMeal(mealDate: DateTime(2026, 11, 5, 23, 59))],
      );

      expect(result.mealCount, 1);
      expect(result.date, DateTime.utc(2026, 11, 5));
    });

    test('does not modify the original meal list', () {
      final meals = [createMeal(id: '1'), createMeal(id: '2')];

      final originalIds = meals.map((meal) => meal.id).toList();

      calculate(meals: meals);

      expect(meals.map((meal) => meal.id).toList(), originalIds);
    });
  });

  group('DailyNutritionService - objectifs', () {
    test('uses the planned day target first', () {
      const plannedTarget = Macros(
        calories: 2100,
        protein: 140,
        carbohydrates: 260,
        fat: 65,
      );

      final result = calculate(
        plannedDay: createPlannedDay(targetMacros: plannedTarget),
        fallbackTarget: target,
      );

      expect(result.targetSource, DailyNutritionTargetSource.plannedDay);
      expect(result.target!.calories, 2100);
    });

    test('uses fallback when the planned target is absent', () {
      final result = calculate(
        plannedDay: createPlannedDay(),
        fallbackTarget: target,
      );

      expect(result.targetSource, DailyNutritionTargetSource.fallback);
      expect(result.target!.calories, 2000);
    });

    test('returns unknown achievements without a target', () {
      final result = calculate();

      expect(result.hasTarget, isFalse);
      expect(result.target, isNull);
      expect(result.variance, isNull);
      expect(result.achievement, isNull);
      expect(result.allGoalsReached, isNull);
      expect(result.caloriesProgress, isNull);
      expect(result.proteinProgress, isNull);
      expect(result.targetSource, DailyNutritionTargetSource.none);
    });

    test('empty day with a target has unknown achievements', () {
      final result = calculate(fallbackTarget: target);
      expect(result.hasTarget, isTrue);
      expect(result.achievement, isNull);
      expect(result.goalStatuses, isNull);
      expect(result.allGoalsReached, isNull);
      expect(result.hasKnownConsumption, isFalse);
    });

    test('treats fiber as optional when its target is zero', () {
      const targetWithoutFiber = Macros(
        calories: 2000,
        protein: 130,
        carbohydrates: 250,
        fat: 60,
      );
      final result = calculate(
        fallbackTarget: targetWithoutFiber,
        meals: [createMealWithMacros(macrosPer100g: targetWithoutFiber)],
      );
      expect(result.achievement!.fiber, isNull);
      expect(result.fiberProgress, isNull);
      expect(result.allGoalsReached, isTrue);
    });

    test('does not invent negative variances when no meal is entered', () {
      final result = calculate(fallbackTarget: target);
      expect(result.variance, isNull);
      expect(result.achievement, isNull);
      expect(result.allGoalsReached, isNull);
    });

    test('returns zero progress when the target exists', () {
      final result = calculate(fallbackTarget: target);

      expect(result.caloriesProgress, isNull);
      expect(result.proteinProgress, isNull);
      expect(result.carbohydratesProgress, isNull);
      expect(result.fatProgress, isNull);
      expect(result.fiberProgress, isNull);
    });
  });

  group('DailyNutritionService - atteinte des objectifs', () {
    DailyNutritionResult calculateConsumption(Macros consumed) {
      return calculate(
        meals: [createMealWithMacros(macrosPer100g: consumed)],
        fallbackTarget: target,
      );
    }

    test('accepts calories at the lower tolerance boundary', () {
      final result = calculateConsumption(
        const Macros(
          calories: 1900,
          protein: 130,
          carbohydrates: 250,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.achievement!.calories, isTrue);
    });

    test('accepts calories at the upper tolerance boundary', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2100,
          protein: 130,
          carbohydrates: 250,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.achievement!.calories, isTrue);
    });

    test('rejects calories below the tolerance range', () {
      final result = calculateConsumption(
        const Macros(
          calories: 1800,
          protein: 130,
          carbohydrates: 250,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.achievement!.calories, isFalse);
    });

    test('rejects calories above the tolerance range', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2200,
          protein: 130,
          carbohydrates: 250,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.achievement!.calories, isFalse);
    });

    test('accepts protein above the minimum', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2000,
          protein: 150,
          carbohydrates: 250,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.achievement!.protein, isTrue);
    });

    test('rejects protein below the minimum', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2000,
          protein: 120,
          carbohydrates: 250,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.achievement!.protein, isFalse);
    });

    test('accepts carbohydrates within 10 percent tolerance', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2000,
          protein: 130,
          carbohydrates: 225,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.achievement!.carbohydrates, isTrue);
    });

    test('rejects carbohydrates outside tolerance', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2000,
          protein: 130,
          carbohydrates: 280,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.achievement!.carbohydrates, isFalse);
    });

    test('accepts fat within 10 percent tolerance', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2000,
          protein: 130,
          carbohydrates: 250,
          fat: 66,
          fiber: 30,
        ),
      );

      expect(result.achievement!.fat, isTrue);
    });

    test('rejects fat above tolerance', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2000,
          protein: 130,
          carbohydrates: 250,
          fat: 70,
          fiber: 30,
        ),
      );

      expect(result.achievement!.fat, isFalse);
    });

    test('accepts fiber above the minimum', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2000,
          protein: 130,
          carbohydrates: 250,
          fat: 60,
          fiber: 35,
        ),
      );

      expect(result.achievement!.fiber, isTrue);
    });

    test('rejects fiber below the minimum', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2000,
          protein: 130,
          carbohydrates: 250,
          fat: 60,
          fiber: 20,
        ),
      );

      expect(result.achievement!.fiber, isFalse);
    });

    test('marks all goals reached when every target is satisfied', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2050,
          protein: 145,
          carbohydrates: 240,
          fat: 62,
          fiber: 32,
        ),
      );

      expect(result.allGoalsReached, isTrue);
    });

    test('marks daily goals not reached when one target fails', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2050,
          protein: 145,
          carbohydrates: 240,
          fat: 70,
          fiber: 32,
        ),
      );

      expect(result.achievement!.fat, isFalse);
      expect(result.allGoalsReached, isFalse);
    });

    test('calculates progress percentages', () {
      final result = calculateConsumption(
        const Macros(
          calories: 2100,
          protein: 143,
          carbohydrates: 250,
          fat: 60,
          fiber: 30,
        ),
      );

      expect(result.caloriesProgress, closeTo(105, 1e-9));
      expect(result.proteinProgress, closeTo(110, 1e-9));
      expect(result.carbohydratesProgress, closeTo(100, 1e-9));
      expect(result.fatProgress, closeTo(100, 1e-9));
      expect(result.fiberProgress, closeTo(100, 1e-9));
    });
  });

  group('DailyNutritionService - validation', () {
    test('rejects an empty user ID', () {
      expect(() => calculate(userId: '  '), throwsArgumentError);
    });

    test('rejects a planned day with another date', () {
      expect(
        () => calculate(
          plannedDay: createPlannedDay(plannedDate: DateTime(2026, 11, 6)),
        ),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('rejects negative target values', () {
      const invalidTarget = Macros(
        calories: -100,
        protein: 130,
        carbohydrates: 250,
        fat: 60,
      );

      expect(
        () => calculate(fallbackTarget: invalidTarget),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('rejects an infinite target', () {
      const invalidTarget = Macros(
        calories: double.infinity,
        protein: 130,
        carbohydrates: 250,
        fat: 60,
      );

      expect(
        () => calculate(fallbackTarget: invalidTarget),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('rejects invalid tolerance configuration', () {
      const invalidService = DailyNutritionService(
        config: DailyNutritionConfig(caloriesToleranceFraction: -0.05),
      );

      expect(() => calculate(calculator: invalidService), throwsArgumentError);
    });

    test('rejects a tolerance greater than 100 percent', () {
      const invalidService = DailyNutritionService(
        config: DailyNutritionConfig(fatToleranceFraction: 1.5),
      );

      expect(() => calculate(calculator: invalidService), throwsArgumentError);
    });

    test('rejects a negative comparison epsilon', () {
      const invalidService = DailyNutritionService(
        config: DailyNutritionConfig(comparisonEpsilon: -1),
      );

      expect(() => calculate(calculator: invalidService), throwsArgumentError);
    });

    test('rejects an empty meal identifier', () {
      expect(
        () => calculate(meals: [createMeal(id: '')]),
        throwsA(isA<DailyNutritionException>()),
      );
    });
  });
  group('DailyNutritionService - consommations réelles', () {
    test('calculates macros from food quantity', () {
      final meal = createMealWithMacros(
        macrosPer100g: const Macros(
          calories: 200,
          protein: 20,
          carbohydrates: 15,
          fat: 5,
          fiber: 3,
        ),
        quantity: 150,
      );

      final result = calculate(meals: [meal]);

      expect(result.mealCount, 1);
      expect(result.consumed.calories, closeTo(300, 1e-9));
      expect(result.consumed.protein, closeTo(30, 1e-9));
      expect(result.consumed.carbohydrates, closeTo(22.5, 1e-9));
      expect(result.consumed.fat, closeTo(7.5, 1e-9));
      expect(result.consumed.fiber, closeTo(4.5, 1e-9));
    });

    test('sums macros from multiple meals', () {
      final meals = [
        createMealWithMacros(
          id: 'breakfast',
          macrosPer100g: const Macros(
            calories: 400,
            protein: 20,
            carbohydrates: 50,
            fat: 10,
            fiber: 5,
          ),
        ),
        createMealWithMacros(
          id: 'lunch',
          macrosPer100g: const Macros(
            calories: 600,
            protein: 40,
            carbohydrates: 70,
            fat: 20,
            fiber: 8,
          ),
        ),
      ];

      final result = calculate(meals: meals);

      expect(result.mealCount, 2);
      expect(result.consumed.calories, closeTo(1000, 1e-9));
      expect(result.consumed.protein, closeTo(60, 1e-9));
      expect(result.consumed.carbohydrates, closeTo(120, 1e-9));
      expect(result.consumed.fat, closeTo(30, 1e-9));
      expect(result.consumed.fiber, closeTo(13, 1e-9));
    });

    test('excludes meals from other users and dates', () {
      final meals = [
        createMealWithMacros(
          id: 'valid',
          macrosPer100g: const Macros(
            calories: 500,
            protein: 30,
            carbohydrates: 50,
            fat: 20,
          ),
        ),
        createMealWithMacros(
          id: 'other-user',
          userId: 'user-2',
          macrosPer100g: const Macros(
            calories: 1000,
            protein: 50,
            carbohydrates: 100,
            fat: 30,
          ),
        ),
        createMealWithMacros(
          id: 'other-date',
          mealDate: DateTime(2026, 11, 6),
          macrosPer100g: const Macros(
            calories: 800,
            protein: 40,
            carbohydrates: 80,
            fat: 20,
          ),
        ),
      ];

      final result = calculate(meals: meals);

      expect(result.mealCount, 1);
      expect(result.consumed.calories, 500);
      expect(result.consumed.protein, 30);
    });

    test('rejects invalid food quantity', () {
      final meal = createMealWithMacros(
        macrosPer100g: const Macros(
          calories: 200,
          protein: 20,
          carbohydrates: 15,
          fat: 5,
        ),
        quantity: -100,
      );

      expect(
        () => calculate(meals: [meal]),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('rejects invalid food nutritional values', () {
      final meal = createMealWithMacros(
        macrosPer100g: const Macros(
          calories: double.nan,
          protein: 20,
          carbohydrates: 15,
          fat: 5,
        ),
      );

      expect(
        () => calculate(meals: [meal]),
        throwsA(isA<DailyNutritionException>()),
      );
    });
  });

  group('DailyNutritionService - tests complémentaires', () {
    test('keeps consumption when no target exists', () {
      final result = calculate(
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 500,
              protein: 35,
              carbohydrates: 60,
              fat: 15,
              fiber: 8,
            ),
          ),
        ],
      );
      expect(result.consumed.calories, 500);
      expect(result.consumed.protein, 35);
      expect(result.achievement, isNull);
      expect(result.allGoalsReached, isNull);
    });

    test('checks both carbohydrate tolerance boundaries', () {
      for (final carbs in [225.0, 275.0]) {
        final result = calculate(
          fallbackTarget: target,
          meals: [
            createMealWithMacros(
              macrosPer100g: Macros(
                calories: 2000,
                protein: 130,
                carbohydrates: carbs,
                fat: 60,
                fiber: 30,
              ),
            ),
          ],
        );
        expect(result.achievement!.carbohydrates, isTrue);
      }
      for (final carbs in [224.0, 276.0]) {
        final result = calculate(
          fallbackTarget: target,
          meals: [
            createMealWithMacros(
              macrosPer100g: Macros(
                calories: 2000,
                protein: 130,
                carbohydrates: carbs,
                fat: 60,
                fiber: 30,
              ),
            ),
          ],
        );
        expect(result.achievement!.carbohydrates, isFalse);
      }
    });

    test('checks both fat tolerance boundaries', () {
      for (final fat in [54.0, 66.0]) {
        final result = calculate(
          fallbackTarget: target,
          meals: [
            createMealWithMacros(
              macrosPer100g: Macros(
                calories: 2000,
                protein: 130,
                carbohydrates: 250,
                fat: fat,
                fiber: 30,
              ),
            ),
          ],
        );
        expect(result.achievement!.fat, isTrue);
      }
      for (final fat in [53.0, 67.0]) {
        final result = calculate(
          fallbackTarget: target,
          meals: [
            createMealWithMacros(
              macrosPer100g: Macros(
                calories: 2000,
                protein: 130,
                carbohydrates: 250,
                fat: fat,
                fiber: 30,
              ),
            ),
          ],
        );
        expect(result.achievement!.fat, isFalse);
      }
    });

    test('uses custom calorie tolerance', () {
      const customService = DailyNutritionService(
        config: DailyNutritionConfig(caloriesToleranceFraction: 0.02),
      );
      final result = calculate(
        calculator: customService,
        fallbackTarget: target,
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 2050,
              protein: 130,
              carbohydrates: 250,
              fat: 60,
              fiber: 30,
            ),
          ),
        ],
      );
      expect(result.achievement!.calories, isFalse);
    });

    test('rejects a negative food value even if another item compensates', () {
      final invalidFood = Food(
        id: 'invalid',
        name: 'Invalid',
        macros: const Macros(
          calories: -100,
          protein: 10,
          carbohydrates: 10,
          fat: 5,
        ),
      );
      final validFood = Food(
        id: 'valid',
        name: 'Valid',
        macros: const Macros(
          calories: 200,
          protein: 10,
          carbohydrates: 10,
          fat: 5,
        ),
      );
      final meal = DailyMeal(
        id: 'mixed-meal',
        userId: 'user-1',
        date: date,
        type: MealType.values.first,
        items: [
          MealItem(id: 'bad', food: invalidFood, quantity: 100),
          MealItem(id: 'good', food: validFood, quantity: 100),
        ],
        createdAt: date,
        updatedAt: date,
      );
      expect(
        () => calculate(meals: [meal]),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('matches calendar dates regardless of time of day', () {
      final result = calculate(
        requestedDate: DateTime(2026, 11, 5, 1),
        meals: [
          createMealWithMacros(
            mealDate: DateTime(2026, 11, 5, 23, 59),
            macrosPer100g: const Macros(
              calories: 100,
              protein: 5,
              carbohydrates: 10,
              fat: 2,
            ),
          ),
        ],
      );
      expect(result.mealCount, 1);
      expect(result.consumed.calories, 100);
    });
  });

  group('DailyNutritionService - journée en cours', () {
    test('keeps consumption and progress without declaring failure', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 10),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 500,
              protein: 35,
              carbohydrates: 60,
              fat: 15,
              fiber: 8,
            ),
          ),
        ],
      );
      expect(result.dayStatus, DailyNutritionDayStatus.inProgress);
      expect(result.consumed.calories, 500);
      expect(result.caloriesProgress, 25);
      expect(result.achievement!.calories, isNull);
      expect(result.allGoalsReached, isNull);
    });

    test('shows reached minimums without prematurely failing others', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 18),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 1000,
              protein: 140,
              carbohydrates: 100,
              fat: 30,
              fiber: 32,
            ),
          ),
        ],
      );
      expect(result.achievement!.protein, isTrue);
      expect(result.achievement!.fiber, isTrue);
      expect(result.achievement!.calories, isNull);
      expect(result.allGoalsReached, isNull);
    });

    test('keeps an unlogged completed day unknown', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 6),
      );
      expect(result.dayStatus, DailyNutritionDayStatus.completed);
      expect(result.achievement, isNull);
      expect(result.allGoalsReached, isNull);
    });

    test('does not declare a future day failed', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 4),
      );
      expect(result.dayStatus, DailyNutritionDayStatus.upcoming);
      expect(result.achievement, isNull);
      expect(result.goalStatuses, isNull);
      expect(result.allGoalsReached, isNull);
    });
  });

  group('DailyNutritionService - planning invalide', () {
    test('uses fallback and explicitly reports invalid planning', () {
      final result = calculate(
        plannedDay: createPlannedDay(),
        macroStatus: MacroCalculationStatus.invalid,
        fallbackTarget: target,
      );
      expect(result.hasInvalidPlanning, isTrue);
      expect(result.macroStatus, MacroCalculationStatus.invalid);
      expect(result.targetSource, DailyNutritionTargetSource.fallback);
      expect(result.target!.calories, 2000);
    });

    test('reports invalid planning without fallback', () {
      final result = calculate(
        plannedDay: createPlannedDay(),
        macroStatus: MacroCalculationStatus.invalid,
      );
      expect(result.hasInvalidPlanning, isTrue);
      expect(result.target, isNull);
      expect(result.achievement, isNull);
      expect(result.targetSource, DailyNutritionTargetSource.none);
    });

    test('distinguishes missing target from invalid planning', () {
      final result = calculate(
        plannedDay: createPlannedDay(),
        macroStatus: null,
        fallbackTarget: target,
      );
      expect(result.hasInvalidPlanning, isFalse);
      expect(result.macroStatus, null);
      expect(result.targetSource, DailyNutritionTargetSource.fallback);
    });

    test('rejects invalid status with a populated planned target', () {
      expect(
        () => calculate(
          plannedDay: createPlannedDay(targetMacros: target),
          macroStatus: MacroCalculationStatus.invalid,
        ),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('rejects planning status without planned day', () {
      expect(
        () => calculate(macroStatus: MacroCalculationStatus.invalid),
        throwsA(isA<DailyNutritionException>()),
      );
    });
  });
  group('DailyNutritionService - corrections audit', () {
    test('fails immediately when calories exceed the upper bound', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 2200,
              protein: 130,
              carbohydrates: 250,
              fat: 60,
            ),
          ),
        ],
      );
      expect(result.achievement!.calories, isFalse);
      expect(result.allGoalsReached, isFalse);
    });

    test('fails immediately when carbohydrates exceed the upper bound', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 2000,
              protein: 130,
              carbohydrates: 280,
              fat: 60,
            ),
          ),
        ],
      );
      expect(result.achievement!.carbohydrates, isFalse);
    });

    test('fails immediately when fat exceeds the upper bound', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 2000,
              protein: 130,
              carbohydrates: 250,
              fat: 70,
            ),
          ),
        ],
      );
      expect(result.achievement!.fat, isFalse);
    });

    test('keeps a lower-bound shortfall pending during the day', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 1800,
              protein: 120,
              carbohydrates: 200,
              fat: 40,
            ),
          ),
        ],
      );
      expect(result.achievement!.calories, isNull);
      expect(result.achievement!.protein, isNull);
      expect(result.achievement!.carbohydrates, isNull);
      expect(result.achievement!.fat, isNull);
    });

    test('zero carbohydrate target is strict by default', () {
      const zeroCarbTarget = Macros(
        calories: 2000,
        protein: 130,
        carbohydrates: 0,
        fat: 60,
      );
      final result = calculate(
        fallbackTarget: zeroCarbTarget,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 2000,
              protein: 130,
              carbohydrates: 3,
              fat: 60,
            ),
          ),
        ],
      );
      expect(result.achievement!.carbohydrates, isFalse);
    });

    test('absolute carbohydrate tolerance allows a small amount', () {
      const zeroCarbTarget = Macros(
        calories: 2000,
        protein: 130,
        carbohydrates: 0,
        fat: 60,
      );
      const custom = DailyNutritionService(
        config: DailyNutritionConfig(minimumCarbohydratesToleranceGrams: 5),
      );
      final result = calculate(
        calculator: custom,
        fallbackTarget: zeroCarbTarget,
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 2000,
              protein: 130,
              carbohydrates: 3,
              fat: 60,
            ),
          ),
        ],
      );
      expect(result.achievement!.carbohydrates, isTrue);
    });

    test('rejects a negative absolute tolerance', () {
      const custom = DailyNutritionService(
        config: DailyNutritionConfig(minimumFatToleranceGrams: -1),
      );
      expect(() => calculate(calculator: custom), throwsArgumentError);
    });

    test('a contradictory invalid planning status is rejected', () {
      expect(
        () => calculate(
          plannedDay: createPlannedDay(targetMacros: target),
          macroStatus: MacroCalculationStatus.invalid,
        ),
        throwsA(isA<DailyNutritionException>()),
      );
    });
  });

  group('DailyNutritionService - statuts métier', () {
    test('un dépassement en cours de journée est exceeded', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 2200,
              protein: 130,
              carbohydrates: 250,
              fat: 60,
              fiber: 30,
            ),
          ),
        ],
      );
      expect(result.goalStatuses!.calories, NutritionGoalStatus.exceeded);
      expect(result.achievement!.calories, isFalse);
    });

    test('un manque en cours de journée est pending', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 500,
              protein: 30,
              carbohydrates: 50,
              fat: 10,
            ),
          ),
        ],
      );
      expect(result.goalStatuses!.calories, NutritionGoalStatus.pending);
      expect(result.allGoalsReached, isNull);
    });

    test('un manque après clôture est missed when meals are recorded', () {
      final result = calculate(
        fallbackTarget: target,
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 500,
              protein: 30,
              carbohydrates: 50,
              fat: 10,
            ),
          ),
        ],
      );
      expect(result.goalStatuses!.protein, NutritionGoalStatus.missed);
      expect(result.allGoalsReached, isFalse);
    });

    test('les fibres obligatoires en attente bloquent allGoalsReached', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [
          createMealWithMacros(
            macrosPer100g: const Macros(
              calories: 2000,
              protein: 130,
              carbohydrates: 250,
              fat: 60,
              fiber: 10,
            ),
          ),
        ],
      );
      expect(result.achievement!.fiber, isNull);
      expect(result.allGoalsReached, isNull);
    });

    test('les fibres sans cible ne bloquent pas allGoalsReached', () {
      const noFiber = Macros(
        calories: 2000,
        protein: 130,
        carbohydrates: 250,
        fat: 60,
      );
      final result = calculate(
        fallbackTarget: noFiber,
        meals: [createMealWithMacros(macrosPer100g: noFiber)],
      );
      expect(result.allGoalsReached, isTrue);
    });

    test('valid sans cible est refusé', () {
      expect(
        () => calculate(
          plannedDay: createPlannedDay(),
          macroStatus: MacroCalculationStatus.valid,
        ),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('warning sans cible est refusé', () {
      expect(
        () => calculate(
          plannedDay: createPlannedDay(),
          macroStatus: MacroCalculationStatus.warning,
        ),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('warning avec cible est conservé', () {
      final result = calculate(
        plannedDay: createPlannedDay(targetMacros: target),
        macroStatus: MacroCalculationStatus.warning,
      );
      expect(result.hasPlanningWarning, isTrue);
      expect(result.targetSource, DailyNutritionTargetSource.plannedDay);
    });

    test('future day without meals has no per-nutrient verdict', () {
      const zeroCarb = Macros(
        calories: 2000,
        protein: 130,
        carbohydrates: 0,
        fat: 60,
      );
      final result = calculate(
        fallbackTarget: zeroCarb,
        asOf: DateTime(2026, 11, 4),
      );
      expect(result.goalStatuses, isNull);
      expect(result.allGoalsReached, isNull);
    });
  });

  group('DailyNutritionService - validation manuelle', () {
    test('une journée sans repas non validée reste inconnue', () {
      final result = calculate(fallbackTarget: target);
      expect(result.isManuallyValidated, isFalse);
      expect(result.allGoalsReached, isNull);
      expect(result.achievement, isNull);
      expect(result.variance, isNull);
    });

    test(
      'une journée sans repas validée est traitée sans réussite nutritionnelle',
      () {
        final result = calculate(
          fallbackTarget: target,
          manualValidation: DailyNutritionValidation(
            userId: 'user-1',
            date: date,
            manuallyValidated: true,
          ),
        );
        expect(result.isManuallyValidated, isTrue);
        expect(result.allGoalsReached, isNull);
        expect(result.hasKnownConsumption, isFalse);
        expect(result.achievement, isNull);
        expect(result.goalStatuses, isNull);
        expect(result.variance, isNull);
        expect(result.consumed.calories, 0);
      },
    );

    test('un repas prime sur une validation manuelle obsolète', () {
      final result = calculate(
        meals: [createMealWithMacros(macrosPer100g: target)],
        fallbackTarget: target,
        manualValidation: DailyNutritionValidation(
          userId: 'user-1',
          date: date,
          manuallyValidated: true,
        ),
      );
      expect(result.isManuallyValidated, isFalse);
      expect(result.hasKnownConsumption, isTrue);
      expect(result.mealCount, 1);
      expect(result.allGoalsReached, isTrue);
    });

    test('une validation manuelle future est ignorée sans exception', () {
      final result = calculate(
        asOf: DateTime(2026, 11, 4),
        manualValidation: DailyNutritionValidation(
          userId: 'user-1',
          date: date,
          manuallyValidated: true,
        ),
      );
      expect(result.isManuallyValidated, isFalse);
      expect(result.allGoalsReached, isNull);
    });

    test('une validation manuelle d’un autre jour est rejetée', () {
      expect(
        () => calculate(
          manualValidation: DailyNutritionValidation(
            userId: 'user-1',
            date: DateTime(2026, 11, 4),
            manuallyValidated: true,
          ),
        ),
        throwsA(
          isA<DailyNutritionException>().having(
            (e) => e.code,
            'code',
            DailyNutritionErrorCode.invalidManualValidation,
          ),
        ),
      );
    });

    test('une validation manuelle sans cible est une réussite déclarée', () {
      final result = calculate(
        manualValidation: DailyNutritionValidation(
          userId: 'user-1',
          date: date,
          manuallyValidated: true,
        ),
      );
      expect(result.hasTarget, isFalse);
      expect(result.allGoalsReached, isNull);
      expect(result.variance, isNull);
    });
  });

  group('Refactoring - statuts et erreurs typées', () {
    test('fourchette satisfaite en cours de journée reste pending', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 5, 12),
        meals: [createMealWithMacros(macrosPer100g: target)],
      );
      expect(result.goalStatuses!.calories, NutritionGoalStatus.pending);
      expect(result.goalStatuses!.carbohydrates, NutritionGoalStatus.pending);
      expect(result.goalStatuses!.fat, NutritionGoalStatus.pending);
      expect(result.achievement!.calories, isNull);
      expect(result.allGoalsReached, isNull);
      expect(result.achievement!.protein, isTrue);
    });

    test('même fourchette atteinte après la fin du jour devient reached', () {
      final result = calculate(
        fallbackTarget: target,
        asOf: DateTime(2026, 11, 6),
        meals: [createMealWithMacros(macrosPer100g: target)],
      );
      expect(result.goalStatuses!.calories, NutritionGoalStatus.reached);
      expect(result.allGoalsReached, isTrue);
    });

    test('repas dupliqués renvoient un code stable', () {
      expect(
        () => calculate(meals: [createMeal(), createMeal()]),
        throwsA(
          isA<DailyNutritionException>().having(
            (e) => e.code,
            'code',
            DailyNutritionErrorCode.duplicateMeal,
          ),
        ),
      );
    });

    test('source planifiée prioritaire avec diagnostic absent ou warning', () {
      for (final status in [
        null,
        MacroCalculationStatus.warning,
        MacroCalculationStatus.valid,
      ]) {
        final result = calculate(
          plannedDay: createPlannedDay(targetMacros: target),
          fallbackTarget: const Macros(
            calories: 1800,
            protein: 100,
            carbohydrates: 220,
            fat: 50,
          ),
          macroStatus: status,
        );
        expect(result.targetSource, DailyNutritionTargetSource.plannedDay);
      }
    });

    test('planning invalid sans cible utilise le fallback', () {
      final result = calculate(
        plannedDay: createPlannedDay(),
        macroStatus: MacroCalculationStatus.invalid,
        fallbackTarget: target,
      );
      expect(result.targetSource, DailyNutritionTargetSource.fallback);
    });
  });
}
