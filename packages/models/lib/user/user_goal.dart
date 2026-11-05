enum GoalType { cut, bulk, maintenance }

class UserGoal {
  final String id;
  final String userId;

  final GoalType type;

  final double? targetWeight;
  final double? targetBodyFatPercentage;

  /// Indique si l'objectif de poids a déjà été atteint.
  final bool targetWeightAchieved;

  /// Indique si l'objectif de masse grasse a déjà été atteint.
  final bool targetBodyFatPercentageAchieved;

  final DateTime startDate;
  final DateTime? endDate;

  final double? calorieAdjustmentPercentage;

  const UserGoal({
    required this.id,
    required this.userId,
    required this.type,
    this.targetWeight,
    this.targetBodyFatPercentage,
    this.targetWeightAchieved = false,
    this.targetBodyFatPercentageAchieved = false,
    required this.startDate,
    this.endDate,
    this.calorieAdjustmentPercentage,
  });

  /// Vérifie la cohérence des données métier.
  void validate() {
    if (id.trim().isEmpty || userId.trim().isEmpty) {
      throw ArgumentError('id et userId ne doivent pas être vides');
    }

    if (targetWeight != null &&
        (!targetWeight!.isFinite || targetWeight! <= 0)) {
      throw ArgumentError.value(
        targetWeight,
        'targetWeight',
        'doit être strictement positif et fini',
      );
    }

    if (targetBodyFatPercentage != null &&
        (!targetBodyFatPercentage!.isFinite ||
            targetBodyFatPercentage! <= 0 ||
            targetBodyFatPercentage! >= 100)) {
      throw ArgumentError.value(
        targetBodyFatPercentage,
        'targetBodyFatPercentage',
        'doit être compris strictement entre 0 et 100',
      );
    }

    if (calorieAdjustmentPercentage != null &&
        !calorieAdjustmentPercentage!.isFinite) {
      throw ArgumentError.value(
        calorieAdjustmentPercentage,
        'calorieAdjustmentPercentage',
        'doit être fini',
      );
    }

    if (endDate != null) {
      final start = DateTime.utc(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      final end = DateTime.utc(endDate!.year, endDate!.month, endDate!.day);

      if (end.isBefore(start)) {
        throw ArgumentError.value(
          endDate,
          'endDate',
          'ne peut pas précéder startDate',
        );
      }
    }
  }

  /// Enregistre une atteinte historique sans réinitialiser
  /// un objectif déjà marqué atteint.
  UserGoal markAchieved({bool weight = false, bool bodyFat = false}) {
    return copyWith(
      targetWeightAchieved: targetWeightAchieved || weight,
      targetBodyFatPercentageAchieved:
          targetBodyFatPercentageAchieved || bodyFat,
    );
  }

  /// Copie le modèle.
  ///
  /// Les champs nullable utilisent un marqueur pour permettre
  /// leur remise explicite à null.
  UserGoal copyWith({
    String? id,
    String? userId,
    GoalType? type,
    Object? targetWeight = _unchanged,
    Object? targetBodyFatPercentage = _unchanged,
    bool? targetWeightAchieved,
    bool? targetBodyFatPercentageAchieved,
    DateTime? startDate,
    Object? endDate = _unchanged,
    Object? calorieAdjustmentPercentage = _unchanged,
  }) {
    return UserGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      targetWeight: identical(targetWeight, _unchanged)
          ? this.targetWeight
          : targetWeight as double?,
      targetBodyFatPercentage: identical(targetBodyFatPercentage, _unchanged)
          ? this.targetBodyFatPercentage
          : targetBodyFatPercentage as double?,
      targetWeightAchieved: targetWeightAchieved ?? this.targetWeightAchieved,
      targetBodyFatPercentageAchieved:
          targetBodyFatPercentageAchieved ??
          this.targetBodyFatPercentageAchieved,
      startDate: startDate ?? this.startDate,
      endDate: identical(endDate, _unchanged)
          ? this.endDate
          : endDate as DateTime?,
      calorieAdjustmentPercentage:
          identical(calorieAdjustmentPercentage, _unchanged)
          ? this.calorieAdjustmentPercentage
          : calorieAdjustmentPercentage as double?,
    );
  }

  static const Object _unchanged = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserGoal &&
          other.id == id &&
          other.userId == userId &&
          other.type == type &&
          other.targetWeight == targetWeight &&
          other.targetBodyFatPercentage == targetBodyFatPercentage &&
          other.targetWeightAchieved == targetWeightAchieved &&
          other.targetBodyFatPercentageAchieved ==
              targetBodyFatPercentageAchieved &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.calorieAdjustmentPercentage == calorieAdjustmentPercentage;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    type,
    targetWeight,
    targetBodyFatPercentage,
    targetWeightAchieved,
    targetBodyFatPercentageAchieved,
    startDate,
    endDate,
    calorieAdjustmentPercentage,
  );

  @override
  String toString() =>
      'UserGoal('
      'id: $id, '
      'userId: $userId, '
      'type: $type, '
      'targetWeight: $targetWeight, '
      'targetBodyFatPercentage: $targetBodyFatPercentage, '
      'targetWeightAchieved: $targetWeightAchieved, '
      'targetBodyFatPercentageAchieved: '
      '$targetBodyFatPercentageAchieved, '
      'startDate: $startDate, '
      'endDate: $endDate, '
      'calorieAdjustmentPercentage: '
      '$calorieAdjustmentPercentage'
      ')';
}
