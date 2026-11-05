import 'body_fat_history.dart';
import 'muscle_mass_history.dart';
import 'user_goal.dart';
import 'weight_history.dart';

class UserStatistics {
  final String userId;

  // Dernières mesures corporelles
  final WeightHistory? latestWeight;
  final BodyFatHistory? latestBodyFat;
  final MuscleMassHistory? latestMuscleMass;

  // Objectif actuellement actif
  final UserGoal? activeGoal;

  // Date de mise à jour des statistiques
  final DateTime updatedAt;

  const UserStatistics({
    required this.userId,
    this.latestWeight,
    this.latestBodyFat,
    this.latestMuscleMass,
    this.activeGoal,
    required this.updatedAt,
  });

  // Valeurs actuelles
  double? get currentWeight => latestWeight?.weight;

  double? get currentBodyFat => latestBodyFat?.bodyFatPercentage;

  double? get currentMuscleMass => latestMuscleMass?.muscleMassPercentage;

  // Vérification de l'existence d'un objectif
  bool get hasActiveGoal => activeGoal != null;
}
