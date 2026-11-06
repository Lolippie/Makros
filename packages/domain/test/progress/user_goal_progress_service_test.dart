import 'package:makros_models/models.dart';
import 'package:makros_nutrition/progress/exceptions/goal_progress_exception.dart';
import 'package:makros_nutrition/progress/results/body_fat_goal_progress_result.dart';
import 'package:makros_nutrition/progress/results/goal_progress_result.dart';
import 'package:makros_nutrition/progress/results/user_goal_progress_result.dart';
import 'package:makros_nutrition/progress/results/weight_progress_result.dart';
import 'package:makros_nutrition/progress/user_goal_progress_service.dart';
import 'package:test/test.dart';

void main() {
  final day = DateTime.utc(2026, 11, 6);
  final start = DateTime.utc(2026, 11, 1);

  const service = UserGoalProgressService();

  UserGoal goal({
    GoalType type = GoalType.cut,
    double? target = 60,
    bool achieved = false,
    DateTime? achievedAt,
    DateTime? from,
    DateTime? until,
  }) => UserGoal(
    id: 'goal-1',
    userId: 'user-1',
    type: type,
    targetWeight: target,
    targetWeightAchieved: achieved,
    targetWeightAchievedAt: achieved ? (achievedAt ?? start) : achievedAt,
    startDate: from ?? start,
    endDate: until,
  );

  WeightProgressResult analysis({
    double? current = 60,
    bool fresh = true,
    bool recalc = false,
    String user = 'user-1',
    DateTime? asOf,
    DateTime? cutoff,
    double? target = 60,
  }) => WeightProgressResult(
    userId: user,
    asOfDay: asOf ?? day,
    earliestMeasurementDate: cutoff,
    referenceWeightKg: 65,
    currentTrendWeightKg: current,
    previousTrendWeightKg: null,
    changeFromReferenceKg: null,
    changeBetweenWindowsKg: null,
    weeklyWeightChangeKg: null,
    targetWeightKg: target,
    remainingToTargetKg: null,
    measurementDaysInCurrentWindow: current == null ? 0 : 3,
    measurementDaysInPreviousWindow: 0,
    lastMeasurementDate: current == null ? null : day,
    isTrendFresh: fresh,
    trendStatus: WeightTrendStatus.unknown,
    shouldSuggestRecalculation: recalc,
    goalToleranceKg: 0.1,
    comparisonEpsilonKg: 1e-9,
  );

  group('Évaluation de l’objectif de poids', () {
    test('atteinte fraîche et filtrée : propose le marquage', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(cutoff: start),
        nutritionWeightProgress: analysis(recalc: true),
      );

      expect(result.evaluationState, UserGoalEvaluationState.evaluated);

      expect(result.weightError, isNull);
      expect(result.weightProgress, isNotNull);

      expect(result.weightProgress!.weightGoalState, WeightGoalState.reached);

      expect(result.shouldMarkWeightAchieved, isTrue);
      expect(result.shouldMarkBodyFatAchieved, isFalse);

      expect(result.shouldSuggestNutritionRecalculation, isTrue);
    });

    test('analyse périmée : pas de marquage', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(cutoff: start, fresh: false),
        nutritionWeightProgress: null,
      );

      expect(result.weightError, isNull);

      expect(result.weightProgress!.weightGoalState, WeightGoalState.stale);

      expect(result.shouldMarkWeightAchieved, isFalse);
    });

    test('objectif déjà atteint : pas de nouveau marquage', () {
      final result = service.analyze(
        goal: goal(achieved: true),
        asOf: day,
        weightProgress: analysis(cutoff: start),
        nutritionWeightProgress: null,
      );

      expect(result.weightError, isNull);

      expect(result.weightProgress!.weightGoalState, WeightGoalState.reached);

      expect(result.shouldMarkWeightAchieved, isFalse);
    });

    test('maintenance : jamais de marquage historique', () {
      final result = service.analyze(
        goal: goal(type: GoalType.maintenance),
        asOf: day,
        weightProgress: analysis(cutoff: start),
        nutritionWeightProgress: null,
      );

      expect(result.weightError, isNull);
      expect(result.shouldMarkWeightAchieved, isFalse);
    });

    test('aucune analyse : aucun marquage', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: null,
        nutritionWeightProgress: null,
      );

      expect(result.evaluationState, UserGoalEvaluationState.noAnalysis);

      expect(result.weightProgress, isNull);
      expect(result.weightError, isNull);
      expect(result.shouldMarkWeightAchieved, isFalse);
      expect(result.shouldMarkBodyFatAchieved, isFalse);
    });
  });

  group('Erreurs métier du poids', () {
    test('analyse non filtrée : erreur dans weightError', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(),
        nutritionWeightProgress: null,
      );

      expect(result.weightProgress, isNull);
      expect(result.shouldMarkWeightAchieved, isFalse);

      expect(
        result.weightError,
        isA<GoalProgressException>().having(
          (e) => e.code,
          'code',
          GoalProgressErrorCode.measurementPeriodMismatch,
        ),
      );
    });

    test('analyse à une autre date : erreur dans weightError', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(
          cutoff: start,
          asOf: day.subtract(const Duration(days: 1)),
        ),
        nutritionWeightProgress: null,
      );

      expect(result.weightProgress, isNull);
      expect(result.shouldMarkWeightAchieved, isFalse);

      expect(
        result.weightError,
        isA<GoalProgressException>().having(
          (e) => e.code,
          'code',
          GoalProgressErrorCode.analysisDateMismatch,
        ),
      );
    });

    test('autre utilisateur : erreur dans weightError', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(cutoff: start, user: 'other'),
        nutritionWeightProgress: null,
      );

      expect(result.weightProgress, isNull);
      expect(result.shouldMarkWeightAchieved, isFalse);

      expect(
        result.weightError,
        isA<GoalProgressException>().having(
          (e) => e.code,
          'code',
          GoalProgressErrorCode.userMismatch,
        ),
      );
    });

    test('erreur de poids : recalcul nutritionnel conservé', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(),
        nutritionWeightProgress: analysis(recalc: true),
      );

      expect(
        result.weightError,
        isA<GoalProgressException>().having(
          (e) => e.code,
          'code',
          GoalProgressErrorCode.measurementPeriodMismatch,
        ),
      );

      expect(result.weightProgress, isNull);
      expect(result.shouldMarkWeightAchieved, isFalse);

      expect(result.nutritionError, isNull);

      expect(result.shouldSuggestNutritionRecalculation, isTrue);
    });
  });

  group('Indépendance du recalcul nutritionnel', () {
    test('sans cible, le recalcul global est conservé', () {
      final result = service.analyze(
        goal: goal(target: null),
        asOf: day,
        weightProgress: null,
        nutritionWeightProgress: analysis(recalc: true),
      );

      expect(result.evaluationState, UserGoalEvaluationState.noTarget);

      expect(result.weightError, isNull);
      expect(result.nutritionError, isNull);

      expect(result.shouldSuggestNutritionRecalculation, isTrue);
    });

    test('objectif inactif : recalcul global conservé', () {
      final result = service.analyze(
        goal: goal(from: day.add(const Duration(days: 1))),
        asOf: day,
        weightProgress: null,
        nutritionWeightProgress: analysis(recalc: true),
      );

      expect(result.evaluationState, UserGoalEvaluationState.inactive);

      expect(result.nutritionError, isNull);

      expect(result.shouldSuggestNutritionRecalculation, isTrue);
    });

    test('sans demande de recalcul : indicateur faux', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(cutoff: start),
        nutritionWeightProgress: analysis(recalc: false),
      );

      expect(result.nutritionError, isNull);

      expect(result.shouldSuggestNutritionRecalculation, isFalse);
    });

    test('absence d’analyse nutritionnelle : pas de recalcul', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(cutoff: start),
        nutritionWeightProgress: null,
      );

      expect(result.nutritionError, isNull);

      expect(result.shouldSuggestNutritionRecalculation, isFalse);
    });
  });

  group('Intégrité du résultat', () {
    test('identifiant de l’objectif conservé', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(cutoff: start),
        nutritionWeightProgress: null,
      );

      expect(result.goalId, 'goal-1');
    });

    test('aucune cible de masse grasse : état noTarget', () {
      final result = service.analyze(
        goal: goal(),
        asOf: day,
        weightProgress: analysis(cutoff: start),
        nutritionWeightProgress: null,
      );

      expect(result.bodyFatProgress, isNotNull);

      expect(result.bodyFatProgress!.state, BodyFatGoalState.noTarget);

      expect(result.bodyFatError, isNull);
      expect(result.shouldMarkBodyFatAchieved, isFalse);
    });
  });
}
