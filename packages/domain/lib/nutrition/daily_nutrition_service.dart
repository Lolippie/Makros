import 'package:makros_models/models.dart';

import 'config/daily_nutrition_config.dart';
import 'daily_nutrition_day_status.dart';
import 'exceptions/daily_nutrition_exception.dart';
import 'daily_nutrition_goal_evaluator.dart';
import 'nutrition_macros_validator.dart';
import 'nutrition_calendar.dart';
import 'results/daily_nutrition_result.dart';
import 'results/macro_calculation_result.dart';

/// `ArgumentError` : erreur de programmation (identifiant vide, configuration).
/// `DailyNutritionException` : données métier ou persistées incohérentes.
class DailyNutritionService {
  final DailyNutritionConfig config;

  const DailyNutritionService({this.config = const DailyNutritionConfig()});

  /// Calcule le bilan d'une date calendaire pour un utilisateur.
  ///
  /// Convention : [date], les dates des repas et [PlannedActiveDay.date]
  /// doivent déjà représenter le jour civil dans le fuseau choisi pour
  /// l'utilisateur. Les horodatages UTC doivent être convertis en amont.
  ///
  /// Priorité : objectifs du planning, puis [fallbackTarget].
  /// Si le planning est invalide, son statut est exposé et le fallback
  /// est utilisé s'il existe. L'appelant doit transmettre `invalid`.
  /// [asOf] est obligatoire et doit représenter le jour civil courant dans le même fuseau
  /// que [date] ; l'horloge est injectée pour rendre les tests déterministes.
  ///
  /// Aucun modèle reçu en paramètre n'est modifié.
  DailyNutritionResult calculate({
    required String userId,
    required DateTime date,
    required List<DailyMeal> meals,
    PlannedActiveDay? plannedDay,
    Macros? fallbackTarget,
    MacroCalculationStatus? macroStatus,
    required DateTime asOf,
    DailyNutritionValidation? manualValidation,
  }) {
    config.validate();
    _validateUserId(userId);
    final selectedDay = calendarDay(date);
    final today = calendarDay(asOf);
    final dayStatus = dayStatusFor(selectedDay, today);

    _validateInputs(
      selectedDay,
      userId,
      plannedDay,
      macroStatus,
      manualValidation,
    );
    final dailyMeals = _filterAndValidateMeals(meals, userId, selectedDay);
    final consumed = _sumMeals(dailyMeals);
    final (target, source) = _resolveTarget(
      plannedDay,
      fallbackTarget,
      macroStatus,
    );
    if (target != null) validateNutritionTarget(target, 'target');

    // Toute validation obsolète (repas présents ou jour futur) est ignorée.
    // La révocation en base reste à gérer lors de l'ajout d'un repas.
    final manuallyValidated =
        dailyMeals.isEmpty &&
        dayStatus != DailyNutritionDayStatus.upcoming &&
        (manualValidation?.manuallyValidated ?? false);

    if (target == null || dailyMeals.isEmpty) {
      return _buildResult(
        userId: userId,
        date: selectedDay,
        mealCount: dailyMeals.length,
        manuallyValidated: manuallyValidated,
        consumed: consumed,
        target: target,
        targetSource: source,
        macroStatus: macroStatus,
        dayStatus: dayStatus,
      );
    }

    final evaluation = DailyNutritionGoalEvaluator(
      config,
    ).evaluate(consumed: consumed, target: target, dayStatus: dayStatus);
    return _buildResult(
      userId: userId,
      date: selectedDay,
      mealCount: dailyMeals.length,
      manuallyValidated: manuallyValidated,
      consumed: consumed,
      target: target,
      targetSource: source,
      macroStatus: macroStatus,
      dayStatus: dayStatus,
      variance: NutritionVariance(target: target, consumed: consumed),
      achievement: evaluation.$2,
      goalStatuses: evaluation.$1,
    );
  }

  void _validateInputs(
    DateTime selectedDay,
    String userId,
    PlannedActiveDay? plannedDay,
    MacroCalculationStatus? macroStatus,
    DailyNutritionValidation? validation,
  ) {
    final planned = plannedDay;
    if (planned == null) {
      if (macroStatus != null) {
        throw const DailyNutritionException(
          DailyNutritionErrorCode.invalidPlanning,
          'missing-planned-day',
        );
      }
    } else {
      if (calendarDay(planned.date) != selectedDay) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.invalidPlanning,
          planned.id,
        );
      }
      final plannedTarget = planned.targetMacros;
      if (macroStatus == MacroCalculationStatus.invalid &&
          plannedTarget != null) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.invalidPlanning,
          planned.id,
        );
      }
      if ((macroStatus == MacroCalculationStatus.valid ||
              macroStatus == MacroCalculationStatus.warning) &&
          plannedTarget == null) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.invalidPlanning,
          planned.id,
        );
      }
    }
    if (validation != null &&
        (validation.userId != userId ||
            calendarDay(validation.date) != selectedDay)) {
      throw const DailyNutritionException(
        DailyNutritionErrorCode.invalidManualValidation,
        'mismatched-user-or-day',
      );
    }
  }

  List<DailyMeal> _filterAndValidateMeals(
    List<DailyMeal> meals,
    String userId,
    DateTime selectedDay,
  ) {
    // Les repas hors périmètre sont ignorés, y compris leurs doublons.
    final selected = meals
        .where(
          (meal) =>
              meal.userId == userId && calendarDay(meal.date) == selectedDay,
        )
        .toList();
    final ids = <String>{};
    for (final meal in selected) {
      if (!ids.add(meal.id)) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.duplicateMeal,
          meal.id,
        );
      }
      _validateMeal(meal);
    }
    return selected;
  }

  Macros _sumMeals(List<DailyMeal> meals) {
    var total = const Macros(
      calories: 0,
      protein: 0,
      carbohydrates: 0,
      fat: 0,
      fiber: 0,
    );
    for (final meal in meals) {
      final value = meal.totalMacros;
      validateNutritionMacros(value, meal.id);
      total = total + value;
    }
    validateNutritionMacros(total, 'daily-total');
    return total;
  }

  (Macros?, DailyNutritionTargetSource) _resolveTarget(
    PlannedActiveDay? plannedDay,
    Macros? fallback,
    MacroCalculationStatus? macroStatus,
  ) {
    // null : absence de diagnostic, la cible planifiée reste utilisable.
    // warning et valid : cible utilisable, warning conservé dans le résultat.
    final plannedTarget = plannedDay?.targetMacros;
    if (macroStatus != MacroCalculationStatus.invalid &&
        plannedTarget != null) {
      return (plannedTarget, DailyNutritionTargetSource.plannedDay);
    }
    if (fallback != null)
      return (fallback, DailyNutritionTargetSource.fallback);
    return (null, DailyNutritionTargetSource.none);
  }

  DailyNutritionResult _buildResult({
    required String userId,
    required DateTime date,
    required int mealCount,
    required bool manuallyValidated,
    required Macros consumed,
    required Macros? target,
    required DailyNutritionTargetSource targetSource,
    required MacroCalculationStatus? macroStatus,
    required DailyNutritionDayStatus dayStatus,
    NutritionVariance? variance,
    DailyNutritionAchievement? achievement,
    DailyNutritionGoalStatuses? goalStatuses,
  }) => DailyNutritionResult(
    userId: userId,
    date: date,
    mealCount: mealCount,
    isManuallyValidated: manuallyValidated,
    consumed: consumed,
    target: target,
    targetSource: targetSource,
    macroStatus: macroStatus,
    dayStatus: dayStatus,
    variance: variance,
    achievement: achievement,
    goalStatuses: goalStatuses,
  );

  void _validateUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('L’identifiant utilisateur ne peut pas être vide.');
    }
  }

  void _validateMeal(DailyMeal meal) {
    if (meal.id.trim().isEmpty) {
      throw DailyNutritionException(
        DailyNutritionErrorCode.invalidMeal,
        meal.id,
      );
    }
    final itemIds = <String>{};
    for (final item in meal.items) {
      if (item.id.trim().isEmpty || !itemIds.add(item.id)) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.invalidMealItem,
          item.id,
        );
      }
      if (item.food.id.trim().isEmpty ||
          !item.quantity.isFinite ||
          item.quantity <= 0) {
        throw DailyNutritionException(
          DailyNutritionErrorCode.invalidMealItem,
          item.id,
        );
      }
      validateNutritionMacros(item.food.macros, item.food.id);
      validateNutritionMacros(item.macros, item.id);
    }
  }
}
