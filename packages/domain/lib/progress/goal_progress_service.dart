import 'package:makros_models/models.dart';

import 'results/weight_progress_result.dart';
import 'exceptions/goal_progress_exception.dart';
import 'results/goal_progress_result.dart';

/// Service pur d'interprétation d'une cible de poids.
class GoalProgressService {
  const GoalProgressService();

  GoalProgressResult analyzeWeightGoal({
    required String goalId,
    required WeightProgressResult weightProgress,
    required double targetWeightKg,
    required GoalType goalType,
  }) {
    if (goalId.trim().isEmpty) {
      throw ArgumentError.value(goalId, 'goalId', 'ne doit pas être vide');
    }
    if (!targetWeightKg.isFinite || targetWeightKg <= 0) {
      throw ArgumentError.value(
        targetWeightKg,
        'targetWeightKg',
        'doit être strictement positif et fini',
      );
    }
    final tolerance = weightProgress.goalToleranceKg;
    final epsilon = weightProgress.comparisonEpsilonKg;
    // Défense en profondeur : résultats potentiellement désérialisés.
    if (!tolerance.isFinite ||
        tolerance < 0 ||
        !epsilon.isFinite ||
        epsilon < 0) {
      throw GoalProgressException(
        GoalProgressErrorCode.invalidWeightAnalysis,
        goalId: goalId,
      );
    }
    final analyzedTarget = weightProgress.targetWeightKg;
    if (analyzedTarget == null) {
      throw GoalProgressException(
        GoalProgressErrorCode.missingTarget,
        goalId: goalId,
      );
    }
    if (!analyzedTarget.isFinite || analyzedTarget <= 0) {
      throw GoalProgressException(
        GoalProgressErrorCode.invalidTarget,
        goalId: goalId,
      );
    }
    if ((analyzedTarget - targetWeightKg).abs() > epsilon) {
      throw GoalProgressException(
        GoalProgressErrorCode.targetMismatch,
        goalId: goalId,
      );
    }
    final currentWeight = weightProgress.currentTrendWeightKg;
    if (currentWeight == null) {
      return GoalProgressResult(
        goalId: goalId,
        weightGoalState: WeightGoalState.unknown,
        hasExceededWeightTarget: false,
      );
    }
    if (!currentWeight.isFinite || currentWeight <= 0) {
      throw GoalProgressException(
        GoalProgressErrorCode.invalidWeightAnalysis,
        goalId: goalId,
      );
    }
    if (!weightProgress.isTrendFresh) {
      return GoalProgressResult(
        goalId: goalId,
        weightGoalState: WeightGoalState.stale,
        hasExceededWeightTarget: false,
      );
    }
    final difference = currentWeight - targetWeightKg;
    if (!difference.isFinite) {
      throw GoalProgressException(
        GoalProgressErrorCode.invalidWeightAnalysis,
        goalId: goalId,
      );
    }
    final withinTolerance = difference.abs() <= tolerance + epsilon;
    final exceeded =
        !withinTolerance &&
        (switch (goalType) {
          GoalType.cut => difference < -tolerance - epsilon,
          GoalType.bulk => difference > tolerance + epsilon,
          GoalType.maintenance => false,
        });
    return GoalProgressResult(
      goalId: goalId,
      weightGoalState: withinTolerance || exceeded
          ? WeightGoalState.reached
          : WeightGoalState.notReached,
      hasExceededWeightTarget: exceeded,
    );
  }
}
