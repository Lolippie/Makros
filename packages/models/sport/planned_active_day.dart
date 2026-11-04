import '../models.dart';

class PlannedActiveDay {
  final String id;
  final String weekPlanId;

  // Date concernée
  final DateTime date;

  // Indique si une activité est prévue
  final bool hasActivity;

  // Type d'activité (facultatif si jour de repos)
  final SportType? sportType;

  // Nom de l'activité (ex : Séance jambes)
  final String? activityName;

  // Durée prévue en minutes
  final int? plannedDurationMinutes;

  // Objectifs nutritionnels de la journée
  final Macros? targetMacros;

  final String? notes;

  const PlannedActiveDay({
    required this.id,
    required this.weekPlanId,
    required this.date,
    required this.hasActivity,
    this.sportType,
    this.activityName,
    this.plannedDurationMinutes,
    this.targetMacros,
    this.notes,
  });
}