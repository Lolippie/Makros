import 'package:makros_models/models.dart';

import '../utils/civil_calendar.dart';
import 'config/body_fat_progress_config.dart';
import 'exceptions/body_fat_progress_exception.dart';
import 'results/body_fat_progress_result.dart';

export 'config/body_fat_progress_config.dart';
export 'exceptions/body_fat_progress_exception.dart';
export 'results/body_fat_progress_result.dart';

/// Analyse pure de masse grasse sur deux fenêtres consécutives.
/// Les dates sont des jours civils et [asOf] est inclusif.
/// Pour l'évaluation d'un objectif, sélectionner explicitement la méthode.
class BodyFatProgressService {
  final BodyFatProgressConfig config;

  const BodyFatProgressService({this.config = const BodyFatProgressConfig()});

  BodyFatProgressResult analyze({
    required String userId,
    required List<BodyFatHistory> measurements,
    required DateTime asOf,
    DateTime? earliestMeasurementDate,
    String? measurementMethod,
    bool selectUnknownMethod = false,

    /// Réservé à l'affichage, jamais au verrouillage d'un objectif.
    bool preferLatestMeasurementMethod = false,
  }) {
    config.validate();
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'ne doit pas être vide');
    }
    final normalizedMethod = normalizeMeasurementMethod(measurementMethod);
    if (measurementMethod != null && normalizedMethod == null) {
      throw ArgumentError.value(measurementMethod, 'measurementMethod', 'vide');
    }
    if (selectUnknownMethod && measurementMethod != null) {
      throw ArgumentError(
        'selectUnknownMethod et measurementMethod sont exclusifs',
      );
    }
    if (preferLatestMeasurementMethod &&
        (selectUnknownMethod || measurementMethod != null)) {
      throw ArgumentError(
        'preferLatestMeasurementMethod est exclusif des autres sélecteurs',
      );
    }

    final asOfDay = civilDay(asOf);
    final cutoff = earliestMeasurementDate == null
        ? null
        : civilDay(earliestMeasurementDate);
    final earliestWindowDay = asOfDay.subtract(
      Duration(days: 2 * config.trendWindowDays - 1),
    );
    final candidates = <BodyFatHistory>[];
    final selected = <BodyFatHistory>[];
    final methods = <String?>{};

    for (final m in measurements) {
      if (m.userId != userId) continue;
      final day = civilDay(m.measuredAt);
      if (day.isBefore(earliestWindowDay) ||
          day.isAfter(asOfDay) ||
          (cutoff != null && day.isBefore(cutoff)))
        continue;
      candidates.add(m);
      final method = normalizeMeasurementMethod(m.measurementMethod);
      if (normalizedMethod != null && method != normalizedMethod) continue;
      if (selectUnknownMethod && method != null) continue;
      selected.add(m);
      methods.add(method);
    }

    if (preferLatestMeasurementMethod && candidates.isNotEmpty) {
      candidates.sort((a, b) {
        final byDay = civilDay(b.measuredAt).compareTo(civilDay(a.measuredAt));
        if (byDay != 0) return byDay;
        final byInstant = b.measuredAt.compareTo(a.measuredAt);
        return byInstant != 0 ? byInstant : a.id.compareTo(b.id);
      });
      final latestMethod = normalizeMeasurementMethod(
        candidates.first.measurementMethod,
      );
      selected
        ..clear()
        ..addAll(
          candidates.where(
            (m) =>
                normalizeMeasurementMethod(m.measurementMethod) == latestMethod,
          ),
        );
      methods
        ..clear()
        ..add(latestMethod);
    }

    final implicit =
        normalizedMethod == null &&
        !selectUnknownMethod &&
        !preferLatestMeasurementMethod;
    final checkedIds = <String>{};
    for (final m in implicit ? candidates : selected) {
      _validateMeasurement(m, checkedIds);
    }
    if (implicit && methods.length > 1) {
      final sortedMethods = methods.toList()
        ..sort(
          (a, b) => a == null
              ? -1
              : b == null
              ? 1
              : a.compareTo(b),
        );
      throw BodyFatProgressException(
        BodyFatProgressErrorCode.mixedMeasurementMethods,
        methods: List.unmodifiable(sortedMethods),
      );
    }

    final effectiveMethod =
        normalizedMethod ?? (methods.isEmpty ? null : methods.single);
    final hasSelectedMethod =
        normalizedMethod != null || selectUnknownMethod || methods.isNotEmpty;
    final grouped = <DateTime, List<double>>{};
    for (final m in selected) {
      grouped
          .putIfAbsent(civilDay(m.measuredAt), () => <double>[])
          .add(m.bodyFatPercentage);
    }
    final means = <DateTime, double>{};
    for (final entry in grouped.entries) {
      final mean = _mean(entry.value);
      if (!mean.isFinite) {
        throw BodyFatProgressException(
          BodyFatProgressErrorCode.invalidComputation,
          date: entry.key,
        );
      }
      means[entry.key] = mean;
    }

    final current = _window(means, asOfDay, earliestWindowDay);
    final previous = _window(
      means,
      asOfDay.subtract(Duration(days: config.trendWindowDays)),
      earliestWindowDay,
    );
    final fresh =
        current.mean != null &&
        current.latest != null &&
        asOfDay.difference(current.latest!).inDays <=
            config.maxDaysSinceLastMeasurement;
    final change = current.mean == null || previous.mean == null
        ? null
        : current.mean! - previous.mean!;
    if (change != null && !change.isFinite) {
      throw const BodyFatProgressException(
        BodyFatProgressErrorCode.invalidComputation,
      );
    }
    double? weekly;
    if (change != null &&
        current.centerDay != null &&
        previous.centerDay != null) {
      final spacing = current.centerDay! - previous.centerDay!;
      if (spacing + 1e-9 >=
          config.trendWindowDays * config.minimumCenterSpacingFraction) {
        weekly = change * 7 / spacing;
        if (!weekly.isFinite) {
          throw const BodyFatProgressException(
            BodyFatProgressErrorCode.invalidComputation,
          );
        }
      }
    }
    final threshold =
        config.stableThresholdPercentagePoints +
        config.comparisonEpsilonPercentagePoints;
    final status = current.mean == null
        ? BodyFatTrendStatus.insufficientData
        : change == null
        ? BodyFatTrendStatus.unknown
        : change < -threshold
        ? BodyFatTrendStatus.decreasing
        : change > threshold
        ? BodyFatTrendStatus.increasing
        : BodyFatTrendStatus.stable;

    return BodyFatProgressResult(
      userId: userId,
      asOfDay: asOfDay,
      earliestMeasurementDate: cutoff,
      measurementMethod: effectiveMethod,
      hasSelectedMethod: hasSelectedMethod,
      trendWindowDays: config.trendWindowDays,
      goalTolerancePercentagePoints: config.goalTolerancePercentagePoints,
      comparisonEpsilonPercentagePoints:
          config.comparisonEpsilonPercentagePoints,
      currentTrendPercentage: current.mean,
      previousTrendPercentage: previous.mean,
      changeBetweenWindowsPercentagePoints: change,
      weeklyChangePercentagePoints: weekly,
      measurementDaysInCurrentWindow: current.days,
      measurementDaysInPreviousWindow: previous.days,
      lastMeasurementDate: current.latest,
      isTrendFresh: fresh,
      trendStatus: status,
    );
  }

  void _validateMeasurement(BodyFatHistory m, Set<String> ids) {
    final day = civilDay(m.measuredAt);
    if (m.id.trim().isEmpty ||
        !m.bodyFatPercentage.isFinite ||
        m.bodyFatPercentage < config.minimumPlausibleBodyFatPercentage ||
        m.bodyFatPercentage > config.maximumPlausibleBodyFatPercentage) {
      throw BodyFatProgressException(
        BodyFatProgressErrorCode.invalidMeasurement,
        measurementId: m.id,
        date: day,
      );
    }
    if (!ids.add(m.id)) {
      throw BodyFatProgressException(
        BodyFatProgressErrorCode.duplicateMeasurement,
        measurementId: m.id,
        date: day,
      );
    }
  }

  _BodyFatWindow _window(
    Map<DateTime, double> means,
    DateTime end,
    DateTime origin,
  ) {
    final start = end.subtract(Duration(days: config.trendWindowDays - 1));
    final days =
        means.keys.where((d) => !d.isBefore(start) && !d.isAfter(end)).toList()
          ..sort();
    if (days.isEmpty) return const _BodyFatWindow(null, null, null, 0);
    final latest = days.last;
    final span = latest.difference(days.first).inDays;
    if (days.length < config.minimumMeasurementDays ||
        span < config.minimumMeasurementSpanDays) {
      return _BodyFatWindow(null, latest, null, days.length);
    }
    final mean = _mean(days.map((d) => means[d]!).toList());
    final center =
        days
            .map((d) => d.difference(origin).inDays.toDouble())
            .reduce((a, b) => a + b) /
        days.length;
    if (!mean.isFinite || !center.isFinite) {
      throw const BodyFatProgressException(
        BodyFatProgressErrorCode.invalidComputation,
      );
    }
    return _BodyFatWindow(mean, latest, center, days.length);
  }

  double _mean(List<double> values) {
    var mean = 0.0;
    for (var i = 0; i < values.length; i++) {
      mean += (values[i] - mean) / (i + 1);
    }
    return mean;
  }
}

class _BodyFatWindow {
  final double? mean;
  final DateTime? latest;
  final double? centerDay;
  final int days;

  const _BodyFatWindow(this.mean, this.latest, this.centerDay, this.days);
}
