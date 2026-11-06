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

  const BodyFatProgressException(this.code, {this.measurementId, this.date});

  @override
  String toString() => 'BodyFatProgressException(code: $code, '
      'measurementId: $measurementId, date: $date)';
}
