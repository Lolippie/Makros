import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/config/nutrition_calculation_config.dart';
import 'package:makros_nutrition/nutrition/nutrition_calculator_service.dart';
import 'package:test/test.dart';

void main() {
  const service = NutritionCalculatorService();
  final referenceDate = DateTime(2025, 6, 15);

  UserProfile profile({
    Gender gender = Gender.male,
    ActivityLevel activityLevel = ActivityLevel.sedentary,
    DateTime? birthDate,
    double height = 175,
  }) => UserProfile(
    userId: 'user-1',
    birthDate: birthDate ?? DateTime(1990, 6, 15),
    height: height,
    gender: gender,
    activityLevel: activityLevel,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  UserGoal goal({
    GoalType type = GoalType.maintenance,
    double? percentage,
    String userId = 'user-1',
  }) => UserGoal(
    id: 'goal-1',
    userId: userId,
    type: type,
    startDate: DateTime(2025),
    calorieAdjustmentPercentage: percentage,
  );

  PlannedActiveDay activeDay({
    DateTime? date,
    bool hasActivity = true,
    SportType? sportType = SportType.running,
    ActivityIntensity? intensity = ActivityIntensity.moderate,
    int? duration = 60,
  }) => PlannedActiveDay(
    id: 'day-1',
    weekPlanId: 'week-1',
    date: date ?? DateTime(2025, 6, 15),
    hasActivity: hasActivity,
    sportType: sportType,
    intensity: intensity,
    plannedDurationMinutes: duration,
  );

  group('Dépense énergétique de repos', () {
    test('formule Mifflin-St Jeor homme, anniversaire inclus', () {
      expect(
        service.calculateRestingEnergyExpenditure(
          profile: profile(),
          weightKg: 70,
          referenceDate: referenceDate,
        ),
        1623.75,
      );
    });

    test('constante femme', () {
      expect(
        service.calculateRestingEnergyExpenditure(
          profile: profile(gender: Gender.female),
          weightKg: 70,
          referenceDate: referenceDate,
        ),
        1457.75,
      );
    });

    test('anniversaire du lendemain non comptabilisé', () {
      expect(
        service.calculateRestingEnergyExpenditure(
          profile: profile(birthDate: DateTime(1990, 6, 16)),
          weightKg: 70,
          referenceDate: referenceDate,
        ),
        1628.75,
      );
    });

    test('date de naissance future, poids et taille invalides rejetés', () {
      expect(
        () => service.calculateRestingEnergyExpenditure(
          profile: profile(birthDate: DateTime(2025, 6, 16)),
          weightKg: 70,
          referenceDate: referenceDate,
        ),
        throwsArgumentError,
      );
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
    });

    test('un résultat numérique débordant est rejeté', () {
      expect(
        () => service.calculateRestingEnergyExpenditure(
          profile: profile(),
          weightKg: 1e308,
          referenceDate: referenceDate,
        ),
        throwsStateError,
      );
    });
  });

  group('Dépenses quotidiennes et sportives', () {
    test('coefficient hors sport appliqué', () {
      expect(
        service.calculateDailyBaselineCalories(
          restingEnergyExpenditureKcal: 2000,
          activityLevel: ActivityLevel.sedentary,
        ),
        2400,
      );
    });

    test('dépense nette de séance et MET égal à 1', () {
      expect(
        service.calculateSessionCalories(
          weightKg: 70,
          durationMinutes: 60,
          metValue: 5,
        ),
        294,
      );
      expect(
        service.calculateSessionCalories(
          weightKg: 70,
          durationMinutes: 60,
          metValue: 1,
        ),
        0,
      );
    });

    test('durée négative, nulle et MET non fini rejetés', () {
      for (final duration in [0, -10]) {
        expect(
          () => service.calculateSessionCalories(
            weightKg: 70,
            durationMinutes: duration,
            metValue: 5,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => service.calculateSessionCalories(
          weightKg: 70,
          durationMinutes: 60,
          metValue: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test('valeur MET connue et combinaison manquante', () {
      expect(
        service.getMetValue(
          sportType: SportType.running,
          intensity: ActivityIntensity.moderate,
        ),
        8,
      );
      const partial = NutritionCalculatorService(
        config: NutritionCalculationConfig(
          nonExerciseActivityFactors: {},
          sportMetValues: {},
        ),
      );
      expect(
        () => partial.getMetValue(
          sportType: SportType.running,
          intensity: ActivityIntensity.moderate,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Planning hebdomadaire', () {
    test('planning vide : aucune dépense sportive', () {
      expect(
        service.calculateWeeklyExerciseCalories(weightKg: 70, plannedDays: []),
        0,
      );
    });

    test('seules les journées actives sont additionnées', () {
      expect(
        service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [
            activeDay(),
            activeDay(date: DateTime(2025, 6, 16), hasActivity: false),
          ],
        ),
        514.5,
      );
    });

    test('un jour de repos peut conserver une ancienne séance', () {
      expect(
        service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [activeDay(hasActivity: false)],
        ),
        0,
      );
    });

    test('dates dupliquées et période de plus de 7 jours rejetées', () {
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
          ],
        ),
        throwsArgumentError,
      );
    });

    test('séance active incomplète rejetée', () {
      expect(
        () => service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [activeDay(duration: null)],
        ),
        throwsArgumentError,
      );
    });

    test('passage heure été/hiver : 7 dates civiles acceptées', () {
      final days = [
        activeDay(date: DateTime(2025, 3, 25), hasActivity: false),
        activeDay(date: DateTime(2025, 3, 31), hasActivity: false),
      ];
      expect(
        service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: days,
        ),
        0,
      );
    });
  });

  group('Ajustements et calcul complet', () {
    test('valeurs par défaut et personnalisées', () {
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

    test('plafonds inclus, dépassements exclus', () {
      expect(
        service.getAdjustmentPercentage(
          goal(type: GoalType.cut, percentage: 30),
        ),
        -30,
      );
      expect(
        service.getAdjustmentPercentage(
          goal(type: GoalType.bulk, percentage: 30),
        ),
        30,
      );
      for (final percentage in [30.01, 100.0, double.nan, double.infinity]) {
        expect(
          () => service.getAdjustmentPercentage(
            goal(type: GoalType.cut, percentage: percentage),
          ),
          throwsArgumentError,
        );
        expect(
          () => service.getAdjustmentPercentage(
            goal(type: GoalType.bulk, percentage: percentage),
          ),
          throwsArgumentError,
        );
      }
    });

    test('un objectif appartenant à un autre utilisateur est rejeté', () {
      expect(
        () => service.calculate(
          profile: profile(),
          goal: goal(userId: 'another-user'),
          currentWeightKg: 70,
          plannedDays: [],
          referenceDate: referenceDate,
        ),
        throwsArgumentError,
      );
    });

    test('chaîne complète : repos, activité, maintien et cut', () {
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

    test('seuil de variation du poids inclus et symétrique', () {
      expect(
        service.shouldRecalculateForWeightChange(
          currentWeight: 71,
          referenceWeight: 70,
        ),
        isTrue,
      );
      expect(
        service.shouldRecalculateForWeightChange(
          currentWeight: 69,
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
        () => service.shouldRecalculateForWeightChange(
          currentWeight: 70,
          referenceWeight: 70,
          threshold: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Validation de la configuration', () {
    test('configuration par défaut valide', () {
      expect(defaultNutritionCalculationConfig.validate, returnsNormally);
    });

    test('une configuration partielle est autorisée', () {
      const config = NutritionCalculationConfig(
        nonExerciseActivityFactors: {},
        sportMetValues: {},
      );
      expect(config.validate, returnsNormally);
    });

    test('facteurs et MET invalides rejetés', () {
      const invalidFactor = NutritionCalculationConfig(
        nonExerciseActivityFactors: {ActivityLevel.sedentary: 0.9},
        sportMetValues: {},
      );
      const invalidMet = NutritionCalculationConfig(
        nonExerciseActivityFactors: {},
        sportMetValues: {
          SportType.gym: {ActivityIntensity.low: double.nan},
        },
      );
      expect(invalidFactor.validate, throwsArgumentError);
      expect(invalidMet.validate, throwsArgumentError);
    });

    test('plafonds et valeurs par défaut incohérents rejetés', () {
      const invalidConfigs = [
        NutritionCalculationConfig(
          nonExerciseActivityFactors: {},
          sportMetValues: {},
          maxCutDeficitPercentage: 100,
        ),
        NutritionCalculationConfig(
          nonExerciseActivityFactors: {},
          sportMetValues: {},
          maxBulkSurplusPercentage: -1,
        ),
        NutritionCalculationConfig(
          nonExerciseActivityFactors: {},
          sportMetValues: {},
          defaultCutDeficitPercentage: 25,
          maxCutDeficitPercentage: 20,
        ),
        NutritionCalculationConfig(
          nonExerciseActivityFactors: {},
          sportMetValues: {},
          defaultBulkSurplusPercentage: 20,
          maxBulkSurplusPercentage: 15,
        ),
      ];
      for (final config in invalidConfigs) {
        expect(config.validate, throwsArgumentError);
      }
    });
  });

  group('Audit de non-régression', () {
    test('une configuration invalide sur un champ inutilisé est rejetée', () {
      const invalid = NutritionCalculatorService(
        config: NutritionCalculationConfig(
          nonExerciseActivityFactors: {
            ActivityLevel.sedentary: double.infinity,
          },
          sportMetValues: {},
        ),
      );
      expect(
        () => invalid.calculateSessionCalories(
          weightKg: 70,
          durationMinutes: 60,
          metValue: 5,
        ),
        throwsArgumentError,
      );
    });

    test(
      'configuration mutable modifiée après création : nouvelle validation',
      () {
        final factors = <ActivityLevel, double>{ActivityLevel.sedentary: 1.2};
        final config = NutritionCalculationConfig(
          nonExerciseActivityFactors: factors,
          sportMetValues: const {},
        );
        final calculator = NutritionCalculatorService(config: config);
        expect(
          calculator.calculateDailyBaselineCalories(
            restingEnergyExpenditureKcal: 1500,
            activityLevel: ActivityLevel.sedentary,
          ),
          1800,
        );
        factors[ActivityLevel.sedentary] = double.nan;
        expect(
          () => calculator.calculateDailyBaselineCalories(
            restingEnergyExpenditureKcal: 1500,
            activityLevel: ActivityLevel.sedentary,
          ),
          throwsArgumentError,
        );
      },
    );

    test('MET 1 : zéro dépense nette même sur une longue séance', () {
      expect(
        service.calculateSessionCalories(
          weightKg: 70,
          durationMinutes: 300,
          metValue: 1,
        ),
        0,
      );
    });

    test('débordement numérique sur une séance : erreur explicite', () {
      expect(
        () => service.calculateSessionCalories(
          weightKg: 1e308,
          durationMinutes: 60,
          metValue: 11,
        ),
        throwsStateError,
      );
    });

    test('un coefficient manquant est signalé lors de son utilisation', () {
      const partial = NutritionCalculatorService(
        config: NutritionCalculationConfig(
          nonExerciseActivityFactors: {},
          sportMetValues: {},
        ),
      );
      expect(
        () => partial.calculateDailyBaselineCalories(
          restingEnergyExpenditureKcal: 1500,
          activityLevel: ActivityLevel.sedentary,
        ),
        throwsArgumentError,
      );
    });

    test('débordement numérique du maintien quotidien rejeté', () {
      expect(
        () => service.calculateDailyBaselineCalories(
          restingEnergyExpenditureKcal: 1.2e308,
          activityLevel: ActivityLevel.extraActive,
        ),
        throwsStateError,
      );
    });

    test('la validation refuse une durée nulle pour un jour actif', () {
      expect(
        () => service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [activeDay(duration: 0)],
        ),
        throwsArgumentError,
      );
    });

    test('deux horaires d’une même date civile sont un doublon', () {
      expect(
        () => service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [
            activeDay(date: DateTime(2025, 6, 15, 9)),
            activeDay(date: DateTime(2025, 6, 15, 21)),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('des plafonds personnalisés sont effectivement appliqués', () {
      const custom = NutritionCalculatorService(
        config: NutritionCalculationConfig(
          nonExerciseActivityFactors: {},
          sportMetValues: {},
          defaultCutDeficitPercentage: 5,
          defaultBulkSurplusPercentage: 5,
          maxCutDeficitPercentage: 10,
          maxBulkSurplusPercentage: 12,
        ),
      );
      expect(custom.getAdjustmentPercentage(goal(type: GoalType.cut)), -5);
      expect(custom.getAdjustmentPercentage(goal(type: GoalType.bulk)), 5);
      expect(
        () => custom.getAdjustmentPercentage(
          goal(type: GoalType.cut, percentage: 11),
        ),
        throwsArgumentError,
      );
      expect(
        () => custom.getAdjustmentPercentage(
          goal(type: GoalType.bulk, percentage: 13),
        ),
        throwsArgumentError,
      );
    });

    test('les pourcentages nuls sont autorisés', () {
      expect(
        service.getAdjustmentPercentage(
          goal(type: GoalType.cut, percentage: 0),
        ),
        0,
      );
      expect(
        service.getAdjustmentPercentage(
          goal(type: GoalType.bulk, percentage: 0),
        ),
        0,
      );
    });

    test('le maintien ignore un ancien ajustement stocké', () {
      expect(
        service.getAdjustmentPercentage(
          goal(type: GoalType.maintenance, percentage: 999),
        ),
        0,
      );
    });

    test('les utilisateurs avec identifiant vide sont rejetés', () {
      final emptyGoal = goal(userId: ' ');
      expect(
        () => service.calculate(
          profile: profile(),
          goal: emptyGoal,
          currentWeightKg: 70,
          plannedDays: [],
          referenceDate: referenceDate,
        ),
        throwsArgumentError,
      );
    });

    test('les deux bords de la fenêtre de sept jours sont inclus', () {
      expect(
        service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [
            activeDay(date: DateTime(2025, 6, 15)),
            activeDay(date: DateTime(2025, 6, 21)),
          ],
        ),
        closeTo(1029, 1e-9),
      );
    });

    test('une date future au-delà de la fenêtre est rejetée', () {
      expect(
        () => service.calculateWeeklyExerciseCalories(
          weightKg: 70,
          plannedDays: [
            activeDay(date: DateTime(2025, 6, 15)),
            activeDay(date: DateTime(2025, 6, 22)),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('toutes les configurations de plafonds non finies sont rejetées', () {
      for (final ceiling in [double.nan, double.infinity, -1.0]) {
        final config = NutritionCalculationConfig(
          nonExerciseActivityFactors: const {},
          sportMetValues: const {},
          maxBulkSurplusPercentage: ceiling,
        );
        expect(config.validate, throwsArgumentError);
      }
    });
  });
}
