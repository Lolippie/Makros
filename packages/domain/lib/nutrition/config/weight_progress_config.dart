/// Paramètres de l'analyse de l'évolution du poids.
class WeightProgressConfig {
  final double recalculationThresholdKg;
  final int trendWindowDays;
  final int minimumMeasurementDays;
  final int minimumMeasurementSpanDays;
  final int maxDaysSinceLastMeasurement;
  final double stableThresholdKg;
  final double goalToleranceKg;
  final double comparisonEpsilonKg;

  /// Écart minimal entre les centres temporels, en fraction de la fenêtre.
  /// Doit être strictement positif et inférieur ou égal à 1.
  final double minimumCenterSpacingFraction;

  /// Bornes facultatives de plausibilité des pesées.
  final double? minimumPlausibleWeightKg;
  final double? maximumPlausibleWeightKg;

  const WeightProgressConfig({
    this.recalculationThresholdKg = 1.0,
    this.trendWindowDays = 7,
    this.minimumMeasurementDays = 3,
    this.minimumMeasurementSpanDays = 2,
    this.maxDaysSinceLastMeasurement = 3,
    this.stableThresholdKg = 0.2,
    this.goalToleranceKg = 0.1,
    this.comparisonEpsilonKg = 1e-9,
    this.minimumCenterSpacingFraction = 0.5,
    this.minimumPlausibleWeightKg,
    this.maximumPlausibleWeightKg,
  });

  void validate() {
    // Deux jours minimum pour autoriser un test de fraîcheur non trivial.
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
        (minimumMeasurementDays == 1 && minimumMeasurementSpanDays != 0)) {
      throw ArgumentError.value(
        minimumMeasurementSpanDays,
        'minimumMeasurementSpanDays',
        'doit être compris entre 0 et trendWindowDays - 1 ; '
            'doit valoir 0 si une seule journée suffit',
      );
    }

    // Sinon toutes les moyennes valides de la fenêtre seraient « fraîches ».
    if (maxDaysSinceLastMeasurement < 0 ||
        maxDaysSinceLastMeasurement >= trendWindowDays - 1) {
      throw ArgumentError.value(
        maxDaysSinceLastMeasurement,
        'maxDaysSinceLastMeasurement',
        'doit être compris entre 0 et trendWindowDays - 2',
      );
    }

    _check(
      recalculationThresholdKg,
      'recalculationThresholdKg',
      positive: true,
    );
    _check(stableThresholdKg, 'stableThresholdKg');
    _check(goalToleranceKg, 'goalToleranceKg');
    _check(comparisonEpsilonKg, 'comparisonEpsilonKg');

    if (!minimumCenterSpacingFraction.isFinite ||
        minimumCenterSpacingFraction <= 0 ||
        minimumCenterSpacingFraction > 1) {
      throw ArgumentError.value(
        minimumCenterSpacingFraction,
        'minimumCenterSpacingFraction',
        'doit être fini et compris dans ]0, 1]',
      );
    }

    if (minimumPlausibleWeightKg != null) {
      _check(
        minimumPlausibleWeightKg!,
        'minimumPlausibleWeightKg',
        positive: true,
      );
    }
    if (maximumPlausibleWeightKg != null) {
      _check(
        maximumPlausibleWeightKg!,
        'maximumPlausibleWeightKg',
        positive: true,
      );
    }
    if (minimumPlausibleWeightKg != null &&
        maximumPlausibleWeightKg != null &&
        minimumPlausibleWeightKg! >= maximumPlausibleWeightKg!) {
      throw ArgumentError.value(
        minimumPlausibleWeightKg,
        'minimumPlausibleWeightKg',
        'doit être strictement inférieur à maximumPlausibleWeightKg',
      );
    }
  }

  void _check(double value, String name, {bool positive = false}) {
    if (!value.isFinite || (positive ? value <= 0 : value < 0)) {
      throw ArgumentError.value(
        value,
        name,
        positive
            ? 'doit être strictement positif et fini'
            : 'doit être positif ou nul et fini',
      );
    }
  }
}
