import 'package:makros_models/models.dart';

import '../nutrition/results/weight_progress_result.dart';
import '../utils/civil_calendar.dart';
import 'exceptions/goal_progress_exception.dart';
import 'goal_progress_service.dart';
import 'results/goal_progress_result.dart';
import 'results/user_goal_progress_result.dart';

/// Orchestre deux analyses distinctes : objectif (filtrée) et nutrition
/// (globale). Service pur : ne persiste pas les marqueurs historiques.
/// L'objectif de masse grasse sera évalué dans un service ultérieur.
class UserGoalProgressService {
  final GoalProgressService goalProgressService;

  const UserGoalProgressService({
    this.goalProgressService = const GoalProgressService(),
  });

  UserGoalProgressResult analyze({
    required UserGoal goal,
    required WeightProgressResult? weightProgress,
    required WeightProgressResult? nutritionWeightProgress,
    required DateTime asOf,
  }) {
    try {
      goal.validate();
    } on ArgumentError {
      throw GoalProgressException(
        GoalProgressErrorCode.invalidGoal,
        goalId: goal.id,
      );
    }
    final day = civilDay(asOf);
    for (final analysis in [weightProgress, nutritionWeightProgress]) {
      if (analysis == null) continue;
      if (analysis.userId != goal.userId) {
        throw GoalProgressException(
          GoalProgressErrorCode.userMismatch,
          goalId: goal.id,
        );
      }
      if (analysis.asOfDay != day) {
        throw GoalProgressException(
          GoalProgressErrorCode.analysisDateMismatch,
          goalId: goal.id,
        );
      }
    }
    // La suggestion de nutrition est indépendante de la présence/activité
    // d'une cible de poids. Seule l'analyse globale la produit.
    if (nutritionWeightProgress?.earliestMeasurementDate != null) {
      throw GoalProgressException(
        GoalProgressErrorCode.invalidWeightAnalysis,
        goalId: goal.id,
      );
    }
    final recalc = nutritionWeightProgress?.shouldSuggestRecalculation ?? false;
    UserGoalProgressResult result(
      UserGoalEvaluationState state, [
      GoalProgressResult? progress,
      bool shouldMark = false,
    ]) => UserGoalProgressResult(
      goalId: goal.id,
      evaluationState: state,
      weightProgress: progress,
      shouldMarkWeightAchieved: shouldMark,
      shouldSuggestNutritionRecalculation: recalc,
    );

    final start = civilDay(goal.startDate);
    final end = goal.endDate == null ? null : civilDay(goal.endDate!);
    if (day.isBefore(start) || (end != null && day.isAfter(end))) {
      return result(UserGoalEvaluationState.inactive);
    }
    if (goal.targetWeight == null) {
      return result(UserGoalEvaluationState.noTarget);
    }
    if (weightProgress == null) {
      return result(UserGoalEvaluationState.noAnalysis);
    }
    // Aucune analyse globale ou filtrée à une autre date ne doit pouvoir
    // marquer irréversiblement un objectif historique.
    if (weightProgress.earliestMeasurementDate != start) {
      throw GoalProgressException(
        GoalProgressErrorCode.measurementPeriodMismatch,
        goalId: goal.id,
      );
    }
    final progress = goalProgressService.analyzeWeightGoal(
      goalId: goal.id,
      weightProgress: weightProgress,
      targetWeightKg: goal.targetWeight!,
      goalType: goal.type,
    );
    final shouldMark =
        goal.type != GoalType.maintenance &&
        !goal.targetWeightAchieved &&
        progress.weightGoalState == WeightGoalState.reached &&
        weightProgress.lastMeasurementDate != null &&
        !weightProgress.lastMeasurementDate!.isBefore(start);
    return result(UserGoalEvaluationState.evaluated, progress, shouldMark);
  }
}
