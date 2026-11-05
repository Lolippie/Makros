import 'dart:math';

import 'package:makros_models/models.dart';

import 'config/nutrition_planning_config.dart';
import 'exceptions/nutrition_planning_exception.dart';
import 'macro_calculator_service.dart';
import 'nutrition_calendar.dart';
import 'results/macro_calculation_result.dart';
import 'results/nutrition_planning_result.dart';

/// Construit un planning nutritionnel sans modifier les données d'entrée.
///
/// [ArgumentError] : erreur de programmation/configuration (ex. poids invalide).
/// [NutritionPlanningException] : incohérence de données métier (ex. date
/// manquante, durée persistée invalide, contrat de macros rompu).
///
/// Option A2 : une référence déjà inférieure au minimum mathématique reste
/// dans le résultat avec statut invalid et n'est jamais réduite davantage.
/// Avec le coefficient global, cela peut neutraliser la redistribution.
/// Les autres journées initialement réalisables restent réalisables.
/// La somme hebdomadaire est conservée à l'erreur flottante près ;
/// un clamp infinitésimal peut introduire un écart au dernier bit.
class NutritionPlanningService {
  static const int _planLength = 7;
  static const double _scoreEpsilon = 1e-12;
  static const double _relativeNumericalTolerance = 1e-12;

  final NutritionPlanningConfig config;
  final MacroCalculatorService macroCalculator;

  const NutritionPlanningService({
    this.config = const NutritionPlanningConfig(),
    this.macroCalculator = const MacroCalculatorService(),
  });

  double calculateActivityScore({required PlannedActiveDay day}) {
    config.validate();
    return _calculateActivityScore(day);
  }

  /// Exige sept jours civils du lundi au dimanche, comme le bilan hebdomadaire.
  /// Les références hors des sept jours sont validées mais ignorées.
  NutritionPlanningResult calculateWeeklyPlan({
    required List<PlannedActiveDay> days,
    required Map<DateTime, double> referenceCaloriesByDate,
    required double weightKg,
    required GoalType goalType,
  }) {
    config.validate();
    _validatePositive(weightKg, 'Le poids');
    final inputs = _buildInputs(days, referenceCaloriesByDate);
    final minimumCalories = macroCalculator.calculateMinimumCalories(
      weightKg: weightKg,
      goalType: goalType,
    );
    if (!minimumCalories.isFinite || minimumCalories <= 0) {
      throw const NutritionPlanningException(
        NutritionPlanningErrorCode.invalidMacroContract,
        'minimumCalories',
      );
    }

    final mean = inputs.scores.reduce((a, b) => a + b) / _planLength;
    final centered = inputs.scores.map((score) => score - mean).toList();
    final decision = _computeScale(inputs, centered, minimumCalories);
    final scale = decision.scale;

    final results = <PlannedNutritionDayResult>[];
    for (var i = 0; i < _planLength; i++) {
      final reference = inputs.references[i];
      var planned = reference + centered[i] * scale;
      // Correction uniquement d'une dérive flottante, pas d'une violation
      // réelle des contraintes. Les ajustements ne sont donc pas exactement
      // à somme nulle au dernier bit du double.
      if (reference >= minimumCalories && planned < minimumCalories) {
        final drift = minimumCalories - planned;
        final tolerance =
            _relativeNumericalTolerance *
            max(1.0, max(reference.abs(), minimumCalories.abs()));
        if (drift > tolerance) {
          throw NutritionPlanningException(
            NutritionPlanningErrorCode.numericalConstraintViolation,
            dayLabel(inputs.dates[i]),
          );
        }
        planned = minimumCalories;
      }
      if (!planned.isFinite || planned <= 0) {
        throw NutritionPlanningException(
          NutritionPlanningErrorCode.invalidMacroContract,
          dayLabel(inputs.dates[i]),
        );
      }
      final macroResult = macroCalculator.calculate(
        weightKg: weightKg,
        targetCalories: planned,
        goalType: goalType,
      );
      final valid =
          macroResult.status == MacroCalculationStatus.valid ||
          macroResult.status == MacroCalculationStatus.warning;
      if (valid != (macroResult.macros != null)) {
        throw NutritionPlanningException(
          NutritionPlanningErrorCode.invalidMacroContract,
          dayLabel(inputs.dates[i]),
        );
      }
      results.add(
        PlannedNutritionDayResult(
          date: inputs.dates[i],
          referenceCalories: inputs.references[i],
          plannedCalories: planned,
          activityScore: inputs.scores[i],
          targetMacros: macroResult.macros,
          macroStatus: macroResult.status,
          macroIssues: List.unmodifiable(macroResult.issues),
        ),
      );
    }
    return NutritionPlanningResult(
      days: List.unmodifiable(results),
      redistributionLimitedBy: decision.reason,
      requestedScale: config.caloriesPerActivityScorePoint,
      appliedScale: scale,
      limitingDate: decision.limitingDate,
    );
  }

  _PlanningInputs _buildInputs(
    List<PlannedActiveDay> days,
    Map<DateTime, double> referenceCaloriesByDate,
  ) {
    if (days.length != _planLength) {
      throw const NutritionPlanningException(
        NutritionPlanningErrorCode.invalidDayCount,
        'dayCount',
      );
    }
    final sorted = [...days]
      ..sort((a, b) => calendarDay(a.date).compareTo(calendarDay(b.date)));
    final normalized = <DateTime, double>{};
    for (final entry in referenceCaloriesByDate.entries) {
      final date = calendarDay(entry.key);
      if (normalized.containsKey(date)) {
        throw NutritionPlanningException(
          NutritionPlanningErrorCode.duplicateReferenceDate,
          dayLabel(date),
        );
      }
      if (!entry.value.isFinite || entry.value <= 0) {
        throw NutritionPlanningException(
          NutritionPlanningErrorCode.invalidReference,
          dayLabel(date),
        );
      }
      normalized[date] = entry.value;
    }

    final dates = <DateTime>[];
    final references = <double>[];
    final scores = <double>[];
    final limits = <double>[];
    for (final day in sorted) {
      final date = calendarDay(day.date);
      if (dates.isNotEmpty && date == dates.last) {
        throw NutritionPlanningException(
          NutritionPlanningErrorCode.duplicateDay,
          dayLabel(date),
        );
      }
      if (dates.isNotEmpty && date.difference(dates.last).inDays != 1) {
        throw NutritionPlanningException(
          NutritionPlanningErrorCode.nonConsecutiveDays,
          dayLabel(date),
        );
      }
      if (dates.isEmpty && date.weekday != DateTime.monday) {
        throw NutritionPlanningException(
          NutritionPlanningErrorCode.invalidWeekStart,
          dayLabel(date),
        );
      }
      final reference = normalized[date];
      if (reference == null) {
        throw NutritionPlanningException(
          NutritionPlanningErrorCode.missingReference,
          dayLabel(date),
        );
      }
      dates.add(date);
      references.add(reference);
      scores.add(_calculateActivityScore(day));
      limits.add(
        min(
          reference * config.maxDailyVariationFraction,
          config.maxDailyVariationCalories,
        ),
      );
    }
    return _PlanningInputs(dates, references, scores, limits);
  }

  _ScaleDecision _computeScale(
    _PlanningInputs inputs,
    List<double> centered,
    double minimumCalories,
  ) {
    var scale = config.caloriesPerActivityScorePoint;
    var reason = RedistributionLimitReason.none;
    DateTime? limitingDate;
    for (var i = 0; i < _planLength; i++) {
      final score = centered[i];
      if (score.abs() < _scoreEpsilon) continue;
      final dailyBound = inputs.limits[i] / score.abs();
      if (dailyBound < scale) {
        scale = dailyBound;
        reason = RedistributionLimitReason.dailyLimit;
        limitingDate = inputs.dates[i];
      }
      if (score >= 0) continue;

      final reference = inputs.references[i];
      if (reference < minimumCalories) {
        // A2 : une journée déjà insuffisante ne perd aucune calorie.
        // Le coefficient étant global, toute la semaine est neutralisée.
        return _ScaleDecision(
          0.0,
          RedistributionLimitReason.minimumCalories,
          inputs.dates[i],
        );
      }
      final available = reference - minimumCalories;
      final bound = max(0.0, available / score.abs());
      if (bound < scale ||
          (bound == scale &&
              reason != RedistributionLimitReason.minimumCalories)) {
        scale = bound;
        reason = RedistributionLimitReason.minimumCalories;
        limitingDate = inputs.dates[i];
      }
    }
    return _ScaleDecision(scale, reason, limitingDate);
  }

  double _calculateActivityScore(PlannedActiveDay day) {
    if (!day.hasActivity) return 0.0;
    final duration =
        day.plannedDurationMinutes ?? config.defaultActivityDurationMinutes;
    if (duration <= 0) {
      throw const NutritionPlanningException(
        NutritionPlanningErrorCode.invalidActivityDuration,
        'duration',
      );
    }
    final score =
        _getSportWeight(day.sportType) *
        duration /
        config.referenceDurationMinutes;
    if (!score.isFinite) {
      throw const NutritionPlanningException(
        NutritionPlanningErrorCode.invalidActivityScore,
        'activityScore',
      );
    }
    return min(score, config.maxActivityScore);
  }

  double _getSportWeight(SportType? type) {
    switch (type) {
      case SportType.gym:
        return config.gymWeight;
      case SportType.running:
        return config.runningWeight;
      case SportType.walking:
        return config.walkingWeight;
      case SportType.cycling:
        return config.cyclingWeight;
      case SportType.swimming:
        return config.swimmingWeight;
      case SportType.cardio:
        return config.cardioWeight;
      case SportType.other:
      case null:
        return config.otherWeight;
    }
  }

  void _validatePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('$label doit être strictement positif et fini.');
    }
  }
}

class _PlanningInputs {
  final List<DateTime> dates;
  final List<double> references;
  final List<double> scores;
  final List<double> limits;

  const _PlanningInputs(this.dates, this.references, this.scores, this.limits);
}

class _ScaleDecision {
  final double scale;
  final RedistributionLimitReason reason;
  final DateTime? limitingDate;

  const _ScaleDecision(this.scale, this.reason, this.limitingDate);
}
