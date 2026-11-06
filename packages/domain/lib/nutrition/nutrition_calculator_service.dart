import 'package:makros_models/models.dart';

import 'config/nutrition_calculation_config.dart';
import 'results/nutrition_calculation_result.dart';

class NutritionCalculatorService {
  const NutritionCalculatorService({
    this.config = defaultNutritionCalculationConfig,
  });

  final NutritionCalculationConfig config;

  /// Estime la dépense énergétique de repos selon Mifflin-St Jeor.
  double calculateRestingEnergyExpenditure({
    required UserProfile profile,
    required double weightKg,
    DateTime? referenceDate,
  }) {
    _validateConfig();
    _validatePositive(weightKg, 'Le poids');
    _validatePositive(profile.height, 'La taille');

    final calculationDate = referenceDate ?? DateTime.now();
    final age = _calculateAge(
      birthDate: profile.birthDate,
      referenceDate: calculationDate,
    );
    if (age < 0 ||
        (age == 0 &&
            _calendarDay(
              profile.birthDate,
            ).isAfter(_calendarDay(calculationDate)))) {
      throw ArgumentError(
        'La date de naissance ne peut pas être dans le futur.',
      );
    }

    final genderConstant = switch (profile.gender) {
      Gender.male => 5.0,
      Gender.female => -161.0,
    };

    final result =
        (10 * weightKg) + (6.25 * profile.height) - (5 * age) + genderConstant;
    return _requireFinitePositive(result, 'La dépense énergétique de repos');
  }

  int _calculateAge({
    required DateTime birthDate,
    required DateTime referenceDate,
  }) {
    var age = referenceDate.year - birthDate.year;
    if (referenceDate.month < birthDate.month ||
        (referenceDate.month == birthDate.month &&
            referenceDate.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Dépense habituelle hors séances sportives planifiées.
  double calculateDailyBaselineCalories({
    required double restingEnergyExpenditureKcal,
    required ActivityLevel activityLevel,
  }) {
    _validateConfig();
    _validatePositive(
      restingEnergyExpenditureKcal,
      'La dépense énergétique de repos',
    );
    final factor = config.nonExerciseActivityFactors[activityLevel];
    if (factor == null) {
      throw ArgumentError('Coefficient absent pour $activityLevel.');
    }
    return _requireFinitePositive(
      restingEnergyExpenditureKcal * factor,
      'La dépense énergétique quotidienne hors sport',
    );
  }

  /// Dépense sportive nette estimée au-dessus du repos (MET - 1).
  double calculateSessionCalories({
    required double weightKg,
    required int durationMinutes,
    required double metValue,
  }) {
    _validateConfig();
    _validatePositive(weightKg, 'Le poids');
    if (durationMinutes <= 0) {
      throw ArgumentError('La durée doit être positive.');
    }
    if (!metValue.isFinite || metValue < 1) {
      throw ArgumentError('La valeur MET doit être supérieure ou égale à 1.');
    }
    final result = (metValue - 1) * 1.05 * weightKg * (durationMinutes / 60);
    return _requireFiniteNonNegative(result, 'Les calories de séance');
  }

  double getMetValue({
    required SportType sportType,
    required ActivityIntensity intensity,
  }) {
    _validateConfig();
    final metValue = config.sportMetValues[sportType]?[intensity];
    if (metValue == null) {
      throw ArgumentError('MET absent pour $sportType avec $intensity.');
    }
    return metValue;
  }

  /// Somme des dépenses des séances d'une période glissante de 7 jours.
  /// Une journée sans activité peut conserver des champs sportifs : ils sont ignorés.
  /// Le service n’impose pas que les dates soient liées à referenceDate :
  /// l’appelant choisit la période de 7 jours à analyser.
  double calculateWeeklyExerciseCalories({
    required double weightKg,
    required List<PlannedActiveDay> plannedDays,
  }) {
    _validateConfig();
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
          'Une journée active doit avoir un sport, une intensité et une durée.',
        );
      }
      final metValue = getMetValue(sportType: sportType, intensity: intensity);
      totalCalories += calculateSessionCalories(
        weightKg: weightKg,
        durationMinutes: duration,
        metValue: metValue,
      );
      _requireFiniteNonNegative(totalCalories, 'Le total sportif hebdomadaire');
    }
    return totalCalories;
  }

  void _validateWeeklyDates(List<PlannedActiveDay> plannedDays) {
    if (plannedDays.isEmpty) return;
    final dates = plannedDays.map((day) => _calendarDay(day.date)).toList();
    if (dates.toSet().length != dates.length) {
      throw ArgumentError(
        'Le planning contient plusieurs entrées pour une même journée.',
      );
    }
    dates.sort();
    if (dates.last.difference(dates.first).inDays > 6) {
      throw ArgumentError(
        'Les journées doivent appartenir à une même période de 7 jours.',
      );
    }
  }

  double getAdjustmentPercentage(UserGoal goal) {
    _validateConfig();
    final percentage = goal.calorieAdjustmentPercentage;
    switch (goal.type) {
      case GoalType.cut:
        final value = percentage ?? config.defaultCutDeficitPercentage;
        _validateAdjustment(value, config.maxCutDeficitPercentage, 'déficit');
        return -value;
      case GoalType.bulk:
        final value = percentage ?? config.defaultBulkSurplusPercentage;
        _validateAdjustment(value, config.maxBulkSurplusPercentage, 'surplus');
        return value;
      case GoalType.maintenance:
        // Un pourcentage éventuellement stocké n'est pas appliqué au maintien.
        return 0;
    }
  }

  NutritionCalculationResult calculate({
    required UserProfile profile,
    required UserGoal goal,
    required double currentWeightKg,
    required List<PlannedActiveDay> plannedDays,
    DateTime? referenceDate,
  }) {
    _validateConfig();
    if (profile.userId.trim().isEmpty || goal.userId.trim().isEmpty) {
      throw ArgumentError(
        'Les identifiants utilisateur ne peuvent pas être vides.',
      );
    }
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
    final averageDailyExerciseCalories = _requireFiniteNonNegative(
      weeklyExerciseCalories / 7,
      'La moyenne sportive quotidienne',
    );
    final maintenanceCalories = _requireFinitePositive(
      dailyBaselineCalories + averageDailyExerciseCalories,
      'Le maintien calorique',
    );
    final adjustmentPercentage = getAdjustmentPercentage(goal);
    final targetCalories = _requireFinitePositive(
      maintenanceCalories * (1 + adjustmentPercentage / 100),
      'La cible calorique',
    );

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

  void _validateConfig() => config.validate();

  void _validateAdjustment(double value, double maximum, String label) {
    if (!value.isFinite || value < 0 || value > maximum) {
      throw ArgumentError('Le $label doit être compris entre 0 et $maximum %.');
    }
  }

  static DateTime _calendarDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  void _validatePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('$label doit être une valeur positive et valide.');
    }
  }

  double _requireFinitePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw StateError('$label calculé est invalide.');
    }
    return value;
  }

  double _requireFiniteNonNegative(double value, String label) {
    if (!value.isFinite || value < 0) {
      throw StateError('$label calculé est invalide.');
    }
    return value;
  }
}
