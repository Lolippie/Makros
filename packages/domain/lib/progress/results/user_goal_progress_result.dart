import '../exceptions/goal_progress_exception.dart';
import 'body_fat_goal_progress_result.dart';
import 'goal_progress_result.dart';

/// Décrit uniquement l'évaluation de la cible de poids.
enum UserGoalEvaluationState { inactive, noTarget, noAnalysis, evaluated }

/// Les erreurs propres à un domaine n'empêchent pas les autres résultats.
/// Les booléens shouldMark* sont des recommandations, pas des écritures.
/// Avant markAchieved(), réparer les anomalies historiques du domaine concerné.
/// Une anomalie d'identité ou de période reste bloquante pour l'ensemble.
class UserGoalProgressResult {
  final String goalId;
  final UserGoalEvaluationState evaluationState;
  final GoalProgressResult? weightProgress;
  final BodyFatGoalProgressResult? bodyFatProgress;
  final GoalProgressException? weightError;
  final GoalProgressException? bodyFatError;
  final GoalProgressException? nutritionError;
  final bool shouldMarkWeightAchieved;
  final bool shouldMarkBodyFatAchieved;
  final bool shouldSuggestNutritionRecalculation;

  const UserGoalProgressResult({
    required this.goalId,
    required this.evaluationState,
    required this.weightProgress,
    required this.bodyFatProgress,
    this.weightError,
    this.bodyFatError,
    this.nutritionError,
    required this.shouldMarkWeightAchieved,
    required this.shouldMarkBodyFatAchieved,
    required this.shouldSuggestNutritionRecalculation,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserGoalProgressResult &&
          other.goalId == goalId &&
          other.evaluationState == evaluationState &&
          other.weightProgress == weightProgress &&
          other.bodyFatProgress == bodyFatProgress &&
          other.weightError == weightError &&
          other.bodyFatError == bodyFatError &&
          other.nutritionError == nutritionError &&
          other.shouldMarkWeightAchieved == shouldMarkWeightAchieved &&
          other.shouldMarkBodyFatAchieved == shouldMarkBodyFatAchieved &&
          other.shouldSuggestNutritionRecalculation ==
              shouldSuggestNutritionRecalculation;

  @override
  int get hashCode => Object.hash(
        goalId, evaluationState, weightProgress, bodyFatProgress,
        weightError, bodyFatError, nutritionError,
        shouldMarkWeightAchieved, shouldMarkBodyFatAchieved,
        shouldSuggestNutritionRecalculation,
      );
}
