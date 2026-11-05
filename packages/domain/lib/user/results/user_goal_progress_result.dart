import 'goal_progress_result.dart';

enum UserGoalEvaluationState { inactive, noTarget, noAnalysis, evaluated }

/// Snapshot sans persistance. L'appelant doit persister un marquage proposé.
/// La masse grasse n'est pas encore évaluée.
class UserGoalProgressResult {
  final String goalId;
  final UserGoalEvaluationState evaluationState;
  final GoalProgressResult? weightProgress;
  final bool shouldMarkWeightAchieved;
  final bool shouldSuggestNutritionRecalculation;

  const UserGoalProgressResult({
    required this.goalId,
    required this.evaluationState,
    required this.weightProgress,
    required this.shouldMarkWeightAchieved,
    required this.shouldSuggestNutritionRecalculation,
  });

  @override
  bool operator ==(Object other) => identical(this, other) ||
      other is UserGoalProgressResult && other.goalId == goalId &&
      other.evaluationState == evaluationState &&
      other.weightProgress == weightProgress &&
      other.shouldMarkWeightAchieved == shouldMarkWeightAchieved &&
      other.shouldSuggestNutritionRecalculation ==
          shouldSuggestNutritionRecalculation;

  @override
  int get hashCode => Object.hash(goalId, evaluationState, weightProgress,
      shouldMarkWeightAchieved, shouldSuggestNutritionRecalculation);

  @override
  String toString() => 'UserGoalProgressResult(goalId: $goalId, '
      'evaluationState: $evaluationState, weightProgress: $weightProgress, '
      'shouldMarkWeightAchieved: $shouldMarkWeightAchieved, '
      'shouldSuggestNutritionRecalculation: '
      '$shouldSuggestNutritionRecalculation)';
}
