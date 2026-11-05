class Macros {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;

  const Macros({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    this.fiber = 0,
  });

  // Additionne deux ensembles de macros.
  Macros operator +(Macros other) {
    return Macros(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbohydrates: carbohydrates + other.carbohydrates,
      fat: fat + other.fat,
      fiber: fiber + other.fiber,
    );
  }

  // Multiplie les macros par une quantité.
  Macros operator *(double multiplier) {
    return Macros(
      calories: calories * multiplier,
      protein: protein * multiplier,
      carbohydrates: carbohydrates * multiplier,
      fat: fat * multiplier,
      fiber: fiber * multiplier,
    );
  }
}
