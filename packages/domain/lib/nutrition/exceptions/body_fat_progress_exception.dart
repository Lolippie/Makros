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

  /// Méthodes normalisées disponibles, null désigne une méthode inconnue.
  /// Renseigné lors de mixedMeasurementMethods, trié (null en premier).
  final List<String?> methods;

  const BodyFatProgressException(
    this.code, {
    this.measurementId,
    this.date,
    this.methods = const [],
  });

  @override
  String toString() => 'BodyFatProgressException('
      'code: $code, measurementId: $measurementId, '
      'date: $date, methods: $methods)';
}
