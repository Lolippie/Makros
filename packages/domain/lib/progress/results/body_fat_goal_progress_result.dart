enum BodyFatGoalState {
  inactive,
  invalidGoal,
  noTarget,
  noMeasurementMethod,
  noAnalysis,
  insufficientData,
  stale,
  notReached,
  reached,
}

class BodyFatGoalProgressResult {
  final String goalId;
  final BodyFatGoalState state;
  final double? targetPercentage;
  final double? currentPercentage;

  /// Ecart signe current - target, en points de pourcentage.
  /// En bulk, la cible est un plafond : une valeur positive le depasse.
  final double? remainingPercentagePoints;
  final bool isHistoricallyAchieved;
  final bool shouldMarkAchieved;

  const BodyFatGoalProgressResult({
    required this.goalId,
    required this.state,
    required this.targetPercentage,
    required this.currentPercentage,
    required this.remainingPercentagePoints,
    required this.isHistoricallyAchieved,
    required this.shouldMarkAchieved,
  });

  /// Respect actuel de la cible, eventuellement a la tolerance pres.
  bool get isReached => state == BodyFatGoalState.reached;
  bool get hasReachedAtLeastOnce => isHistoricallyAchieved;
  double? get absoluteDistancePercentagePoints =>
      remainingPercentagePoints?.abs();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyFatGoalProgressResult &&
          other.goalId == goalId &&
          other.state == state &&
          other.targetPercentage == targetPercentage &&
          other.currentPercentage == currentPercentage &&
          other.remainingPercentagePoints == remainingPercentagePoints &&
          other.isHistoricallyAchieved == isHistoricallyAchieved &&
          other.shouldMarkAchieved == shouldMarkAchieved;

  @override
  int get hashCode => Object.hash(
    goalId,
    state,
    targetPercentage,
    currentPercentage,
    remainingPercentagePoints,
    isHistoricallyAchieved,
    shouldMarkAchieved,
  );

  @override
  String toString() =>
      'BodyFatGoalProgressResult('
      'goalId: $goalId, state: $state, '
      'targetPercentage: $targetPercentage, '
      'currentPercentage: $currentPercentage, '
      'remainingPercentagePoints: $remainingPercentagePoints, '
      'isHistoricallyAchieved: $isHistoricallyAchieved, '
      'shouldMarkAchieved: $shouldMarkAchieved)';
}
