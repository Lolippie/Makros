import '../common/field_update.dart';
import '../common/measurement_method_normalizer.dart';
import 'user_goal_validation.dart';

enum GoalType { cut, bulk, maintenance }

/// Objectif et ses atteintes historiques.
///
/// `type`, `startDate`, `id` et `userId` ne sont pas modifiables via copyWith.
/// Un changement de stratégie ou de date de début crée un nouvel objectif.
/// Les dates sont interprétées comme jours civils de l'utilisateur :
/// le code appelant doit fournir `asOf` dans cette même convention.
class UserGoal {
  final String id;
  final String userId;
  final GoalType type;
  final double? targetWeight;
  final double? targetBodyFatPercentage;

  /// Valeur éventuellement brute si construite directement depuis la base.
  /// Les comparaisons passent par normalizeMeasurementMethod.
  final String? targetBodyFatMeasurementMethod;
  final bool targetWeightAchieved;
  final bool targetBodyFatPercentageAchieved;
  final DateTime? targetWeightAchievedAt;
  final DateTime? targetBodyFatPercentageAchievedAt;
  final DateTime startDate;
  final DateTime? endDate;
  final double? calorieAdjustmentPercentage;

  const UserGoal({
    required this.id,
    required this.userId,
    required this.type,
    this.targetWeight,
    this.targetBodyFatPercentage,
    this.targetBodyFatMeasurementMethod,
    this.targetWeightAchieved = false,
    this.targetBodyFatPercentageAchieved = false,
    this.targetWeightAchievedAt,
    this.targetBodyFatPercentageAchievedAt,
    required this.startDate,
    this.endDate,
    this.calorieAdjustmentPercentage,
  });

  static DateTime _civilDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  bool _withinPeriod(DateTime value) {
    final day = _civilDay(value);
    return !day.isBefore(_civilDay(startDate)) &&
        (endDate == null || !day.isAfter(_civilDay(endDate!)));
  }

  /// Diagnostic sans exception pour les anciennes lignes de base.
  List<UserGoalValidationIssue> get validationIssues {
    final issues = <UserGoalValidationIssue>[];
    if (id.trim().isEmpty) issues.add(UserGoalValidationIssue.emptyId);
    if (userId.trim().isEmpty) issues.add(UserGoalValidationIssue.emptyUserId);
    if (targetWeight != null &&
        (!targetWeight!.isFinite || targetWeight! <= 0)) {
      issues.add(UserGoalValidationIssue.invalidTargetWeight);
    }
    if (targetBodyFatPercentage != null &&
        (!targetBodyFatPercentage!.isFinite ||
            targetBodyFatPercentage! <= 0 ||
            targetBodyFatPercentage! >= 100)) {
      issues.add(UserGoalValidationIssue.invalidTargetBodyFat);
    }
    if (calorieAdjustmentPercentage != null &&
        !calorieAdjustmentPercentage!.isFinite) {
      issues.add(UserGoalValidationIssue.invalidCalorieAdjustment);
    }
    if (targetBodyFatMeasurementMethod != null &&
        normalizeMeasurementMethod(targetBodyFatMeasurementMethod) == null) {
      issues.add(UserGoalValidationIssue.emptyMeasurementMethod);
    }
    if (targetBodyFatPercentage == null &&
        targetBodyFatMeasurementMethod != null) {
      issues.add(UserGoalValidationIssue.methodWithoutBodyFatTarget);
    }
    if (targetWeightAchieved && targetWeight == null) {
      issues.add(UserGoalValidationIssue.weightAchievedWithoutTarget);
    }
    if (targetBodyFatPercentageAchieved && targetBodyFatPercentage == null) {
      issues.add(UserGoalValidationIssue.bodyFatAchievedWithoutTarget);
    }
    if (!targetWeightAchieved && targetWeightAchievedAt != null) {
      issues.add(UserGoalValidationIssue.weightDateWithoutAchievement);
    }
    if (!targetBodyFatPercentageAchieved &&
        targetBodyFatPercentageAchievedAt != null) {
      issues.add(UserGoalValidationIssue.bodyFatDateWithoutAchievement);
    }
    if (endDate != null && _civilDay(endDate!).isBefore(_civilDay(startDate))) {
      issues.add(UserGoalValidationIssue.endBeforeStart);
    }
    if (targetWeightAchievedAt != null &&
        !_withinPeriod(targetWeightAchievedAt!)) {
      issues.add(UserGoalValidationIssue.weightAchievementOutsidePeriod);
    }
    if (targetBodyFatPercentageAchievedAt != null &&
        !_withinPeriod(targetBodyFatPercentageAchievedAt!)) {
      issues.add(UserGoalValidationIssue.bodyFatAchievementOutsidePeriod);
    }
    return List.unmodifiable(issues);
  }

  bool get isValid => validationIssues.isEmpty;

  void validate() {
    final issues = validationIssues;
    if (issues.isNotEmpty) throw UserGoalValidationException(issues);
  }

  /// Enregistre une atteinte irréversible et idempotente.
  ///
  /// `achievedAt` DOIT être le jour civil `asOf` de l'analyse, pas
  /// DateTime.now(). Le service d'orchestration décide pour la maintenance.
  UserGoal markAchieved({
    bool weight = false,
    bool bodyFat = false,
    required DateTime achievedAt,
  }) {
    validate();
    final markWeight = weight && !targetWeightAchieved;
    final markBodyFat = bodyFat && !targetBodyFatPercentageAchieved;
    if (!markWeight && !markBodyFat) return this;
    if (markWeight && targetWeight == null) {
      throw StateError('Impossible de marquer un poids cible absent.');
    }
    if (markBodyFat && targetBodyFatPercentage == null) {
      throw StateError('Impossible de marquer une masse grasse cible absente.');
    }
    final achievementDay = _civilDay(achievedAt);
    if (!_withinPeriod(achievementDay)) {
      throw ArgumentError.value(
        achievedAt,
        'achievedAt',
        'le jour de constatation doit appartenir à la période de l’objectif',
      );
    }
    final result = copyWith(
      targetWeightAchieved: targetWeightAchieved || markWeight,
      targetBodyFatPercentageAchieved:
          targetBodyFatPercentageAchieved || markBodyFat,
      targetWeightAchievedAt: markWeight
          ? SetField<DateTime?>(achievementDay)
          : const KeepField<DateTime?>(),
      targetBodyFatPercentageAchievedAt: markBodyFat
          ? SetField<DateTime?>(achievementDay)
          : const KeepField<DateTime?>(),
    );
    result.validate();
    return result;
  }

  /// Change les cibles. Valide seulement le résultat afin de pouvoir réparer
  /// une cible historiquement invalide.
  ///
  /// Toute vraie modification réinitialise l'atteinte correspondante.
  /// La suppression de la cible de masse grasse supprime aussi sa méthode.
  /// Pour conserver l'ancien historique, clôturer et créer un nouvel objectif.
  UserGoal withUpdatedTargets({
    FieldUpdate<double?> targetWeight = const KeepField<double?>(),
    FieldUpdate<double?> targetBodyFatPercentage = const KeepField<double?>(),
    FieldUpdate<String?> targetBodyFatMeasurementMethod =
        const KeepField<String?>(),
  }) {
    final newWeight = switch (targetWeight) {
      KeepField<double?>() => this.targetWeight,
      SetField<double?>(:final value) => value,
    };
    final newBodyFat = switch (targetBodyFatPercentage) {
      KeepField<double?>() => this.targetBodyFatPercentage,
      SetField<double?>(:final value) => value,
    };
    final requestedMethod = switch (targetBodyFatMeasurementMethod) {
      KeepField<String?>() => this.targetBodyFatMeasurementMethod,
      SetField<String?>(:final value) => value,
    };
    // Ne pas masquer une saisie blanche sous la valeur null.
    if (targetBodyFatMeasurementMethod is SetField<String?> &&
        newBodyFat != null &&
        requestedMethod != null &&
        normalizeMeasurementMethod(requestedMethod) == null) {
      throw ArgumentError.value(
        requestedMethod,
        'targetBodyFatMeasurementMethod',
        'ne doit pas être vide',
      );
    }
    if (targetBodyFatMeasurementMethod is SetField<String?> &&
        newBodyFat == null &&
        requestedMethod != null) {
      throw ArgumentError.value(
        requestedMethod,
        'targetBodyFatMeasurementMethod',
        'impossible de définir une méthode sans cible de masse grasse',
      );
    }
    final newMethod = newBodyFat == null
        ? null
        : normalizeMeasurementMethod(requestedMethod);
    final weightChanged = newWeight != this.targetWeight;
    final bodyFatChanged =
        newBodyFat != this.targetBodyFatPercentage ||
        newMethod !=
            normalizeMeasurementMethod(this.targetBodyFatMeasurementMethod);

    final result = copyWith(
      targetWeight: SetField<double?>(newWeight),
      targetBodyFatPercentage: SetField<double?>(newBodyFat),
      targetBodyFatMeasurementMethod:
          targetBodyFatMeasurementMethod is KeepField<String?> &&
              newBodyFat != null
          ? const KeepField<String?>()
          : SetField<String?>(newMethod),
      targetWeightAchieved: weightChanged ? false : targetWeightAchieved,
      targetBodyFatPercentageAchieved: bodyFatChanged
          ? false
          : targetBodyFatPercentageAchieved,
      targetWeightAchievedAt: weightChanged
          ? const SetField<DateTime?>(null)
          : const KeepField<DateTime?>(),
      targetBodyFatPercentageAchievedAt: bodyFatChanged
          ? const SetField<DateTime?>(null)
          : const KeepField<DateTime?>(),
    );
    result.validate();
    return result;
  }

  /// Répare les anomalies historiques sans effacer une atteinte réelle
  /// lorsqu'une date seule est incohérente.
  ///
  /// - Atteinte sans cible : efface le booléen et la date.
  /// - Date hors période : conserve le booléen et efface la date.
  /// - Date sans atteinte : efface uniquement la date.
  ///
  /// Valide le résultat : une anomalie bloquante indépendante (par exemple
  /// une cible invalide ou endBeforeStart) doit être réparée séparément.
  UserGoal repairHistory() {
    final issues = validationIssues.toSet();
    final clearWeightAchievement = issues.contains(
      UserGoalValidationIssue.weightAchievedWithoutTarget,
    );
    final clearBodyFatAchievement = issues.contains(
      UserGoalValidationIssue.bodyFatAchievedWithoutTarget,
    );
    final clearWeightDate =
        clearWeightAchievement ||
        issues.contains(UserGoalValidationIssue.weightDateWithoutAchievement) ||
        issues.contains(UserGoalValidationIssue.weightAchievementOutsidePeriod);
    final clearBodyFatDate =
        clearBodyFatAchievement ||
        issues.contains(
          UserGoalValidationIssue.bodyFatDateWithoutAchievement,
        ) ||
        issues.contains(
          UserGoalValidationIssue.bodyFatAchievementOutsidePeriod,
        );
    final result = copyWith(
      targetWeightAchieved: clearWeightAchievement
          ? false
          : targetWeightAchieved,
      targetBodyFatPercentageAchieved: clearBodyFatAchievement
          ? false
          : targetBodyFatPercentageAchieved,
      targetWeightAchievedAt: clearWeightDate
          ? const SetField<DateTime?>(null)
          : const KeepField<DateTime?>(),
      targetBodyFatPercentageAchievedAt: clearBodyFatDate
          ? const SetField<DateTime?>(null)
          : const KeepField<DateTime?>(),
    );
    result.validate();
    return result;
  }

  /// Clôture une fois seulement. Une prolongation/réouverture doit être une
  /// opération métier distincte et explicite.
  UserGoal close({required DateTime endDate}) {
    if (this.endDate != null) {
      throw StateError('Cet objectif est déjà clôturé.');
    }
    final result = copyWith(endDate: SetField<DateTime?>(_civilDay(endDate)));
    result.validate();
    return result;
  }

  /// Copie technique, sans validation automatique.
  /// Les changements de stratégie et d'identité nécessitent un nouvel objet.
  UserGoal copyWith({
    FieldUpdate<double?> targetWeight = const KeepField<double?>(),
    FieldUpdate<double?> targetBodyFatPercentage = const KeepField<double?>(),
    FieldUpdate<String?> targetBodyFatMeasurementMethod =
        const KeepField<String?>(),
    bool? targetWeightAchieved,
    bool? targetBodyFatPercentageAchieved,
    FieldUpdate<DateTime?> targetWeightAchievedAt =
        const KeepField<DateTime?>(),
    FieldUpdate<DateTime?> targetBodyFatPercentageAchievedAt =
        const KeepField<DateTime?>(),
    FieldUpdate<DateTime?> endDate = const KeepField<DateTime?>(),
    FieldUpdate<double?> calorieAdjustmentPercentage =
        const KeepField<double?>(),
  }) {
    final requestedMethod = switch (targetBodyFatMeasurementMethod) {
      KeepField<String?>() => this.targetBodyFatMeasurementMethod,
      SetField<String?>(:final value) => value,
    };
    if (targetBodyFatMeasurementMethod is SetField<String?> &&
        requestedMethod != null &&
        normalizeMeasurementMethod(requestedMethod) == null) {
      throw ArgumentError.value(
        requestedMethod,
        'targetBodyFatMeasurementMethod',
        'ne doit pas être vide',
      );
    }
    return UserGoal(
      id: id,
      userId: userId,
      type: type,
      startDate: startDate,
      targetWeight: switch (targetWeight) {
        KeepField<double?>() => this.targetWeight,
        SetField<double?>(:final value) => value,
      },
      targetBodyFatPercentage: switch (targetBodyFatPercentage) {
        KeepField<double?>() => this.targetBodyFatPercentage,
        SetField<double?>(:final value) => value,
      },
      targetBodyFatMeasurementMethod:
          targetBodyFatMeasurementMethod is KeepField<String?>
          ? this.targetBodyFatMeasurementMethod
          : normalizeMeasurementMethod(requestedMethod),
      targetWeightAchieved: targetWeightAchieved ?? this.targetWeightAchieved,
      targetBodyFatPercentageAchieved:
          targetBodyFatPercentageAchieved ??
          this.targetBodyFatPercentageAchieved,
      targetWeightAchievedAt: switch (targetWeightAchievedAt) {
        KeepField<DateTime?>() => this.targetWeightAchievedAt,
        SetField<DateTime?>(:final value) => value,
      },
      targetBodyFatPercentageAchievedAt:
          switch (targetBodyFatPercentageAchievedAt) {
            KeepField<DateTime?>() => this.targetBodyFatPercentageAchievedAt,
            SetField<DateTime?>(:final value) => value,
          },
      endDate: switch (endDate) {
        KeepField<DateTime?>() => this.endDate,
        SetField<DateTime?>(:final value) => value,
      },
      calorieAdjustmentPercentage: switch (calorieAdjustmentPercentage) {
        KeepField<double?>() => this.calorieAdjustmentPercentage,
        SetField<double?>(:final value) => value,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserGoal &&
          other.id == id &&
          other.userId == userId &&
          other.type == type &&
          other.targetWeight == targetWeight &&
          other.targetBodyFatPercentage == targetBodyFatPercentage &&
          normalizeMeasurementMethod(other.targetBodyFatMeasurementMethod) ==
              normalizeMeasurementMethod(targetBodyFatMeasurementMethod) &&
          other.targetWeightAchieved == targetWeightAchieved &&
          other.targetBodyFatPercentageAchieved ==
              targetBodyFatPercentageAchieved &&
          other.targetWeightAchievedAt == targetWeightAchievedAt &&
          other.targetBodyFatPercentageAchievedAt ==
              targetBodyFatPercentageAchievedAt &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.calorieAdjustmentPercentage == calorieAdjustmentPercentage;

  @override
  int get hashCode => Object.hashAll([
    id,
    userId,
    type,
    targetWeight,
    targetBodyFatPercentage,
    normalizeMeasurementMethod(targetBodyFatMeasurementMethod),
    targetWeightAchieved,
    targetBodyFatPercentageAchieved,
    targetWeightAchievedAt,
    targetBodyFatPercentageAchievedAt,
    startDate,
    endDate,
    calorieAdjustmentPercentage,
  ]);

  @override
  String toString() =>
      'UserGoal('
      'id: $id, userId: $userId, type: $type, '
      'targetWeight: $targetWeight, '
      'targetBodyFatPercentage: $targetBodyFatPercentage, '
      'targetBodyFatMeasurementMethod: $targetBodyFatMeasurementMethod, '
      'targetWeightAchieved: $targetWeightAchieved, '
      'targetBodyFatPercentageAchieved: $targetBodyFatPercentageAchieved, '
      'targetWeightAchievedAt: $targetWeightAchievedAt, '
      'targetBodyFatPercentageAchievedAt: $targetBodyFatPercentageAchievedAt, '
      'startDate: $startDate, endDate: $endDate, '
      'calorieAdjustmentPercentage: $calorieAdjustmentPercentage)';
}
