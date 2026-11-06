import 'package:makros_models/models.dart';

import '../utils/civil_calendar.dart';
import 'body_fat_goal_progress_service.dart';
import 'exceptions/goal_progress_exception.dart';
import 'goal_progress_service.dart';
import 'results/body_fat_goal_progress_result.dart';
import 'results/body_fat_progress_result.dart';
import 'results/goal_progress_result.dart';
import 'results/user_goal_progress_result.dart';
import 'results/weight_progress_result.dart';

/// Évalue séparément poids, masse grasse et suggestion nutritionnelle.
/// Seules les erreurs structurelles communes restent fail-fast.
class UserGoalProgressService {
  final GoalProgressService goalProgressService;
  final BodyFatGoalProgressService bodyFatGoalProgressService;

  const UserGoalProgressService({
    this.goalProgressService = const GoalProgressService(),
    this.bodyFatGoalProgressService = const BodyFatGoalProgressService(),
  });

  UserGoalProgressResult analyze({
    required UserGoal goal,
    required WeightProgressResult? weightProgress,
    required WeightProgressResult? nutritionWeightProgress,
    required DateTime asOf,
    BodyFatProgressResult? bodyFatProgress,
  }) {
    final day = civilDay(asOf);
    final start = civilDay(goal.startDate);
    final end = goal.endDate == null ? null : civilDay(goal.endDate!);
    if (goal.validationIssues.any(
      (issue) => issue.isBlocking && issue.affectsIdentityOrPeriod,
    )) {
      throw GoalProgressException(
        GoalProgressErrorCode.invalidGoal, goalId: goal.id,
      );
    }
    final active = !day.isBefore(start) && (end == null || !day.isAfter(end));

    GoalProgressException? nutritionError;
    var recalc = false;
    if (nutritionWeightProgress != null) {
      final analysis = nutritionWeightProgress;
      if (analysis.userId != goal.userId) {
        nutritionError = GoalProgressException(
          GoalProgressErrorCode.userMismatch, goalId: goal.id);
      } else if (civilDay(analysis.asOfDay) != day) {
        nutritionError = GoalProgressException(
          GoalProgressErrorCode.analysisDateMismatch, goalId: goal.id);
      } else if (analysis.earliestMeasurementDate != null) {
        nutritionError = GoalProgressException(
          GoalProgressErrorCode.invalidWeightAnalysis, goalId: goal.id);
      } else {
        recalc = analysis.shouldSuggestRecalculation;
      }
    }

    BodyFatGoalProgressResult? bodyFat;
    GoalProgressException? bodyFatError;
    try {
      bodyFat = bodyFatGoalProgressService.analyze(
        goal: goal, asOf: asOf, progress: bodyFatProgress);
    } on GoalProgressException catch (error) {
      bodyFatError = error;
    }

    GoalProgressResult? weight;
    GoalProgressException? weightError;
    var state = UserGoalEvaluationState.inactive;
    var markWeight = false;

    if (active) {
      final target = goal.targetWeight;
      if (target == null) {
        state = UserGoalEvaluationState.noTarget;
      } else if (goal.validationIssues.any(
        (issue) => issue.isBlocking && issue.affectsWeight,
      ) || !target.isFinite || target <= 0) {
        weightError = GoalProgressException(
          GoalProgressErrorCode.invalidGoal, goalId: goal.id);
      } else if (weightProgress == null) {
        state = UserGoalEvaluationState.noAnalysis;
      } else {
        final analysis = weightProgress;
        GoalProgressErrorCode? errorCode;
        if (analysis.userId != goal.userId) {
          errorCode = GoalProgressErrorCode.userMismatch;
        } else if (civilDay(analysis.asOfDay) != day) {
          errorCode = GoalProgressErrorCode.analysisDateMismatch;
        } else if (analysis.earliestMeasurementDate == null ||
            civilDay(analysis.earliestMeasurementDate!) != start) {
          errorCode = GoalProgressErrorCode.measurementPeriodMismatch;
        }
        if (errorCode != null) {
          weightError = GoalProgressException(errorCode, goalId: goal.id);
        } else {
          try {
            weight = goalProgressService.analyzeWeightGoal(
              goalId: goal.id,
              weightProgress: analysis,
              targetWeightKg: target,
              goalType: goal.type,
            );
            state = UserGoalEvaluationState.evaluated;
            final last = analysis.lastMeasurementDate;
            final lastDay = last == null ? null : civilDay(last);
            final inPeriod = lastDay != null &&
                !lastDay.isBefore(start) && !lastDay.isAfter(day);
            final historicalIssue = goal.validationIssues.any(
              (issue) => issue.isHistorical && issue.affectsWeight,
            );
            markWeight = goal.type != GoalType.maintenance &&
                !goal.targetWeightAchieved && !historicalIssue &&
                weight.weightGoalState == WeightGoalState.reached &&
                analysis.isTrendFresh && inPeriod;
          } on GoalProgressException catch (error) {
            weightError = error;
          }
        }
      }
    }

    return UserGoalProgressResult(
      goalId: goal.id,
      evaluationState: state,
      weightProgress: weight,
      bodyFatProgress: bodyFat,
      weightError: weightError,
      bodyFatError: bodyFatError,
      nutritionError: nutritionError,
      shouldMarkWeightAchieved: markWeight,
      shouldMarkBodyFatAchieved: bodyFat?.shouldMarkAchieved ?? false,
      shouldSuggestNutritionRecalculation: recalc,
    );
  }
}
