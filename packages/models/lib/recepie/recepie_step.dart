class RecipeStep {
  final String id;
  final String description;
  final int? durationMinutes;
  final int order;

  const RecipeStep({
    required this.id,
    required this.description,
    this.durationMinutes,
    required this.order,
  });
}
