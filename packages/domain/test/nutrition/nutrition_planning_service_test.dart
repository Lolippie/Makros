import 'package:makros_nutrition/nutrition/exceptions/nutrition_planning_exception.dart';
import 'package:makros_nutrition/nutrition/config/nutrition_planning_config.dart';
import 'package:makros_nutrition/nutrition/nutrition_planning_service.dart';
import 'package:makros_nutrition/nutrition/results/macro_calculation_result.dart';
import 'package:makros_nutrition/nutrition/results/nutrition_planning_result.dart';
import 'package:test/test.dart';

import 'package:makros_models/models.dart';

void main() {
  group('NutritionPlanningService', () {
    const service = NutritionPlanningService();

    final monday = DateTime(2026, 11, 2);

    // --------------------------------------------------
    // Helpers
    // --------------------------------------------------

    List<PlannedActiveDay> createDays({
      List<SportType?>? sports,
      List<int?>? durations,
      List<bool>? activities,
      DateTime? startDate,
    }) {
      final start = startDate ?? monday;

      return List.generate(7, (index) {
        final sport = sports?[index];
        final hasActivity = activities?[index] ?? sport != null;

        return PlannedActiveDay(
          id: 'day-$index',
          weekPlanId: 'week-1',
          date: start.add(Duration(days: index)),
          hasActivity: hasActivity,
          sportType: sport,
          plannedDurationMinutes: durations?[index],
        );
      });
    }

    Map<DateTime, double> createReferences({
      double calories = 2000,
      DateTime? startDate,
    }) {
      final start = startDate ?? monday;

      return {
        for (var i = 0; i < 7; i++) start.add(Duration(days: i)): calories,
      };
    }

    NutritionPlanningResult calculate({
      required List<PlannedActiveDay> days,
      Map<DateTime, double>? references,
      double weightKg = 65,
      GoalType goalType = GoalType.cut,
      NutritionPlanningService planningService = service,
    }) {
      return planningService.calculateWeeklyPlan(
        days: days,
        referenceCaloriesByDate: references ?? createReferences(),
        weightKg: weightKg,
        goalType: goalType,
      );
    }

    void expectWeeklyBudgetPreserved(NutritionPlanningResult result) {
      expect(
        result.totalPlannedCalories,
        closeTo(result.totalReferenceCalories, 0.000001),
      );
    }

    void expectDailyLimitsRespected(
      NutritionPlanningResult result, {
      double fraction = 0.10,
      double absoluteLimit = 250,
    }) {
      for (final day in result.days) {
        final limit = day.referenceCalories * fraction < absoluteLimit
            ? day.referenceCalories * fraction
            : absoluteLimit;

        expect(
          day.calorieAdjustment.abs(),
          lessThanOrEqualTo(limit + 0.000001),
        );
      }
    }

    // --------------------------------------------------
    // 1. Scores d'activité
    // --------------------------------------------------

    group('calculateActivityScore', () {
      test('retourne 0 pour une journée de repos', () {
        final day = createDays().first;

        expect(service.calculateActivityScore(day: day), 0);
      });

      test('calcule 1 pour 60 minutes de musculation', () {
        final day = createDays(
          sports: [SportType.gym, null, null, null, null, null, null],
          durations: [60, null, null, null, null, null, null],
        ).first;

        expect(
          service.calculateActivityScore(day: day),
          closeTo(1.0, 0.000001),
        );
      });

      test('calcule 1.5 pour 90 minutes de musculation', () {
        final day = createDays(
          sports: [SportType.gym, null, null, null, null, null, null],
          durations: [90, null, null, null, null, null, null],
        ).first;

        expect(
          service.calculateActivityScore(day: day),
          closeTo(1.5, 0.000001),
        );
      });

      test('applique le coefficient de marche', () {
        final day = createDays(
          sports: [SportType.walking, null, null, null, null, null, null],
          durations: [60, null, null, null, null, null, null],
        ).first;

        expect(
          service.calculateActivityScore(day: day),
          closeTo(0.5, 0.000001),
        );
      });

      test('plafonne le score d’une activité longue', () {
        final day = createDays(
          sports: [SportType.running, null, null, null, null, null, null],
          durations: [180, null, null, null, null, null, null],
        ).first;

        expect(service.calculateActivityScore(day: day), 2.0);
      });

      test('utilise la durée par défaut si absente', () {
        final day = createDays(
          sports: [SportType.gym, null, null, null, null, null, null],
        ).first;

        expect(service.calculateActivityScore(day: day), 1.0);
      });

      test('rejette une durée nulle pour une activité', () {
        final day = createDays(
          sports: [SportType.gym, null, null, null, null, null, null],
          durations: [0, null, null, null, null, null, null],
        ).first;

        expect(
          () => service.calculateActivityScore(day: day),
          throwsA(
            isA<NutritionPlanningException>().having(
              (error) => error.code,
              'code',
              NutritionPlanningErrorCode.invalidActivityDuration,
            ),
          ),
        );
      });

      test('rejette une durée négative', () {
        final day = createDays(
          sports: [SportType.gym, null, null, null, null, null, null],
          durations: [-30, null, null, null, null, null, null],
        ).first;

        expect(
          () => service.calculateActivityScore(day: day),
          throwsA(
            isA<NutritionPlanningException>().having(
              (error) => error.code,
              'code',
              NutritionPlanningErrorCode.invalidActivityDuration,
            ),
          ),
        );
      });
    });

    // --------------------------------------------------
    // 2. Redistribution calorique
    // --------------------------------------------------

    group('calculateWeeklyPlan - redistribution', () {
      test('ne modifie pas les calories si tous les jours sont au repos', () {
        final result = calculate(days: createDays());

        for (final day in result.days) {
          expect(day.plannedCalories, closeTo(2000, 0.000001));
          expect(day.calorieAdjustment, closeTo(0, 0.000001));
        }

        expectWeeklyBudgetPreserved(result);
      });

      test('ne redistribue rien si tous les scores sont identiques', () {
        final result = calculate(
          days: createDays(
            sports: List.filled(7, SportType.gym),
            durations: List.filled(7, 60),
          ),
        );

        for (final day in result.days) {
          expect(day.plannedCalories, closeTo(2000, 0.000001));
        }

        expectWeeklyBudgetPreserved(result);
      });

      test('redistribue selon 4 jours sportifs et 3 jours de repos', () {
        final result = calculate(
          days: createDays(
            sports: [
              SportType.gym,
              null,
              SportType.gym,
              null,
              SportType.gym,
              null,
              SportType.gym,
            ],
            durations: [60, null, 60, null, 60, null, 60],
          ),
        );

        // Score moyen = 4 / 7.
        // Sport : 2000 + 150 * (1 - 4/7)
        // Repos : 2000 + 150 * (0 - 4/7)
        final sportCalories = 2000 + 150 * (3 / 7);
        final restCalories = 2000 - 150 * (4 / 7);

        for (var i = 0; i < 7; i++) {
          expect(
            result.days[i].plannedCalories,
            closeTo(i.isEven ? sportCalories : restCalories, 0.000001),
          );
        }

        expectWeeklyBudgetPreserved(result);
        expectDailyLimitsRespected(result);
      });

      test('une activité plus intense reçoit davantage de calories', () {
        final result = calculate(
          days: createDays(
            sports: [
              SportType.running,
              SportType.walking,
              null,
              null,
              null,
              null,
              null,
            ],
            durations: [60, 60, null, null, null, null, null],
          ),
        );

        expect(
          result.days[0].plannedCalories,
          greaterThan(result.days[1].plannedCalories),
        );

        expect(
          result.days[1].plannedCalories,
          greaterThan(result.days[2].plannedCalories),
        );

        expectWeeklyBudgetPreserved(result);
      });

      test('des scores proches entraînent de petites variations', () {
        const customService = NutritionPlanningService(
          config: NutritionPlanningConfig(gymWeight: 1.0, runningWeight: 1.01),
        );

        final result = calculate(
          planningService: customService,
          days: createDays(
            sports: [
              SportType.running,
              SportType.gym,
              SportType.gym,
              SportType.gym,
              SportType.gym,
              SportType.gym,
              SportType.gym,
            ],
            durations: List.filled(7, 60),
          ),
        );

        for (final day in result.days) {
          expect(day.calorieAdjustment.abs(), lessThan(2));
        }

        expectWeeklyBudgetPreserved(result);
      });

      test('respecte les plafonds journaliers', () {
        final result = calculate(
          days: createDays(
            sports: [SportType.running, null, null, null, null, null, null],
            durations: [180, null, null, null, null, null, null],
          ),
        );

        expectDailyLimitsRespected(result);
        expectWeeklyBudgetPreserved(result);
      });

      test('respecte un plafond absolu personnalisé', () {
        const customService = NutritionPlanningService(
          config: NutritionPlanningConfig(
            maxDailyVariationFraction: 0.50,
            maxDailyVariationCalories: 40,
          ),
        );

        final result = calculate(
          planningService: customService,
          days: createDays(
            sports: [SportType.running, null, null, null, null, null, null],
            durations: [180, null, null, null, null, null, null],
          ),
        );

        expectDailyLimitsRespected(result, fraction: 0.50, absoluteLimit: 40);

        expectWeeklyBudgetPreserved(result);
      });

      test('une intensité de redistribution nulle ne change rien', () {
        const customService = NutritionPlanningService(
          config: NutritionPlanningConfig(caloriesPerActivityScorePoint: 0),
        );

        final result = calculate(
          planningService: customService,
          days: createDays(
            sports: [SportType.gym, null, null, null, null, null, null],
          ),
        );

        for (final day in result.days) {
          expect(day.plannedCalories, closeTo(2000, 0.000001));
        }
      });
    });

    // --------------------------------------------------
    // 3. Calories de référence variables
    // --------------------------------------------------

    group('calculateWeeklyPlan - transitions', () {
      test('conserve un budget avec références variables', () {
        final days = createDays(
          sports: [
            SportType.gym,
            null,
            SportType.gym,
            null,
            SportType.gym,
            null,
            SportType.gym,
          ],
        );

        final references = <DateTime, double>{
          for (var i = 0; i < 7; i++)
            monday.add(Duration(days: i)): i < 3 ? 2100.0 : 2000.0,
        };

        final result = calculate(days: days, references: references);

        expect(result.totalReferenceCalories, closeTo(14300, 0.000001));

        expectWeeklyBudgetPreserved(result);
        expectDailyLimitsRespected(result);
      });

      test('accepte des dates avec des heures différentes', () {
        final days = createDays();

        final references = <DateTime, double>{
          for (var i = 0; i < 7; i++) DateTime(2026, 11, 2 + i, 18, 30): 2000,
        };

        final result = calculate(days: days, references: references);

        expect(result.days.length, 7);
        expectWeeklyBudgetPreserved(result);
      });

      test('trie les journées chronologiquement', () {
        final days = createDays().reversed.toList();

        final result = calculate(days: days);

        for (var i = 0; i < 7; i++) {
          expect(result.days[i].date, DateTime.utc(2026, 11, 2 + i));
        }
      });
    });

    // --------------------------------------------------
    // 4. Faisabilité des macros
    // --------------------------------------------------

    group('calculateWeeklyPlan - macros', () {
      test('calcule des macros pour chaque journée valide', () {
        final result = calculate(days: createDays());

        for (final day in result.days) {
          expect(day.targetMacros, isNotNull);
          expect(day.macroStatus, MacroCalculationStatus.valid);

          final macros = day.targetMacros!;

          expect(macros.calories, closeTo(day.plannedCalories, 0.000001));
          expect(macros.protein, closeTo(130, 0.000001));
          expect(macros.fat, closeTo(52, 0.000001));
          expect(macros.carbohydrates, closeTo(253, 0.000001));
        }
      });

      test('ne descend pas sous le minimum des protéines et lipides', () {
        final references = createReferences(calories: 1000);

        final result = calculate(
          days: createDays(
            sports: [
              SportType.gym,
              null,
              SportType.gym,
              null,
              SportType.gym,
              null,
              SportType.gym,
            ],
          ),
          references: references,
        );

        for (final day in result.days) {
          expect(day.plannedCalories, greaterThanOrEqualTo(988 - 0.000001));
        }

        expectWeeklyBudgetPreserved(result);
      });

      test('signale une référence initialement insuffisante', () {
        final result = calculate(
          days: createDays(),
          references: createReferences(calories: 900),
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

      test('conserve les avertissements sur les glucides', () {
        final result = calculate(
          days: createDays(),
          references: createReferences(calories: 1100),
        );

        expect(result.hasMacroWarnings, isTrue);

        for (final day in result.days) {
          expect(day.targetMacros, isNotNull);
          expect(day.macroStatus, MacroCalculationStatus.warning);
          expect(
            day.macroIssues,
            contains(MacroCalculationIssue.lowCarbohydrates),
          );
        }
      });

      test('les macros respectent la répartition énergétique', () {
        final result = calculate(
          days: createDays(
            sports: [
              SportType.gym,
              null,
              SportType.gym,
              null,
              SportType.gym,
              null,
              SportType.gym,
            ],
          ),
        );

        for (final day in result.days) {
          final macros = day.targetMacros!;

          final reconstructedCalories =
              macros.protein * 4 + macros.carbohydrates * 4 + macros.fat * 9;

          expect(reconstructedCalories, closeTo(day.plannedCalories, 0.001));
        }
      });
    });

    // --------------------------------------------------
    // 5. Validations
    // --------------------------------------------------

    group('calculateWeeklyPlan - validations', () {
      test('rejette moins de sept journées', () {
        expect(
          () => calculate(days: createDays().take(6).toList()),
          throwsA(
            isA<NutritionPlanningException>().having(
              (error) => error.code,
              'code',
              NutritionPlanningErrorCode.invalidDayCount,
            ),
          ),
        );
      });

      test('rejette les dates dupliquées', () {
        final days = createDays();
        final duplicateDays = [...days];

        duplicateDays[1] = PlannedActiveDay(
          id: 'duplicate',
          weekPlanId: 'week-1',
          date: days[0].date,
          hasActivity: false,
        );

        expect(
          () => calculate(days: duplicateDays),
          throwsA(
            isA<NutritionPlanningException>().having(
              (error) => error.code,
              'code',
              NutritionPlanningErrorCode.duplicateDay,
            ),
          ),
        );
      });

      test('rejette les journées non consécutives', () {
        final days = createDays();

        final invalidDays = [...days];

        invalidDays[6] = PlannedActiveDay(
          id: 'last-day',
          weekPlanId: 'week-1',
          date: monday.add(const Duration(days: 8)),
          hasActivity: false,
        );

        expect(
          () => calculate(days: invalidDays),
          throwsA(
            isA<NutritionPlanningException>().having(
              (error) => error.code,
              'code',
              NutritionPlanningErrorCode.nonConsecutiveDays,
            ),
          ),
        );
      });

      test('rejette une référence manquante', () {
        final references = createReferences();
        references.remove(monday);

        expect(
          () => calculate(days: createDays(), references: references),
          throwsA(
            isA<NutritionPlanningException>().having(
              (error) => error.code,
              'code',
              NutritionPlanningErrorCode.missingReference,
            ),
          ),
        );
      });

      test('rejette un poids négatif', () {
        expect(
          () => calculate(days: createDays(), weightKg: -65),
          throwsArgumentError,
        );
      });

      test('rejette un poids NaN', () {
        expect(
          () => calculate(days: createDays(), weightKg: double.nan),
          throwsArgumentError,
        );
      });

      test('rejette des calories négatives', () {
        expect(
          () => calculate(
            days: createDays(),
            references: createReferences(calories: -100),
          ),
          throwsA(
            isA<NutritionPlanningException>().having(
              (error) => error.code,
              'code',
              NutritionPlanningErrorCode.invalidReference,
            ),
          ),
        );
      });

      test('rejette des calories infinies', () {
        expect(
          () => calculate(
            days: createDays(),
            references: createReferences(calories: double.infinity),
          ),
          throwsA(
            isA<NutritionPlanningException>().having(
              (error) => error.code,
              'code',
              NutritionPlanningErrorCode.invalidReference,
            ),
          ),
        );
      });

      test('rejette une configuration invalide', () {
        const invalidService = NutritionPlanningService(
          config: NutritionPlanningConfig(caloriesPerActivityScorePoint: -150),
        );

        expect(
          () => calculate(days: createDays(), planningService: invalidService),
          throwsArgumentError,
        );
      });
    });

    // --------------------------------------------------
    // 6. Immutabilité
    // --------------------------------------------------

    group('calculateWeeklyPlan - immutabilité', () {
      test('ne modifie pas la liste de journées fournie', () {
        final days = createDays().reversed.toList();
        final originalIds = days.map((day) => day.id).toList();

        calculate(days: days);

        expect(days.map((day) => day.id).toList(), originalIds);
      });

      test('retourne une liste de résultats non modifiable', () {
        final result = calculate(days: createDays());

        expect(() => result.days.clear(), throwsUnsupportedError);
      });

      test('retourne une liste de problèmes non modifiable', () {
        final result = calculate(days: createDays());

        expect(
          () => result.days.first.macroIssues.clear(),
          throwsUnsupportedError,
        );
      });
    });
  });
}
