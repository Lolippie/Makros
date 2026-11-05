import 'package:test/test.dart';
import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/weight_progress_service.dart';
import 'package:makros_nutrition/nutrition/config/weight_progress_config.dart';
import 'package:makros_nutrition/nutrition/results/weight_progress_result.dart';

void main() {
  const service = WeightProgressService();
  final today = DateTime(2026, 11, 5);
  WeightHistory m(int daysAgo, double kg, {String userId = 'user-1'}) => WeightHistory(
    id: 'm-$daysAgo-$kg-$userId', userId: userId,
    measuredAt: today.subtract(Duration(days: daysAgo)), weight: kg);
  WeightProgressResult run(List<WeightHistory> items, {
    double reference = 65, double? target, WeightProgressService calculator = service,
  }) => calculator.analyze(userId: 'user-1', measurements: items, referenceWeightKg: reference,
      asOf: today, targetWeightKg: target);

  test('empty and sparse observations have no trend or recalculation', () {
    for (final items in <List<WeightHistory>>[[], [m(0, 60)], [m(0, 60), m(1, 60)]]) {
      final r = run(items);
      expect(r.trendStatus, WeightTrendStatus.insufficientData);
      expect(r.shouldSuggestRecalculation, isFalse);
      expect(r.currentTrendWeightKg, isNull);
    }
  });
  test('current average without previous data is unknown, not stable', () {
    final r = run([m(0, 64), m(1, 64), m(2, 64)]);
    expect(r.trendStatus, WeightTrendStatus.unknown);
    expect(r.shouldSuggestRecalculation, isTrue);
    expect(r.measurementDaysInPreviousWindow, 0);
    expect(r.isTrendFresh, isTrue);
    expect(r.hasUsableData, isTrue);
  });
  test('stale window can be measured but cannot suggest recalculation', () {
    final r = run([m(4, 63), m(5, 63), m(6, 63)]);
    expect(r.currentTrendWeightKg, 63);
    expect(r.isTrendFresh, isFalse);
    expect(r.shouldSuggestRecalculation, isFalse);
    expect(r.lastMeasurementDate, DateTime.utc(2026, 11, 1));
  });
  test('comparison windows have no overlap and trend is decreasing', () {
    final r = run([m(0, 64), m(1, 64), m(2, 64),
      m(7, 65), m(8, 65), m(9, 65)]);
    expect(r.changeBetweenWindowsKg, closeTo(-1, 1e-10));
    expect(r.weeklyWeightChangeKg, closeTo(-1, 1e-10));
    expect(r.hasComparableData, isTrue);
    expect(r.trendStatus, WeightTrendStatus.decreasing);
    expect(r.measurementDaysInPreviousWindow, 3);
  });
  test('stable and increasing thresholds are configurable', () {
    final r = run([m(0, 65.1), m(1, 65.1), m(2, 65.1),
      m(7, 65), m(8, 65), m(9, 65)]);
    expect(r.trendStatus, WeightTrendStatus.stable);
    const strict = WeightProgressService(config: WeightProgressConfig(stableThresholdKg: 0.05));
    expect(run([m(0, 65.1), m(1, 65.1), m(2, 65.1),
      m(7, 65), m(8, 65), m(9, 65)], calculator: strict).trendStatus,
      WeightTrendStatus.increasing);
  });
  test('multiple weighings on same date have equal daily weight', () {
    final r = run([m(0, 60), m(0, 64), m(1, 64), m(2, 64)]);
    expect(r.measurementDaysInCurrentWindow, 3);
    expect(r.currentTrendWeightKg, closeTo((62 + 64 + 64) / 3, 1e-10));
  });
  test('measurements must span configured minimum calendar days', () {
    const strict = WeightProgressService(config: WeightProgressConfig(minimumMeasurementSpanDays: 4));
    final r = run([m(0, 64), m(1, 64), m(2, 64)], calculator: strict);
    expect(r.hasSufficientData, isFalse);
    expect(r.measurementDaysInCurrentWindow, 3);
  });
  test('window edges and future dates', () {
    final r = run([m(0, 65), m(2, 65), m(6, 65), m(7, 40), m(-1, 40)]);
    expect(r.currentTrendWeightKg, 65);
    expect(r.measurementDaysInCurrentWindow, 3);
  });
  test('threshold is symmetric and does not trigger below 1kg', () {
    expect(run([m(0, 64), m(1, 64), m(2, 64)]).shouldSuggestRecalculation, isTrue);
    expect(run([m(0, 66), m(1, 66), m(2, 66)]).shouldSuggestRecalculation, isTrue);
    expect(run([m(0, 64.001), m(1, 64.001), m(2, 64.001)]).shouldSuggestRecalculation, isFalse);
  });
  test('goal statuses distinguish not reached, reached, exceeded and unknown', () {
    List<WeightHistory> data(double kg) => [m(0, kg), m(1, kg), m(2, kg)];
    expect(run(data(64), target: 60).goalProgressStatus, WeightGoalProgressStatus.notReached);
    expect(run(data(60), target: 60).goalProgressStatus, WeightGoalProgressStatus.reached);
    expect(run(data(59), target: 60).goalProgressStatus, WeightGoalProgressStatus.exceeded);
    expect(run(data(66), target: 70).goalProgressStatus, WeightGoalProgressStatus.notReached);
    expect(run(data(71), target: 70).goalProgressStatus, WeightGoalProgressStatus.exceeded);
    expect(run(data(65), target: 65).goalProgressStatus, WeightGoalProgressStatus.reached);
    expect(run(data(64), target: 65).goalProgressStatus, WeightGoalProgressStatus.notReached);
    expect(run(data(64)).goalProgressStatus, WeightGoalProgressStatus.unknown);
    expect(run(data(64), target: 60).remainingToTargetKg, -4);
  });
  test('does not mutate input list, objects or order', () {
    final items = [m(2, 64), m(0, 63), m(1, 65), m(-1, 40)];
    final before = List<WeightHistory>.of(items);
    run(items);
    expect(items.length, before.length);
    for (var i = 0; i < items.length; i++) {
      expect(identical(items[i], before[i]), isTrue);
      expect(items[i].weight, before[i].weight);
      expect(items[i].measuredAt, before[i].measuredAt);
    }
  });
  test('invalid stored observation throws typed error with date', () {
    expect(() => run([m(0, double.nan)]), throwsA(isA<WeightProgressException>()
      .having((e) => e.code, 'code', WeightProgressErrorCode.invalidMeasurement)
      .having((e) => e.date, 'date', DateTime.utc(2026, 11, 5))));
    expect(run([m(-1, -1)]).hasSufficientData, isFalse);
  });
  test('invalid arguments and configurations throw ArgumentError', () {
    expect(() => run([], reference: double.nan), throwsArgumentError);
    expect(() => run([], target: -1), throwsArgumentError);
    for (final config in [
      const WeightProgressConfig(minimumMeasurementDays: 8),
      const WeightProgressConfig(minimumMeasurementSpanDays: 7),
      const WeightProgressConfig(minimumMeasurementDays: 1, minimumMeasurementSpanDays: 2),
      const WeightProgressConfig(maxDaysSinceLastMeasurement: -1),
      const WeightProgressConfig(stableThresholdKg: -1),
      const WeightProgressConfig(goalToleranceKg: double.infinity),
      const WeightProgressConfig(recalculationThresholdKg: 0),
    ]) {
      expect(() => run([], calculator: WeightProgressService(config: config)), throwsArgumentError);
    }
  });
  test('does not mix measurements from different users', () {
    final r = run([m(0, 64), m(1, 64), m(2, 64),
      m(0, 110, userId: 'user-2')]);
    expect(r.currentTrendWeightKg, 64);
    expect(r.measurementDaysInCurrentWindow, 3);
  });
  test('ignores later instants on the same calendar day', () {
    final cutoff = DateTime(2026, 11, 5, 10);
    final entries = [m(1, 64), m(2, 64),
      WeightHistory(id: 'early', userId: 'user-1', weight: 64,
        measuredAt: DateTime(2026, 11, 5, 9)),
      WeightHistory(id: 'late', userId: 'user-1', weight: 100,
        measuredAt: DateTime(2026, 11, 5, 20))];
    final r = service.analyze(userId: 'user-1', measurements: entries,
      referenceWeightKg: 65, asOf: cutoff);
    expect(r.currentTrendWeightKg, 64);
  });
  test('normalizes weekly change when window is not seven days', () {
    const custom = WeightProgressService(config: WeightProgressConfig(
      trendWindowDays: 5, minimumMeasurementDays: 3,
      minimumMeasurementSpanDays: 2));
    final r = run([m(0, 64), m(1, 64), m(2, 64),
      m(5, 65), m(6, 65), m(7, 65)], calculator: custom);
    expect(r.weeklyWeightChangeKg, closeTo(-1.4, 1e-10));
  });
  test('invalid user id is rejected', () {
    expect(() => service.analyze(userId: ' ', measurements: [],
      referenceWeightKg: 65, asOf: today), throwsArgumentError);
  });
  test('very large finite positive weights do not overflow a sum', () {
    final huge = 1e300;
    final r = run([m(0, huge), m(1, huge), m(2, huge)]);
    expect(r.currentTrendWeightKg, huge);
  });
}
