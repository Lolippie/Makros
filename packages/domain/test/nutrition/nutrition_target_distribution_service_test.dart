import 'package:test/test.dart';
import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/config/nutrition_target_distribution_config.dart';
import 'package:makros_nutrition/nutrition/nutrition_recommendation_service.dart';
import 'package:makros_nutrition/nutrition/nutrition_target_distribution_service.dart';
import 'package:makros_nutrition/nutrition/results/nutrition_target_distribution_result.dart';

void main() {
  const service = NutritionTargetDistributionService();
  final monday = DateTime.utc(2026, 11, 2);

  PlannedActiveDay planned(DateTime date, {bool active = true}) =>
      PlannedActiveDay(
        id: date.toIso8601String(),
        weekPlanId: 'week-1',
        date: date,
        hasActivity: active,
      );

  NutritionTargetDistributionResult distribute({
    List<PlannedActiveDay> days = const [],
    double weight = 70,
    double calories = 2200.0,
    NutritionGoalType goal = NutritionGoalType.maintenance,
    MacroDistributionPreferences preferences =
        const MacroDistributionPreferences(),
    double Function(DateTime)? caloriesForDate,
    double Function(PlannedActiveDay)? exercise,
  }) => service.distribute(
    weekStart: monday,
    weightKg: weight,
    goal: goal,
    preferences: preferences,
    plannedDays: days,
    caloriesForDate: caloriesForDate ?? (_) => calories,
    exerciseCaloriesForDay: exercise ?? (_) => 300.0,
  );

  group('Recommandations', () {
    test('profils de départ selon le goal', () {
      const recommender = NutritionRecommendationService();
      expect(recommender.recommend(NutritionGoalType.cut).proteinGramsPerKg, 2);
      expect(
        recommender.recommend(NutritionGoalType.maintenance).fatGramsPerKg,
        0.9,
      );
      expect(recommender.recommend(NutritionGoalType.bulk).fatGramsPerKg, 1);
    });
    test('mode recommandé ignore les valeurs personnalisées', () {
      final result = distribute(
        preferences: const MacroDistributionPreferences(
          proteinGramsPerKg: 2.5,
          fatGramsPerKg: 1.3,
        ),
      );
      expect(result.days.first.proteinGrams, closeTo(126, 1e-8));
      expect(result.mode, NutritionRecommendationMode.recommended);
    });
    test('mode personnalisé applique les deux valeurs', () {
      final result = distribute(
        preferences: const MacroDistributionPreferences(
          mode: NutritionRecommendationMode.custom,
          proteinGramsPerKg: 1.8,
          fatGramsPerKg: 0.8,
        ),
      );
      expect(result.days.first.proteinGrams, closeTo(126, 1e-8));
      expect(result.days.first.fatGrams, closeTo(56, 1e-8));
      expect(result.appliedRecommendation.referenceVersion, 'custom');
    });
    test('mode personnalisé incomplet rejeté', () {
      expect(
        () => distribute(
          preferences: const MacroDistributionPreferences(
            mode: NutritionRecommendationMode.custom,
            proteinGramsPerKg: 1.8,
          ),
        ),
        throwsArgumentError,
      );
    });
    test('amplitude négative, >100 et NaN rejetées', () {
      for (final amplitude in [-1.0, 101.0, double.nan]) {
        expect(
          () => distribute(
            preferences: MacroDistributionPreferences(
              carbCyclingAmplitudePercentage: amplitude,
            ),
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('Distribution hebdomadaire', () {
    test('7 jours civils, conservation et macros énergétiques', () {
      final result = distribute(
        days: [planned(monday), planned(monday.add(const Duration(days: 2)))],
      );
      expect(result.days, hasLength(7));
      expect(result.isFeasible, isTrue);
      expect(result.weeklyCaloriesKcal, closeTo(15400, 1e-7));
      for (final day in result.days) {
        expect(
          day.caloriesKcal,
          closeTo(
            day.proteinGrams * 4 + day.fatGrams * 9 + day.carbohydrateGrams * 4,
            1e-8,
          ),
        );
        expect(day.carbohydrateGrams, greaterThanOrEqualTo(0));
      }
      expect(
        result.days[0].caloriesKcal,
        greaterThan(result.days[1].caloriesKcal),
      );
    });
    test('transition recalculée à chaque date', () {
      final result = distribute(
        caloriesForDate: (date) =>
            2000 + date.difference(monday).inDays * 100.0,
      );
      expect(result.weeklyEnergyBudgetKcal, closeTo(16100, 1e-8));
      expect(result.days.first.caloriesKcal, closeTo(2000, 1e-8));
      expect(result.days.last.caloriesKcal, closeTo(2600, 1e-8));
    });
    test('aucune activité: aucun transfert', () {
      final result = distribute();
      expect(result.days.every((d) => !d.hasActivity), isTrue);
      expect(
        result.days.every((d) => (d.caloriesKcal - 2200).abs() < 1e-8),
        isTrue,
      );
      expect(
        result.issues,
        contains(NutritionDistributionIssue.noCarbCyclingContrast),
      );
    });
    test('semaine entièrement active: aucun transfert', () {
      final result = distribute(
        days: List.generate(7, (i) => planned(monday.add(Duration(days: i)))),
      );
      expect(
        result.days.every((d) => (d.caloriesKcal - 2200).abs() < 1e-8),
        isTrue,
      );
    });
    test('doublons civils rejetés', () {
      expect(
        () => distribute(
          days: [
            planned(monday),
            planned(monday.add(const Duration(hours: 3))),
          ],
        ),
        throwsArgumentError,
      );
    });
    test('hors période rejeté', () {
      expect(
        () => distribute(
          days: [planned(monday.subtract(const Duration(days: 1)))],
        ),
        throwsArgumentError,
      );
    });
    test('calories insuffisantes signalées sans macros négatives', () {
      final result = distribute(calories: 500);
      expect(result.isFeasible, isFalse);
      expect(result.days, isEmpty);
      expect(
        result.issues,
        contains(NutritionDistributionIssue.insufficientCaloriesForMacros),
      );
    });
    test('valeurs sportives invalides rejetées', () {
      expect(
        () => distribute(days: [planned(monday)], exercise: (_) => double.nan),
        throwsArgumentError,
      );
      expect(
        () => distribute(days: [planned(monday)], exercise: (_) => -1.0),
        throwsArgumentError,
      );
    });
    test('poids et calories invalides rejetés', () {
      expect(() => distribute(weight: 0), throwsArgumentError);
      expect(() => distribute(calories: double.infinity), throwsArgumentError);
    });
    test('liste du résultat non modifiable', () {
      final result = distribute();
      expect(() => result.days.clear(), throwsUnsupportedError);
      expect(() => result.issues.clear(), throwsUnsupportedError);
    });
  });
  group('Audit V5 : cas limites', () {
    test('semaine commençant un autre jour que lundi rejetée', () {
      expect(
        () => service.distribute(
          weekStart: monday.add(const Duration(days: 1)),
          weightKg: 70,
          goal: NutritionGoalType.maintenance,
          preferences: const MacroDistributionPreferences(),
          plannedDays: const [],
          caloriesForDate: (_) => 2200.0,
          exerciseCaloriesForDay: (_) => 0.0,
        ),
        throwsArgumentError,
      );
    });

    test('dépense sportive supérieure au budget : résultat impossible', () {
      final result = distribute(
        calories: 1000,
        days: [planned(monday)],
        exercise: (_) => 7000.0,
      );
      expect(result.isFeasible, isFalse);
      expect(result.days, isEmpty);
      expect(
        result.issues,
        contains(NutritionDistributionIssue.insufficientCaloriesForMacros),
      );
    });

    test('budget hebdomadaire préservé avec transition et activité', () {
      final result = distribute(
        days: [planned(monday), planned(monday.add(const Duration(days: 4)))],
        exercise: (_) => 450.0,
        caloriesForDate: (d) => 2100.0 + 40.0 * d.difference(monday).inDays,
      );
      expect(result.isFeasible, isTrue);
      expect(
        result.weeklyCaloriesKcal,
        closeTo(result.weeklyEnergyBudgetKcal, 1e-7),
      );
      expect(result.days.every((d) => d.carbohydrateGrams >= 0), isTrue);
    });

    test('débordement des grammes fixes rejeté', () {
      expect(() => distribute(weight: 1e308), throwsArgumentError);
    });

    test('mode custom avec infinities rejeté', () {
      expect(
        () => distribute(
          preferences: const MacroDistributionPreferences(
            mode: NutritionRecommendationMode.custom,
            proteinGramsPerKg: double.infinity,
            fatGramsPerKg: 0.8,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Audit V6 : invariants et tests ciblés', () {
    test('redistribution sportive exacte sans carb cycling', () {
      final result = distribute(
        days: [planned(monday)],
        exercise: (_) => 700.0,
        preferences: const MacroDistributionPreferences(
          carbCyclingAmplitudePercentage: 0,
        ),
      );
      expect(result.isFeasible, isTrue);
      expect(result.days.first.caloriesKcal, closeTo(2800.0, 1e-8));
      for (var i = 1; i < 7; i++) {
        expect(result.days[i].caloriesKcal, closeTo(2100.0, 1e-8));
      }
      expect(result.weeklyCaloriesKcal, closeTo(15400.0, 1e-7));
    });

    test('20 pour cent : transfert centré, énergie et grammes cohérents', () {
      final noCycle = distribute(
        days: [planned(monday), planned(monday.add(const Duration(days: 2)))],
        exercise: (_) => 300.0,
        preferences: const MacroDistributionPreferences(
          carbCyclingAmplitudePercentage: 0,
        ),
      );
      final cycled = distribute(
        days: [planned(monday), planned(monday.add(const Duration(days: 2)))],
        exercise: (_) => 300.0,
      );
      expect(cycled.isFeasible, isTrue);
      expect(
        cycled.weeklyCaloriesKcal,
        closeTo(noCycle.weeklyCaloriesKcal, 1e-7),
      );
      expect(
        cycled.days[0].carbohydrateGrams,
        greaterThan(noCycle.days[0].carbohydrateGrams),
      );
      expect(
        cycled.days[1].carbohydrateGrams,
        lessThan(noCycle.days[1].carbohydrateGrams),
      );
      for (var i = 0; i < 7; i++) {
        final d = cycled.days[i];
        expect(
          d.caloriesKcal,
          closeTo(
            4 * d.proteinGrams + 9 * d.fatGrams + 4 * d.carbohydrateGrams,
            1e-7,
          ),
        );
      }
    });

    test('palier de transition avec séance : budget hebdomadaire inchangé', () {
      final result = distribute(
        days: [planned(monday.add(const Duration(days: 3)))],
        exercise: (_) => 560.0,
        caloriesForDate: (d) =>
            d.difference(monday).inDays < 3 ? 2000.0 : 2100.0,
        preferences: const MacroDistributionPreferences(
          carbCyclingAmplitudePercentage: 0,
        ),
      );
      expect(result.weeklyEnergyBudgetKcal, closeTo(14400.0, 1e-8));
      expect(result.weeklyCaloriesKcal, closeTo(14400.0, 1e-7));
      expect(result.days[0].caloriesKcal, closeTo(1920.0, 1e-8));
      expect(result.days[3].caloriesKcal, closeTo(2580.0, 1e-8));
    });

    test('journée marquée active avec dépense nulle', () {
      final result = distribute(
        days: [planned(monday)],
        exercise: (_) => 0.0,
        preferences: const MacroDistributionPreferences(
          carbCyclingAmplitudePercentage: 0,
        ),
      );
      expect(result.isFeasible, isTrue);
      expect(result.days.first.hasActivity, isTrue);
      expect(
        result.days.every((d) => (d.caloriesKcal - 2200.0).abs() < 1e-8),
        isTrue,
      );
    });

    test('dépense très élevée : issue explicite et aucun jour négatif', () {
      final result = distribute(
        days: [planned(monday)],
        exercise: (_) => 7000.0,
        calories: 1000.0,
      );
      expect(result.isFeasible, isFalse);
      expect(result.days, isEmpty);
      expect(result.weeklyEnergyBudgetKcal, closeTo(7000.0, 1e-7));
    });

    test('débordement du calcul des calories fixes avec grammes finis', () {
      expect(
        () => distribute(
          weight: 1.5e307,
          preferences: const MacroDistributionPreferences(
            mode: NutritionRecommendationMode.custom,
            proteinGramsPerKg: 1.0,
            fatGramsPerKg: 1.0,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
