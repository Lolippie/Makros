class SecondaryNutritionConfig {
  // Fibres : objectif journalier en grammes.
  final double fiberGrams;

  // Sucres libres : maximum en proportion des calories.
  final double maxFreeSugarsEnergyFraction;

  // Acides gras saturés : maximum en proportion des calories.
  final double maxSaturatedFatEnergyFraction;

  // Acides gras trans : maximum en proportion des calories.
  final double maxTransFatEnergyFraction;

  // Sel : maximum journalier en grammes.
  final double maxSaltGrams;

  // Potassium : repère journalier en milligrammes.
  final double potassiumMilligrams;

  const SecondaryNutritionConfig({
    this.fiberGrams = 30.0,
    this.maxFreeSugarsEnergyFraction = 0.10,
    this.maxSaturatedFatEnergyFraction = 0.10,
    this.maxTransFatEnergyFraction = 0.01,
    this.maxSaltGrams = 5.0,
    this.potassiumMilligrams = 3510.0,
  });
}