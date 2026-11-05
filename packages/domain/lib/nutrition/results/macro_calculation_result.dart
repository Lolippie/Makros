import 'package:makros_models/models.dart';

enum MacroCalculationStatus { valid, warning, invalid }

enum MacroCalculationIssue {
  insufficientCalories,
  lowCarbohydrates,
  lowFat,
  lowProtein,
}

class MacroCalculationResult {
  final Macros? macros;
  final double proteinPerKg;
  final double fatPerKg;

  final MacroCalculationStatus status;
  final List<MacroCalculationIssue> issues;

  const MacroCalculationResult({
    required this.macros,
    required this.proteinPerKg,
    required this.fatPerKg,
    required this.status,
    required this.issues,
  });

  bool get isValid => status != MacroCalculationStatus.invalid;
  bool get hasWarnings => status == MacroCalculationStatus.warning;
}
