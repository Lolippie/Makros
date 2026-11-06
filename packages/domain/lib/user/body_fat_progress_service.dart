import 'package:makros_models/models.dart';

import '../utils/civil_calendar.dart';
import 'config/body_fat_progress_config.dart';
import 'exceptions/body_fat_progress_exception.dart';
import 'results/body_fat_progress_result.dart';

export 'config/body_fat_progress_config.dart';
export 'exceptions/body_fat_progress_exception.dart';
export 'results/body_fat_progress_result.dart';

/// Analyse pure de mesures de masse grasse en pourcentage.
///
/// Les dates doivent être exprimées dans le même calendrier civil utilisateur.
/// [asOf] est inclusif. Les mesures d'autres utilisateurs et hors des deux
/// fenêtres (ou avant [earliestMeasurementDate]) sont ignorées.
///
/// Une analyse compare UNE SEULE méthode de mesure. Si plusieurs méthodes
/// sont présentes, [measurementMethod] doit être fourni explicitement.
/// Une méthode null est une méthode distincte (inconnue), pas un joker.
///
/// L'analyse ne valide jamais un UserGoal et ne persiste rien.
class BodyFatProgressService {
  final BodyFatProgressConfig config;

  const BodyFatProgressService({
    this.config = const BodyFatProgressConfig(),
  });

  BodyFatProgressResult analyze({
    required String userId,
    required List<BodyFatHistory> measurements,
    required DateTime asOf,
    DateTime? earliestMeasurementDate,
    String? measurementMethod,
  }) {
    config.validate();
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'ne doit pas être vide');
    }
    if (measurementMethod != null && measurementMethod.trim().isEmpty) {
      throw ArgumentError.value(measurementMethod, 'measurementMethod', 'ne doit pas être vide');
    }
    final normalizedMethod = measurementMethod?.trim().toLowerCase();
    final asOfDay = civilDay(asOf);
    final cutoff = earliestMeasurementDate == null
        ? null
        : civilDay(earliestMeasurementDate);
    final earliestWindowDay = asOfDay.subtract(
      Duration(days: 2 * config.trendWindowDays - 1),
    );
    final selected = <BodyFatHistory>[];
    final methods = <String?>{};
    for (final m in measurements) {
      if (m.userId != userId) continue;
      final day = civilDay(m.measuredAt);
      if (day.isBefore(earliestWindowDay) || day.isAfter(asOfDay) ||
          (cutoff != null && day.isBefore(cutoff))) continue;
      final method = _normalizedMethod(m.measurementMethod);
      // En mode explicite, ignorer les autres méthodes (sans les valider).
      if (normalizedMethod != null && method != normalizedMethod) continue;
      selected.add(m);
      methods.add(method);
    }
    if (normalizedMethod == null && methods.length > 1) {
      throw const BodyFatProgressException(
        BodyFatProgressErrorCode.mixedMeasurementMethods,
      );
    }
    final effectiveMethod = normalizedMethod ??
        (methods.isEmpty ? null : methods.single);
    final ids = <String>{};
    final grouped = <DateTime, List<double>>{};
    for (final m in selected) {
      final day = civilDay(m.measuredAt);
      if (m.id.trim().isEmpty ||
          !m.bodyFatPercentage.isFinite ||
          m.bodyFatPercentage <= 0 || m.bodyFatPercentage >= 100) {
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
      grouped.putIfAbsent(day, () => <double>[]).add(m.bodyFatPercentage);
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
    final fresh = current.mean != null && current.latest != null &&
        asOfDay.difference(current.latest!).inDays <=
            config.maxDaysSinceLastMeasurement;
    final change = current.mean == null || previous.mean == null
        ? null
        : current.mean! - previous.mean!;
    if (change != null && !change.isFinite) {
      throw const BodyFatProgressException(BodyFatProgressErrorCode.invalidComputation);
    }
    double? weekly;
    if (change != null && current.centerDay != null && previous.centerDay != null) {
      final spacing = current.centerDay! - previous.centerDay!;
      if (spacing + 1e-9 >=
          config.trendWindowDays * config.minimumCenterSpacingFraction) {
        weekly = change * 7 / spacing;
        if (!weekly.isFinite) {
          throw const BodyFatProgressException(BodyFatProgressErrorCode.invalidComputation);
        }
      }
    }
    final status = change == null
        ? BodyFatTrendStatus.insufficientData
        : change < -config.stableThresholdPercentagePoints -
                config.comparisonEpsilonPercentagePoints
            ? BodyFatTrendStatus.decreasing
            : change > config.stableThresholdPercentagePoints +
                    config.comparisonEpsilonPercentagePoints
                ? BodyFatTrendStatus.increasing
                : BodyFatTrendStatus.stable;

    return BodyFatProgressResult(
      userId: userId,
      asOfDay: asOfDay,
      earliestMeasurementDate: cutoff,
      measurementMethod: effectiveMethod,
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

  _BodyFatWindow _window(
    Map<DateTime, double> means,
    DateTime end,
    DateTime origin,
  ) {
    final start = end.subtract(Duration(days: config.trendWindowDays - 1));
    final days = means.keys.where(
      (d) => !d.isBefore(start) && !d.isAfter(end),
    ).toList()..sort();
    if (days.isEmpty) return const _BodyFatWindow(null, null, null, 0);
    final latest = days.last;
    final span = latest.difference(days.first).inDays;
    if (days.length < config.minimumMeasurementDays ||
        span < config.minimumMeasurementSpanDays) {
      return _BodyFatWindow(null, latest, null, days.length);
    }
    final values = days.map((d) => means[d]!).toList();
    final mean = _mean(values);
    final center = days.map((d) => d.difference(origin).inDays.toDouble())
        .reduce((a, b) => a + b) / days.length;
    if (!mean.isFinite || !center.isFinite) {
      throw const BodyFatProgressException(BodyFatProgressErrorCode.invalidComputation);
    }
    return _BodyFatWindow(mean, latest, center, days.length);
  }

  double _mean(List<double> values) {
    // Moyenne incrémentale pour éviter le débordement des sommes.
    var mean = 0.0;
    for (var i = 0; i < values.length; i++) {
      mean += (values[i] - mean) / (i + 1);
    }
    return mean;
  }

  String? _normalizedMethod(String? method) {
    if (method == null) return null;
    final normalized = method.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }
}

class _BodyFatWindow {
  final double? mean;
  final DateTime? latest;
  final double? centerDay;
  final int days;

  const _BodyFatWindow(this.mean, this.latest, this.centerDay, this.days);
}
