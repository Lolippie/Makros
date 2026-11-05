enum WeightTrendStatus {
  insufficientData,
  unknown,
  stable,
  decreasing,
  increasing,
}

enum WeightGoalProgressStatus { unknown, notReached, reached, exceeded }

/// Immutable analysis snapshot. No user goal or calorie target is mutated.
class WeightProgressResult {
  final double referenceWeightKg;
  final double? currentTrendWeightKg;
  final double? previousTrendWeightKg;
  final double? changeFromReferenceKg;
  final double? changeBetweenWindowsKg;
  /// Normalized change between window averages, in kg per 7 days.
  final double? weeklyWeightChangeKg;
  final double? targetWeightKg;
  /// Signed: target minus current; negative for a lower target.
  final double? remainingToTargetKg;
  final int measurementDaysInCurrentWindow;
  final int measurementDaysInPreviousWindow;
  final DateTime? lastMeasurementDate;
  final bool isTrendFresh;
  final WeightTrendStatus trendStatus;
  final WeightGoalProgressStatus goalProgressStatus;
  final bool shouldSuggestRecalculation;

  const WeightProgressResult({
    required this.referenceWeightKg,
    required this.currentTrendWeightKg,
    required this.previousTrendWeightKg,
    required this.changeFromReferenceKg,
    required this.changeBetweenWindowsKg,
    required this.weeklyWeightChangeKg,
    required this.targetWeightKg,
    required this.remainingToTargetKg,
    required this.measurementDaysInCurrentWindow,
    required this.measurementDaysInPreviousWindow,
    required this.lastMeasurementDate,
    required this.isTrendFresh,
    required this.trendStatus,
    required this.goalProgressStatus,
    required this.shouldSuggestRecalculation,
  });

  bool get hasSufficientData => currentTrendWeightKg != null;
  bool get hasComparableData =>
      currentTrendWeightKg != null && previousTrendWeightKg != null;
  bool get hasUsableData => hasSufficientData && isTrendFresh;
  bool get hasEvaluableGoal =>
      goalProgressStatus != WeightGoalProgressStatus.unknown;
}
