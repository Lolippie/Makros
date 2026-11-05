enum NutritionTransitionStatus {
  pending,
  inProgress,
  completed,
  paused,
}

enum NutritionTransitionDirection {
  increase,
  decrease,
}

class NutritionTransition {
  final String id;
  final String userGoalId;

  final NutritionTransitionDirection direction;
  final NutritionTransitionStatus status;

  /// Calories de départ de la transition.
  final double startingCalories;

  /// Calories finales calculées.
  final double targetCalories;

  /// Taille de chaque palier.
  final double stepCalories;

  /// Nombre de jours entre deux paliers.
  final int stepDurationDays;

  final DateTime startDate;
  final DateTime? endDate;

  const NutritionTransition({
    required this.id,
    required this.userGoalId,
    required this.direction,
    required this.status,
    required this.startingCalories,
    required this.targetCalories,
    required this.stepCalories,
    required this.stepDurationDays,
    required this.startDate,
    this.endDate,
  });
}