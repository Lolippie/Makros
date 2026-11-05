import 'dart:math';

import 'package:makros_models/models.dart';

import 'config/nutrition_planning_config.dart';
import 'macro_calculator_service.dart';
import 'results/nutrition_planning_result.dart';

class NutritionPlanningService {
  final NutritionPlanningConfig config;
  final MacroCalculatorService macroCalculator;

  const NutritionPlanningService({
    this.config = const NutritionPlanningConfig(),
    this.macroCalculator = const MacroCalculatorService(),
  });

  /// Calcule le score d'activité d'une journée.
  ///
  /// Ce score sert uniquement à répartir les calories.
  /// Il ne représente pas une estimation de dépense énergétique.
  double calculateActivityScore({required PlannedActiveDay day}) {
    _validateConfig();
    return _calculateActivityScore(day);
  }

  /// Calcule un planning nutritionnel sur sept jours consécutifs.
  ///
  /// Les calories de référence peuvent varier selon la journée,
  /// notamment lorsqu'une transition nutritionnelle est en cours.
  ///
  /// Garanties :
  /// - budget calorique hebdomadaire conservé, à la précision
  ///   des nombres flottants près ;
  /// - plafonds journaliers respectés ;
  /// - redistribution proportionnelle aux différences d'activité ;
  /// - redistribution limitée par la faisabilité des macros ;
  /// - aucune modification des journées enregistrées.
  NutritionPlanningResult calculateWeeklyPlan({
    required List<PlannedActiveDay> days,
    required Map<DateTime, double> referenceCaloriesByDate,
    required double weightKg,
    required GoalType goalType,
  }) {
    _validateConfig();
    _validatePositive(weightKg, 'Le poids');

    if (days.length != 7) {
      throw ArgumentError(
        'Le planning doit contenir exactement sept journées.',
      );
    }

    // --------------------------------------------------
    // 1. Normalisation et tri des dates
    // --------------------------------------------------

    final sortedDays = [
      ...days,
    ]..sort((a, b) => _normalizeDate(a.date).compareTo(_normalizeDate(b.date)));

    final normalizedReferences = <DateTime, double>{};

    for (final entry in referenceCaloriesByDate.entries) {
      final date = _normalizeDate(entry.key);

      if (normalizedReferences.containsKey(date)) {
        throw ArgumentError('Plusieurs références existent pour la même date.');
      }

      _validatePositive(entry.value, 'Les calories de référence');
      normalizedReferences[date] = entry.value;
    }

    // --------------------------------------------------
    // 2. Préparation des données journalières
    // --------------------------------------------------

    final dates = <DateTime>[];
    final references = <double>[];
    final scores = <double>[];
    final limits = <double>[];

    for (var i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final date = _normalizeDate(day.date);

      if (i > 0 && date.difference(dates.last).inDays != 1) {
        throw ArgumentError(
          'Les sept journées doivent être consécutives et uniques.',
        );
      }

      final referenceCalories = normalizedReferences[date];

      if (referenceCalories == null) {
        throw ArgumentError('Calories de référence manquantes pour $date.');
      }

      dates.add(date);
      references.add(referenceCalories);
      scores.add(_calculateActivityScore(day));

      limits.add(
        min(
          referenceCalories * config.maxDailyVariationFraction,
          config.maxDailyVariationCalories,
        ),
      );
    }

    // --------------------------------------------------
    // 3. Calcul des scores centrés
    // --------------------------------------------------

    final averageScore = scores.reduce((a, b) => a + b) / scores.length;

    final centeredScores = scores.map((score) => score - averageScore).toList();

    // --------------------------------------------------
    // 4. Minimum calorique compatible avec les macros
    // --------------------------------------------------

    final minimumCalories = macroCalculator.calculateMinimumCalories(
      weightKg: weightKg,
      goalType: goalType,
    );

    // --------------------------------------------------
    // 5. Calcul du coefficient maximal autorisé
    // --------------------------------------------------

    double maxScale = config.caloriesPerActivityScorePoint;

    for (var i = 0; i < centeredScores.length; i++) {
      final centeredScore = centeredScores[i];

      // Seuls les scores exactement nuls ne produisent
      // aucune variation et peuvent être ignorés.
      if (centeredScore == 0.0) {
        continue;
      }

      // Limite de variation journalière.
      final allowedScale = limits[i] / centeredScore.abs();

      maxScale = min(maxScale, allowedScale);

      // Les journées moins actives perdent des calories.
      // On empêche cette perte de rendre les protéines
      // et les lipides mathématiquement impossibles.
      if (centeredScore < 0) {
        final availableCalories = references[i] - minimumCalories;

        if (availableCalories <= 0) {
          maxScale = 0.0;
        } else {
          final macroScale = availableCalories / centeredScore.abs();

          maxScale = min(maxScale, macroScale);
        }
      }
    }

    // --------------------------------------------------
    // 6. Calcul des calories et des macros
    // --------------------------------------------------

    final results = <PlannedNutritionDayResult>[];

    for (var i = 0; i < sortedDays.length; i++) {
      final adjustment = centeredScores[i] * maxScale;
      final plannedCalories = references[i] + adjustment;

      final macroResult = macroCalculator.calculate(
        weightKg: weightKg,
        targetCalories: plannedCalories,
        goalType: goalType,
      );

      results.add(
        PlannedNutritionDayResult(
          date: dates[i],
          referenceCalories: references[i],
          plannedCalories: plannedCalories,
          activityScore: scores[i],
          targetMacros: macroResult.macros,
          macroStatus: macroResult.status,
          macroIssues: List.unmodifiable(macroResult.issues),
        ),
      );
    }

    return NutritionPlanningResult(days: List.unmodifiable(results));
  }

  // --------------------------------------------------
  // Calcul du score d'activité
  // --------------------------------------------------

  double _calculateActivityScore(PlannedActiveDay day) {
    if (!day.hasActivity) {
      return 0.0;
    }

    final durationMinutes =
        day.plannedDurationMinutes ?? config.defaultActivityDurationMinutes;

    if (durationMinutes <= 0) {
      throw ArgumentError('La durée prévue doit être strictement positive.');
    }

    final sportWeight = _getSportWeight(day.sportType);

    final score =
        sportWeight * durationMinutes / config.referenceDurationMinutes;

    if (!score.isFinite) {
      throw ArgumentError('Le score d’activité calculé est invalide.');
    }

    return min(score, config.maxActivityScore);
  }

  double _getSportWeight(SportType? sportType) {
    switch (sportType) {
      case SportType.gym:
        return config.gymWeight;

      case SportType.running:
        return config.runningWeight;

      case SportType.walking:
        return config.walkingWeight;

      case SportType.cycling:
        return config.cyclingWeight;

      case SportType.swimming:
        return config.swimmingWeight;

      case SportType.cardio:
        return config.cardioWeight;

      case SportType.other:
      case null:
        return config.otherWeight;
    }
  }

  // --------------------------------------------------
  // Dates
  // --------------------------------------------------

  /// Normalise une date en conservant son jour calendaire.
  ///
  /// UTC sert ici uniquement à comparer les dates
  /// sans subir les changements d'heure.
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  // --------------------------------------------------
  // Validations
  // --------------------------------------------------

  void _validatePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('$label doit être une valeur positive et finie.');
    }
  }

  void _validateConfig() {
    if (!config.maxDailyVariationFraction.isFinite ||
        config.maxDailyVariationFraction < 0 ||
        !config.maxDailyVariationCalories.isFinite ||
        config.maxDailyVariationCalories < 0 ||
        !config.maxActivityScore.isFinite ||
        config.maxActivityScore <= 0 ||
        !config.referenceDurationMinutes.isFinite ||
        config.referenceDurationMinutes <= 0 ||
        config.defaultActivityDurationMinutes <= 0 ||
        !config.caloriesPerActivityScorePoint.isFinite ||
        config.caloriesPerActivityScorePoint < 0) {
      throw ArgumentError(
        'La configuration du planning nutritionnel est invalide.',
      );
    }

    final weights = [
      config.gymWeight,
      config.runningWeight,
      config.walkingWeight,
      config.cyclingWeight,
      config.swimmingWeight,
      config.cardioWeight,
      config.otherWeight,
    ];

    if (weights.any((weight) => !weight.isFinite || weight < 0)) {
      throw ArgumentError(
        'Les coefficients sportifs doivent être positifs ou nuls.',
      );
    }
  }
}
