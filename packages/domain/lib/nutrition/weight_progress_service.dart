import 'package:makros_models/models.dart';

import 'config/weight_progress_config.dart';
import 'exceptions/weight_progress_exception.dart';
import 'results/weight_progress_result.dart';

export 'exceptions/weight_progress_exception.dart';

/// Analyses weight history without modifying measurements or nutrition goals.
///
/// [asOf] and [WeightHistory.measuredAt] must represent comparable instants.
/// Their calendar fields must also already reflect the user's chosen civil
/// time zone before being passed here. The service cannot infer that zone.
class WeightProgressService {
  final WeightProgressConfig config;

  const WeightProgressService({
    this.config = const WeightProgressConfig(),
  });

  WeightProgressResult analyze({
    required String userId,
    required List<WeightHistory> measurements,
    required double referenceWeightKg,
    required DateTime asOf,
    double? targetWeightKg,
  }) {
    config.validate();
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }
    _validatePositive(referenceWeightKg, 'referenceWeightKg');
    if (targetWeightKg != null) {
      _validatePositive(targetWeightKg, 'targetWeightKg');
    }

    final asOfDay = _civilDay(asOf);
    final grouped = <DateTime, List<double>>{};

    for (final measurement in measurements) {
      if (measurement.userId != userId) continue;
      // Exclude future instants, including those later on the same civil day.
      if (measurement.measuredAt.isAfter(asOf)) continue;
      final day = _civilDay(measurement.measuredAt);
      if (day.isAfter(asOfDay)) continue;
      if (!measurement.weight.isFinite || measurement.weight <= 0) {
        throw WeightProgressException(
          WeightProgressErrorCode.invalidMeasurement,
          date: day,
        );
      }
      grouped.putIfAbsent(day, () => <double>[]).add(measurement.weight);
    }

    final dailyMeans = <DateTime, double>{};
    for (final entry in grouped.entries) {
      dailyMeans[entry.key] = _mean(entry.value, entry.key);
    }

    final current = _window(dailyMeans, asOfDay);
    final previous = _window(
      dailyMeans,
      asOfDay.subtract(Duration(days: config.trendWindowDays)),
    );
    final currentMean = current.mean;
    final previousMean = previous.mean;
    final latest = current.latest;
    final fresh = currentMean != null &&
        latest != null &&
        asOfDay.difference(latest).inDays <=
            config.maxDaysSinceLastMeasurement;

    final delta = currentMean == null
        ? null
        : _finiteDifference(currentMean, referenceWeightKg, asOfDay);
    final between = currentMean == null || previousMean == null
        ? null
        : _finiteDifference(currentMean, previousMean, asOfDay);
    final remaining = currentMean == null || targetWeightKg == null
        ? null
        : _finiteDifference(targetWeightKg, currentMean, asOfDay);

    // Window centers are trendWindowDays apart. This is a normalized
    // window-to-window estimate, not a regression on individual weigh-ins.
    final weeklyChange = between == null
        ? null
        : _finiteProduct(between, 7.0 / config.trendWindowDays, asOfDay);

    return WeightProgressResult(
      referenceWeightKg: referenceWeightKg,
      currentTrendWeightKg: currentMean,
      previousTrendWeightKg: previousMean,
      changeFromReferenceKg: delta,
      changeBetweenWindowsKg: between,
      weeklyWeightChangeKg: weeklyChange,
      targetWeightKg: targetWeightKg,
      remainingToTargetKg: remaining,
      measurementDaysInCurrentWindow: current.count,
      measurementDaysInPreviousWindow: previous.count,
      lastMeasurementDate: latest,
      isTrendFresh: fresh,
      trendStatus: _trendStatus(currentMean: currentMean, between: between),
      goalProgressStatus: _goalStatus(
        currentMean: currentMean,
        reference: referenceWeightKg,
        target: targetWeightKg,
      ),
      shouldSuggestRecalculation: fresh &&
          delta != null &&
          delta.abs() + 1e-9 >= config.recalculationThresholdKg,
    );
  }

  WeightTrendStatus _trendStatus({
    required double? currentMean,
    required double? between,
  }) {
    if (currentMean == null) return WeightTrendStatus.insufficientData;
    if (between == null) return WeightTrendStatus.unknown;
    if (between < -config.stableThresholdKg) {
      return WeightTrendStatus.decreasing;
    }
    if (between > config.stableThresholdKg) {
      return WeightTrendStatus.increasing;
    }
    return WeightTrendStatus.stable;
  }

  WeightGoalProgressStatus _goalStatus({
    required double? currentMean,
    required double reference,
    required double? target,
  }) {
    if (currentMean == null || target == null) {
      return WeightGoalProgressStatus.unknown;
    }
    final difference = _finiteDifference(currentMean, target, null);
    if (difference.abs() <= config.goalToleranceKg) {
      return WeightGoalProgressStatus.reached;
    }
    // When target equals reference, there is no directional 'exceeded'.
    if (target == reference) return WeightGoalProgressStatus.notReached;
    final exceeded = target < reference ? difference < 0 : difference > 0;
    return exceeded
        ? WeightGoalProgressStatus.exceeded
        : WeightGoalProgressStatus.notReached;
  }

  ({double? mean, int count, DateTime? latest}) _window(
    Map<DateTime, double> dailyMeans,
    DateTime endInclusive,
  ) {
    final start = endInclusive.subtract(
      Duration(days: config.trendWindowDays - 1),
    );
    final dates = dailyMeans.keys
        .where((date) => !date.isBefore(start) && !date.isAfter(endInclusive))
        .toList()
      ..sort();
    if (dates.isEmpty) return (mean: null, count: 0, latest: null);

    final latest = dates.last;
    if (dates.length < config.minimumMeasurementDays ||
        latest.difference(dates.first).inDays <
            config.minimumMeasurementSpanDays) {
      return (mean: null, count: dates.length, latest: latest);
    }
    return (
      mean: _mean([for (final date in dates) dailyMeans[date]!], latest),
      count: dates.length,
      latest: latest,
    );
  }

  double _mean(List<double> values, DateTime? date) {
    if (values.isEmpty) {
      throw WeightProgressException(
        WeightProgressErrorCode.numericalFailure, date: date,
      );
    }
    var average = 0.0;
    for (var i = 0; i < values.length; i++) {
      average += (values[i] - average) / (i + 1);
    }
    if (!average.isFinite || average <= 0) {
      throw WeightProgressException(
        WeightProgressErrorCode.numericalFailure, date: date,
      );
    }
    return average;
  }

  double _finiteDifference(double a, double b, DateTime? date) {
    final result = a - b;
    if (!result.isFinite) {
      throw WeightProgressException(
        WeightProgressErrorCode.numericalFailure, date: date,
      );
    }
    return result;
  }

  double _finiteProduct(double a, double b, DateTime? date) {
    final result = a * b;
    if (!result.isFinite) {
      throw WeightProgressException(
        WeightProgressErrorCode.numericalFailure, date: date,
      );
    }
    return result;
  }

  // Calendar key only: not a time-zone conversion.
  DateTime _civilDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  void _validatePositive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name);
    }
  }
}
