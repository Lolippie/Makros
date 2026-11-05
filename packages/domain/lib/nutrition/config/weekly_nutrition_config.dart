/// Règles de lecture des statistiques hebdomadaires.
/// Les journées absentes ne sont jamais remplacées par des journées à zéro.
class WeeklyNutritionConfig {
  /// Si vrai, les journées futures ne participent pas aux moyennes de
  /// consommation (elles restent visibles dans les données de la semaine).
  final bool excludeUpcomingFromConsumption;

  const WeeklyNutritionConfig({this.excludeUpcomingFromConsumption = true});
}
