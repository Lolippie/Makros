enum WeightTrendStatus {
  insufficientData,
  unknown,
  stable,
  decreasing,
  increasing,
}

/// Snapshot immuable d'une analyse de pesées, sans décision d'atteinte d'objectif.
class WeightProgressResult {
  /// Utilisateur auquel appartiennent les pesées analysées.
  final String userId;
  /// Jour civil inclusif de l'analyse.
  final DateTime asOfDay;
  /// Date minimale réellement appliquée aux mesures, ou null pour l'analyse globale.
  final DateTime? earliestMeasurementDate;
  final double referenceWeightKg;
  final double? currentTrendWeightKg;
  final double? previousTrendWeightKg;
  final double? changeFromReferenceKg;
  final double? changeBetweenWindowsKg;
  final double? weeklyWeightChangeKg;
  final double? targetWeightKg;
  final double? remainingToTargetKg;
  final int measurementDaysInCurrentWindow;
  final int measurementDaysInPreviousWindow;
  final DateTime? lastMeasurementDate;
  /// La tendance est assez récente; trendStatus peut rester historique.
  final bool isTrendFresh;
  final WeightTrendStatus trendStatus;
  final bool shouldSuggestRecalculation;
  /// Demi-largeur en kg de la zone cible, utilisée par GoalProgressService.
  final double goalToleranceKg;
  /// Tolérance numérique en kg ajoutée aux bornes des comparaisons.
  final double comparisonEpsilonKg;

  const WeightProgressResult({
    required this.userId,
    required this.asOfDay,
    required this.earliestMeasurementDate,
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
    required this.shouldSuggestRecalculation,
    required this.goalToleranceKg,
    required this.comparisonEpsilonKg,
  });

  bool get hasSufficientData => currentTrendWeightKg != null;
  bool get hasComparableData =>
      currentTrendWeightKg != null && previousTrendWeightKg != null;
  bool get hasUsableData => hasSufficientData && isTrendFresh;

  List<Object?> get _values => [
    userId, asOfDay, earliestMeasurementDate, referenceWeightKg,
    currentTrendWeightKg, previousTrendWeightKg, changeFromReferenceKg,
    changeBetweenWindowsKg, weeklyWeightChangeKg, targetWeightKg,
    remainingToTargetKg, measurementDaysInCurrentWindow,
    measurementDaysInPreviousWindow, lastMeasurementDate, isTrendFresh,
    trendStatus, shouldSuggestRecalculation, goalToleranceKg,
    comparisonEpsilonKg,
  ];

  @override
  bool operator ==(Object other) => identical(this, other) ||
      other is WeightProgressResult && _sameValues(_values, other._values);

  static bool _sameValues(List<Object?> a, List<Object?> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_values);

  @override
  String toString() => 'WeightProgressResult('
      'userId: $userId, asOfDay: $asOfDay, '
      'earliestMeasurementDate: $earliestMeasurementDate, '
      'referenceWeightKg: $referenceWeightKg, '
      'currentTrendWeightKg: $currentTrendWeightKg, '
      'previousTrendWeightKg: $previousTrendWeightKg, '
      'changeFromReferenceKg: $changeFromReferenceKg, '
      'changeBetweenWindowsKg: $changeBetweenWindowsKg, '
      'weeklyWeightChangeKg: $weeklyWeightChangeKg, '
      'targetWeightKg: $targetWeightKg, '
      'remainingToTargetKg: $remainingToTargetKg, '
      'measurementDaysInCurrentWindow: $measurementDaysInCurrentWindow, '
      'measurementDaysInPreviousWindow: $measurementDaysInPreviousWindow, '
      'lastMeasurementDate: $lastMeasurementDate, '
      'isTrendFresh: $isTrendFresh, trendStatus: $trendStatus, '
      'shouldSuggestRecalculation: $shouldSuggestRecalculation, '
      'goalToleranceKg: $goalToleranceKg, '
      'comparisonEpsilonKg: $comparisonEpsilonKg)';
}
