import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/results/weight_progress_result.dart';
import 'package:makros_nutrition/user/exceptions/goal_progress_exception.dart';
import 'package:makros_nutrition/user/results/goal_progress_result.dart';
import 'package:makros_nutrition/user/results/user_goal_progress_result.dart';
import 'package:makros_nutrition/user/user_goal_progress_service.dart';
import 'package:test/test.dart';

void main() {
  final day = DateTime.utc(2026, 11, 6);
  final start = DateTime.utc(2026, 11, 1);
  const service = UserGoalProgressService();

  UserGoal goal({GoalType type = GoalType.cut, double? target = 60,
      bool achieved = false, DateTime? from, DateTime? until}) => UserGoal(
    id: 'goal-1', userId: 'user-1', type: type,
    targetWeight: target, targetWeightAchieved: achieved,
    startDate: from ?? start, endDate: until,
  );

  WeightProgressResult analysis({double? current = 60, bool fresh = true,
      bool recalc = false, String user = 'user-1', DateTime? asOf,
      DateTime? cutoff, double? target = 60}) => WeightProgressResult(
    userId: user, asOfDay: asOf ?? day,
    earliestMeasurementDate: cutoff,
    referenceWeightKg: 65, currentTrendWeightKg: current,
    previousTrendWeightKg: null, changeFromReferenceKg: null,
    changeBetweenWindowsKg: null, weeklyWeightChangeKg: null,
    targetWeightKg: target, remainingToTargetKg: null,
    measurementDaysInCurrentWindow: current == null ? 0 : 3,
    measurementDaysInPreviousWindow: 0,
    lastMeasurementDate: current == null ? null : day,
    isTrendFresh: fresh, trendStatus: WeightTrendStatus.unknown,
    shouldSuggestRecalculation: recalc,
    goalToleranceKg: 0.1, comparisonEpsilonKg: 1e-9,
  );

  test('atteinte fraîche et filtrée : propose le marquage', () {
    final result = service.analyze(goal: goal(), asOf: day,
      weightProgress: analysis(cutoff: start),
      nutritionWeightProgress: analysis(recalc: true));
    expect(result.evaluationState, UserGoalEvaluationState.evaluated);
    expect(result.weightProgress!.weightGoalState, WeightGoalState.reached);
    expect(result.shouldMarkWeightAchieved, isTrue);
    expect(result.shouldSuggestNutritionRecalculation, isTrue);
  });

  test('une analyse non filtrée ne peut pas marquer l’objectif', () {
    expect(() => service.analyze(goal: goal(), asOf: day,
      weightProgress: analysis(), nutritionWeightProgress: null),
      throwsA(isA<GoalProgressException>().having(
        (e) => e.code, 'code', GoalProgressErrorCode.measurementPeriodMismatch)));
  });

  test('analyse périmée : pas de marquage', () {
    final result = service.analyze(goal: goal(), asOf: day,
      weightProgress: analysis(cutoff: start, fresh: false),
      nutritionWeightProgress: null);
    expect(result.weightProgress!.weightGoalState, WeightGoalState.stale);
    expect(result.shouldMarkWeightAchieved, isFalse);
  });

  test('maintenance : jamais de marquage historique automatique', () {
    final result = service.analyze(goal: goal(type: GoalType.maintenance),
      asOf: day, weightProgress: analysis(cutoff: start),
      nutritionWeightProgress: null);
    expect(result.shouldMarkWeightAchieved, isFalse);
  });

  test('sans cible, le recalcul global est conservé', () {
    final result = service.analyze(goal: goal(target: null), asOf: day,
      weightProgress: null,
      nutritionWeightProgress: analysis(recalc: true));
    expect(result.evaluationState, UserGoalEvaluationState.noTarget);
    expect(result.shouldSuggestNutritionRecalculation, isTrue);
  });

  test('objectif inactif, le recalcul global est conservé', () {
    final result = service.analyze(goal: goal(from: day.add(const Duration(days: 1))),
      asOf: day, weightProgress: null,
      nutritionWeightProgress: analysis(recalc: true));
    expect(result.evaluationState, UserGoalEvaluationState.inactive);
    expect(result.shouldSuggestNutritionRecalculation, isTrue);
  });

  test('analyse à une autre date : erreur typée', () {
    expect(() => service.analyze(goal: goal(), asOf: day,
      weightProgress: analysis(cutoff: start,
        asOf: day.subtract(const Duration(days: 1))),
      nutritionWeightProgress: null),
      throwsA(isA<GoalProgressException>().having(
        (e) => e.code, 'code', GoalProgressErrorCode.analysisDateMismatch)));
  });

  test('autre utilisateur : erreur typée', () {
    expect(() => service.analyze(goal: goal(), asOf: day,
      weightProgress: analysis(cutoff: start, user: 'other'),
      nutritionWeightProgress: null),
      throwsA(isA<GoalProgressException>().having(
        (e) => e.code, 'code', GoalProgressErrorCode.userMismatch)));
  });
}
