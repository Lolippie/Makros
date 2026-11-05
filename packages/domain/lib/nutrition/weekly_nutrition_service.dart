import 'package:makros_models/models.dart';

import 'daily_nutrition_day_status.dart';
import 'exceptions/daily_nutrition_exception.dart';
import 'nutrition_macros_validator.dart';
import 'nutrition_calendar.dart';
import 'results/daily_nutrition_result.dart';
import 'results/macro_calculation_result.dart';
import 'results/weekly_nutrition_result.dart';

/// Agrège les bilans d'une semaine, recalculés avec le même jour civil [asOf].
/// Les résultats d'autres utilisateurs ou semaines sont ignorés, doublons inclus.
/// Les dates sont déjà exprimées dans le calendrier civil de l'utilisateur.
/// Les bilans sont des instantanés : après une modification de repas, recalculer
/// le jour concerné puis la semaine. Les totaux incluent le jour en cours ;
/// les verdicts de réussite ne concernent que les jours terminés.
/// Un jour clos avec repas mais sans cible contribue aux apports consommés,
/// mais pas aux journées évaluées ni au taux de réussite.
/// `ArgumentError` : erreur de programmation (identifiant vide).
/// `DailyNutritionException` : bilan journalier métier invalide ou périmé.
class WeeklyNutritionService {
  const WeeklyNutritionService();

  WeeklyNutritionResult calculate({
    required String userId,
    required DateTime dateInWeek,
    required DateTime asOf,
    required List<DailyNutritionResult> dailyResults,
  }) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Identifiant vide');
    }

    final today = calendarDay(asOf);
    final date = calendarDay(dateInWeek);
    final start = date.subtract(Duration(days: date.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 6));
    final byDate = <DateTime, DailyNutritionResult>{};

    for (final result in dailyResults) {
      if (result.userId != userId) continue;
      final day = calendarDay(result.date);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      if (byDate.containsKey(day)) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.duplicateDailyResult,
          dayLabel(day),
        );
      }
      _validateDailyResult(result, day: day, today: today);
      byDate[day] = result;
    }

    final accumulator = _WeekAccumulator();
    for (var offset = 0; offset < 7; offset++) {
      final day = start.add(Duration(days: offset));
      final result = byDate[day];
      if (result == null) {
        accumulator.missing.add(day);
      } else {
        accumulator.add(result, day);
      }
    }
    return accumulator.build(
      userId: userId,
      start: start,
      end: end,
      today: today,
    );
  }

  void _validateDailyResult(
    DailyNutritionResult result, {
    required DateTime day,
    required DateTime today,
  }) {
    _validateTemporal(result, day, today);
    _validateConsumption(result, day);
    _validateTarget(result, day);
    _validateVariance(result, day);
  }

  void _validateTemporal(
    DailyNutritionResult result,
    DateTime day,
    DateTime today,
  ) {
    final expected = dayStatusFor(day, today);
    if (result.dayStatus != expected) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.staleDailyResult,
        dayLabel(day),
      );
    }
    // Un résultat produit par DailyNutritionService ne peut conserver
    // une validation manuelle effective sur un jour futur ou avec repas.
    if (result.isManuallyValidated &&
        (result.mealCount != 0 || day.isAfter(today))) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.invalidDailyResult,
        dayLabel(day),
      );
    }
  }

  void _validateConsumption(DailyNutritionResult result, DateTime day) {
    if (result.mealCount < 0) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.invalidDailyResult,
        dayLabel(day),
      );
    }
    validateNutritionMacros(result.consumed, 'consumed:${dayLabel(day)}');
    if (result.mealCount == 0 && !_isZero(result.consumed)) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.invalidDailyResult,
        dayLabel(day),
      );
    }
    if (result.mealCount == 0 &&
        (result.achievement != null ||
            result.goalStatuses != null ||
            result.variance != null)) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.invalidDailyResult,
        dayLabel(day),
      );
    }
  }

  void _validateTarget(DailyNutritionResult result, DateTime day) {
    final target = result.target;
    if (target == null) {
      if (result.targetSource != DailyNutritionTargetSource.none ||
          result.achievement != null ||
          result.goalStatuses != null ||
          result.variance != null) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.invalidDailyResult,
          dayLabel(day),
        );
      }
    } else {
      validateNutritionTarget(target, 'target:${dayLabel(day)}');
      if (result.targetSource == DailyNutritionTargetSource.none ||
          (result.mealCount > 0 && result.achievement == null)) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.invalidDailyResult,
          dayLabel(day),
        );
      }
    }
    // Un jour terminé avec repas et cible doit avoir un verdict définitif.
    // Les résultats sans cible restent non évaluables, sans être invalides.
    if (result.dayStatus == DailyNutritionDayStatus.completed &&
        result.mealCount > 0 &&
        target != null &&
        result.allGoalsReached == null) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.invalidDailyResult,
        dayLabel(day),
      );
    }
    if (result.macroStatus == MacroCalculationStatus.invalid &&
        result.targetSource == DailyNutritionTargetSource.plannedDay) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.invalidDailyResult,
        dayLabel(day),
      );
    }
  }

  void _validateVariance(DailyNutritionResult result, DateTime day) {
    if (result.variance == null || result.target == null) return;
    final diff = result.variance!.difference;
    final expected = _subtract(result.consumed, result.target!);
    final differences = [
      diff.calories - expected.calories,
      diff.protein - expected.protein,
      diff.carbohydrates - expected.carbohydrates,
      diff.fat - expected.fat,
      diff.fiber - expected.fiber,
    ];
    if (differences.any(
      (v) => !v.isFinite || v.abs() > _varianceConsistencyEpsilon,
    )) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.invalidDailyResult,
        dayLabel(day),
      );
    }
  }
}

/// Tolérance arithmétique pour contrôler les écarts, distincte des seuils métier.
const double _varianceConsistencyEpsilon = 1e-6;

const Macros _zeroMacros = Macros(
  calories: 0,
  protein: 0,
  carbohydrates: 0,
  fat: 0,
  fiber: 0,
);

bool _isZero(Macros value) =>
    value.calories == 0 &&
    value.protein == 0 &&
    value.carbohydrates == 0 &&
    value.fat == 0 &&
    value.fiber == 0;

Macros _subtract(Macros a, Macros b) => Macros(
  calories: a.calories - b.calories,
  protein: a.protein - b.protein,
  carbohydrates: a.carbohydrates - b.carbohydrates,
  fat: a.fat - b.fat,
  fiber: a.fiber - b.fiber,
);

/// Accumulateur interne : aucun état partagé entre deux appels à calculate.
class _WeekAccumulator {
  final days = <DailyNutritionResult>[];
  final missing = <DateTime>[];
  final unknown = <DateTime>[];

  Macros consumed = _zeroMacros;
  Macros knownTargets = _zeroMacros;
  Macros comparableConsumed = _zeroMacros;
  Macros comparableTargets = _zeroMacros;

  int consumptionDays = 0;
  int targetDays = 0;
  int comparableDays = 0;
  int completed = 0;
  int inProgress = 0;
  int upcoming = 0;
  int evaluated = 0;
  int successful = 0;
  int failed = 0;
  int manuallyValidated = 0;

  void add(DailyNutritionResult result, DateTime day) {
    days.add(result);
    if (result.isManuallyValidated) manuallyValidated++;
    // Seuls les jours passés non renseignés sont inconnus.
    if (result.dayStatus == DailyNutritionDayStatus.completed &&
        result.mealCount == 0 &&
        !result.isManuallyValidated) {
      unknown.add(day);
    }

    switch (result.dayStatus) {
      case DailyNutritionDayStatus.completed:
        completed++;
        break;
      case DailyNutritionDayStatus.inProgress:
        inProgress++;
        break;
      case DailyNutritionDayStatus.upcoming:
        upcoming++;
        break;
    }

    final isUpcoming = result.dayStatus == DailyNutritionDayStatus.upcoming;
    // Les jours futurs ne contribuent pas aux apports consommés.
    if (!isUpcoming && result.mealCount > 0) {
      consumed = consumed + result.consumed;
      consumptionDays++;
    }
    final target = result.target;
    if (target != null) {
      knownTargets = knownTargets + target;
      targetDays++;
      if (!isUpcoming && result.mealCount > 0) {
        comparableConsumed = comparableConsumed + result.consumed;
        comparableTargets = comparableTargets + target;
        comparableDays++;
      }
    }

    // Un jour en cours n'a jamais de verdict hebdomadaire définitif.
    if (result.dayStatus != DailyNutritionDayStatus.completed) return;
    // Traitée manuellement, mais exclue des statistiques de réussite.
    if (result.isManuallyValidated) return;
    if (target == null || result.mealCount == 0) return;
    evaluated++;
    switch (result.allGoalsReached) {
      case true:
        successful++;
        break;
      case false:
        failed++;
        break;
      case null:
        // _validateTarget a déjà rejeté un verdict indéterminé sur jour clos.
        throw StateError("Verdict journalier manquant après validation.");
    }
  }

  WeeklyNutritionResult build({
    required String userId,
    required DateTime start,
    required DateTime end,
    required DateTime today,
  }) => WeeklyNutritionResult(
    userId: userId,
    weekStart: start,
    weekEnd: end,
    asOfDay: today,
    days: List.unmodifiable(days),
    missingDates: List.unmodifiable(missing),
    unknownDates: List.unmodifiable(unknown),
    recordedDayCount: days.length,
    consumptionDayCount: consumptionDays,
    targetDayCount: targetDays,
    completedDayCount: completed,
    inProgressDayCount: inProgress,
    upcomingDayCount: upcoming,
    totalConsumed: consumed,
    totalKnownTargets: knownTargets,
    comparableConsumed: comparableConsumed,
    comparableTargets: comparableTargets,
    comparableVariance: _subtract(comparableConsumed, comparableTargets),
    comparableDayCount: comparableDays,
    evaluatedCompletedDays: evaluated,
    successfulCompletedDays: successful,
    failedCompletedDays: failed,
    manuallyValidatedDayCount: manuallyValidated,
  );
}
