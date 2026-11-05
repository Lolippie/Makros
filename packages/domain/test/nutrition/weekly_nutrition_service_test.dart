import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/daily_nutrition_day_status.dart';
import 'package:makros_nutrition/nutrition/results/daily_nutrition_result.dart';
import 'package:makros_nutrition/nutrition/weekly_nutrition_service.dart';
import 'package:makros_nutrition/nutrition/exceptions/daily_nutrition_exception.dart';
import 'package:makros_nutrition/nutrition/results/macro_calculation_result.dart';
import 'package:test/test.dart';

void main() {
  const service = WeeklyNutritionService();
  const target = Macros(
    calories: 2000,
    protein: 120,
    carbohydrates: 250,
    fat: 60,
    fiber: 25,
  );

  DailyNutritionResult day(
    int d, {
    double calories = 2000,
    Macros? goal = target,
    bool? reached = true,
    DailyNutritionDayStatus? status,
    DailyNutritionTargetSource? source,
    MacroCalculationStatus? macroStatus,
    String userId = 'user-1',
    int mealCount = 2,
    bool manuallyValidated = false,
  }) => DailyNutritionResult(
    userId: userId,
    date: DateTime(2026, 11, d, 16),
    mealCount: mealCount,
    isManuallyValidated: manuallyValidated,
    consumed: Macros(
      calories: mealCount == 0 ? 0 : calories,
      protein: mealCount == 0 ? 0 : 120,
      carbohydrates: mealCount == 0 ? 0 : 250,
      fat: mealCount == 0 ? 0 : 60,
      fiber: mealCount == 0 ? 0 : 25,
    ),
    target: goal,
    targetSource:
        source ??
        (goal == null
            ? DailyNutritionTargetSource.none
            : DailyNutritionTargetSource.fallback),
    macroStatus: macroStatus,
    dayStatus:
        status ??
        (d < 5
            ? DailyNutritionDayStatus.completed
            : d == 5
            ? DailyNutritionDayStatus.inProgress
            : DailyNutritionDayStatus.upcoming),
    variance: null,
    achievement: goal == null || mealCount == 0
        ? null
        : DailyNutritionAchievement(
            calories: reached,
            protein: reached,
            carbohydrates: reached,
            fat: reached,
            fiber: reached,
          ),
  );

  dynamic calculate(List<DailyNutritionResult> days, {DateTime? asOf}) =>
      service.calculate(
        userId: 'user-1',
        dateInWeek: DateTime(2026, 11, 5),
        asOf: asOf ?? DateTime(2026, 11, 5),
        dailyResults: days,
      );

  group('WeeklyNutritionService', () {
    test('semaine vide et bornes lundi dimanche', () {
      final r = calculate([]);
      expect(r.weekStart, DateTime.utc(2026, 11, 2));
      expect(r.weekEnd, DateTime.utc(2026, 11, 8));
      expect(r.missingDates.length, 7);
      expect(r.averageDailyConsumed, isNull);
      expect(r.completedSuccessRate, isNull);
    });

    test('les jours absents ne sont pas comptés comme zéro', () {
      final r = calculate([day(2), day(3, calories: 1800)]);
      expect(r.recordedDayCount, 2);
      expect(r.totalConsumed.calories, 3800);
      expect(r.averageDailyConsumed!.calories, 1900);
      expect(r.weeklyTarget, isNull);
      expect(r.comparableVariance.calories, -200);
    });

    test('consommations futures exclues, objectifs futurs conservés', () {
      final r = calculate([day(2, calories: 1900), day(6, calories: 2400)]);
      expect(r.totalConsumed.calories, 1900);
      expect(r.totalKnownTargets.calories, 4000);
      expect(r.comparableConsumed.calories, 1900);
      expect(r.comparableTargets.calories, 2000);
    });

    test('les périmètres comparables restent identiques', () {
      final r = calculate([
        day(2, calories: 1900),
        day(3, goal: null, calories: 500),
      ]);
      expect(r.totalConsumed.calories, 2400);
      expect(r.comparableConsumed.calories, 1900);
      expect(r.comparableTargets.calories, 2000);
      expect(r.comparableVariance.calories, -100);
    });

    test('taux de réussite et couverture distincts', () {
      final r = calculate([
        day(2, reached: true),
        day(3, reached: false),
        day(4, goal: null),
        day(5, reached: null),
      ]);
      expect(r.completedSuccessRate, 50);
      // 2 jours évalués sur 3 jours documentés terminés :
      // le jour sans cible est documenté, mais non évaluable.
      expect(r.evaluationCoverageRate, closeTo(200 / 3, 0.0001));
      expect(r.completedDayCoverageRate, 100);
    });

    test('rejette un verdict indéterminé sur un jour terminé avec cible', () {
      expect(
        () => calculate([day(2, reached: null)]),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('cibles complètes même si certains jours sont futurs', () {
      final r = calculate([for (var d = 2; d <= 8; d++) day(d)]);
      expect(r.hasCompleteTargets, isTrue);
      expect(r.weeklyTarget!.calories, 14000);
      expect(r.totalConsumed.calories, 8000);
    });

    test('une semaine terminée utilise le même asOf pour chaque jour', () {
      final r = calculate([
        for (var d = 2; d <= 8; d++)
          day(d, status: DailyNutritionDayStatus.completed),
      ], asOf: DateTime(2026, 11, 9));
      expect(r.completedDayCount, 7);
      expect(r.completedSuccessRate, 100);
      expect(r.totalConsumed.calories, 14000);
    });

    test('rejette un bilan au statut temporel périmé', () {
      expect(
        () => calculate([day(2, status: DailyNutritionDayStatus.inProgress)]),
        throwsA(
          isA<DailyNutritionException>().having(
            (e) => e.code,
            'code',
            DailyNutritionErrorCode.staleDailyResult,
          ),
        ),
      );
    });

    test('rejette les doublons', () {
      expect(
        () => calculate([day(2), day(2)]),
        throwsA(
          isA<DailyNutritionException>().having(
            (e) => e.code,
            'code',
            DailyNutritionErrorCode.duplicateDailyResult,
          ),
        ),
      );
    });

    test('ignore autres utilisateurs et autres semaines', () {
      final r = calculate([day(2), day(3, userId: 'other'), day(9)]);
      expect(r.recordedDayCount, 1);
    });

    test('rejette source sans cible cohérente', () {
      expect(
        () => calculate([day(2, source: DailyNutritionTargetSource.none)]),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('rejette invalid avec cible planifiée', () {
      expect(
        () => calculate([
          day(
            2,
            source: DailyNutritionTargetSource.plannedDay,
            macroStatus: MacroCalculationStatus.invalid,
          ),
        ]),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('warning avec cible planifiée', () {
      final r = calculate([
        day(
          2,
          source: DailyNutritionTargetSource.plannedDay,
          macroStatus: MacroCalculationStatus.warning,
        ),
      ]);
      expect(r.recordedDayCount, 1);
    });

    test('rejette NaN, négatifs et repas négatifs', () {
      expect(
        () => calculate([day(2, calories: double.nan)]),
        throwsA(isA<DailyNutritionException>()),
      );
      expect(
        () => calculate([day(2, calories: -1)]),
        throwsA(isA<DailyNutritionException>()),
      );
      expect(
        () => calculate([day(2, mealCount: -1)]),
        throwsA(isA<DailyNutritionException>()),
      );
    });

    test('semaine entièrement future : pas de consommation', () {
      final r = calculate([day(6), day(7)]);
      expect(r.totalConsumed.calories, 0);
      expect(r.averageDailyConsumed, isNull);
      expect(r.targetDayCount, 2);
    });

    test('année bissextile et changement d’année', () {
      final leap = service.calculate(
        userId: 'user-1',
        dateInWeek: DateTime(2028, 2, 29),
        asOf: DateTime(2028, 2, 29),
        dailyResults: [],
      );
      expect(leap.weekStart, DateTime.utc(2028, 2, 28));
      expect(leap.weekEnd, DateTime.utc(2028, 3, 5));
      final crossing = service.calculate(
        userId: 'user-1',
        dateInWeek: DateTime(2027, 1, 1),
        asOf: DateTime(2027, 1, 1),
        dailyResults: [],
      );
      expect(crossing.weekStart, DateTime.utc(2026, 12, 28));
      expect(crossing.weekEnd, DateTime.utc(2027, 1, 3));
    });

    test('listes de sortie immuables, entrées non modifiées', () {
      final inputs = [day(3), day(2)];
      final first = inputs.first;
      final r = calculate(inputs);
      expect(identical(inputs.first, first), isTrue);
      expect(r.days.first.date.day, 2);
      expect(() => r.days.clear(), throwsUnsupportedError);
      expect(() => r.missingDates.clear(), throwsUnsupportedError);
    });

    test('refuse un identifiant utilisateur vide', () {
      expect(
        () => service.calculate(
          userId: ' ',
          dateInWeek: DateTime(2026, 11, 5),
          asOf: DateTime(2026, 11, 5),
          dailyResults: [],
        ),
        throwsArgumentError,
      );
    });
    group('validation manuelle sans repas', () {
      test('sans repas et sans validation : inconnu, jamais un échec', () {
        final r = calculate([day(2, mealCount: 0)]);
        expect(r.unknownDates, [DateTime.utc(2026, 11, 2)]);
        // Le 5 est en cours et les 6-8 sont futurs : seuls les 2-4
        // peuvent être inconnus, y compris les dates sans résultat.
        expect(r.unknownDayCount, 3);
        expect(r.completedDayCount, 1);
        expect(r.evaluatedCompletedDays, 0);
        expect(r.successfulCompletedDays, 0);
        expect(r.failedCompletedDays, 0);
        expect(r.completedSuccessRate, isNull);
        expect(r.consumptionDayCount, 0);
        expect(r.comparableDayCount, 0);
        expect(r.totalConsumed.calories, 0);
      });

      test(
        'sans repas et validé : journée traitée sans succès nutritionnel',
        () {
          final r = calculate([day(2, mealCount: 0, manuallyValidated: true)]);
          expect(r.unknownDates, isEmpty);
          expect(r.manuallyValidatedDayCount, 1);
          expect(r.successfulCompletedDays, 0);
          expect(r.failedCompletedDays, 0);
          expect(r.evaluatedCompletedDays, 0);
          expect(r.completedSuccessRate, isNull);
          expect(r.consumptionDayCount, 0);
          expect(r.comparableDayCount, 0);
          expect(r.totalConsumed.calories, 0);
          expect(r.comparableConsumed.calories, 0);
          expect(r.comparableTargets.calories, 0);
          expect(r.totalKnownTargets.calories, 2000);
        },
      );

      test('validation manuelle exclue du taux, réussite calculée retenue', () {
        final r = calculate([
          day(2, mealCount: 0, manuallyValidated: true),
          day(3, reached: true),
        ]);
        expect(r.successfulCompletedDays, 1);
        expect(r.manuallyValidatedDayCount, 1);
        expect(r.completedSuccessRate, 100);
        expect(r.consumptionDayCount, 1);
        expect(r.comparableDayCount, 1);
        expect(r.comparableConsumed.calories, 2000);
      });

      test('validation manuelle et repas simultanés interdits', () {
        expect(
          () => calculate([day(2, manuallyValidated: true)]),
          throwsA(isA<DailyNutritionException>()),
        );
      });

      test('validation manuelle d’une journée future interdite', () {
        expect(
          () => calculate([day(7, mealCount: 0, manuallyValidated: true)]),
          throwsA(isA<DailyNutritionException>()),
        );
      });

      test('jour sans repas ne doit contenir ni macros ni verdicts', () {
        final r = calculate([day(2, mealCount: 0)]);
        expect(r.days.single.achievement, isNull);
        expect(r.days.single.allGoalsReached, isNull);
      });

      test(
        'validation manuelle sans cible reste traitée sans succès mesuré',
        () {
          final r = calculate([
            day(2, mealCount: 0, manuallyValidated: true, goal: null),
          ]);
          expect(r.successfulCompletedDays, 0);
          expect(r.completedSuccessRate, isNull);
          expect(r.targetDayCount, 0);
          expect(r.comparableDayCount, 0);
        },
      );
    });
  });
  test('réussites automatiques séparées des validations manuelles', () {
    final r = calculate([
      day(2, mealCount: 0, manuallyValidated: true),
      day(3, reached: true),
      day(4, mealCount: 0),
    ]);
    expect(r.successfulCompletedDays, 1);
    expect(r.automaticallySuccessfulCompletedDays, 1);
    expect(r.manuallyValidatedDayCount, 1);
    expect(r.unevaluableCompletedDayCount, 2);
  });
}
