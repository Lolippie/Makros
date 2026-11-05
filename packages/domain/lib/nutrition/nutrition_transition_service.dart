import 'dart:math';

import 'package:makros_models/models.dart';

import 'results/nutrition_transition_result.dart';

class NutritionTransitionService {
  const NutritionTransitionService();

  static const double _tolerance = 0.001;

  /// Calcule les calories à appliquer à une date donnée.
  ///
  /// Le résultat est déterministe :
  /// pour une même transition et une même date,
  /// le résultat sera toujours identique.
  ///
  /// À partir de la date d'annulation ou de fin, les calories sont figées
  /// à la valeur qu'elles avaient à cette date.
  double calculateCaloriesAtDate({
    required NutritionTransition transition,
    required DateTime date,
  }) {
    _validateTransition(transition);

    final endDate = _endDate(transition);
    final effectiveDate = endDate != null && !_isBeforeDate(date, endDate)
        ? endDate
        : date;

    final totalDifference =
        transition.targetCalories - transition.startingCalories;

    if (totalDifference.abs() < _tolerance) {
      return transition.targetCalories;
    }

    final elapsedDays = _calendarDaysBetween(
      transition.startDate,
      effectiveDate,
    );

    if (elapsedDays < 0) {
      return transition.startingCalories;
    }

    final completedSteps = elapsedDays ~/ transition.stepDurationDays;

    // La tolérance évite un palier de trop dû aux erreurs de flottants
    // (ex. 1.1 / 0.1 = 11.000000000000002).
    final totalSteps = max(
      1,
      ((totalDifference.abs() - _tolerance) / transition.stepCalories).ceil(),
    );

    final appliedSteps = min(completedSteps, totalSteps);
    final adjustment = appliedSteps * transition.stepCalories;

    // La dernière étape ne doit jamais dépasser la cible.
    if (totalDifference > 0) {
      return min(
        transition.startingCalories + adjustment,
        transition.targetCalories,
      );
    }

    return max(
      transition.startingCalories - adjustment,
      transition.targetCalories,
    );
  }

  /// Retourne la progression globale de la transition.
  NutritionTransitionResult calculateProgress({
    required NutritionTransition transition,
    required DateTime date,
  }) {
    _validateTransition(transition);

    final currentCalories = calculateCaloriesAtDate(
      transition: transition,
      date: date,
    );

    final totalDifference =
        (transition.targetCalories - transition.startingCalories).abs();

    final remainingDifference = (transition.targetCalories - currentCalories)
        .abs();

    final progressPercentage = totalDifference < _tolerance
        ? 100.0
        : ((totalDifference - remainingDifference) / totalDifference * 100)
              .clamp(0.0, 100.0)
              .toDouble();

    final isCompleted = remainingDifference < _tolerance;

    final effectiveStatus = _getEffectiveStatus(
      transition: transition,
      date: date,
      isCompleted: isCompleted,
    );

    final isTerminal =
        effectiveStatus == NutritionTransitionStatus.completed ||
        effectiveStatus == NutritionTransitionStatus.cancelled;

    return NutritionTransitionResult(
      currentCalories: currentCalories,
      targetCalories: transition.targetCalories,
      progressPercentage: progressPercentage,
      status: effectiveStatus,
      nextStepDate: isTerminal
          ? null
          : calculateNextStepDate(transition: transition, date: date),
      isCompleted: effectiveStatus == NutritionTransitionStatus.completed,
    );
  }

  /// Retourne la prochaine date à laquelle les calories changent.
  ///
  /// Les calories changent à startDate + n * stepDurationDays (n >= 1).
  /// Avant le début de la transition, retourne donc
  /// startDate + stepDurationDays.
  ///
  /// Retourne null si la cible est atteinte, ou si la prochaine étape
  /// tomberait après la date d'annulation ou de fin.
  DateTime? calculateNextStepDate({
    required NutritionTransition transition,
    required DateTime date,
  }) {
    _validateTransition(transition);

    final currentCalories = calculateCaloriesAtDate(
      transition: transition,
      date: date,
    );

    if ((currentCalories - transition.targetCalories).abs() < _tolerance) {
      return null;
    }

    final start = transition.startDate;
    final elapsedDays = _calendarDaysBetween(start, date);
    final completedSteps = elapsedDays < 0
        ? 0
        : elapsedDays ~/ transition.stepDurationDays;

    // Le constructeur normalise les jours : pas de décalage lié au DST.
    final nextStepDate = DateTime(
      start.year,
      start.month,
      start.day + (completedSteps + 1) * transition.stepDurationDays,
    );

    final endDate = _endDate(transition);
    if (endDate != null && _isBeforeDate(endDate, nextStepDate)) {
      return null;
    }

    return nextStepDate;
  }

  NutritionTransitionStatus _getEffectiveStatus({
    required NutritionTransition transition,
    required DateTime date,
    required bool isCompleted,
  }) {
    // L'annulation ne prend effet qu'à partir de sa date.
    if (transition.cancelledAt != null &&
        !_isBeforeDate(date, transition.cancelledAt!)) {
      return NutritionTransitionStatus.cancelled;
    }

    // Une transition terminée ne l'est qu'à partir de sa date de fin.
    if (transition.completedAt != null &&
        !_isBeforeDate(date, transition.completedAt!)) {
      return NutritionTransitionStatus.completed;
    }

    // La cible a été atteinte selon le calendrier de transition.
    if (isCompleted) {
      return NutritionTransitionStatus.completed;
    }

    if (_isBeforeDate(date, transition.startDate)) {
      return NutritionTransitionStatus.pending;
    }

    return NutritionTransitionStatus.inProgress;
  }

  /// Date à partir de laquelle la transition est figée (annulée ou terminée).
  /// Retourne null si la transition n'a pas de date de fin.
  DateTime? _endDate(NutritionTransition transition) =>
      transition.cancelledAt ?? transition.completedAt;

  void _validateTransition(NutritionTransition transition) {
    _validatePositive(transition.startingCalories, 'Les calories de départ');
    _validatePositive(transition.targetCalories, 'Les calories cibles');
    _validatePositive(transition.stepCalories, 'Les calories par étape');

    if (transition.stepDurationDays <= 0) {
      throw ArgumentError('La durée entre deux étapes doit être positive.');
    }

    if (transition.userGoalId.isEmpty) {
      throw ArgumentError(
        'La transition doit être associée à un objectif utilisateur.',
      );
    }

    // Cohérence statut / dates de fin : un statut ne peut pas porter
    // la date de fin d'un autre, ce qui garantit qu'une seule des deux
    // dates (cancelledAt, completedAt) peut être renseignée.
    if (transition.status == NutritionTransitionStatus.cancelled &&
        transition.cancelledAt == null) {
      throw ArgumentError(
        'Une transition annulée doit avoir une date d’annulation.',
      );
    }

    if (transition.status != NutritionTransitionStatus.cancelled &&
        transition.cancelledAt != null) {
      throw ArgumentError(
        'Une transition non annulée ne doit pas avoir de date d’annulation.',
      );
    }

    if (transition.status == NutritionTransitionStatus.completed &&
        transition.completedAt == null) {
      throw ArgumentError(
        'Une transition terminée doit avoir une date de fin.',
      );
    }

    if (transition.status != NutritionTransitionStatus.completed &&
        transition.completedAt != null) {
      throw ArgumentError(
        'Une transition non terminée ne doit pas avoir de date de fin.',
      );
    }

    // Annuler une transition planifiée avant son début est valide
    // (calories inchangées), mais pas la terminer avant son début.
    if (transition.completedAt != null &&
        _isBeforeDate(transition.completedAt!, transition.startDate)) {
      throw ArgumentError(
        'La date de fin ne peut pas précéder le début de la transition.',
      );
    }
  }

  /// Nombre de jours calendaires entre deux dates (end - start),
  /// indépendant des heures et du changement d'heure.
  int _calendarDaysBetween(DateTime start, DateTime end) {
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day);

    return endUtc.difference(startUtc).inDays;
  }

  /// Vrai si [first] est strictement avant [second] (jour calendaire).
  bool _isBeforeDate(DateTime first, DateTime second) =>
      _calendarDaysBetween(first, second) > 0;

  void _validatePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('$label doivent être une valeur positive et valide.');
    }
  }
}
