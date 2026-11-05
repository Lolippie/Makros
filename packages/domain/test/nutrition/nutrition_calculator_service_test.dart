import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/nutrition_calculator_service.dart';
import 'package:test/test.dart';

import 'package:makros_nutrition/nutrition/config/nutrition_calculation_config.dart';

void main() {
  const service = NutritionCalculatorService();
  final referenceDate = DateTime(2025, 6, 15);

  UserProfile profile({
    Gender gender = Gender.male,
    ActivityLevel activityLevel = ActivityLevel.sedentary,
    DateTime? birthDate,
    double height = 175,
  }) {
    return UserProfile(
      userId: 'user-1',
      birthDate: birthDate ?? DateTime(1990, 6, 15),
      height: height,
      gender: gender,
      activityLevel: activityLevel,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
  }

  UserGoal goal({
    GoalType type = GoalType.maintenance,
    double? percentage,
    String userId = 'user-1',
  }) {
    return UserGoal(
      id: 'goal-1',
      userId: userId,
      type: type,
      startDate: DateTime(2025),
      calorieAdjustmentPercentage: percentage,
    );
  }

  PlannedActiveDay activeDay({
    DateTime? date,
    bool hasActivity = true,
    SportType? sportType = SportType.running,
    ActivityIntensity? intensity = ActivityIntensity.moderate,
    int? duration = 60,
  }) {
    return PlannedActiveDay(
      id: 'day-1',
      weekPlanId: 'week-1',
      date: date ?? DateTime(2025, 6, 15),
      hasActivity: hasActivity,
      sportType: sportType,
      intensity: intensity,
      plannedDurationMinutes: duration,
    );
  }

  group('calculateRestingEnergyExpenditure', () {
    test(
      'uses the male Mifflin-St Jeor formula with age at reference date',
      () {
        final result = service.calculateRestingEnergyExpenditure(
          profile: profile(),
          weightKg: 70,
          referenceDate: referenceDate,
        );

        expect(result, 1623.75);
      },
    );

    test('uses the female constant', () {
      final result = service.calculateRestingEnergyExpenditure(
        profile: profile(gender: Gender.female),
        weightKg: 70,
        referenceDate: referenceDate,
      );

      expect(result, 1457.75);
    });

    test('does not count a birthday that has not occurred yet', () {
      final result = service.calculateRestingEnergyExpenditure(
        profile: profile(birthDate: DateTime(1990, 6, 16)),
        weightKg: 70,
        referenceDate: referenceDate,
      );

      expect(result, 1628.75);
    });

    test('rejects invalid weight, height, and future birth date', () {
      expect(
        () => service.calculateRestingEnergyExpenditure(
          profile: profile(),
          weightKg: 0,
          referenceDate: referenceDate,
        ),
        throwsArgumentError,
      );
      expect(
        () => service.calculateRestingEnergyExpenditure(
          profile: profile(height: double.infinity),
          weightKg: 70,
          referenceDate: referenceDate,
        ),
        throwsArgumentError,
      );
      expect(
        () => service.calculateRestingEnergyExpenditure(
          profile: profile(birthDate: DateTime(2025, 6, 16)),
          weightKg: 70,
          referenceDate: referenceDate,
        ),
        throwsArgumentError,
      );
    });
  });

  group('daily and session calories', () {
    test('applies the selected non-exercise activity factor', () {
      expect(
        service.calculateDailyBaselineCalories(
          restingEnergyExpenditureKcal: 2000,
          activityLevel: ActivityLevel.sedentary,
        ),
        2400,
      );
    });

    test('calculates net session calories and rejects invalid inputs', () {
      expect(
        service.calculateSessionCalories(
          weightKg: 70,
          durationMinutes: 60,
          metValue: 5,
        ),
        294,
      );
      expect(
        () => service.calculateSessionCalories(
          weightKg: 70,
          durationMinutes: 0,
          metValue: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => service.calculateSessionCalories(
          weightKg: 70,
          durationMinutes: 60,
          metValue: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test(
      'returns a configured MET value and rejects an unknown combination',
      () {
        expect(
          service.getMetValue(
            sportType: SportType.running,
            intensity: ActivityIntensity.moderate,
          ),
          8,
        );
        expect(
          () =>
              NutritionCalculatorService(
                config: const NutritionCalculationConfig(
                  nonExerciseActivityFactors: {},
                  sportMetValues: {},
                ),
              ).getMetValue(
                sportType: SportType.running,
                intensity: ActivityIntensity.moderate,
              ),
          throwsArgumentError,
        );
      },
    );
  });

  group('weekly exercise calories', () {
    test('sums only active days in a seven-day period', () {
      final calories = service.calculateWeeklyExerciseCalories(
        weightKg: 70,
        plannedDays: [
          activeDay(),
          activeDay(date: DateTime(2025, 6, 16), hasActivity: false),
        ],
      );

      expect(calories, 514.5);
    });

    test('rejects duplicate dates, a period longer than a week, and incomplete '
        'active days', () {
      expect(
        () => service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [activeDay(), activeDay()],
        ),
        throwsArgumentError,
      );
      expect(
        () => service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [
            activeDay(),
            activeDay(date: DateTime(2025, 6, 22)),
            activeDay(date: DateTime(2025, 6, 23)),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [activeDay(duration: null)],
        ),
        throwsArgumentError,
      );
    });
  });

  group('goal adjustment and full calculation', () {
    test('uses default and custom cut and bulk adjustments', () {
      expect(service.getAdjustmentPercentage(goal(type: GoalType.cut)), -15);
      expect(
        service.getAdjustmentPercentage(
          goal(type: GoalType.cut, percentage: 20),
        ),
        -20,
      );
      expect(service.getAdjustmentPercentage(goal(type: GoalType.bulk)), 10);
      expect(
        service.getAdjustmentPercentage(
          goal(type: GoalType.bulk, percentage: 5),
        ),
        5,
      );
      expect(
        service.getAdjustmentPercentage(goal(type: GoalType.maintenance)),
        0,
      );
    });

    test('rejects invalid goal adjustments and mismatched users', () {
      expect(
        () => service.getAdjustmentPercentage(
          goal(type: GoalType.cut, percentage: 100),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.getAdjustmentPercentage(
          goal(type: GoalType.bulk, percentage: -1),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.calculate(
          profile: profile(),
          goal: goal(userId: 'another-user'),
          currentWeightKg: 70,
          plannedDays: const [],
          referenceDate: referenceDate,
        ),
        throwsArgumentError,
      );
    });

    test('combines resting, baseline, exercise, and cut adjustment', () {
      final result = service.calculate(
        profile: profile(activityLevel: ActivityLevel.moderatelyActive),
        goal: goal(type: GoalType.cut),
        currentWeightKg: 70,
        plannedDays: [activeDay()],
        referenceDate: referenceDate,
      );

      expect(result.restingEnergyExpenditureKcal, 1623.75);
      expect(result.dailyBaselineCaloriesKcal, 2273.25);
      expect(result.weeklyExerciseCaloriesKcal, 514.5);
      expect(result.averageDailyExerciseCaloriesKcal, 73.5);
      expect(result.maintenanceCaloriesKcal, 2346.75);
      expect(result.adjustmentPercentage, -15);
      expect(result.targetCaloriesKcal, closeTo(1994.7375, 0.0001));
    });

    test(
      'recalculates when the absolute weight change reaches the threshold',
      () {
        expect(
          service.shouldRecalculateForWeightChange(
            currentWeight: 71,
            referenceWeight: 70,
          ),
          isTrue,
        );
        expect(
          service.shouldRecalculateForWeightChange(
            currentWeight: 70.5,
            referenceWeight: 70,
          ),
          isFalse,
        );
        expect(
          service.shouldRecalculateForWeightChange(
            currentWeight: 69,
            referenceWeight: 70,
          ),
          isTrue,
        );
      },
    );
  });
}
