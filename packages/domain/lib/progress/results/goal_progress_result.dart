enum WeightGoalState { unknown, stale, notReached, reached }

class GoalProgressResult {
  final String goalId;
  final WeightGoalState weightGoalState;

  /// Vrai seulement pour un franchissement frais dans le sens cut/bulk.
  final bool hasExceededWeightTarget;

  const GoalProgressResult({
    required this.goalId,
    required this.weightGoalState,
    required this.hasExceededWeightTarget,
  });

  bool get isEvaluable =>
      weightGoalState == WeightGoalState.notReached ||
      weightGoalState == WeightGoalState.reached;
  bool get isWeightGoalReached => weightGoalState == WeightGoalState.reached;
  bool get isStale => weightGoalState == WeightGoalState.stale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalProgressResult &&
          other.goalId == goalId &&
          other.weightGoalState == weightGoalState &&
          other.hasExceededWeightTarget == hasExceededWeightTarget;

  @override
  int get hashCode =>
      Object.hash(goalId, weightGoalState, hasExceededWeightTarget);

  @override
  String toString() =>
      'GoalProgressResult(goalId: $goalId, '
      'weightGoalState: $weightGoalState, '
      'hasExceededWeightTarget: $hasExceededWeightTarget)';
}
