class MuscleMassHistory {
  final String id;
  final String userId;

  // Pourcentage de masse musculaire (%)
  final double muscleMassPercentage;

  // Date de la mesure
  final DateTime measuredAt;

  // Méthode utilisée pour la mesure
  final String? measurementMethod;

  // Notes facultatives
  final String? notes;

  const MuscleMassHistory({
    required this.id,
    required this.userId,
    required this.muscleMassPercentage,
    required this.measuredAt,
    this.measurementMethod,
    this.notes,
  });
}
