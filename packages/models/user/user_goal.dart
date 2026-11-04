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

  final DateTime startDate;
  final DateTime? endDate;

  const UserGoal({
    required this.id,
    required this.userId,
    required this.type,
    this.targetWeight,
    this.targetBodyFatPercentage,
    required this.startDate,
    this.endDate,
  });
}