import 'package:makros_models/models.dart';

import '../daily_nutrition_day_status.dart';
import 'daily_nutrition_result.dart';

/// Agrégats observés, sans compensation des objectifs entre journées.
class WeeklyNutritionResult {
  final String userId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime asOfDay;
  final List<DailyNutritionResult> days;
  final List<DateTime> missingDates;

  /// Journées terminées sans repas ni validation (pas les jours en cours/futurs).
  final List<DateTime> unknownDates;
  final int recordedDayCount;
  final int consumptionDayCount;
  final int targetDayCount;
  final int completedDayCount;
  final int inProgressDayCount;
  final int upcomingDayCount;
  final Macros totalConsumed;
  final Macros totalKnownTargets;
  final Macros comparableConsumed;
  final Macros comparableTargets;
  final Macros comparableVariance;
  final int comparableDayCount;

  /// Jours terminés avec repas, cible et verdict nutritionnel définitif.
  /// Les jours validés manuellement sont exclus de ce compteur.
  final int evaluatedCompletedDays;
  final int successfulCompletedDays;
  final int failedCompletedDays;
  final int manuallyValidatedDayCount;

  const WeeklyNutritionResult({
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    required this.asOfDay,
    required this.days,
    required this.missingDates,
    required this.unknownDates,
    required this.recordedDayCount,
    required this.consumptionDayCount,
    required this.targetDayCount,
    required this.completedDayCount,
    required this.inProgressDayCount,
    required this.upcomingDayCount,
    required this.totalConsumed,
    required this.totalKnownTargets,
    required this.comparableConsumed,
    required this.comparableTargets,
    required this.comparableVariance,
    required this.comparableDayCount,
    required this.evaluatedCompletedDays,
    required this.successfulCompletedDays,
    required this.failedCompletedDays,
    required this.manuallyValidatedDayCount,
  });

  /// Réussites nutritionnelles uniquement ; aucune validation manuelle incluse.
  int get automaticallySuccessfulCompletedDays => successfulCompletedDays;

  /// Jours terminés sans verdict nutritionnel : non renseignés, sans cible
  /// ou validés manuellement. Ne signifie pas que la journée est non traitée.
  int get unevaluableCompletedDayCount =>
      completedDayCount - successfulCompletedDays - failedCompletedDays;

  /// Jours terminés avec repas mais sans objectif chiffré : consommation
  /// connue, mais réussite impossible à déterminer.
  int get completedDaysWithoutTarget => days
      .where(
        (day) =>
            day.dayStatus == DailyNutritionDayStatus.completed &&
            day.mealCount > 0 &&
            day.target == null,
      )
      .length;

  /// Journées passées non renseignées : jours absents ou sans repas.
  /// Les journées en cours et futures sont exclues de ce compteur.
  int get unknownDayCount =>
      missingDates.where((day) => day.isBefore(asOfDay)).length +
      unknownDates.length;

  /// Journées terminées avec repas ou validation manuelle.
  int get documentedCompletedDayCount =>
      completedDayCount -
      days
          .where(
            (d) =>
                d.dayStatus == DailyNutritionDayStatus.completed &&
                d.mealCount == 0 &&
                !d.isManuallyValidated,
          )
          .length;

  bool get hasAllDays => recordedDayCount == 7;
  bool get hasCompleteTargets => targetDayCount == 7;
  Macros? get weeklyTarget => hasCompleteTargets ? totalKnownTargets : null;

  /// Moyenne par bilan enregistré non futur, et non par jour calendaire.
  Macros? get averageDailyConsumed => consumptionDayCount == 0
      ? null
      : totalConsumed * (1 / consumptionDayCount);

  Macros? get averageKnownDailyTarget =>
      targetDayCount == 0 ? null : totalKnownTargets * (1 / targetDayCount);

  /// Taux nutritionnel : seules les réussites/échecs mesurés sont retenus.
  /// Les validations manuelles sont exclues du numérateur et du dénominateur.
  double? get completedSuccessRate {
    final known = successfulCompletedDays + failedCompletedDays;
    return known == 0 ? null : successfulCompletedDays / known * 100;
  }

  /// Part des journées traitées avec verdict nutritionnel mesuré.
  /// Les validations manuelles sont traitées, mais sans verdict nutritionnel.
  double? get evaluationCoverageRate => documentedCompletedDayCount == 0
      ? null
      : (successfulCompletedDays + failedCompletedDays) /
            documentedCompletedDayCount *
            100;

  /// Couverture des journées terminées, y compris les jours absents.
  double? get completedDayCoverageRate {
    final elapsed = weekStart.isAfter(asOfDay)
        ? 0
        : asOfDay.isAfter(weekEnd)
        ? 7
        : asOfDay.difference(weekStart).inDays;
    if (elapsed == 0) return null;
    return documentedCompletedDayCount / elapsed * 100;
  }
}
