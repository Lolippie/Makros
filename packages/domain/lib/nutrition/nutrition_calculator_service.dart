
import 'package:makros_models/models.dart';

import 'config/nutrition_calculation_config.dart';
import 'results/nutrition_calculation_result.dart';

class NutritionCalculatorService {
  const NutritionCalculatorService({
    this.config = defaultNutritionCalculationConfig,
  });

  final NutritionCalculationConfig config;

  /// Estime la dépense énergétique de repos avec Mifflin-St Jeor.
  ///
  /// referenceDate permet de recalculer un résultat historique
  /// sans utiliser systématiquement la date actuelle.
  double calculateRestingEnergyExpenditure({
    required UserProfile profile,
    required double weightKg,
    DateTime? referenceDate,
  }) {
    _validatePositive(weightKg, 'Le poids');
    _validatePositive(profile.height, 'La taille');

    final calculationDate = referenceDate ?? DateTime.now();
    final age = _calculateAge(
      birthDate: profile.birthDate,
      referenceDate: calculationDate,
    );

    if (age < 0) {
      throw ArgumentError(
        'La date de naissance ne peut pas être dans le futur.',
      );
    }

    final genderConstant = switch (profile.gender) {
      Gender.male => 5.0,
      Gender.female => -161.0,
    };

    return (10 * weightKg) +
        (6.25 * profile.height) -
        (5 * age) +
        genderConstant;
  }

  int _calculateAge({
    required DateTime birthDate,
    required DateTime referenceDate,
  }) {
    var age = referenceDate.year - birthDate.year;

    final birthdayNotReached =
        referenceDate.month < birthDate.month ||
        (referenceDate.month == birthDate.month &&
            referenceDate.day < birthDate.day);

    if (birthdayNotReached) {
      age--;
    }

    return age;
  }

  /// Estime les dépenses quotidiennes habituelles,
  /// en excluant les séances de sport planifiées.
  double calculateDailyBaselineCalories({
    required double restingEnergyExpenditureKcal,
    required ActivityLevel activityLevel,
  }) {
    _validatePositive(
      restingEnergyExpenditureKcal,
      'La dépense énergétique de repos',
    );

    final factor = config.nonExerciseActivityFactors[activityLevel];

    if (factor == null || !factor.isFinite || factor < 1) {
      throw ArgumentError(
        'Coefficient d’activité hors sport invalide pour $activityLevel.',
      );
    }

    return restingEnergyExpenditureKcal * factor;
  }

  /// Estime les calories supplémentaires dépensées pendant une séance,
  /// au-dessus de la dépense de repos.
  ///
  /// MET est une estimation : ce n'est pas une mesure individuelle.
  double calculateSessionCalories({
    required double weightKg,
    required int durationMinutes,
    required double metValue,
  }) {
    _validatePositive(weightKg, 'Le poids');

    if (durationMinutes <= 0) {
      throw ArgumentError('La durée doit être positive.');
    }

    if (!metValue.isFinite || metValue < 1) {
      throw ArgumentError(
        'La valeur MET doit être supérieure ou égale à 1.',
      );
    }

    // Calories nettes : on retire 1 MET correspondant au repos.
    return (metValue - 1) *
        1.05 *
        weightKg *
        (durationMinutes / 60);
  }

  double getMetValue({
    required SportType sportType,
    required ActivityIntensity intensity,
  }) {
    final metValue = config.sportMetValues[sportType]?[intensity];

    if (metValue == null || !metValue.isFinite || metValue < 1) {
      throw ArgumentError(
        'Valeur MET absente ou invalide pour $sportType avec $intensity.',
      );
    }

    return metValue;
  }

  /// Calcule la dépense sportive totale d'un planning hebdomadaire.
  ///
  /// plannedDays peut contenir uniquement les jours planifiés :
  /// les jours absents sont considérés comme sans séance.
  ///
  /// Les dates doivent appartenir à une même période de 7 jours
  /// et ne doivent pas être dupliquées.
  double calculateWeeklyExerciseCalories({
    required double weightKg,
    required List<PlannedActiveDay> plannedDays,
  }) {
    _validatePositive(weightKg, 'Le poids');
    _validateWeeklyDates(plannedDays);

    var totalCalories = 0.0;

    for (final day in plannedDays) {
      if (!day.hasActivity) continue;

      final sportType = day.sportType;
      final intensity = day.intensity;
      final duration = day.plannedDurationMinutes;

      if (sportType == null || intensity == null || duration == null) {
        throw ArgumentError(
          'Une journée active doit avoir un sport, une intensité '
          'et une durée.',
        );
      }

      final metValue = getMetValue(
        sportType: sportType,
        intensity: intensity,
      );

      totalCalories += calculateSessionCalories(
        weightKg: weightKg,
        durationMinutes: duration,
        metValue: metValue,
      );
    }

    return totalCalories;
  }

  void _validateWeeklyDates(List<PlannedActiveDay> plannedDays) {
    if (plannedDays.isEmpty) return;

    final dates = plannedDays.map((day) {
      return DateTime(day.date.year, day.date.month, day.date.day);
    }).toList();

    final uniqueDates = dates.toSet();

    if (uniqueDates.length != dates.length) {
      throw ArgumentError(
        'Le planning contient plusieurs entrées pour une même journée.',
      );
    }

    dates.sort();

    final firstDate = dates.first;
    final lastDate = dates.last;

    if (lastDate.difference(firstDate).inDays > 6) {
      throw ArgumentError(
        'Les journées fournies doivent appartenir à une même période '
        'de 7 jours.',
      );
    }
  }

  /// Retourne un pourcentage signé :
  /// - négatif pour un cut ;
  /// - positif pour un bulk ;
  /// - nul pour le maintien.
  double getAdjustmentPercentage(UserGoal goal) {
    final percentage = goal.calorieAdjustmentPercentage;

    switch (goal.type) {
      case GoalType.cut:
        final value =
            percentage ?? config.defaultCutDeficitPercentage;

        if (!value.isFinite || value < 0 || value >= 100) {
          throw ArgumentError(
            'Le déficit doit être compris entre 0 et 100 %.',
          );
        }

        return -value;

      case GoalType.bulk:
        final value =
            percentage ?? config.defaultBulkSurplusPercentage;

        if (!value.isFinite || value < 0) {
          throw ArgumentError(
            'Le surplus doit être positif ou nul.',
          );
        }

        return value;

      case GoalType.maintenance:
        return 0;
    }
  }

  /// Calcule une estimation du maintien et de la cible calorique moyenne.
  NutritionCalculationResult calculate({
    required UserProfile profile,
    required UserGoal goal,
    required double currentWeightKg,
    required List<PlannedActiveDay> plannedDays,
    DateTime? referenceDate,
  }) {
    if (profile.userId != goal.userId) {
      throw ArgumentError(
        'Le profil et l’objectif doivent appartenir au même utilisateur.',
      );
    }

    _validatePositive(currentWeightKg, 'Le poids actuel');

    final restingEnergy = calculateRestingEnergyExpenditure(
      profile: profile,
      weightKg: currentWeightKg,
      referenceDate: referenceDate,
    );

    final dailyBaselineCalories = calculateDailyBaselineCalories(
      restingEnergyExpenditureKcal: restingEnergy,
      activityLevel: profile.activityLevel,
    );

    final weeklyExerciseCalories = calculateWeeklyExerciseCalories(
      weightKg: currentWeightKg,
      plannedDays: plannedDays,
    );

    final averageDailyExerciseCalories =
        weeklyExerciseCalories / 7;

    final maintenanceCalories =
        dailyBaselineCalories + averageDailyExerciseCalories;

    final adjustmentPercentage = getAdjustmentPercentage(goal);

    final targetCalories = maintenanceCalories *
        (1 + adjustmentPercentage / 100);

    if (!targetCalories.isFinite || targetCalories <= 0) {
      throw StateError(
        'La cible calorique calculée est invalide.',
      );
    }

    return NutritionCalculationResult(
      restingEnergyExpenditureKcal: restingEnergy,
      dailyBaselineCaloriesKcal: dailyBaselineCalories,
      weeklyExerciseCaloriesKcal: weeklyExerciseCalories,
      averageDailyExerciseCaloriesKcal: averageDailyExerciseCalories,
      maintenanceCaloriesKcal: maintenanceCalories,
      targetCaloriesKcal: targetCalories,
      adjustmentPercentage: adjustmentPercentage,
    );
  }

  bool shouldRecalculateForWeightChange({
    required double currentWeight,
    required double referenceWeight,
    double threshold = 1.0,
  }) {
    _validatePositive(currentWeight, 'Le poids actuel');
    _validatePositive(referenceWeight, 'Le poids de référence');
    _validatePositive(threshold, 'Le seuil');

    return (currentWeight - referenceWeight).abs() >= threshold;
  }

  void _validatePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('$label doit être une valeur positive et valide.');
    }
  }
}
