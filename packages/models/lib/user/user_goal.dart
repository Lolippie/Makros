enum GoalType {
  cut,
  bulk,
  maintenance,
}

class UserGoal {
  final String id;
  final String userId;

  final GoalType type;

  final double? targetWeight;
  final double? targetBodyFatPercentage;

  final bool targetWeightAchieved;
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
    this.calorieAdjustmentPercentage
  });
}