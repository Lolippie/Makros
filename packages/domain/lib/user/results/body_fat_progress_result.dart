/// Décrit la variation entre deux fenêtres complètes, pas l'atteinte d'un but.
enum BodyFatTrendStatus { insufficientData, decreasing, stable, increasing }

class BodyFatProgressResult {
  final String userId;
  final DateTime asOfDay;
  final DateTime? earliestMeasurementDate;
  /// Méthode choisie pour la comparaison. Null = méthode non renseignée.
  final String? measurementMethod;
  /// Moyennes en % ; les différences sont en points de pourcentage.
  final double? currentTrendPercentage;
  final double? previousTrendPercentage;
  final double? changeBetweenWindowsPercentagePoints;
  final double? weeklyChangePercentagePoints;
  final int measurementDaysInCurrentWindow;
  final int measurementDaysInPreviousWindow;
  final DateTime? lastMeasurementDate;
  final bool isTrendFresh;
  final BodyFatTrendStatus trendStatus;

  const BodyFatProgressResult({
    required this.userId,
    required this.asOfDay,
    required this.earliestMeasurementDate,
    required this.measurementMethod,
    required this.currentTrendPercentage,
    required this.previousTrendPercentage,
    required this.changeBetweenWindowsPercentagePoints,
    required this.weeklyChangePercentagePoints,
    required this.measurementDaysInCurrentWindow,
    required this.measurementDaysInPreviousWindow,
    required this.lastMeasurementDate,
    required this.isTrendFresh,
    required this.trendStatus,
  });

  bool get hasUsableCurrentTrend => currentTrendPercentage != null && isTrendFresh;

  @override
  bool operator ==(Object other) => identical(this, other) ||
      other is BodyFatProgressResult &&
          other.userId == userId &&
          other.asOfDay == asOfDay &&
          other.earliestMeasurementDate == earliestMeasurementDate &&
          other.measurementMethod == measurementMethod &&
          other.currentTrendPercentage == currentTrendPercentage &&
          other.previousTrendPercentage == previousTrendPercentage &&
          other.changeBetweenWindowsPercentagePoints == changeBetweenWindowsPercentagePoints &&
          other.weeklyChangePercentagePoints == weeklyChangePercentagePoints &&
          other.measurementDaysInCurrentWindow == measurementDaysInCurrentWindow &&
          other.measurementDaysInPreviousWindow == measurementDaysInPreviousWindow &&
          other.lastMeasurementDate == lastMeasurementDate &&
          other.isTrendFresh == isTrendFresh &&
          other.trendStatus == trendStatus;

  @override
  int get hashCode => Object.hashAll([
        userId, asOfDay, earliestMeasurementDate, measurementMethod,
        currentTrendPercentage, previousTrendPercentage,
        changeBetweenWindowsPercentagePoints, weeklyChangePercentagePoints,
        measurementDaysInCurrentWindow, measurementDaysInPreviousWindow,
        lastMeasurementDate, isTrendFresh, trendStatus,
      ]);

  @override
  String toString() => 'BodyFatProgressResult('
      'userId: $userId, asOfDay: $asOfDay, '
      'earliestMeasurementDate: $earliestMeasurementDate, '
      'measurementMethod: $measurementMethod, '
      'currentTrendPercentage: $currentTrendPercentage, '
      'previousTrendPercentage: $previousTrendPercentage, '
      'changeBetweenWindowsPercentagePoints: $changeBetweenWindowsPercentagePoints, '
      'weeklyChangePercentagePoints: $weeklyChangePercentagePoints, '
      'measurementDaysInCurrentWindow: $measurementDaysInCurrentWindow, '
      'measurementDaysInPreviousWindow: $measurementDaysInPreviousWindow, '
      'lastMeasurementDate: $lastMeasurementDate, '
      'isTrendFresh: $isTrendFresh, trendStatus: $trendStatus)';
}
