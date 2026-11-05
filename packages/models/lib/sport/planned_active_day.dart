
import '../alimentation/macros.dart';
import 'sport_type.dart';

enum ActivityIntensity { low, moderate, high }

class PlannedActiveDay {
  final String id;
  final String weekPlanId;

  final DateTime date;
  final bool hasActivity;

  final SportType? sportType;
  final ActivityIntensity? intensity;

  final String? activityName;
  final int? plannedDurationMinutes;

  final Macros? targetMacros;

  final String? notes;

  const PlannedActiveDay({
    required this.id,
    required this.weekPlanId,
    required this.date,
    required this.hasActivity,
    this.sportType,
    this.intensity,
    this.activityName,
    this.plannedDurationMinutes,
    this.targetMacros,
    this.notes,
  });
}
