import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/nutrition_transition_service.dart';
import 'package:test/test.dart';

void main() {
  const service = NutritionTransitionService();
  final startDate = DateTime(2025, 1, 1);

  NutritionTransition transition({
    double startingCalories = 1000,
    double targetCalories = 1300,
    double stepCalories = 100,
    int stepDurationDays = 2,
    DateTime? startDate,
    NutritionTransitionStatus status = NutritionTransitionStatus.pending,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String userGoalId = 'goal-1',
  }) {
    return NutritionTransition(
      id: 'transition-1',
      userGoalId: userGoalId,
      startingCalories: startingCalories,
      targetCalories: targetCalories,
      stepCalories: stepCalories,
      stepDurationDays: stepDurationDays,
      startDate: startDate ?? DateTime(2025, 1, 1),
      status: status,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
    );
  }

  DateTime day(int offset, {int hour = 0}) =>
      DateTime(2025, 1, 1 + offset, hour);

  group('calculateCaloriesAtDate', () {
    test('keeps starting calories before the start and between steps', () {
      final item = transition();

      expect(
        service.calculateCaloriesAtDate(transition: item, date: day(-1)),
        1000,
      );
      expect(
        service.calculateCaloriesAtDate(transition: item, date: day(1)),
        1000,
      );
    });

    test(
      'applies each step on its calendar-day boundary and caps at target',
      () {
        final item = transition(targetCalories: 1250);

        expect(
          service.calculateCaloriesAtDate(transition: item, date: day(2)),
          1100,
        );
        expect(
          service.calculateCaloriesAtDate(transition: item, date: day(6)),
          1250,
        );
        expect(
          service.calculateCaloriesAtDate(transition: item, date: day(20)),
          1250,
        );
      },
    );

    test('supports a decreasing transition and ignores time of day', () {
      final item = transition(startingCalories: 1500, targetCalories: 1200);

      expect(
        service.calculateCaloriesAtDate(
          transition: item,
          date: day(2, hour: 23),
        ),
        1400,
      );
      expect(
        service.calculateCaloriesAtDate(transition: item, date: day(8)),
        1200,
      );
    });

    test(
      'returns the target when the calorie difference is within tolerance',
      () {
        final item = transition(
          startingCalories: 1000,
          targetCalories: 1000.0005,
        );

        expect(
          service.calculateCaloriesAtDate(transition: item, date: day(-10)),
          1000.0005,
        );
      },
    );

    test('freezes calories at the cancellation or completion date', () {
      final cancelled = transition(
        status: NutritionTransitionStatus.cancelled,
        cancelledAt: day(3),
      );
      final completed = transition(
        targetCalories: 1100,
        status: NutritionTransitionStatus.completed,
        completedAt: day(4),
      );

      expect(
        service.calculateCaloriesAtDate(transition: cancelled, date: day(10)),
        1100,
      );
      expect(
        service.calculateCaloriesAtDate(transition: completed, date: day(10)),
        1100,
      );
    });
  });

  group('calculateProgress', () {
    test('reports pending status and the first upcoming step before start', () {
      final result = service.calculateProgress(
        transition: transition(),
        date: day(-1),
      );

      expect(result.currentCalories, 1000);
      expect(result.progressPercentage, 0);
      expect(result.status, NutritionTransitionStatus.pending);
      expect(result.nextStepDate, day(2));
      expect(result.isCompleted, isFalse);
    });

    test('reports progress and the next step while in progress', () {
      final result = service.calculateProgress(
        transition: transition(),
        date: day(2),
      );

      expect(result.currentCalories, 1100);
      expect(result.progressPercentage, closeTo(100 / 3, 0.0001));
      expect(result.status, NutritionTransitionStatus.inProgress);
      expect(result.nextStepDate, day(4));
      expect(result.isCompleted, isFalse);
    });

    test('reports completion and no next step when the target is reached', () {
      final result = service.calculateProgress(
        transition: transition(targetCalories: 1100),
        date: day(2),
      );

      expect(result.currentCalories, 1100);
      expect(result.progressPercentage, 100);
      expect(result.status, NutritionTransitionStatus.completed);
      expect(result.nextStepDate, isNull);
      expect(result.isCompleted, isTrue);
    });

    test(
      'uses explicit completion and cancellation dates for effective status',
      () {
        final completed = service.calculateProgress(
          transition: transition(
            targetCalories: 1100,
            status: NutritionTransitionStatus.completed,
            completedAt: day(2),
          ),
          date: day(2),
        );
        final cancelled = service.calculateProgress(
          transition: transition(
            status: NutritionTransitionStatus.cancelled,
            cancelledAt: day(2),
          ),
          date: day(2),
        );

        expect(completed.status, NutritionTransitionStatus.completed);
        expect(completed.isCompleted, isTrue);
        expect(completed.nextStepDate, isNull);
        expect(cancelled.status, NutritionTransitionStatus.cancelled);
        expect(cancelled.isCompleted, isFalse);
        expect(cancelled.nextStepDate, isNull);
      },
    );
  });

  group('calculateNextStepDate', () {
    test(
      'returns the next scheduled date and stops at terminal boundaries',
      () {
        expect(
          service.calculateNextStepDate(transition: transition(), date: day(0)),
          day(2),
        );
        expect(
          service.calculateNextStepDate(
            transition: transition(targetCalories: 1100),
            date: day(2),
          ),
          isNull,
        );
        expect(
          service.calculateNextStepDate(
            transition: transition(
              status: NutritionTransitionStatus.cancelled,
              cancelledAt: day(1),
            ),
            date: day(0),
          ),
          isNull,
        );
      },
    );
  });

  group('validation', () {
    test('rejects non-positive calories and step durations', () {
      for (final invalid in [
        transition(startingCalories: 0),
        transition(targetCalories: double.infinity),
        transition(stepCalories: double.nan),
        transition(stepDurationDays: 0),
      ]) {
        expect(
          () => service.calculateCaloriesAtDate(
            transition: invalid,
            date: startDate,
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects empty goal ids and inconsistent terminal dates', () {
      final invalidTransitions = [
        transition(userGoalId: ''),
        transition(status: NutritionTransitionStatus.cancelled),
        transition(cancelledAt: day(2)),
        transition(status: NutritionTransitionStatus.completed),
        transition(completedAt: day(2)),
        transition(
          status: NutritionTransitionStatus.completed,
          completedAt: day(-1),
        ),
      ];

      for (final invalid in invalidTransitions) {
        expect(
          () => service.calculateProgress(transition: invalid, date: startDate),
          throwsArgumentError,
        );
      }
    });
  });
}
