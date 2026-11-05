enum WeightProgressErrorCode { invalidMeasurement, numericalFailure }

/// Invalid stored observations or impossible numerical results.
/// Caller parameters and service configuration use ArgumentError instead.
class WeightProgressException implements Exception {
  final WeightProgressErrorCode code;
  final DateTime? date;
  const WeightProgressException(this.code, {this.date});

  @override
  String toString() => 'WeightProgressException($code, $date)';
}
