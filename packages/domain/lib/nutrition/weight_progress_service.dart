import 'package:makros_models/models.dart';

import 'config/weight_progress_config.dart';
import 'exceptions/weight_progress_exception.dart';
import 'results/weight_progress_result.dart';
import 'utils/civil_calendar.dart';

export 'exceptions/weight_progress_exception.dart';

/// Analyse l'historique de poids sans modifier les pesées ou les objectifs.
///
/// [asOf] est un JOUR CIVIL inclusif (et non une heure limite).
/// [asOf] et les dates de pesée doivent déjà être représentés dans le même
/// calendrier civil de l'utilisateur. Ne pas mélanger UTC et heure locale :
/// la conversion de fuseau appartient à la couche application.
/// Les mesures d'autres utilisateurs et hors des deux fenêtres sont ignorées,
/// même si elles ont un identifiant en double ou une valeur invalide.
/// Les doublons et identifiants vides sont rejetés uniquement dans ce périmètre.
///
/// Les statuts de tendance et d'objectif sont historiques : leur affichage
/// comme état actuel nécessite de vérifier [WeightProgressResult.isTrendFresh].
class WeightProgressService {
  final WeightProgressConfig config;

  const WeightProgressService({this.config = const WeightProgressConfig()});

  WeightProgressResult analyze({
    required String userId,
    required List<WeightHistory> measurements,
    required double referenceWeightKg,
    required DateTime asOf,
    double? targetWeightKg,
  }) {
    config.validate();
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'ne doit pas être vide');
    }
    _validatePositive(referenceWeightKg, 'referenceWeightKg');
    if (targetWeightKg != null) {
      _validatePositive(targetWeightKg, 'targetWeightKg');
    }

    final asOfDay = civilDay(asOf);
    final earliest = asOfDay.subtract(
      Duration(days: 2 * config.trendWindowDays - 1),
    );
    // Même origine pour les centres des deux fenêtres.
    final centerOrigin = earliest;
    final grouped = <DateTime, List<double>>{};
    final ids = <String>{};

    for (final measurement in measurements) {
      if (measurement.userId != userId) continue;
      final day = civilDay(measurement.measuredAt);
      if (day.isBefore(earliest) || day.isAfter(asOfDay)) continue;
      if (measurement.id.trim().isEmpty) {
        throw WeightProgressException(
          WeightProgressErrorCode.invalidMeasurement,
          date: day,
          measurementId: measurement.id,
        );
      }
      if (!ids.add(measurement.id)) {
        throw WeightProgressException(
          WeightProgressErrorCode.duplicateMeasurement,
          date: day, measurementId: measurement.id,
        );
      }
      final weight = measurement.weight;
      if (!weight.isFinite || weight <= 0 ||
          (config.minimumPlausibleWeightKg != null &&
              weight < config.minimumPlausibleWeightKg!) ||
          (config.maximumPlausibleWeightKg != null &&
              weight > config.maximumPlausibleWeightKg!)) {
        throw WeightProgressException(
          WeightProgressErrorCode.invalidMeasurement,
          date: day, measurementId: measurement.id,
        );
      }
      grouped.putIfAbsent(day, () => <double>[]).add(weight);
    }

    final dailyMeans = <DateTime, double>{};
    for (final entry in grouped.entries) {
      dailyMeans[entry.key] = _mean(entry.value, entry.key);
    }
    final sortedDays = dailyMeans.keys.toList()..sort();
    final current = _window(sortedDays, dailyMeans, asOfDay, centerOrigin);
    final previous = _window(sortedDays, dailyMeans,
        asOfDay.subtract(Duration(days: config.trendWindowDays)), centerOrigin);
    final currentMean = current.mean;
    final previousMean = previous.mean;
    final latest = current.latest;
    final fresh = currentMean != null && latest != null &&
        asOfDay.difference(latest).inDays <= config.maxDaysSinceLastMeasurement;

    final delta = currentMean == null ? null :
        _finiteDifference(currentMean, referenceWeightKg, asOfDay);
    final between = currentMean == null || previousMean == null ? null :
        _finiteDifference(currentMean, previousMean, asOfDay);
    final remaining = currentMean == null || targetWeightKg == null ? null :
        _finiteDifference(targetWeightKg, currentMean, asOfDay);

    // Centre des jours réellement mesurés, et non milieu théorique de fenêtre.
    final spacingDays = current.centerDay == null || previous.centerDay == null
        ? null : current.centerDay! - previous.centerDay!;
    final minimumSpacingDays =
        config.trendWindowDays * config.minimumCenterSpacingFraction;
    // Tolérance temporelle en jours, indépendante des seuils en kg.
    final weeklyChange = between == null ||
            spacingDays == null ||
            spacingDays + 1e-9 < minimumSpacingDays
        ? null
        : _finiteProduct(between, 7.0 / spacingDays, asOfDay);

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
        currentMean: currentMean, reference: referenceWeightKg,
        target: targetWeightKg,
      ),
      shouldSuggestRecalculation: fresh && delta != null &&
          delta.abs() + config.comparisonEpsilonKg >= config.recalculationThresholdKg,
    );
  }

  WeightTrendStatus _trendStatus({required double? currentMean, required double? between}) {
    if (currentMean == null) return WeightTrendStatus.insufficientData;
    if (between == null) return WeightTrendStatus.unknown;
    if (between < -config.stableThresholdKg - config.comparisonEpsilonKg) {
      return WeightTrendStatus.decreasing;
    }
    if (between > config.stableThresholdKg + config.comparisonEpsilonKg) {
      return WeightTrendStatus.increasing;
    }
    return WeightTrendStatus.stable;
  }

  WeightGoalProgressStatus _goalStatus({
    required double? currentMean, required double reference, required double? target,
  }) {
    if (currentMean == null || target == null) return WeightGoalProgressStatus.unknown;
    final difference = _finiteDifference(currentMean, target, null);
    if (difference.abs() <= config.goalToleranceKg + config.comparisonEpsilonKg) {
      return WeightGoalProgressStatus.reached;
    }
    if ((target - reference).abs() <= config.comparisonEpsilonKg) {
      return WeightGoalProgressStatus.notReached;
    }
    final exceeded = target < reference ? difference < 0 : difference > 0;
    return exceeded ? WeightGoalProgressStatus.exceeded : WeightGoalProgressStatus.notReached;
  }

  _WeightWindow _window(
    List<DateTime> sortedDays, Map<DateTime, double> dailyMeans,
    DateTime endInclusive, DateTime centerOrigin,
  ) {
    final start = endInclusive.subtract(Duration(days: config.trendWindowDays - 1));
    final dates = sortedDays.where((day) =>
        !day.isBefore(start) && !day.isAfter(endInclusive)).toList();
    if (dates.isEmpty) {
      return const _WeightWindow(mean: null, count: 0, latest: null, centerDay: null);
    }
    final latest = dates.last;
    if (dates.length < config.minimumMeasurementDays ||
        latest.difference(dates.first).inDays < config.minimumMeasurementSpanDays) {
      return _WeightWindow(
        mean: null,
        count: dates.length,
        latest: latest,
        centerDay: null,
      );
    }
    // Décalages non négatifs par rapport à une origine commune.
    // Ne pas utiliser _mean, qui impose une moyenne de poids > 0.
    final center = _meanOffsets(
      [for (final date in dates) date.difference(centerOrigin).inDays],
    );
    return _WeightWindow(
      mean: _mean([for (final date in dates) dailyMeans[date]!], latest),
      count: dates.length,
      latest: latest,
      centerDay: center,
    );
  }

  double _mean(List<double> values, DateTime? date) {
    if (values.isEmpty) {
      throw WeightProgressException(WeightProgressErrorCode.numericalFailure, date: date);
    }
    var average = 0.0;
    for (var i = 0; i < values.length; i++) {
      average += (values[i] - average) / (i + 1);
    }
    if (!average.isFinite || average <= 0) {
      throw WeightProgressException(WeightProgressErrorCode.numericalFailure, date: date);
    }
    return average;
  }

  double _meanOffsets(List<int> offsets) {
    var mean = 0.0;
    for (var i = 0; i < offsets.length; i++) {
      mean += (offsets[i] - mean) / (i + 1);
    }
    return mean;
  }

  double _finiteDifference(double a, double b, DateTime? date) {
    final value = a - b;
    if (!value.isFinite) {
      throw WeightProgressException(WeightProgressErrorCode.numericalFailure, date: date);
    }
    return value;
  }

  double _finiteProduct(double a, double b, DateTime? date) {
    final value = a * b;
    if (!value.isFinite) {
      throw WeightProgressException(WeightProgressErrorCode.numericalFailure, date: date);
    }
    return value;
  }

  void _validatePositive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'doit être strictement positif et fini',
      );
    }
  }
}

/// Statistiques d'une fenêtre de pesées ; aucune dépendance à la persistance.
class _WeightWindow {
  final double? mean;
  final int count;
  final DateTime? latest;
  final double? centerDay;

  const _WeightWindow({
    required this.mean,
    required this.count,
    required this.latest,
    required this.centerDay,
  });
}
