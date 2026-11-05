class MacroCalculationConfig {
  final double cutProteinPerKg;
  final double cutFatPerKg;
  final double carbohydrateWarningPerKg;
  final double calorieTolerance;

  final double maintenanceProteinPerKg;
  final double maintenanceFatPerKg;

  final double bulkProteinPerKg;
  final double bulkFatPerKg;

  const MacroCalculationConfig({
    this.calorieTolerance = 0.001,

    this.cutProteinPerKg = 2.0,
    this.cutFatPerKg = 0.8,
    this.carbohydrateWarningPerKg = 1.0,
    this.maintenanceProteinPerKg = 1.8,
    this.maintenanceFatPerKg = 0.9,
    this.bulkProteinPerKg = 1.8,
    this.bulkFatPerKg = 0.9,
  });
}
