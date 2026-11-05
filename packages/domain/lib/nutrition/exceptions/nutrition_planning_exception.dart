enum NutritionPlanningErrorCode {
  invalidDayCount,
  duplicateDay,
  nonConsecutiveDays,
  invalidWeekStart,
  duplicateReferenceDate,
  missingReference,
  invalidReference,
  invalidActivityDuration,
  invalidActivityScore,
  invalidMacroContract,
  numericalConstraintViolation,
}

/// Incohérence de données métier ; aucun message destiné à l'interface.
class NutritionPlanningException implements Exception {
  final NutritionPlanningErrorCode code;
  final String? context;

  const NutritionPlanningException(this.code, [this.context]);

  @override
  String toString() =>
      'NutritionPlanningException($code${context == null ? '' : ', $context'})';
}
