class WeightHistory {
  final String id;
  final String userId;

  final double weight; // En kg
  final DateTime measuredAt;

  final String? notes;

  const WeightHistory({
    required this.id,
    required this.userId,
    required this.weight,
    required this.measuredAt,
    this.notes,
  });
}