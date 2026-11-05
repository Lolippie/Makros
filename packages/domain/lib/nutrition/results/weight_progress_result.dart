enum WeightTrendStatus {
  insufficientData,
  unknown,
  stable,
  decreasing,
  increasing,
}

enum WeightGoalProgressStatus { unknown, notReached, reached, exceeded }

/// Résultat immuable : ne modifie ni les objectifs ni les pesées.
class WeightProgressResult {
  final double referenceWeightKg;
  final double? currentTrendWeightKg;
  final double? previousTrendWeightKg;
  final double? changeFromReferenceKg;
  final double? changeBetweenWindowsKg;
  /// Estimation en kg/semaine basée sur les dates réellement mesurées.
  /// Null si les centres temporels sont trop proches pour une estimation fiable.
  final double? weeklyWeightChangeKg;
  final double? targetWeightKg;
  /// Cible moins moyenne actuelle (valeur signée).
  final double? remainingToTargetKg;
  final int measurementDaysInCurrentWindow;
  final int measurementDaysInPreviousWindow;
  /// Dernier jour mesuré dans la fenêtre actuelle. Peut être non nul même
  /// lorsque currentTrendWeightKg est nul (données insuffisantes).
  final DateTime? lastMeasurementDate;
  /// Indique si la dernière pesée de la fenêtre actuelle est assez récente.
  /// trendStatus et goalProgressStatus décrivent une analyse historique :
  /// ils peuvent être renseignés même si isTrendFresh est false.
  /// L’interface doit vérifier isTrendFresh avant d’afficher un statut actuel.
  /// Une valeur false ne supprime pas les statuts historiques.
  final bool isTrendFresh;
  final WeightTrendStatus trendStatus;
  final WeightGoalProgressStatus goalProgressStatus;
  /// Suggestion uniquement si la tendance est fraîche et si l’écart absolu
  /// au poids de référence atteint le seuil de configuration (avec epsilon).
  /// Ne déclenche aucun recalcul ni aucune modification.
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
  /// Nom explicite pour l’UI ; actuellement équivalent à isTrendFresh,
  /// puisque le service exige une moyenne disponible pour être « frais ».
  bool get hasUsableData => hasSufficientData && isTrendFresh;
  /// Indique qu’un statut historique est disponible, même si les données
  /// ne sont plus fraîches : consulter isTrendFresh pour un affichage actuel.
  bool get hasEvaluableGoal =>
      goalProgressStatus != WeightGoalProgressStatus.unknown;

  /// Égalité par valeur pour les tests et les comparaisons de snapshots.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightProgressResult &&
          other.referenceWeightKg == referenceWeightKg &&
          other.currentTrendWeightKg == currentTrendWeightKg &&
          other.previousTrendWeightKg == previousTrendWeightKg &&
          other.changeFromReferenceKg == changeFromReferenceKg &&
          other.changeBetweenWindowsKg == changeBetweenWindowsKg &&
          other.weeklyWeightChangeKg == weeklyWeightChangeKg &&
          other.targetWeightKg == targetWeightKg &&
          other.remainingToTargetKg == remainingToTargetKg &&
          other.measurementDaysInCurrentWindow == measurementDaysInCurrentWindow &&
          other.measurementDaysInPreviousWindow == measurementDaysInPreviousWindow &&
          other.lastMeasurementDate == lastMeasurementDate &&
          other.isTrendFresh == isTrendFresh &&
          other.trendStatus == trendStatus &&
          other.goalProgressStatus == goalProgressStatus &&
          other.shouldSuggestRecalculation == shouldSuggestRecalculation;

  @override
  int get hashCode => Object.hashAll([
        referenceWeightKg,
        currentTrendWeightKg,
        previousTrendWeightKg,
        changeFromReferenceKg,
        changeBetweenWindowsKg,
        weeklyWeightChangeKg,
        targetWeightKg,
        remainingToTargetKg,
        measurementDaysInCurrentWindow,
        measurementDaysInPreviousWindow,
        lastMeasurementDate,
        isTrendFresh,
        trendStatus,
        goalProgressStatus,
        shouldSuggestRecalculation,
      ]);

  @override
  String toString() => 'WeightProgressResult('
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
      'isTrendFresh: $isTrendFresh, '
      'trendStatus: $trendStatus, '
      'goalProgressStatus: $goalProgressStatus, '
      'shouldSuggestRecalculation: $shouldSuggestRecalculation)';

}
