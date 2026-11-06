import 'package:makros_models/models.dart';
import 'package:makros_nutrition/progress/body_fat_progress_service.dart';
import 'package:makros_nutrition/progress/exceptions/goal_progress_exception.dart';
import 'package:makros_nutrition/progress/results/body_fat_goal_progress_result.dart';
import 'package:makros_nutrition/progress/results/goal_progress_result.dart';
import 'package:makros_nutrition/progress/results/weight_progress_result.dart';
import 'package:makros_nutrition/progress/results/user_goal_progress_result.dart';
import 'package:makros_nutrition/progress/user_goal_progress_service.dart';
import 'package:makros_nutrition/progress/weight_progress_service.dart';
import 'package:test/test.dart';

void main() {
  final asOf = DateTime.utc(2026, 11, 6);
  final start = DateTime.utc(2026, 10, 1);
  const weightService = WeightProgressService();
  const fatService = BodyFatProgressService();
  const goalService = UserGoalProgressService();

  UserGoal goal({
    double? targetWeight = 60,
    double? targetFat = 25,
    GoalType type = GoalType.cut,
  }) => UserGoal(
    id: 'goal-1',
    userId: 'user-1',
    type: type,
    startDate: start,
    targetWeight: targetWeight,
    targetBodyFatPercentage: targetFat,
    targetBodyFatMeasurementMethod: targetFat == null ? null : 'DEXA',
  );

  List<WeightHistory> weights(double kg) => [
    for (final d in [0, 1, 2])
      WeightHistory(
        id: 'w-$d',
        userId: 'user-1',
        measuredAt: asOf.subtract(Duration(days: d)),
        weight: kg,
      ),
  ];

  List<BodyFatHistory> fats(double percentage) => [
    for (final d in [0, 8, 16])
      BodyFatHistory(
        id: 'bf-$d',
        userId: 'user-1',
        measuredAt: asOf.subtract(Duration(days: d)),
        bodyFatPercentage: percentage,
        measurementMethod: 'DEXA',
      ),
  ];

  // L'analyse de l'objectif doit être limitée aux mesures depuis son début.
  // L'analyse nutritionnelle, elle, utilise l'historique global.
  WeightProgressResult weightForGoal(List<WeightHistory> history) =>
      weightService.analyze(
        userId: 'user-1',
        measurements: history,
        referenceWeightKg: 65,
        targetWeightKg: 60,
        earliestMeasurementDate: start,
        asOf: asOf,
      );

  WeightProgressResult weightForNutrition(List<WeightHistory> history) =>
      weightService.analyze(
        userId: 'user-1',
        measurements: history,
        referenceWeightKg: 65,
        asOf: asOf,
      );

  BodyFatProgressResult fatForGoal(List<BodyFatHistory> history) =>
      fatService.analyze(
        userId: 'user-1',
        measurements: history,
        earliestMeasurementDate: start,
        measurementMethod: 'DEXA',
        asOf: asOf,
      );

  group('Intégration progression des objectifs', () {
    test('historiques -> tendances -> atteinte des deux cibles', () {
      final weight = weightForGoal(weights(59.5));
      final fat = fatForGoal(fats(24));
      final result = goalService.analyze(
        goal: goal(),
        asOf: asOf,
        weightProgress: weight,
        bodyFatProgress: fat,
        nutritionWeightProgress: weightForNutrition(weights(59.5)),
      );

      expect(weight.currentTrendWeightKg, closeTo(59.5, 1e-9));
      expect(fat.currentTrendPercentage, closeTo(24, 1e-9));
      expect(result.evaluationState, UserGoalEvaluationState.evaluated);
      expect(result.weightProgress!.weightGoalState, WeightGoalState.reached);
      expect(result.bodyFatProgress!.state, BodyFatGoalState.reached);
      expect(result.weightError, isNull);
      expect(result.bodyFatError, isNull);
      expect(result.shouldMarkWeightAchieved, isTrue);
      expect(result.shouldMarkBodyFatAchieved, isTrue);
    });

    test('marquage historique -> réévaluation idempotente', () {
      final initialGoal = goal();
      final weight = weightForGoal(weights(59.5));
      final fat = fatForGoal(fats(24));
      final first = goalService.analyze(
        goal: initialGoal,
        asOf: asOf,
        weightProgress: weight,
        bodyFatProgress: fat,
        nutritionWeightProgress: null,
      );
      expect(first.shouldMarkWeightAchieved, isTrue);
      expect(first.shouldMarkBodyFatAchieved, isTrue);

      final updatedGoal = initialGoal.markAchieved(
        weight: first.shouldMarkWeightAchieved,
        bodyFat: first.shouldMarkBodyFatAchieved,
        achievedAt: asOf,
      );
      expect(updatedGoal.targetWeightAchieved, isTrue);
      expect(updatedGoal.targetBodyFatPercentageAchieved, isTrue);
      expect(updatedGoal.targetWeightAchievedAt, asOf);
      expect(updatedGoal.targetBodyFatPercentageAchievedAt, asOf);

      final second = goalService.analyze(
        goal: updatedGoal,
        asOf: asOf,
        weightProgress: weight,
        bodyFatProgress: fat,
        nutritionWeightProgress: null,
      );
      expect(second.shouldMarkWeightAchieved, isFalse);
      expect(second.shouldMarkBodyFatAchieved, isFalse);
      expect(second.bodyFatProgress!.isHistoricallyAchieved, isTrue);
      expect(
        updatedGoal.markAchieved(weight: true, bodyFat: true, achievedAt: asOf),
        same(updatedGoal),
      );
    });

    test('erreur de masse grasse isolée : poids toujours évalué', () {
      // Une analyse issue d'un autre utilisateur est invalide pour cet objectif.
      final foreignFat = fatService.analyze(
        userId: 'other-user',
        measurements: [
          for (final d in [0, 8, 16])
            BodyFatHistory(
              id: 'foreign-$d',
              userId: 'other-user',
              measuredAt: asOf.subtract(Duration(days: d)),
              bodyFatPercentage: 24,
              measurementMethod: 'DEXA',
            ),
        ],
        earliestMeasurementDate: start,
        measurementMethod: 'DEXA',
        asOf: asOf,
      );
      final result = goalService.analyze(
        goal: goal(),
        asOf: asOf,
        weightProgress: weightForGoal(weights(59.5)),
        bodyFatProgress: foreignFat,
        nutritionWeightProgress: weightForNutrition(weights(59.5)),
      );
      expect(result.weightError, isNull);
      expect(result.weightProgress!.weightGoalState, WeightGoalState.reached);
      expect(result.shouldMarkWeightAchieved, isTrue);
      expect(result.bodyFatProgress, isNull);
      expect(
        result.bodyFatError,
        isA<GoalProgressException>().having(
          (e) => e.code,
          'code',
          GoalProgressErrorCode.userMismatch,
        ),
      );
      expect(result.shouldMarkBodyFatAchieved, isFalse);
      expect(result.shouldSuggestNutritionRecalculation, isTrue);
    });

    test('erreur de poids isolée : masse grasse toujours évaluée', () {
      final unfilteredWeight = weightForNutrition(weights(59.5));
      final result = goalService.analyze(
        goal: goal(),
        asOf: asOf,
        weightProgress: unfilteredWeight,
        bodyFatProgress: fatForGoal(fats(24)),
        nutritionWeightProgress: unfilteredWeight,
      );
      expect(result.weightProgress, isNull);
      expect(
        result.weightError,
        isA<GoalProgressException>().having(
          (e) => e.code,
          'code',
          GoalProgressErrorCode.measurementPeriodMismatch,
        ),
      );
      expect(result.bodyFatError, isNull);
      expect(result.bodyFatProgress!.state, BodyFatGoalState.reached);
      expect(result.shouldMarkBodyFatAchieved, isTrue);
      expect(result.shouldSuggestNutritionRecalculation, isTrue);
    });

    test('évolution de poids -> recalcul nutritionnel même sans cible', () {
      final history = weights(63.5);
      final nutrition = weightForNutrition(history);
      expect(nutrition.shouldSuggestRecalculation, isTrue);
      final result = goalService.analyze(
        goal: goal(targetWeight: null, targetFat: null),
        asOf: asOf,
        weightProgress: null,
        nutritionWeightProgress: nutrition,
      );
      expect(result.evaluationState, UserGoalEvaluationState.noTarget);
      expect(result.shouldSuggestNutritionRecalculation, isTrue);
      expect(result.nutritionError, isNull);
      expect(result.shouldMarkWeightAchieved, isFalse);
    });

    test('évolution inférieure au seuil -> aucun recalcul', () {
      final nutrition = weightForNutrition(weights(64.5));
      expect(nutrition.shouldSuggestRecalculation, isFalse);
      final result = goalService.analyze(
        goal: goal(targetWeight: null, targetFat: null),
        asOf: asOf,
        weightProgress: null,
        nutritionWeightProgress: nutrition,
      );
      expect(result.shouldSuggestNutritionRecalculation, isFalse);
    });
  });
}
