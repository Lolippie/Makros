enum GoalProgressErrorCode {
  missingTarget,
  invalidTarget,
  targetMismatch,
  invalidWeightAnalysis,
  invalidGoal,
  userMismatch,
  analysisDateMismatch,
  measurementPeriodMismatch,
}

/// Erreur métier codée, sans texte d'interface.
class GoalProgressException implements Exception {
  final GoalProgressErrorCode code;
  final String? goalId;

  const GoalProgressException(this.code, {this.goalId});

  @override
  String toString() => 'GoalProgressException(code: $code, goalId: $goalId)';
}
