
import '../recepie/recepie_step.dart';
import 'macros.dart';
import 'meal_item.dart';

class Meal {
  final String id;
  final String userId;
  final String name;
  final String? description;

  // Composition
  final List<MealItem> items;

  // Préparation (facultative)
  final List<RecipeStep> steps;

  // Nombre de portions
  final int servings;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Meal({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.items,
    this.steps = const [],
    this.servings = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  // Un repas est considéré comme une recette s'il possède des étapes.
  bool get hasPreparation => steps.isNotEmpty;

  Macros get totalMacros {
    return items.fold(
      const Macros(
        calories: 0,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
      ),
      (total, item) => total + item.macros,
    );
  }
}