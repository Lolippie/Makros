import '../models.dart';
import 'shopping_item.dart';

class ShoppingList {
  final String id;
  final String userId;

  final String name;
  final String? description;

  final List<ShoppingItem> items;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingList({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Nombre total d'articles
  int get totalItems => items.length;

  // Nombre d'articles achetés
  int get purchasedItems => items
      .where((item) => item.status == ShoppingItemStatus.purchased)
      .length;

  // Nombre d'articles restant à acheter
  int get remainingItems => items
      .where((item) => item.status == ShoppingItemStatus.toBuy)
      .length;

  // Progression des courses en pourcentage
  double get completionPercentage {
    if (items.isEmpty) return 0;

    return purchasedItems / items.length * 100;
  }
}