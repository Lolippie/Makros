import 'package:makros_models/models.dart';
import '../utils/civil_calendar.dart';
import 'exceptions/goal_progress_exception.dart';
import 'results/body_fat_goal_progress_result.dart';
import 'results/body_fat_progress_result.dart';

class BodyFatGoalProgressService {
  const BodyFatGoalProgressService();

  BodyFatGoalProgressResult analyze({
    required UserGoal goal,
    required DateTime asOf,
    BodyFatProgressResult? progress,
  }) {
    final day = civilDay(asOf);
    final start = civilDay(goal.startDate);
    final end = goal.endDate == null ? null : civilDay(goal.endDate!);
    final historical = goal.targetBodyFatPercentageAchieved;
    final rawTarget = goal.targetBodyFatPercentage;
    final target =
        rawTarget != null &&
            rawTarget.isFinite &&
            rawTarget > 0 &&
            rawTarget < 100
        ? rawTarget
        : null;

    BodyFatGoalProgressResult make(
      BodyFatGoalState state, {
      double? current,
      double? remaining,
      bool mark = false,
    }) => BodyFatGoalProgressResult(
      goalId: goal.id,
      state: state,
      targetPercentage: target,
      currentPercentage: current,
      remainingPercentagePoints: remaining,
      isHistoricallyAchieved: historical,
      shouldMarkAchieved: mark,
    );

    final issues = goal.validationIssues;
    final blocking = issues.where((issue) =>
        issue.isBlocking &&
        (issue.affectsIdentityOrPeriod || issue.affectsBodyFat) &&
        issue != UserGoalValidationIssue.emptyMeasurementMethod).toList();
    if (blocking.isNotEmpty || (rawTarget != null && target == null)) {
      return make(BodyFatGoalState.invalidGoal);
    }
    final hasHistoricalIssue = issues.any(
      (issue) => issue.isHistorical && issue.affectsBodyFat,
    );

    if (day.isBefore(start) || (end != null && day.isAfter(end))) {
      return make(BodyFatGoalState.inactive);
    }
    if (target == null) return make(BodyFatGoalState.noTarget);

    final method = normalizeMeasurementMethod(
      goal.targetBodyFatMeasurementMethod,
    );
    if (method == null) return make(BodyFatGoalState.noMeasurementMethod);
    if (progress == null) return make(BodyFatGoalState.noAnalysis);

    if (progress.userId != goal.userId) {
      throw GoalProgressException(
        GoalProgressErrorCode.userMismatch,
        goalId: goal.id,
      );
    }
    if (civilDay(progress.asOfDay) != day) {
      throw GoalProgressException(
        GoalProgressErrorCode.analysisDateMismatch,
        goalId: goal.id,
      );
    }
    if (progress.earliestMeasurementDate == null ||
        civilDay(progress.earliestMeasurementDate!) != start) {
      throw GoalProgressException(
        GoalProgressErrorCode.measurementPeriodMismatch,
        goalId: goal.id,
      );
    }
    if (!progress.hasSelectedMethod ||
        normalizeMeasurementMethod(progress.measurementMethod) != method) {
      throw GoalProgressException(
        GoalProgressErrorCode.measurementMethodMismatch,
        goalId: goal.id,
      );
    }

    final tolerance = progress.goalTolerancePercentagePoints;
    final epsilon = progress.comparisonEpsilonPercentagePoints;
    final current = progress.currentTrendPercentage;
    if (!tolerance.isFinite ||
        tolerance < 0 ||
        !epsilon.isFinite ||
        epsilon < 0 ||
        progress.trendWindowDays <= 0 ||
        progress.measurementDaysInCurrentWindow < 0 ||
        progress.measurementDaysInPreviousWindow < 0 ||
        (current != null &&
            (!current.isFinite || current <= 0 || current >= 100))) {
      throw GoalProgressException(
        GoalProgressErrorCode.invalidBodyFatAnalysis,
        goalId: goal.id,
      );
    }
    if (current == null || progress.measurementDaysInCurrentWindow == 0) {
      return make(BodyFatGoalState.insufficientData);
    }

    final remaining = current - target;
    if (!progress.isTrendFresh) {
      return make(
        BodyFatGoalState.stale,
        current: current,
        remaining: remaining,
      );
    }

    final lastDate = progress.lastMeasurementDate;
    final measurementInPeriod =
        lastDate != null &&
        !civilDay(lastDate).isBefore(start) &&
        !civilDay(lastDate).isAfter(day);
    if (!measurementInPeriod) {
      return make(
        BodyFatGoalState.insufficientData,
        current: current,
        remaining: remaining,
      );
    }

    final reached = switch (goal.type) {
      GoalType.cut => current <= target + tolerance + epsilon,
      GoalType.bulk => (current - target).abs() <= tolerance + epsilon,
      GoalType.maintenance => (current - target).abs() <= tolerance + epsilon,
    };
    // La tolérance sert à l'affichage, pas au verrou historique.
    // En bulk, la cible est symétrique mais le verrou reste désactivé.
    final strictlyReached = switch (goal.type) {
      GoalType.cut => current <= target + epsilon,
      GoalType.bulk || GoalType.maintenance => false,
    };
    return make(
      reached ? BodyFatGoalState.reached : BodyFatGoalState.notReached,
      current: current,
      remaining: remaining,
      mark: strictlyReached && !historical && !hasHistoricalIssue,
    );
  }
}
