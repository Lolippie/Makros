enum NutritionComparison { below, reached, exceeded, unknown }

class SecondaryNutrients {
  final double? fiber;
  final double? sugars;
  final double? freeSugars;
  final double? saturatedFat;
  final double? transFat;
  final double? salt;
  final double? potassium; // mg

  const SecondaryNutrients({
    this.fiber,
    this.sugars,
    this.freeSugars,
    this.saturatedFat,
    this.transFat,
    this.salt,
    this.potassium,
  });
}
