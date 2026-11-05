/// Déclaration explicite de réussite sans aucun repas enregistré.
/// À conserver par utilisateur et par jour civil dans le stockage applicatif.
class DailyNutritionValidation {
  final String userId;
  final DateTime date;
  final bool manuallyValidated;

  const DailyNutritionValidation({
    required this.userId,
    required this.date,
    this.manuallyValidated = false,
  });
}
