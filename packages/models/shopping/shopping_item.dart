import '../models.dart';

class ShoppingItem {
  final String id;
  final String shoppingListId;

  // Aliment référencé dans Makros (facultatif)
  final String? foodId;

  // Nom conservé même si foodId est renseigné
  final String name;

  // Quantité souhaitée
  final double? quantity;
  final String? unit;

  // Magasin dans lequel acheter cet article
  final String? buyingPlaceId;

  final ShoppingItemStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingItem({
    required this.id,
    required this.shoppingListId,
    this.foodId,
    required this.name,
    this.quantity,
    this.unit,
    this.buyingPlaceId,
    this.status = ShoppingItemStatus.toBuy,
    required this.createdAt,
    required this.updatedAt,
  });
}