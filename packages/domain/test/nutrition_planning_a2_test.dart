import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/config/nutrition_planning_config.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_service.dart';
import 'package:makros_nutrition/nutrition/exceptions/nutrition_planning_exception.dart';
import 'package:makros_nutrition/nutrition/macro_calculator_service.dart';
import 'package:makros_nutrition/nutrition/nutrition_planning_service.dart';
import 'package:makros_nutrition/nutrition/results/macro_calculation_result.dart';
import 'package:makros_nutrition/nutrition/results/nutrition_planning_result.dart';
import 'package:test/test.dart';

void main() {
  final monday = DateTime(2026, 11, 2);
  final dates = List.generate(7, (i) => monday.add(Duration(days: i)));

  PlannedActiveDay day(int index, {bool active = false, int? minutes}) =>
      PlannedActiveDay(
        id: 'day-$index',
        weekPlanId: 'week-1',
        date: dates[index],
        hasActivity: active,
        sportType: active ? SportType.gym : null,
        plannedDurationMinutes: minutes,
      );

  List<PlannedActiveDay> schedule({int activeIndex = 6}) => [
    for (var i = 0; i < 7; i++) day(i, active: i == activeIndex),
  ];

  Map<DateTime, double> references(double calories) => {
    for (final date in dates) date: calories,
  };

  test('A2 : une référence déjà insuffisante ne baisse pas', () {
    const calculator = MacroCalculatorService();
    final minimum = calculator.calculateMinimumCalories(
      weightKg: 70,
      goalType: GoalType.cut,
    );
    final refs = references(minimum + 400);
    refs[dates[0]] = minimum - 50;
    final result = const NutritionPlanningService().calculateWeeklyPlan(
      days: schedule(),
      referenceCaloriesByDate: refs,
      weightKg: 70,
      goalType: GoalType.cut,
    );
    expect(result.days[0].plannedCalories, refs[dates[0]]);
    expect(
      result.redistributionLimitedBy,
      RedistributionLimitReason.minimumCalories,
    );
    expect(result.appliedScale, 0);
    expect(result.limitingDate, DateTime.utc(2026, 11, 2));
    expect(result.days[0].macroStatus, MacroCalculationStatus.invalid);
    expect(result.days[0].targetMacros, isNull);
    expect(result.days.every((d) => d.calorieAdjustment.abs() < 1e-8), isTrue);
  });

  test('Une journée initialement réalisable reste non invalide', () {
    const service = NutritionPlanningService();
    const calculator = MacroCalculatorService();
    for (final goal in GoalType.values) {
      for (final weight in [50.0, 70.0, 100.0]) {
        final minimum = calculator.calculateMinimumCalories(
          weightKg: weight,
          goalType: goal,
        );
        for (final margin in [0.0, 1e-7, 20.0, 250.0]) {
          final refs = references(minimum + margin);
          final result = service.calculateWeeklyPlan(
            days: schedule(),
            referenceCaloriesByDate: refs,
            weightKg: weight,
            goalType: goal,
          );
          for (final d in result.days) {
            expect(d.macroStatus, isNot(MacroCalculationStatus.invalid));
            expect(d.targetMacros, isNotNull);
          }
          expect(
            result.totalPlannedCalories,
            closeTo(result.totalReferenceCalories, 1e-7),
          );
        }
      }
    }
  });

  test('Contrat entre planning et DailyNutritionService', () {
    const planning = NutritionPlanningService();
    const daily = DailyNutritionService();
    const calculator = MacroCalculatorService();
    final minimum = calculator.calculateMinimumCalories(
      weightKg: 70,
      goalType: GoalType.cut,
    );
    final refs = references(minimum + 300);
    refs[dates[0]] = minimum - 50;
    final plan = planning.calculateWeeklyPlan(
      days: schedule(),
      referenceCaloriesByDate: refs,
      weightKg: 70,
      goalType: GoalType.cut,
    );
    for (var i = 0; i < 7; i++) {
      final entry = plan.days[i];
      expect(
        entry.macroStatus == MacroCalculationStatus.invalid,
        entry.targetMacros == null,
      );
      final plannedDay = PlannedActiveDay(
        id: 'day-$i',
        weekPlanId: 'week-1',
        date: entry.date,
        hasActivity: i == 6,
        targetMacros: entry.targetMacros,
      );
      final result = daily.calculate(
        userId: 'user-1',
        date: entry.date,
        meals: const [],
        plannedDay: plannedDay,
        macroStatus: entry.macroStatus,
        asOf: DateTime(2026, 11, 10),
      );
      expect(result.macroStatus, entry.macroStatus);
    }
  });

  test('Configuration : fraction supérieure à 1 refusée', () {
    const service = NutritionPlanningService(
      config: NutritionPlanningConfig(maxDailyVariationFraction: 1.1),
    );
    expect(
      () => service.calculateActivityScore(day: day(0)),
      throwsArgumentError,
    );
  });

  test('Dates persistées incohérentes : exception typée', () {
    final duplicated = schedule();
    duplicated[1] = day(0);
    expect(
      () => const NutritionPlanningService().calculateWeeklyPlan(
        days: duplicated,
        referenceCaloriesByDate: references(2200),
        weightKg: 70,
        goalType: GoalType.maintenance,
      ),
      throwsA(
        isA<NutritionPlanningException>().having(
          (e) => e.code,
          'code',
          NutritionPlanningErrorCode.duplicateDay,
        ),
      ),
    );
  });

  test('plafond journalier exposé dans le diagnostic', () {
    const service = NutritionPlanningService(
      config: NutritionPlanningConfig(maxDailyVariationCalories: 10),
    );
    final result = service.calculateWeeklyPlan(
      days: schedule(),
      referenceCaloriesByDate: references(2500),
      weightKg: 70,
      goalType: GoalType.maintenance,
    );
    expect(
      result.redistributionLimitedBy,
      RedistributionLimitReason.dailyLimit,
    );
    expect(result.appliedScale, lessThan(result.requestedScale));
    expect(result.limitingDate, isNotNull);
    expect(
      result.totalPlannedCalories,
      closeTo(result.totalReferenceCalories, 1e-7),
    );
  });

  test('sans différence de score : pas de limitation', () {
    final result = const NutritionPlanningService().calculateWeeklyPlan(
      days: [for (var i = 0; i < 7; i++) day(i)],
      referenceCaloriesByDate: references(2300),
      weightKg: 70,
      goalType: GoalType.maintenance,
    );
    expect(result.redistributionLimitedBy, RedistributionLimitReason.none);
    expect(result.limitingDate, isNull);
    expect(result.totalPlannedCalories, result.totalReferenceCalories);
  });

  test('semaine commençant un mercredi refusée', () {
    final shifted = [
      for (var i = 0; i < 7; i++)
        PlannedActiveDay(
          id: 'shift-$i',
          weekPlanId: 'shift',
          date: DateTime(2026, 11, 4 + i),
          hasActivity: false,
        ),
    ];
    expect(
      () => const NutritionPlanningService().calculateWeeklyPlan(
        days: shifted,
        referenceCaloriesByDate: {for (final d in shifted) d.date: 2200},
        weightKg: 70,
        goalType: GoalType.maintenance,
      ),
      throwsA(
        isA<NutritionPlanningException>().having(
          (e) => e.code,
          'code',
          NutritionPlanningErrorCode.invalidWeekStart,
        ),
      ),
    );
  });

  test('Références supplémentaires validées puis ignorées', () {
    final refs = references(2200);
    refs[DateTime(2026, 11, 15)] = 2400;
    final result = const NutritionPlanningService().calculateWeeklyPlan(
      days: schedule(),
      referenceCaloriesByDate: refs,
      weightKg: 70,
      goalType: GoalType.maintenance,
    );
    expect(result.days, hasLength(7));
  });
}
