/// Tendance des deux fenêtres ; unknown signifie qu'une seule fenêtre
/// possède une moyenne exploitable.
enum BodyFatTrendStatus {
  insufficientData,
  unknown,
  decreasing,
  stable,
  increasing,
}

/// Analyse immutable, sans décision d'atteinte d'un objectif.
///
/// La tendance est lissée sur [trendWindowDays] jours : une atteinte
/// constatée sur cette moyenne est retardée par rapport à une mesure isolée.
/// La méthode est une clé normalisée (non un libellé destiné à l'UI).
class BodyFatProgressResult {
  final String userId;
  final DateTime asOfDay;
  final DateTime? earliestMeasurementDate;
  final int trendWindowDays;
  /// Null : méthode inconnue OU aucune méthode sélectionnée.
  /// [hasSelectedMethod] distingue les deux cas.
  final String? measurementMethod;
  /// Indique qu’une méthode a été explicitement sélectionnée, même si
  /// aucune mesure correspondante n’existe dans la période analysée.
  /// Pour distinguer « sélection vide » et « données disponibles »,
  /// consulter [lastMeasurementDate] et [measurementDaysInCurrentWindow].
  /// Une date de dernière mesure ne garantit pas une moyenne exploitable.
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
    required this.trendWindowDays,
    required this.measurementMethod,
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
    required this.goalTolerancePercentagePoints,
    required this.comparisonEpsilonPercentagePoints,
  });

  bool get hasUsableCurrentTrend => currentTrendPercentage != null && isTrendFresh;

  @override
  bool operator ==(Object other) => identical(this, other) ||
      other is BodyFatProgressResult &&
          other.userId == userId &&
          other.asOfDay == asOfDay &&
          other.earliestMeasurementDate == earliestMeasurementDate &&
          other.trendWindowDays == trendWindowDays &&
          other.measurementMethod == measurementMethod &&
          other.hasSelectedMethod == hasSelectedMethod &&
          other.currentTrendPercentage == currentTrendPercentage &&
          other.previousTrendPercentage == previousTrendPercentage &&
          other.changeBetweenWindowsPercentagePoints == changeBetweenWindowsPercentagePoints &&
          other.weeklyChangePercentagePoints == weeklyChangePercentagePoints &&
          other.measurementDaysInCurrentWindow == measurementDaysInCurrentWindow &&
          other.measurementDaysInPreviousWindow == measurementDaysInPreviousWindow &&
          other.lastMeasurementDate == lastMeasurementDate &&
          other.isTrendFresh == isTrendFresh &&
          other.trendStatus == trendStatus &&
          other.goalTolerancePercentagePoints == goalTolerancePercentagePoints &&
          other.comparisonEpsilonPercentagePoints == comparisonEpsilonPercentagePoints;

  @override
  int get hashCode => Object.hashAll([
        userId, asOfDay, earliestMeasurementDate, trendWindowDays,
        measurementMethod, hasSelectedMethod, currentTrendPercentage,
        previousTrendPercentage, changeBetweenWindowsPercentagePoints,
        weeklyChangePercentagePoints, measurementDaysInCurrentWindow,
        measurementDaysInPreviousWindow, lastMeasurementDate,
        isTrendFresh, trendStatus, goalTolerancePercentagePoints,
        comparisonEpsilonPercentagePoints,
      ]);

  @override
  String toString() => 'BodyFatProgressResult('
      'userId: $userId, asOfDay: $asOfDay, '
      'earliestMeasurementDate: $earliestMeasurementDate, '
      'trendWindowDays: $trendWindowDays, '
      'measurementMethod: $measurementMethod, '
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
