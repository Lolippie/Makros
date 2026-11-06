/// Tendance entre fenêtres de mesures, indépendante des objectifs.
enum BodyFatTrendStatus { insufficientData, decreasing, stable, increasing, unknown }

class BodyFatProgressResult {
  final String userId;
  final DateTime asOfDay;
  final DateTime? earliestMeasurementDate;
  final String? measurementMethod;
  final int trendWindowDays;

  /// Indique si une méthode a été sélectionnée, même si elle est inconnue.
  final bool hasSelectedMethod;
  bool get usesUnknownMethod => hasSelectedMethod && measurementMethod == null;

  final double? currentTrendPercentage;
  final double? previousTrendPercentage;
  final double? changeBetweenWindowsPercentagePoints;
  final double? weeklyChangePercentagePoints;
  final int measurementDaysInCurrentWindow;
  final int measurementDaysInPreviousWindow;
  final DateTime? lastMeasurementDate;
  final bool isTrendFresh;
  final BodyFatTrendStatus trendStatus;
  final double goalTolerancePercentagePoints;
  final double comparisonEpsilonPercentagePoints;

  const BodyFatProgressResult({
    required this.userId,
    required this.asOfDay,
    required this.earliestMeasurementDate,
    required this.measurementMethod,
    this.trendWindowDays = 28,
    required this.hasSelectedMethod,
    required this.currentTrendPercentage,
    required this.previousTrendPercentage,
    required this.changeBetweenWindowsPercentagePoints,
    required this.weeklyChangePercentagePoints,
    required this.measurementDaysInCurrentWindow,
    required this.measurementDaysInPreviousWindow,
    required this.lastMeasurementDate,
    required this.isTrendFresh,
    required this.trendStatus,
    this.goalTolerancePercentagePoints = 1.0,
    this.comparisonEpsilonPercentagePoints = 1e-9,
  });

  bool get hasUsableCurrentTrend =>
      currentTrendPercentage != null && isTrendFresh;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyFatProgressResult &&
          other.userId == userId &&
          other.asOfDay == asOfDay &&
          other.earliestMeasurementDate == earliestMeasurementDate &&
          other.measurementMethod == measurementMethod &&
          other.trendWindowDays == trendWindowDays &&
          other.hasSelectedMethod == hasSelectedMethod &&
          other.currentTrendPercentage == currentTrendPercentage &&
          other.previousTrendPercentage == previousTrendPercentage &&
          other.changeBetweenWindowsPercentagePoints ==
              changeBetweenWindowsPercentagePoints &&
          other.weeklyChangePercentagePoints == weeklyChangePercentagePoints &&
          other.measurementDaysInCurrentWindow ==
              measurementDaysInCurrentWindow &&
          other.measurementDaysInPreviousWindow ==
              measurementDaysInPreviousWindow &&
          other.lastMeasurementDate == lastMeasurementDate &&
          other.isTrendFresh == isTrendFresh &&
          other.trendStatus == trendStatus &&
          other.goalTolerancePercentagePoints ==
              goalTolerancePercentagePoints &&
          other.comparisonEpsilonPercentagePoints ==
              comparisonEpsilonPercentagePoints;

  @override
  int get hashCode => Object.hashAll([
    userId,
    asOfDay,
    earliestMeasurementDate,
    measurementMethod,
    trendWindowDays,
    hasSelectedMethod,
    currentTrendPercentage,
    previousTrendPercentage,
    changeBetweenWindowsPercentagePoints,
    weeklyChangePercentagePoints,
    measurementDaysInCurrentWindow,
    measurementDaysInPreviousWindow,
    lastMeasurementDate,
    isTrendFresh,
    trendStatus,
    goalTolerancePercentagePoints,
    comparisonEpsilonPercentagePoints,
  ]);

  @override
  String toString() =>
      'BodyFatProgressResult('
      'userId: $userId, asOfDay: $asOfDay, '
      'earliestMeasurementDate: $earliestMeasurementDate, '
      'measurementMethod: $measurementMethod, '
      'trendWindowDays: $trendWindowDays, '
      'hasSelectedMethod: $hasSelectedMethod, '
      'currentTrendPercentage: $currentTrendPercentage, '
      'previousTrendPercentage: $previousTrendPercentage, '
      'changeBetweenWindowsPercentagePoints: $changeBetweenWindowsPercentagePoints, '
      'weeklyChangePercentagePoints: $weeklyChangePercentagePoints, '
      'measurementDaysInCurrentWindow: $measurementDaysInCurrentWindow, '
      'measurementDaysInPreviousWindow: $measurementDaysInPreviousWindow, '
      'lastMeasurementDate: $lastMeasurementDate, '
      'isTrendFresh: $isTrendFresh, trendStatus: $trendStatus, '
      'goalTolerancePercentagePoints: $goalTolerancePercentagePoints, '
      'comparisonEpsilonPercentagePoints: $comparisonEpsilonPercentagePoints)';
}
