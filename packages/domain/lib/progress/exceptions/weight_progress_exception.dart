enum WeightProgressErrorCode {
  invalidMeasurement,
  duplicateMeasurement,
  numericalFailure,
}

/// Erreur de données enregistrées ou de calcul numérique.
class WeightProgressException implements Exception {
  final WeightProgressErrorCode code;
  final DateTime? date;
  final String? measurementId;

  const WeightProgressException(this.code, {this.date, this.measurementId});

  @override
  String toString() =>
      'WeightProgressException($code, date: $date, measurementId: $measurementId)';
}
