class WeightProgressConfig {
  final double recalculationThresholdKg;
  final int trendWindowDays;
  final int minimumMeasurementDays;
  final int minimumMeasurementSpanDays;
  final int maxDaysSinceLastMeasurement;
  final double stableThresholdKg;
  final double goalToleranceKg;

  const WeightProgressConfig({
    this.recalculationThresholdKg = 1.0,
    this.trendWindowDays = 7,
    this.minimumMeasurementDays = 3,
    this.minimumMeasurementSpanDays = 2,
    this.maxDaysSinceLastMeasurement = 3,
    this.stableThresholdKg = 0.2,
    this.goalToleranceKg = 0.1,
  });

  void validate() {
    if (!recalculationThresholdKg.isFinite || recalculationThresholdKg <= 0) {
      throw ArgumentError.value(recalculationThresholdKg, 'recalculationThresholdKg');
    }
    if (trendWindowDays < 1) throw ArgumentError.value(trendWindowDays, 'trendWindowDays');
    if (minimumMeasurementDays < 1 || minimumMeasurementDays > trendWindowDays) {
      throw ArgumentError.value(minimumMeasurementDays, 'minimumMeasurementDays');
    }
    if (minimumMeasurementSpanDays < 0 ||
        minimumMeasurementSpanDays >= trendWindowDays ||
        (minimumMeasurementDays == 1 && minimumMeasurementSpanDays != 0)) {
      throw ArgumentError.value(minimumMeasurementSpanDays, 'minimumMeasurementSpanDays');
    }
    if (maxDaysSinceLastMeasurement < 0) {
      throw ArgumentError.value(maxDaysSinceLastMeasurement, 'maxDaysSinceLastMeasurement');
    }
    if (!stableThresholdKg.isFinite || stableThresholdKg < 0) {
      throw ArgumentError.value(stableThresholdKg, 'stableThresholdKg');
    }
    if (!goalToleranceKg.isFinite || goalToleranceKg < 0) {
      throw ArgumentError.value(goalToleranceKg, 'goalToleranceKg');
    }
  }
}
