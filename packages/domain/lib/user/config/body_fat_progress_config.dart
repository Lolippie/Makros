/// Paramètres statistiques de l'analyse de masse grasse.
/// Les seuils sont des choix produit, pas des seuils cliniques.
class BodyFatProgressConfig {
  final int trendWindowDays;
  final int minimumMeasurementDays;
  final int minimumMeasurementSpanDays;
  final int maxDaysSinceLastMeasurement;
  final double stableThresholdPercentagePoints;
  final double minimumCenterSpacingFraction;
  final double comparisonEpsilonPercentagePoints;

  const BodyFatProgressConfig({
    this.trendWindowDays = 28,
    this.minimumMeasurementDays = 2,
    this.minimumMeasurementSpanDays = 7,
    this.maxDaysSinceLastMeasurement = 14,
    this.stableThresholdPercentagePoints = 0.5,
    this.minimumCenterSpacingFraction = 0.5,
    this.comparisonEpsilonPercentagePoints = 1e-9,
  });

  void validate() {
    if (trendWindowDays < 2) {
      throw ArgumentError.value(trendWindowDays, 'trendWindowDays', 'doit être >= 2');
    }
    if (minimumMeasurementDays < 1 || minimumMeasurementDays > trendWindowDays) {
      throw ArgumentError.value(minimumMeasurementDays, 'minimumMeasurementDays', 'doit être compris entre 1 et trendWindowDays');
    }
    if (minimumMeasurementSpanDays < 0 ||
        minimumMeasurementSpanDays >= trendWindowDays ||
        (minimumMeasurementDays == 1 && minimumMeasurementSpanDays != 0)) {
      throw ArgumentError.value(minimumMeasurementSpanDays, 'minimumMeasurementSpanDays', 'incompatible avec la fenêtre et le nombre minimal de jours');
    }
    if (maxDaysSinceLastMeasurement < 0 || maxDaysSinceLastMeasurement >= trendWindowDays) {
      throw ArgumentError.value(maxDaysSinceLastMeasurement, 'maxDaysSinceLastMeasurement', 'doit être compris entre 0 et trendWindowDays - 1');
    }
    if (!stableThresholdPercentagePoints.isFinite || stableThresholdPercentagePoints < 0) {
      throw ArgumentError.value(stableThresholdPercentagePoints, 'stableThresholdPercentagePoints', 'doit être fini et >= 0');
    }
    if (!comparisonEpsilonPercentagePoints.isFinite || comparisonEpsilonPercentagePoints < 0) {
      throw ArgumentError.value(comparisonEpsilonPercentagePoints, 'comparisonEpsilonPercentagePoints', 'doit être fini et >= 0');
    }
    if (!minimumCenterSpacingFraction.isFinite ||
        minimumCenterSpacingFraction <= 0 || minimumCenterSpacingFraction > 1) {
      throw ArgumentError.value(minimumCenterSpacingFraction, 'minimumCenterSpacingFraction', 'doit être dans ]0, 1]');
    }
  }
}
