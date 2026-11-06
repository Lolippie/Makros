import 'package:makros_models/models.dart';

import 'config/nutrition_target_distribution_config.dart';
import 'nutrition_recommendation_service.dart';
import 'results/nutrition_target_distribution_result.dart';

/// Distribue 7 jours civils. Les caloriesForDate sont les calories moyennes
/// applicables à chaque date (transition incluse), avec la moyenne des séances
/// déjà intégrée si elles proviennent de NutritionCalculatorService.
///
/// La dépense de chaque séance remplace cette moyenne, elle ne s'y ajoute pas.
/// Une modulation high/low carb redistribue ensuite uniquement de l'énergie
/// glucidique, sans changer les totaux hebdomadaires.
class NutritionTargetDistributionService {
  const NutritionTargetDistributionService({
    this.recommendations = const NutritionRecommendationService(),
  });

  final NutritionRecommendationService recommendations;

  NutritionTargetDistributionResult distribute({
    required DateTime weekStart,
    required double weightKg,
    required NutritionGoalType goal,
    required MacroDistributionPreferences preferences,
    required List<PlannedActiveDay> plannedDays,
    required double Function(DateTime date) caloriesForDate,
    required double Function(PlannedActiveDay day) exerciseCaloriesForDay,
  }) {
    _positive(weightKg, 'weightKg');
    preferences.validate();
    final recommendation = recommendations.resolve(
      goal: goal,
      preferences: preferences,
    );
    final start = _civil(weekStart);
    if (start.weekday != DateTime.monday) {
      throw ArgumentError.value(
        weekStart,
        'weekStart',
        'Le début de semaine doit être un lundi civil.',
      );
    }
    final byDate = <DateTime, PlannedActiveDay>{};
    for (final day in plannedDays) {
      final date = _civil(day.date);
      final offset = date.difference(start).inDays;
      if (offset < 0 || offset >= 7) {
        throw ArgumentError('Activité hors de la semaine demandée.');
      }
      if (byDate.containsKey(date)) {
        throw ArgumentError('Deux entrées pour le même jour civil.');
      }
      byDate[date] = day;
    }

    final dates = List.generate(7, (i) => start.add(Duration(days: i)));
    final activity = <bool>[];
    final exercise = <double>[];
    final base = <double>[];
    for (final date in dates) {
      final day = byDate[date];
      final active = day?.hasActivity ?? false;
      activity.add(active);
      final sport = active ? exerciseCaloriesForDay(day!) : 0.0;
      _nonNegative(sport, 'exerciseCaloriesForDay');
      exercise.add(sport);
      final calories = caloriesForDate(date);
      _positive(calories, 'caloriesForDate');
      base.add(calories);
    }

    final totalExercise = _sum(exercise, 'weeklyExerciseCalories');
    final averageExercise = totalExercise / 7;
    _nonNegative(averageExercise, 'averageExercise');
    final protein = recommendation.proteinGramsPerKg * weightKg;
    final fat = recommendation.fatGramsPerKg * weightKg;
    _positive(protein, 'proteinGrams');
    _positive(fat, 'fatGrams');
    final fixedCalories = 4 * protein + 9 * fat;
    _positive(fixedCalories, 'fixedMacroCalories');

    final weeklyBudget = _sum(base, 'weeklyEnergyBudget');
    // Les variations sportives sont à somme nulle, y compris lorsque
    // la cible de transition change entre deux journées.
    final dailyEnergy = <double>[];
    final carbsEnergy = <double>[];
    final issues = <NutritionDistributionIssue>{};
    for (var i = 0; i < 7; i++) {
      final energy = base[i] + (exercise[i] - averageExercise);
      if (!energy.isFinite) {
        throw StateError('dailyEnergy : dépassement numérique.');
      }
      if (energy <= 0) {
        issues.add(NutritionDistributionIssue.insufficientCaloriesForMacros);
        dailyEnergy.add(energy);
        carbsEnergy.add(energy - fixedCalories);
        continue;
      }
      final remaining = energy - fixedCalories;
      if (!remaining.isFinite) {
        throw StateError('Dépassement numérique du budget glucidique.');
      }
      if (remaining < 0) {
        issues.add(NutritionDistributionIssue.insufficientCaloriesForMacros);
      }
      final fatShare = 9 * fat / energy;
      if (fatShare < 0.20 || fatShare > 0.35) {
        issues.add(NutritionDistributionIssue.unrealisticFatEnergyShare);
      }
      dailyEnergy.add(energy);
      carbsEnergy.add(remaining);
    }

    // Pas de macros négatives : un résultat impossible est explicitement
    // signalé, sans modification silencieuse des objectifs de l'utilisateur.
    if (issues.contains(
      NutritionDistributionIssue.insufficientCaloriesForMacros,
    )) {
      return NutritionTargetDistributionResult(
        days: const [],
        issues: issues.toList(),
        appliedRecommendation: recommendation,
        mode: preferences.mode,
        weeklyEnergyBudgetKcal: weeklyBudget,
      );
    }

    final activeCount = activity.where((value) => value).length;
    final restCount = 7 - activeCount;
    if (activeCount == 0 || restCount == 0) {
      if (preferences.carbCyclingAmplitudePercentage > 0) {
        issues.add(NutritionDistributionIssue.noCarbCyclingContrast);
      }
    }
    final minimumCarbEnergy = carbsEnergy.reduce((a, b) => a < b ? a : b);
    // La modulation de 20 % est un choix de produit, pas une recommandation
    // scientifique. La variation est centrée pour conserver le budget total.
    final activeFraction = activeCount / 7;
    // Le pourcentage porte sur la réserve glucidique minimale. Pour les jours
    // de repos, le prélèvement ne peut dépasser leur réserve propre.
    // Cela évite les glucides négatifs sans ajustement silencieux.
    final requestedTransfer =
        minimumCarbEnergy * (preferences.carbCyclingAmplitudePercentage / 100);
    _nonNegative(requestedTransfer, 'requestedCarbTransfer');
    var transfer = requestedTransfer;
    if (activeCount > 0 && restCount > 0) {
      final restCapacity = <double>[
        for (var i = 0; i < 7; i++)
          if (!activity[i]) carbsEnergy[i] / activeFraction,
      ].reduce((a, b) => a < b ? a : b);
      if (transfer > restCapacity) {
        transfer = restCapacity;
        issues.add(NutritionDistributionIssue.carbCyclingAmplitudeLimited);
      }
    } else {
      transfer = 0;
    }
    final days = <DailyNutritionTarget>[];
    for (var i = 0; i < 7; i++) {
      final delta = transfer * ((activity[i] ? 1.0 : 0.0) - activeFraction);
      if (!delta.isFinite) {
        throw StateError('Transfert glucidique : dépassement numérique.');
      }
      final adjustedCarbEnergy = carbsEnergy[i] + delta;
      if (!adjustedCarbEnergy.isFinite || adjustedCarbEnergy < 0) {
        throw StateError('Répartition glucidique numériquement invalide.');
      }
      final carbs = adjustedCarbEnergy / 4;
      final finalCalories = fixedCalories + adjustedCarbEnergy;
      _positive(finalCalories, 'finalDailyCalories');
      days.add(
        DailyNutritionTarget(
          date: dates[i],
          hasActivity: activity[i],
          exerciseCaloriesKcal: exercise[i],
          caloriesKcal: finalCalories,
          proteinGrams: protein,
          fatGrams: fat,
          carbohydrateGrams: carbs,
        ),
      );
    }
    final actualWeekly = _sum(days.map((d) => d.caloriesKcal), 'actualWeekly');
    final tolerance = 1e-10 * (weeklyBudget > 1 ? weeklyBudget : 1);
    if ((actualWeekly - weeklyBudget).abs() > tolerance) {
      throw StateError('Conservation énergétique hebdomadaire non respectée.');
    }
    return NutritionTargetDistributionResult(
      days: days,
      issues: issues.toList(),
      appliedRecommendation: recommendation,
      mode: preferences.mode,
      weeklyEnergyBudgetKcal: weeklyBudget,
    );
  }

  DateTime _civil(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  double _sum(Iterable<double> values, String label) {
    var result = 0.0;
    for (final value in values) {
      result += value;
      if (!result.isFinite) {
        throw StateError('$label : dépassement numérique.');
      }
    }
    return result;
  }

  void _positive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('$label doit être fini et strictement positif.');
    }
  }

  void _nonNegative(double value, String label) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError('$label doit être fini et positif ou nul.');
    }
  }
}
