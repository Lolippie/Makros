/// Paramètres produit de l'analyse de masse grasse, non seuils cliniques.
class BodyFatProgressConfig {
  final int trendWindowDays;
  final int minimumMeasurementDays;
  final int minimumMeasurementSpanDays;
  final int maxDaysSinceLastMeasurement;
  final double stableThresholdPercentagePoints;
  final double minimumCenterSpacingFraction;
  final double comparisonEpsilonPercentagePoints;
  final double goalTolerancePercentagePoints;
  final double minimumPlausibleBodyFatPercentage;
  final double maximumPlausibleBodyFatPercentage;

  const BodyFatProgressConfig({
    this.trendWindowDays = 28,
    this.minimumMeasurementDays = 3,
    this.minimumMeasurementSpanDays = 7,
    this.maxDaysSinceLastMeasurement = 14,
    this.stableThresholdPercentagePoints = 0.5,
    this.minimumCenterSpacingFraction = 0.5,
    this.comparisonEpsilonPercentagePoints = 1e-9,
    this.goalTolerancePercentagePoints = 1.0,
    this.minimumPlausibleBodyFatPercentage = 3.0,
    this.maximumPlausibleBodyFatPercentage = 60.0,
  });

  void validate() {
    if (trendWindowDays < 3) {
      throw ArgumentError.value(trendWindowDays, 'trendWindowDays', 'doit être >= 3');
    }
    if (minimumMeasurementDays < 1 || minimumMeasurementDays > trendWindowDays) {
      throw ArgumentError.value(minimumMeasurementDays, 'minimumMeasurementDays', 'hors fenêtre');
    }
    if (minimumMeasurementSpanDays < 0 ||
        minimumMeasurementSpanDays >= trendWindowDays ||
        (minimumMeasurementDays == 1 && minimumMeasurementSpanDays != 0)) {
      throw ArgumentError.value(minimumMeasurementSpanDays, 'minimumMeasurementSpanDays', 'incompatible');
    }
    if (maxDaysSinceLastMeasurement < 0 ||
        maxDaysSinceLastMeasurement >= trendWindowDays - 1) {
      throw ArgumentError.value(maxDaysSinceLastMeasurement, 'maxDaysSinceLastMeasurement', 'doit être <= trendWindowDays - 2');
    }
    if (!stableThresholdPercentagePoints.isFinite || stableThresholdPercentagePoints < 0) {
      throw ArgumentError.value(stableThresholdPercentagePoints, 'stableThresholdPercentagePoints', 'doit être fini et >= 0');
    }
    if (!comparisonEpsilonPercentagePoints.isFinite || comparisonEpsilonPercentagePoints < 0) {
      throw ArgumentError.value(comparisonEpsilonPercentagePoints, 'comparisonEpsilonPercentagePoints', 'doit être fini et >= 0');
    }
    if (!goalTolerancePercentagePoints.isFinite || goalTolerancePercentagePoints < 0) {
      throw ArgumentError.value(goalTolerancePercentagePoints, 'goalTolerancePercentagePoints', 'doit être fini et >= 0');
    }
    if (!minimumCenterSpacingFraction.isFinite || minimumCenterSpacingFraction <= 0 || minimumCenterSpacingFraction > 1) {
      throw ArgumentError.value(minimumCenterSpacingFraction, 'minimumCenterSpacingFraction', 'doit être dans ]0, 1]');
    }
    if (!minimumPlausibleBodyFatPercentage.isFinite ||
        !maximumPlausibleBodyFatPercentage.isFinite ||
        minimumPlausibleBodyFatPercentage <= 0 ||
        maximumPlausibleBodyFatPercentage >= 100 ||
        minimumPlausibleBodyFatPercentage >= maximumPlausibleBodyFatPercentage) {
      throw ArgumentError('Bornes plausibles : 0 < minimum < maximum < 100');
    }
  }
}
