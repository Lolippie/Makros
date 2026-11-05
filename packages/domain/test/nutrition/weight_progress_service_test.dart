import 'package:test/test.dart';
import 'package:makros_models/models.dart';
import 'package:makros_nutrition/nutrition/weight_progress_service.dart';
import 'package:makros_nutrition/nutrition/config/weight_progress_config.dart';
import 'package:makros_nutrition/nutrition/results/weight_progress_result.dart';

void main() {
  const service = WeightProgressService();
  final today = DateTime(2026, 11, 5);
  WeightHistory m(int daysAgo, double kg, {String userId = 'user-1'}) =>
      WeightHistory(
        id: 'm-$daysAgo-$kg-$userId',
        userId: userId,
        measuredAt: today.subtract(Duration(days: daysAgo)),
        weight: kg,
      );
  WeightProgressResult run(
    List<WeightHistory> items, {
    double reference = 65,
    double? target,
    WeightProgressService calculator = service,
  }) => calculator.analyze(
    userId: 'user-1',
    measurements: items,
    referenceWeightKg: reference,
    asOf: today,
    targetWeightKg: target,
  );

  test('empty and sparse observations have no trend or recalculation', () {
    for (final items in <List<WeightHistory>>[
      [],
      [m(0, 60)],
      [m(0, 60), m(1, 60)],
    ]) {
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
    final r = run([m(0, 64), m(1, 64), m(2, 64), m(7, 65), m(8, 65), m(9, 65)]);
    expect(r.changeBetweenWindowsKg, closeTo(-1, 1e-10));
    expect(r.weeklyWeightChangeKg, closeTo(-1, 1e-10));
    expect(r.hasComparableData, isTrue);
    expect(r.trendStatus, WeightTrendStatus.decreasing);
    expect(r.measurementDaysInPreviousWindow, 3);
  });
  test('stable and increasing thresholds are configurable', () {
    final r = run([
      m(0, 65.1),
      m(1, 65.1),
      m(2, 65.1),
      m(7, 65),
      m(8, 65),
      m(9, 65),
    ]);
    expect(r.trendStatus, WeightTrendStatus.stable);
    const strict = WeightProgressService(
      config: WeightProgressConfig(stableThresholdKg: 0.05),
    );
    expect(
      run([
        m(0, 65.1),
        m(1, 65.1),
        m(2, 65.1),
        m(7, 65),
        m(8, 65),
        m(9, 65),
      ], calculator: strict).trendStatus,
      WeightTrendStatus.increasing,
    );
  });
  test('multiple weighings on same date have equal daily weight', () {
    final r = run([m(0, 60), m(0, 64), m(1, 64), m(2, 64)]);
    expect(r.measurementDaysInCurrentWindow, 3);
    expect(r.currentTrendWeightKg, closeTo((62 + 64 + 64) / 3, 1e-10));
  });
  test('measurements must span configured minimum calendar days', () {
    const strict = WeightProgressService(
      config: WeightProgressConfig(minimumMeasurementSpanDays: 4),
    );
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
    expect(
      run([m(0, 64), m(1, 64), m(2, 64)]).shouldSuggestRecalculation,
      isTrue,
    );
    expect(
      run([m(0, 66), m(1, 66), m(2, 66)]).shouldSuggestRecalculation,
      isTrue,
    );
    expect(
      run([
        m(0, 64.001),
        m(1, 64.001),
        m(2, 64.001),
      ]).shouldSuggestRecalculation,
      isFalse,
    );
  });
  test('remainingToTargetKg stays a signed difference', () {
    List<WeightHistory> data(double kg) => [m(0, kg), m(1, kg), m(2, kg)];
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
    expect(
      () => run([m(0, double.nan)]),
      throwsA(
        isA<WeightProgressException>()
            .having(
              (e) => e.code,
              'code',
              WeightProgressErrorCode.invalidMeasurement,
            )
            .having((e) => e.date, 'date', DateTime.utc(2026, 11, 5)),
      ),
    );
    expect(run([m(-1, -1)]).hasSufficientData, isFalse);
  });
  test('invalid arguments and configurations throw ArgumentError', () {
    expect(() => run([], reference: double.nan), throwsArgumentError);
    expect(() => run([], target: -1), throwsArgumentError);
    for (final config in [
      const WeightProgressConfig(minimumMeasurementDays: 8),
      const WeightProgressConfig(minimumMeasurementSpanDays: 7),
      const WeightProgressConfig(
        minimumMeasurementDays: 1,
        minimumMeasurementSpanDays: 2,
      ),
      const WeightProgressConfig(maxDaysSinceLastMeasurement: -1),
      const WeightProgressConfig(stableThresholdKg: -1),
      const WeightProgressConfig(goalToleranceKg: double.infinity),
      const WeightProgressConfig(recalculationThresholdKg: 0),
    ]) {
      expect(
        () => run([], calculator: WeightProgressService(config: config)),
        throwsArgumentError,
      );
    }
  });
  test('does not mix measurements from different users', () {
    final r = run([m(0, 64), m(1, 64), m(2, 64), m(0, 110, userId: 'user-2')]);
    expect(r.currentTrendWeightKg, 64);
    expect(r.measurementDaysInCurrentWindow, 3);
  });
  test('includes all weighings on asOf civil day', () {
    final cutoff = DateTime(2026, 11, 5, 10);
    final entries = [
      m(1, 64),
      m(2, 64),
      WeightHistory(
        id: 'early',
        userId: 'user-1',
        weight: 64,
        measuredAt: DateTime(2026, 11, 5, 9),
      ),
      WeightHistory(
        id: 'late',
        userId: 'user-1',
        weight: 100,
        measuredAt: DateTime(2026, 11, 5, 20),
      ),
    ];
    final r = service.analyze(
      userId: 'user-1',
      measurements: entries,
      referenceWeightKg: 65,
      asOf: cutoff,
    );
    expect(r.currentTrendWeightKg, closeTo((64 + 64 + 82) / 3, 1e-10));
  });
  test('normalizes weekly change when window is not seven days', () {
    const custom = WeightProgressService(
      config: WeightProgressConfig(
        trendWindowDays: 5,
        minimumMeasurementDays: 3,
        minimumMeasurementSpanDays: 2,
      ),
    );
    final r = run([
      m(0, 64),
      m(1, 64),
      m(2, 64),
      m(5, 65),
      m(6, 65),
      m(7, 65),
    ], calculator: custom);
    expect(r.weeklyWeightChangeKg, closeTo(-1.4, 1e-10));
  });
  test('invalid user id is rejected', () {
    expect(
      () => service.analyze(
        userId: ' ',
        measurements: [],
        referenceWeightKg: 65,
        asOf: today,
      ),
      throwsArgumentError,
    );
  });
  test('very large finite positive weights do not overflow a sum', () {
    final huge = 1e300;
    final r = run([m(0, huge), m(1, huge), m(2, huge)]);
    expect(r.currentTrendWeightKg, huge);
  });
  test('invalid old weighing outside both windows is ignored', () {
    final r = run([m(0, 64), m(1, 64), m(2, 64), m(40, double.nan)]);
    expect(r.currentTrendWeightKg, 64);
  });
  test('duplicate measurement id within analyzed windows is rejected', () {
    final entry = m(0, 64);
    expect(
      () => run([entry, entry]),
      throwsA(
        isA<WeightProgressException>()
            .having(
              (e) => e.code,
              'code',
              WeightProgressErrorCode.duplicateMeasurement,
            )
            .having((e) => e.measurementId, 'measurementId', entry.id),
      ),
    );
  });
  test('plausibility bounds are optional and configurable', () {
    const bounded = WeightProgressService(
      config: WeightProgressConfig(
        minimumPlausibleWeightKg: 20,
        maximumPlausibleWeightKg: 300,
      ),
    );
    expect(
      () => run([m(0, 700)], calculator: bounded),
      throwsA(
        isA<WeightProgressException>().having(
          (e) => e.code,
          'code',
          WeightProgressErrorCode.invalidMeasurement,
        ),
      ),
    );
  });
  test('weekly estimate uses actual measured day centers', () {
    final r = run([
      m(0, 64),
      m(1, 64),
      m(2, 64),
      m(11, 65),
      m(12, 65),
      m(13, 65),
    ]);
    expect(r.weeklyWeightChangeKg, closeTo(-7 / 11, 1e-10));
  });
  test('freshness config must not make freshness check a no-op', () {
    const invalid = WeightProgressService(
      config: WeightProgressConfig(maxDaysSinceLastMeasurement: 6),
    );
    expect(() => run([], calculator: invalid), throwsArgumentError);
  });

  test('dates proches de 1970 ne font pas échouer le calcul des centres', () {
    final base = DateTime.utc(1970, 1, 3);
    final items = <WeightHistory>[
      for (final d in [0, 1, 2, 7, 8, 9])
        WeightHistory(
          id: 'epoch-$d',
          userId: 'user-1',
          weight: d < 7 ? 64 : 65,
          measuredAt: base.subtract(Duration(days: d)),
        ),
    ];
    final r = service.analyze(
      userId: 'user-1',
      measurements: items,
      referenceWeightKg: 65,
      asOf: base,
    );
    expect(r.weeklyWeightChangeKg, closeTo(-1, 1e-10));
  });

  test('centre temporel trop proche masque le taux hebdomadaire', () {
    const custom = WeightProgressService(
      config: WeightProgressConfig(
        minimumMeasurementDays: 1,
        minimumMeasurementSpanDays: 0,
      ),
    );
    final r = run([m(6, 64), m(7, 65)], calculator: custom);
    expect(r.changeBetweenWindowsKg, closeTo(-1, 1e-10));
    expect(r.weeklyWeightChangeKg, isNull);
  });

  test('id vide dans une fenêtre est rejeté', () {
    final bad = WeightHistory(
      id: '',
      userId: 'user-1',
      weight: 64,
      measuredAt: today,
    );
    expect(
      () => run([bad]),
      throwsA(
        isA<WeightProgressException>().having(
          (e) => e.code,
          'code',
          WeightProgressErrorCode.invalidMeasurement,
        ),
      ),
    );
  });

  test('fraction d’espacement invalide est rejetée', () {
    for (final fraction in [0.0, -1.0, 1.1, double.nan]) {
      final custom = WeightProgressService(
        config: WeightProgressConfig(minimumCenterSpacingFraction: fraction),
      );
      expect(() => run([], calculator: custom), throwsArgumentError);
    }
  });

  test('une tendance périmée est signalée', () {
    final r = run([m(4, 60), m(5, 60), m(6, 60)], target: 60);
    expect(r.isTrendFresh, isFalse);
  });

  test('config rejette les paramètres de fenêtre impossibles', () {
    for (final config in [
      const WeightProgressConfig(trendWindowDays: 0),
      const WeightProgressConfig(trendWindowDays: 1),
      const WeightProgressConfig(minimumMeasurementDays: 8),
      const WeightProgressConfig(minimumMeasurementDays: 0),
      const WeightProgressConfig(minimumMeasurementSpanDays: 7),
      const WeightProgressConfig(maxDaysSinceLastMeasurement: 6),
    ]) {
      expect(config.validate, throwsArgumentError);
    }
  });

  test('config rejette les bornes et seuils invalides', () {
    for (final config in [
      const WeightProgressConfig(
        minimumPlausibleWeightKg: 200,
        maximumPlausibleWeightKg: 100,
      ),
      const WeightProgressConfig(minimumPlausibleWeightKg: 0),
      const WeightProgressConfig(stableThresholdKg: double.nan),
      const WeightProgressConfig(comparisonEpsilonKg: -1),
      const WeightProgressConfig(goalToleranceKg: double.infinity),
      const WeightProgressConfig(recalculationThresholdKg: 0),
      const WeightProgressConfig(minimumCenterSpacingFraction: double.nan),
      const WeightProgressConfig(minimumCenterSpacingFraction: 1.01),
    ]) {
      expect(config.validate, throwsArgumentError);
    }
  });

  test('doublon hors fenêtre ignoré même avec identifiant commun', () {
    final recent = m(0, 64);
    final old = WeightHistory(
      id: recent.id,
      userId: 'user-1',
      weight: double.nan,
      measuredAt: today.subtract(const Duration(days: 100)),
    );
    final result = run([recent, m(1, 64), m(2, 64), old]);
    expect(result.currentTrendWeightKg, 64);
  });

  test('données périmées non utilisables actuellement', () {
    final result = run([m(4, 60), m(5, 60), m(6, 60)], target: 60);
    expect(result.isTrendFresh, isFalse);
    expect(result.hasUsableData, isFalse);
  });

  test('fraction 1.0 accepte deux fenêtres complètes', () {
    const custom = WeightProgressService(
      config: WeightProgressConfig(minimumCenterSpacingFraction: 1.0),
    );
    final items = [
      for (var day = 0; day < 14; day++) m(day, day < 7 ? 64 : 65),
    ];
    final result = run(items, calculator: custom);
    expect(result.weeklyWeightChangeKg, closeTo(-1, 1e-10));
  });

  test('snapshots identiques ont la même égalité et le même hashCode', () {
    final items = [m(0, 64), m(1, 64), m(2, 64)];
    final a = run(items, target: 60);
    final b = run(items, target: 60);
    final c = run(items, target: 61);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
    expect(a.toString(), contains('WeightProgressResult('));
    expect(a.hasUsableData, a.isTrendFresh);
  });

  test('date de dernière mesure renseignée même si moyenne absente', () {
    final result = run([m(0, 64)]);
    expect(result.currentTrendWeightKg, isNull);
    expect(result.lastMeasurementDate, DateTime.utc(2026, 11, 5));
  });
}
