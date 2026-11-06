
/// Paramètres du calcul de tendance de masse grasse.
class BodyFatProgressConfig {
  final int trendWindowDays;
  final int minimumMeasurementDays;
  final int minimumMeasurementSpanDays;
  final int maxDaysSinceLastMeasurement;
  final double minimumCenterSpacingFraction;
  final double stableThresholdPercentagePoints;
  final double goalTolerancePercentagePoints;
  final double comparisonEpsilonPercentagePoints;
  final double minimumPlausibleBodyFatPercentage;
  final double maximumPlausibleBodyFatPercentage;

  const BodyFatProgressConfig({
    this.trendWindowDays = 28,
    this.minimumMeasurementDays = 3,
    this.minimumMeasurementSpanDays = 7,
    this.maxDaysSinceLastMeasurement = 14,
    this.minimumCenterSpacingFraction = 0.5,
    this.stableThresholdPercentagePoints = 0.5,
    this.goalTolerancePercentagePoints = 1.0,
    this.comparisonEpsilonPercentagePoints = 1e-9,
    this.minimumPlausibleBodyFatPercentage = 1.0,
    this.maximumPlausibleBodyFatPercentage = 75.0,
  });

  void validate() {
    if (trendWindowDays < 2) {
      throw ArgumentError.value(
        trendWindowDays,
        'trendWindowDays',
        'doit être supérieur ou égal à 2',
      );
    }

    if (minimumMeasurementDays < 1 ||
        minimumMeasurementDays > trendWindowDays) {
      throw ArgumentError.value(
        minimumMeasurementDays,
        'minimumMeasurementDays',
        'doit être compris entre 1 et trendWindowDays',
      );
    }

    if (minimumMeasurementSpanDays < 0 ||
        minimumMeasurementSpanDays >= trendWindowDays ||
        (minimumMeasurementDays == 1 &&
            minimumMeasurementSpanDays != 0)) {
      throw ArgumentError.value(
        minimumMeasurementSpanDays,
        'minimumMeasurementSpanDays',
        'doit être compris entre 0 et trendWindowDays - 1 ; '
            'doit valoir 0 si une seule journée suffit',
      );
    }

    // Une limite trop grande rendrait toutes les
    // mesures de la fenêtre automatiquement fraîches.
    if (maxDaysSinceLastMeasurement < 0 ||
        maxDaysSinceLastMeasurement >= trendWindowDays - 1) {
      throw ArgumentError.value(
        maxDaysSinceLastMeasurement,
        'maxDaysSinceLastMeasurement',
        'doit être compris entre 0 et trendWindowDays - 2',
      );
    }

    if (!minimumCenterSpacingFraction.isFinite ||
        minimumCenterSpacingFraction <= 0 ||
        minimumCenterSpacingFraction > 1) {
      throw ArgumentError.value(
        minimumCenterSpacingFraction,
        'minimumCenterSpacingFraction',
        'doit être fini et compris dans ]0, 1]',
      );
    }

    _check(
      stableThresholdPercentagePoints,
      'stableThresholdPercentagePoints',
    );

    _check(
      goalTolerancePercentagePoints,
      'goalTolerancePercentagePoints',
    );

    _check(
      comparisonEpsilonPercentagePoints,
      'comparisonEpsilonPercentagePoints',
    );

    if (!minimumPlausibleBodyFatPercentage.isFinite ||
        minimumPlausibleBodyFatPercentage <= 0 ||
        minimumPlausibleBodyFatPercentage >= 100) {
      throw ArgumentError.value(
        minimumPlausibleBodyFatPercentage,
        'minimumPlausibleBodyFatPercentage',
        'doit être fini et compris strictement entre 0 et 100',
      );
    }

    if (!maximumPlausibleBodyFatPercentage.isFinite ||
        maximumPlausibleBodyFatPercentage <= 0 ||
        maximumPlausibleBodyFatPercentage >= 100) {
      throw ArgumentError.value(
        maximumPlausibleBodyFatPercentage,
        'maximumPlausibleBodyFatPercentage',
        'doit être fini et compris strictement entre 0 et 100',
      );
    }

    if (minimumPlausibleBodyFatPercentage >=
        maximumPlausibleBodyFatPercentage) {
      throw ArgumentError.value(
        minimumPlausibleBodyFatPercentage,
        'minimumPlausibleBodyFatPercentage',
        'doit être strictement inférieur '
            'à maximumPlausibleBodyFatPercentage',
      );
    }
  }

  void _check(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'doit être positif ou nul et fini',
      );
    }
  }
}
