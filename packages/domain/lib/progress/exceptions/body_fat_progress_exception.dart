enum BodyFatProgressErrorCode {
  invalidMeasurement,
  duplicateMeasurement,
  mixedMeasurementMethods,
  invalidComputation,
}

class BodyFatProgressException implements Exception {
  final BodyFatProgressErrorCode code;
  final String? measurementId;
  final DateTime? date;
  final List<String?>? methods;

  const BodyFatProgressException(
    this.code, {
    this.measurementId,
    this.date,
    this.methods,
  });

  @override
  String toString() =>
      'BodyFatProgressException('
      'code: $code, measurementId: $measurementId, '
      'date: $date, methods: $methods)';
}
