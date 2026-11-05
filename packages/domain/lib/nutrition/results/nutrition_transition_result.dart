
import 'package:makros_models/models.dart';

class NutritionTransitionResult {
  const NutritionTransitionResult({
    required this.currentCalories,
    required this.targetCalories,
    required this.progressPercentage,
    required this.status,
    required this.nextStepDate,
    required this.isCompleted,
  });

  /// Apport quotidien à appliquer à la date demandée.
  final double currentCalories;

  final double targetCalories;

  /// Progression entre 0 et 100.
  final double progressPercentage;

  final NutritionTransitionStatus status;

  /// Prochaine date de changement calorique.
  /// Null si la transition est terminée ou annulée.
  final DateTime? nextStepDate;

  final bool isCompleted;
}
