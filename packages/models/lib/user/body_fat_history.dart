class BodyFatHistory {
  final String id;
  final String userId;

  final double bodyFatPercentage; // En %
  final DateTime measuredAt;

  final String? measurementMethod;
  final String? notes;

  const BodyFatHistory({
    required this.id,
    required this.userId,
    required this.bodyFatPercentage,
    required this.measuredAt,
    this.measurementMethod,
    this.notes,
  });
}