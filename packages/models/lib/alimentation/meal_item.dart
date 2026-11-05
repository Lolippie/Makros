import 'food.dart';
import 'macros.dart';

class MealItem {
  final String id;
  final Food food;
  final double quantity;

  const MealItem({
    required this.id,
    required this.food,
    required this.quantity,
  });

  Macros get macros => food.macros * (quantity / 100);
}
