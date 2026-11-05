
enum NutritionTransitionStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

class NutritionTransition {
  final String id;
  final String userGoalId;

  /// Apport quotidien moyen au début de la transition.
  final double startingCalories;

  /// Objectif calorique final calculé.
  final double targetCalories;

  /// Nombre de kcal ajoutées ou retirées à chaque étape.
  final double stepCalories;

  /// Nombre de jours entre deux étapes.
  final int stepDurationDays;

  final DateTime startDate;
  final NutritionTransitionStatus status;

  /// Date réelle de fin, si la transition est terminée.
  final DateTime? completedAt;
final DateTime? cancelledAt;

  const NutritionTransition({
    required this.id,
    required this.userGoalId,
    required this.startingCalories,
    required this.targetCalories,
    required this.stepCalories,
    required this.stepDurationDays,
    required this.startDate,
    this.status = NutritionTransitionStatus.pending,
    this.completedAt,
    this.cancelledAt,
  });
}
