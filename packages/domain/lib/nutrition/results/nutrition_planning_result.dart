import 'package:makros_models/models.dart';

import 'macro_calculation_result.dart';

class PlannedNutritionDayResult {
  final DateTime date;
  final double referenceCalories;
  final double plannedCalories;
  final double activityScore;

  final Macros? targetMacros;
  final MacroCalculationStatus macroStatus;
  final List<MacroCalculationIssue> macroIssues;

  const PlannedNutritionDayResult({
    required this.date,
    required this.referenceCalories,
    required this.plannedCalories,
    required this.activityScore,
    required this.targetMacros,
    required this.macroStatus,
    required this.macroIssues,
  });

  double get calorieAdjustment =>
      plannedCalories - referenceCalories;
}

class NutritionPlanningResult {
  final List<PlannedNutritionDayResult> days;

  const NutritionPlanningResult({
    required this.days,
  });

  double get totalReferenceCalories =>
      days.fold(0.0, (sum, day) => sum + day.referenceCalories);

  double get totalPlannedCalories =>
      days.fold(0.0, (sum, day) => sum + day.plannedCalories);

  double get averagePlannedCalories =>
      days.isEmpty ? 0.0 : totalPlannedCalories / days.length;

  bool get hasInvalidMacros =>
      days.any(
        (day) => day.macroStatus == MacroCalculationStatus.invalid,
      );

  bool get hasMacroWarnings =>
      days.any(
        (day) => day.macroStatus == MacroCalculationStatus.warning,
      );
}