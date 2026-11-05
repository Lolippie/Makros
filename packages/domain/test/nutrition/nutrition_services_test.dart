import 'package:makros_nutrition/nutrition/exceptions/nutrition_planning_exception.dart';
import 'package:makros_models/models.dart';

import 'package:makros_nutrition/nutrition/macro_calculator_service.dart';
import 'package:makros_nutrition/nutrition/nutrition_planning_service.dart';
import 'package:makros_nutrition/nutrition/secondary_nutrition_service.dart';

import 'package:makros_nutrition/nutrition/config/nutrition_planning_config.dart';
import 'package:makros_nutrition/nutrition/config/macro_calculation_config.dart';

import 'package:makros_nutrition/nutrition/results/macro_calculation_result.dart';

import 'package:test/test.dart';

void main() {
  // ==================================================
  // HELPERS
  // ==================================================

  final startDate = DateTime(2024, 12, 30);

  List<PlannedActiveDay> createWeek({
    List<int> activeDays = const [],
    SportType sportType = SportType.gym,
    ActivityIntensity intensity = ActivityIntensity.moderate,
    int durationMinutes = 60,
    DateTime? start,
  }) {
    final firstDay = start ?? startDate;

    return List.generate(7, (index) {
      final isActive = activeDays.contains(index);

      return PlannedActiveDay(
        id: 'day-$index',
        weekPlanId: 'week-1',
        date: DateTime(firstDay.year, firstDay.month, firstDay.day + index),
        hasActivity: isActive,
        sportType: isActive ? sportType : null,
        intensity: isActive ? intensity : null,
        plannedDurationMinutes: isActive ? durationMinutes : null,
      );
    });
  }

  Map<DateTime, double> createReferences({
    double calories = 2000,
    DateTime? start,
  }) {
    final firstDay = start ?? startDate;

    return {
      for (var i = 0; i < 7; i++)
        DateTime(firstDay.year, firstDay.month, firstDay.day + i): calories,
    };
  }

  void expectBudgetPreserved(double reference, double planned) {
    expect(planned, closeTo(reference, 0.000001));
  }

  // ==================================================
  // NUTRITION PLANNING SERVICE
  // ==================================================

  group('NutritionPlanningService', () {
    const service = NutritionPlanningService();

    test('calculates activity scores and ignores inactive days', () {
      final days = createWeek(activeDays: [0], sportType: SportType.running);

      expect(service.calculateActivityScore(day: days[0]), closeTo(1.3, 1e-10));

      expect(service.calculateActivityScore(day: days[1]), 0.0);
    });

    test('calculates activity score according to duration', () {
      final days = createWeek(
        activeDays: [0],
        sportType: SportType.gym,
        durationMinutes: 90,
      );

      expect(service.calculateActivityScore(day: days[0]), closeTo(1.5, 1e-10));
    });

    test('caps activity score at configured maximum', () {
      final days = createWeek(
        activeDays: [0],
        sportType: SportType.running,
        durationMinutes: 180,
      );

      expect(service.calculateActivityScore(day: days[0]), 2.0);
    });

    test('rejects invalid activity duration', () {
      final days = createWeek(activeDays: [0], durationMinutes: 0);

      expect(
        () => service.calculateActivityScore(day: days[0]),
        throwsA(
          isA<NutritionPlanningException>().having(
            (error) => error.code,
            'code',
            NutritionPlanningErrorCode.invalidActivityDuration,
          ),
        ),
      );
    });

    test('creates a valid seven-day plan without exceeding limits', () {
      final result = service.calculateWeeklyPlan(
        days: createWeek(activeDays: [0], sportType: SportType.running),
        referenceCaloriesByDate: createReferences(),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      expect(result.days.length, 7);

      expect(result.totalReferenceCalories, closeTo(14000, 1e-9));

      expectBudgetPreserved(
        result.totalReferenceCalories,
        result.totalPlannedCalories,
      );

      for (final day in result.days) {
        expect(day.plannedCalories, inInclusiveRange(1800, 2200));
        expect(day.targetMacros, isNotNull);
        expect(day.macroStatus, MacroCalculationStatus.valid);
      }
    });

    test('does not redistribute calories when all days are inactive', () {
      final result = service.calculateWeeklyPlan(
        days: createWeek(),
        referenceCaloriesByDate: createReferences(),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      for (final day in result.days) {
        expect(day.plannedCalories, closeTo(2000, 1e-9));
        expect(day.calorieAdjustment, closeTo(0, 1e-9));
      }

      expectBudgetPreserved(
        result.totalReferenceCalories,
        result.totalPlannedCalories,
      );
    });

    test('does not redistribute calories when all scores are equal', () {
      final result = service.calculateWeeklyPlan(
        days: createWeek(activeDays: [0, 1, 2, 3, 4, 5, 6]),
        referenceCaloriesByDate: createReferences(),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      for (final day in result.days) {
        expect(day.plannedCalories, closeTo(2000, 1e-9));
      }
    });

    test('gives more calories to active days', () {
      final result = service.calculateWeeklyPlan(
        days: createWeek(activeDays: [0, 2, 4, 6]),
        referenceCaloriesByDate: createReferences(),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      expect(
        result.days[0].plannedCalories,
        greaterThan(result.days[1].plannedCalories),
      );

      expectBudgetPreserved(
        result.totalReferenceCalories,
        result.totalPlannedCalories,
      );
    });

    test('respects a custom daily calorie limit', () {
      const customService = NutritionPlanningService(
        config: NutritionPlanningConfig(
          maxDailyVariationFraction: 0.50,
          maxDailyVariationCalories: 40,
        ),
      );

      final result = customService.calculateWeeklyPlan(
        days: createWeek(
          activeDays: [0],
          sportType: SportType.running,
          durationMinutes: 180,
        ),
        referenceCaloriesByDate: createReferences(),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      for (final day in result.days) {
        expect(day.calorieAdjustment.abs(), lessThanOrEqualTo(40.000001));
      }

      expectBudgetPreserved(
        result.totalReferenceCalories,
        result.totalPlannedCalories,
      );
    });

    test('preserves the budget with changing reference calories', () {
      final references = createReferences();

      for (var i = 3; i < 7; i++) {
        references[DateTime(2024, 12, 30 + i)] = 2100;
      }

      final result = service.calculateWeeklyPlan(
        days: createWeek(activeDays: [0, 2, 4, 6]),
        referenceCaloriesByDate: references,
        weightKg: 65,
        goalType: GoalType.cut,
      );

      expect(result.totalReferenceCalories, closeTo(14400, 1e-9));

      expectBudgetPreserved(
        result.totalReferenceCalories,
        result.totalPlannedCalories,
      );
    });

    test('calculates expected macro targets', () {
      final result = service.calculateWeeklyPlan(
        days: createWeek(),
        referenceCaloriesByDate: createReferences(),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      final macros = result.days.first.targetMacros!;

      expect(macros.calories, closeTo(2000, 1e-9));
      expect(macros.protein, closeTo(130, 1e-9));
      expect(macros.fat, closeTo(52, 1e-9));
      expect(macros.carbohydrates, closeTo(253, 1e-9));
    });

    test('does not redistribute below minimum macro calories', () {
      final result = service.calculateWeeklyPlan(
        days: createWeek(activeDays: [0, 2, 4, 6]),
        referenceCaloriesByDate: createReferences(calories: 1000),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      for (final day in result.days) {
        expect(day.plannedCalories, greaterThanOrEqualTo(988 - 0.000001));
      }

      expectBudgetPreserved(
        result.totalReferenceCalories,
        result.totalPlannedCalories,
      );
    });

    test('reports invalid macros when initial calories are insufficient', () {
      final result = service.calculateWeeklyPlan(
        days: createWeek(),
        referenceCaloriesByDate: createReferences(calories: 900),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      expect(result.hasInvalidMacros, isTrue);

      for (final day in result.days) {
        expect(day.targetMacros, isNull);
        expect(day.macroStatus, MacroCalculationStatus.invalid);
        expect(
          day.macroIssues,
          contains(MacroCalculationIssue.insufficientCalories),
        );
      }
    });

    test('rejects fewer than seven days', () {
      expect(
        () => service.calculateWeeklyPlan(
          days: createWeek().take(6).toList(),
          referenceCaloriesByDate: createReferences(),
          weightKg: 65,
          goalType: GoalType.cut,
        ),
        throwsA(
          isA<NutritionPlanningException>().having(
            (error) => error.code,
            'code',
            NutritionPlanningErrorCode.invalidDayCount,
          ),
        ),
      );
    });

    test('rejects missing reference calories', () {
      expect(
        () => service.calculateWeeklyPlan(
          days: createWeek(),
          referenceCaloriesByDate: {DateTime(2024, 12, 30): 2000},
          weightKg: 65,
          goalType: GoalType.cut,
        ),
        throwsA(
          isA<NutritionPlanningException>().having(
            (error) => error.code,
            'code',
            NutritionPlanningErrorCode.missingReference,
          ),
        ),
      );
    });

    test('rejects duplicate dates', () {
      final days = createWeek();

      final duplicate = PlannedActiveDay(
        id: 'duplicate',
        weekPlanId: 'week-1',
        date: days.first.date,
        hasActivity: false,
      );

      days[1] = duplicate;

      expect(
        () => service.calculateWeeklyPlan(
          days: days,
          referenceCaloriesByDate: createReferences(),
          weightKg: 65,
          goalType: GoalType.cut,
        ),
        throwsA(
          isA<NutritionPlanningException>().having(
            (error) => error.code,
            'code',
            NutritionPlanningErrorCode.duplicateDay,
          ),
        ),
      );
    });

    test('rejects invalid weight', () {
      expect(
        () => service.calculateWeeklyPlan(
          days: createWeek(),
          referenceCaloriesByDate: createReferences(),
          weightKg: double.nan,
          goalType: GoalType.cut,
        ),
        throwsArgumentError,
      );
    });

    test('does not mutate the input days', () {
      final days = createWeek().reversed.toList();
      final originalIds = days.map((day) => day.id).toList();

      service.calculateWeeklyPlan(
        days: days,
        referenceCaloriesByDate: createReferences(),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      expect(days.map((day) => day.id).toList(), originalIds);
    });

    test('returns immutable result collections', () {
      final result = service.calculateWeeklyPlan(
        days: createWeek(),
        referenceCaloriesByDate: createReferences(),
        weightKg: 65,
        goalType: GoalType.cut,
      );

      expect(() => result.days.clear(), throwsUnsupportedError);

      expect(
        () => result.days.first.macroIssues.clear(),
        throwsUnsupportedError,
      );
    });
  });

  // ==================================================
  // MACRO CALCULATOR SERVICE
  // ==================================================

  group('MacroCalculatorService', () {
    const service = MacroCalculatorService();

    test('calculates valid macro targets for maintenance', () {
      final result = service.calculate(
        weightKg: 70,
        targetCalories: 2500,
        goalType: GoalType.maintenance,
      );

      expect(result.status, MacroCalculationStatus.valid);
      expect(result.macros, isNotNull);
      expect(result.macros!.protein, closeTo(126.0, 1e-9));
      expect(result.macros!.fat, closeTo(63.0, 1e-9));
      expect(result.macros!.carbohydrates, closeTo(357.25, 1e-9));
    });

    test('calculates minimum macro calories', () {
      final minimum = service.calculateMinimumCalories(
        weightKg: 65,
        goalType: GoalType.cut,
      );

      expect(minimum, closeTo(988, 1e-9));
    });

    test('marks insufficient calories as invalid', () {
      final result = service.calculate(
        weightKg: 70,
        targetCalories: 500,
        goalType: GoalType.cut,
      );

      expect(result.status, MacroCalculationStatus.invalid);
      expect(
        result.issues,
        contains(MacroCalculationIssue.insufficientCalories),
      );
    });

    test('warns when carbohydrates are too low', () {
      final result = service.calculate(
        weightKg: 65,
        targetCalories: 1100,
        goalType: GoalType.cut,
      );

      expect(result.status, MacroCalculationStatus.warning);
      expect(result.issues, contains(MacroCalculationIssue.lowCarbohydrates));
    });

    test('rejects invalid numeric inputs', () {
      expect(
        () => service.calculate(
          weightKg: 0,
          targetCalories: 2000,
          goalType: GoalType.maintenance,
        ),
        throwsArgumentError,
      );

      expect(
        () => service.calculate(
          weightKg: 70,
          targetCalories: 0,
          goalType: GoalType.maintenance,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an invalid carbohydrate warning threshold', () {
      const invalidService = MacroCalculatorService(
        config: MacroCalculationConfig(carbohydrateWarningPerKg: -1),
      );

      expect(
        () => invalidService.calculate(
          weightKg: 65,
          targetCalories: 2000,
          goalType: GoalType.cut,
        ),
        throwsArgumentError,
      );
    });

    test('accepts a zero carbohydrate warning threshold', () {
      const customService = MacroCalculatorService(
        config: MacroCalculationConfig(carbohydrateWarningPerKg: 0),
      );

      final result = customService.calculate(
        weightKg: 65,
        targetCalories: 1100,
        goalType: GoalType.cut,
      );

      expect(result.status, MacroCalculationStatus.valid);
    });

    test('accepts tiny negative remaining calories within tolerance', () {
      final minimum = service.calculateMinimumCalories(
        weightKg: 65,
        goalType: GoalType.cut,
      );

      final result = service.calculate(
        weightKg: 65,
        targetCalories: minimum - 0.0005,
        goalType: GoalType.cut,
      );

      expect(result.status, MacroCalculationStatus.warning);
      expect(result.macros, isNotNull);
      expect(result.macros!.carbohydrates, 0);
    });
  });

  // ==================================================
  // SECONDARY NUTRITION SERVICE
  // ==================================================

  group('SecondaryNutritionService', () {
    const service = SecondaryNutritionService();

    test('calculates daily nutritional reference values', () {
      final result = service.calculate(targetCalories: 2000);

      expect(result.fiber, 30.0);
      expect(result.freeSugars, closeTo(50.0, 1e-9));
      expect(result.saturatedFat, closeTo(22.2222222222, 1e-9));
      expect(result.transFat, closeTo(2.2222222222, 1e-9));
      expect(result.salt, 5.0);
      expect(result.potassium, 3510.0);
    });

    test('compares a value to a reference and handles unknown values', () {
      expect(
        service.compareToReference(consumed: 10, reference: 20),
        NutritionComparison.below,
      );

      expect(
        service.compareToReference(consumed: 20, reference: 20),
        NutritionComparison.reached,
      );

      expect(
        service.compareToReference(consumed: 30, reference: 20),
        NutritionComparison.exceeded,
      );

      expect(
        service.compareToReference(consumed: null, reference: 20),
        NutritionComparison.unknown,
      );

      expect(
        service.compareToReference(consumed: double.nan, reference: 20),
        NutritionComparison.unknown,
      );
    });

    test('checks minimum and maximum thresholds correctly', () {
      expect(service.isMinimumAchieved(consumed: 25, reference: 30), isFalse);

      expect(service.isMinimumAchieved(consumed: 30, reference: 30), isTrue);

      expect(service.isMaximumRespected(consumed: 5, reference: 5), isTrue);

      expect(service.isMaximumRespected(consumed: 6, reference: 5), isFalse);

      expect(service.isMaximumRespected(consumed: null, reference: 5), isNull);
    });
  });
}
