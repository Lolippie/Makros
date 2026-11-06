
import 'package:makros_models/models.dart';
import 'package:makros_nutrition/progress/body_fat_goal_progress_service.dart';
import 'package:makros_nutrition/progress/results/body_fat_goal_progress_result.dart';
import 'package:makros_nutrition/progress/results/body_fat_progress_result.dart';
import 'package:test/test.dart';

void main() {
  const service = BodyFatGoalProgressService();

  final start = DateTime.utc(2026, 1, 1);
  final asOf = DateTime.utc(2026, 2, 1);

  UserGoal goal({
    GoalType type = GoalType.cut,
    double? target = 25,
    String? method = 'DEXA',
    bool achieved = false,
    DateTime? achievedAt,
    DateTime? endDate,
    DateTime? startDate,
  }) =>
      UserGoal(
        id: 'g1',
        userId: 'u1',
        type: type,
        startDate: startDate ?? start,
        endDate: endDate,
        targetWeight: 65,
        targetBodyFatPercentage: target,
        targetBodyFatMeasurementMethod: method,
        targetBodyFatPercentageAchieved: achieved,
        targetBodyFatPercentageAchievedAt:
            achieved ? (achievedAt ?? start) : achievedAt,
      );

  BodyFatProgressResult progress({
    double? current = 26,
    bool fresh = true,
    String userId = 'u1',
    String? method = 'DEXA',
    bool hasSelectedMethod = true,
    DateTime? analysisDate,
    DateTime? earliestDate,
    DateTime? lastDate,
    int currentDays = 3,
    int previousDays = 3,
    double tolerance = 1,
    double epsilon = 1e-9,
    int windowDays = 28,
  }) =>
      BodyFatProgressResult(
        userId: userId,
        asOfDay: analysisDate ?? asOf,
        earliestMeasurementDate: earliestDate ?? start,
        measurementMethod: method,
        trendWindowDays: windowDays,
        hasSelectedMethod: hasSelectedMethod,
        currentTrendPercentage: current,
        previousTrendPercentage: 27,
        changeBetweenWindowsPercentagePoints:
            current == null ? null : current - 27,
        weeklyChangePercentagePoints: null,
        measurementDaysInCurrentWindow: currentDays,
        measurementDaysInPreviousWindow: previousDays,
        lastMeasurementDate: lastDate ?? asOf,
        isTrendFresh: fresh,
        trendStatus: BodyFatTrendStatus.stable,
        goalTolerancePercentagePoints: tolerance,
        comparisonEpsilonPercentagePoints: epsilon,
      );

  group('Validation des objectifs', () {
    test('objectif non encore actif', () {
      final result = service.analyze(
        goal: goal(startDate: DateTime.utc(2026, 3, 1)),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.inactive);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('objectif terminé', () {
      final result = service.analyze(
        goal: goal(endDate: DateTime.utc(2026, 1, 20)),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.inactive);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('absence de cible', () {
      final result = service.analyze(
        goal: goal(target: null, method: null),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.noTarget);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('cible invalide', () {
      final result = service.analyze(
        goal: goal(target: 110),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.invalidGoal);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('absence de méthode de mesure', () {
      final result = service.analyze(
        goal: goal(method: null),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.noMeasurementMethod);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('méthode de mesure vide', () {
      final result = service.analyze(
        goal: goal(method: '   '),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.noMeasurementMethod);
      expect(result.shouldMarkAchieved, isFalse);
    });
  });

  group('Disponibilité des analyses', () {
    test('absence d’analyse', () {
      final result = service.analyze(
        goal: goal(),
        progress: null,
        asOf: asOf,
      );

      expect(result.goalId, 'g1');
      expect(result.state, BodyFatGoalState.noAnalysis);
      expect(result.isHistoricallyAchieved, isFalse);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('données insuffisantes', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(
          current: null,
          currentDays: 0,
        ),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.insufficientData);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('analyse périmée', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(fresh: false),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.stale);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('objectif historiquement atteint, analyse périmée', () {
      final result = service.analyze(
        goal: goal(achieved: true),
        progress: progress(fresh: false),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.stale);
      expect(result.isHistoricallyAchieved, isTrue);
      expect(result.shouldMarkAchieved, isFalse);
    });
  });

  group('Objectif de sèche', () {
    test('objectif non atteint', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(current: 28),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.notReached);
      expect(result.remainingPercentagePoints, closeTo(3, 1e-9));
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('objectif strictement atteint', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(current: 24),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.shouldMarkAchieved, isTrue);
      expect(result.isReached, isTrue);
    });

    test('objectif exactement à la cible', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(current: 25),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.shouldMarkAchieved, isTrue);
    });

    test('objectif atteint uniquement grâce à la tolérance', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(current: 25.5),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('borne supérieure de tolérance sans verrouillage', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(current: 26),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('objectif déjà historiquement atteint', () {
      final result = service.analyze(
        goal: goal(achieved: true),
        progress: progress(current: 24),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.isHistoricallyAchieved, isTrue);
      expect(result.shouldMarkAchieved, isFalse);
      expect(result.hasReachedAtLeastOnce, isTrue);
    });

    test('date historique hors période : pas de nouveau marquage', () {
      final result = service.analyze(
        goal: goal(
          achievedAt: DateTime.utc(2025, 12, 20),
        ),
        progress: progress(current: 24),
        asOf: asOf,
      );

      expect(result.shouldMarkAchieved, isFalse);
    });
  });

  group('Prise de masse', () {
    test('bulk sous la tolérance : cible non atteinte', () {
      final result = service.analyze(
        goal: goal(type: GoalType.bulk),
        progress: progress(current: 23),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.notReached);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('bulk dans la tolérance : cible atteinte sans verrouillage', () {
      final result = service.analyze(
        goal: goal(type: GoalType.bulk),
        progress: progress(current: 24.5),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('bulk exactement à la cible : aucun verrouillage', () {
      final result = service.analyze(
        goal: goal(type: GoalType.bulk),
        progress: progress(current: 25),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('bulk au-dessus de la tolérance : cible non atteinte', () {
      final result = service.analyze(
        goal: goal(type: GoalType.bulk),
        progress: progress(current: 28),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.notReached);
      expect(result.shouldMarkAchieved, isFalse);
    });
  });

  group('Maintenance', () {
    test('maintenance dans la tolérance', () {
      final result = service.analyze(
        goal: goal(type: GoalType.maintenance),
        progress: progress(current: 25.5),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('maintenance exactement à la cible', () {
      final result = service.analyze(
        goal: goal(type: GoalType.maintenance),
        progress: progress(current: 25),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.reached);
      expect(result.shouldMarkAchieved, isFalse);
    });

    test('maintenance hors tolérance', () {
      final result = service.analyze(
        goal: goal(type: GoalType.maintenance),
        progress: progress(current: 27),
        asOf: asOf,
      );

      expect(result.state, BodyFatGoalState.notReached);
      expect(result.shouldMarkAchieved, isFalse);
    });
  });

  group('Résultats', () {
    test('identifiant conservé', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(),
        asOf: asOf,
      );

      expect(result.goalId, 'g1');
    });

    test('distance signée et absolue correctes', () {
      final result = service.analyze(
        goal: goal(),
        progress: progress(current: 23),
        asOf: asOf,
      );

      expect(result.remainingPercentagePoints, closeTo(-2, 1e-9));
      expect(result.absoluteDistancePercentagePoints, closeTo(2, 1e-9));
    });
  });
}
