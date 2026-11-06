enum UserGoalValidationIssue {
  emptyId,
  emptyUserId,
  invalidTargetWeight,
  invalidTargetBodyFat,
  invalidCalorieAdjustment,
  emptyMeasurementMethod,
  methodWithoutBodyFatTarget,
  weightAchievedWithoutTarget,
  bodyFatAchievedWithoutTarget,
  weightDateWithoutAchievement,
  bodyFatDateWithoutAchievement,
  endBeforeStart,
  weightAchievementOutsidePeriod,
  bodyFatAchievementOutsidePeriod,
}

/// Une anomalie historique n'empêche pas à elle seule une analyse de cible,
/// mais doit interdire un nouveau marquage tant qu'elle n'est pas réparée.
/// Une anomalie bloquante peut concerner une seule cible : l'orchestrateur
/// doit traiter poids, masse grasse et nutrition indépendamment.
extension UserGoalValidationIssueClassification on UserGoalValidationIssue {
  bool get isHistorical => switch (this) {
    UserGoalValidationIssue.weightAchievedWithoutTarget ||
    UserGoalValidationIssue.bodyFatAchievedWithoutTarget ||
    UserGoalValidationIssue.weightDateWithoutAchievement ||
    UserGoalValidationIssue.bodyFatDateWithoutAchievement ||
    UserGoalValidationIssue.weightAchievementOutsidePeriod ||
    UserGoalValidationIssue.bodyFatAchievementOutsidePeriod => true,
    UserGoalValidationIssue.emptyId ||
    UserGoalValidationIssue.emptyUserId ||
    UserGoalValidationIssue.invalidTargetWeight ||
    UserGoalValidationIssue.invalidTargetBodyFat ||
    UserGoalValidationIssue.invalidCalorieAdjustment ||
    UserGoalValidationIssue.emptyMeasurementMethod ||
    UserGoalValidationIssue.methodWithoutBodyFatTarget ||
    UserGoalValidationIssue.endBeforeStart => false,
  };

  bool get isBlocking => !isHistorical;

  bool get affectsWeight => switch (this) {
    UserGoalValidationIssue.emptyId ||
    UserGoalValidationIssue.emptyUserId ||
    UserGoalValidationIssue.endBeforeStart ||
    UserGoalValidationIssue.invalidTargetWeight ||
    UserGoalValidationIssue.weightAchievedWithoutTarget ||
    UserGoalValidationIssue.weightDateWithoutAchievement ||
    UserGoalValidationIssue.weightAchievementOutsidePeriod => true,
    UserGoalValidationIssue.invalidTargetBodyFat ||
    UserGoalValidationIssue.invalidCalorieAdjustment ||
    UserGoalValidationIssue.emptyMeasurementMethod ||
    UserGoalValidationIssue.methodWithoutBodyFatTarget ||
    UserGoalValidationIssue.bodyFatAchievedWithoutTarget ||
    UserGoalValidationIssue.bodyFatDateWithoutAchievement ||
    UserGoalValidationIssue.bodyFatAchievementOutsidePeriod => false,
  };

  bool get affectsBodyFat => switch (this) {
    UserGoalValidationIssue.emptyId ||
    UserGoalValidationIssue.emptyUserId ||
    UserGoalValidationIssue.endBeforeStart ||
    UserGoalValidationIssue.invalidTargetBodyFat ||
    UserGoalValidationIssue.emptyMeasurementMethod ||
    UserGoalValidationIssue.methodWithoutBodyFatTarget ||
    UserGoalValidationIssue.bodyFatAchievedWithoutTarget ||
    UserGoalValidationIssue.bodyFatDateWithoutAchievement ||
    UserGoalValidationIssue.bodyFatAchievementOutsidePeriod => true,
    UserGoalValidationIssue.invalidTargetWeight ||
    UserGoalValidationIssue.invalidCalorieAdjustment ||
    UserGoalValidationIssue.weightAchievedWithoutTarget ||
    UserGoalValidationIssue.weightDateWithoutAchievement ||
    UserGoalValidationIssue.weightAchievementOutsidePeriod => false,
  };

  /// Concerne uniquement la configuration calorique du UserGoal,
  /// jamais la suggestion indépendante de recalcul nutritionnel.
  bool get affectsNutritionConfig => switch (this) {
    UserGoalValidationIssue.invalidCalorieAdjustment => true,
    UserGoalValidationIssue.emptyId ||
    UserGoalValidationIssue.emptyUserId ||
    UserGoalValidationIssue.invalidTargetWeight ||
    UserGoalValidationIssue.invalidTargetBodyFat ||
    UserGoalValidationIssue.emptyMeasurementMethod ||
    UserGoalValidationIssue.methodWithoutBodyFatTarget ||
    UserGoalValidationIssue.weightAchievedWithoutTarget ||
    UserGoalValidationIssue.bodyFatAchievedWithoutTarget ||
    UserGoalValidationIssue.weightDateWithoutAchievement ||
    UserGoalValidationIssue.bodyFatDateWithoutAchievement ||
    UserGoalValidationIssue.endBeforeStart ||
    UserGoalValidationIssue.weightAchievementOutsidePeriod ||
    UserGoalValidationIssue.bodyFatAchievementOutsidePeriod => false,
  };

  bool get affectsIdentityOrPeriod => switch (this) {
    UserGoalValidationIssue.emptyId ||
    UserGoalValidationIssue.emptyUserId ||
    UserGoalValidationIssue.endBeforeStart => true,
    UserGoalValidationIssue.invalidTargetWeight ||
    UserGoalValidationIssue.invalidTargetBodyFat ||
    UserGoalValidationIssue.invalidCalorieAdjustment ||
    UserGoalValidationIssue.emptyMeasurementMethod ||
    UserGoalValidationIssue.methodWithoutBodyFatTarget ||
    UserGoalValidationIssue.weightAchievedWithoutTarget ||
    UserGoalValidationIssue.bodyFatAchievedWithoutTarget ||
    UserGoalValidationIssue.weightDateWithoutAchievement ||
    UserGoalValidationIssue.bodyFatDateWithoutAchievement ||
    UserGoalValidationIssue.weightAchievementOutsidePeriod ||
    UserGoalValidationIssue.bodyFatAchievementOutsidePeriod => false,
  };
}

/// Hérite d'ArgumentError pour rester compatible avec les anciens `on ArgumentError`.
class UserGoalValidationException extends ArgumentError {
  final List<UserGoalValidationIssue> issues;

  UserGoalValidationException(Iterable<UserGoalValidationIssue> issues)
      : issues = List.unmodifiable(issues),
        super('UserGoal invalide : ${issues.join(', ')}');

  @override
  String toString() => 'UserGoalValidationException(issues: $issues)';
}
