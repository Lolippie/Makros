
import 'food_category.dart';
import 'macros.dart';
import 'nutritional_category.dart';

class Food {
  final String id;
  final String name;
  final String? barcode;
  final String? imageUrl;

  final Macros macros;

  final String? buyingPlaceBrandId;

  final FoodCategory? foodCategory;
  final List<NutritionalCategory>? nutritionalCategories;

  const Food({
    required this.id,
    required this.name,
    this.buyingPlaceBrandId,
    this.barcode,
    this.imageUrl,
    required this.macros,
    this.foodCategory,
    this.nutritionalCategories,
  });
}