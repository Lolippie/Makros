

import 'macros.dart';
import 'meal_item.dart';
import 'meal_type.dart';

class DailyMeal {
  final String id;
  final String userId;

  final DateTime date;
  final MealType type;

  final String? recipeId;
  final String? name;

  final List<MealItem> items;

  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyMeal({
    required this.id,
    required this.userId,
    required this.date,
    required this.type,
    this.recipeId,
    this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

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