enum Gender {
  male,
  female,
}

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

class UserProfile {
  final String userId;

  // Informations personnelles
  final DateTime birthDate;
  final double height; // En cm
  final Gender gender;
  final ActivityLevel activityLevel;

  // Informations complémentaires
  final String? firstName;
  final String? lastName;

  // Dates
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.userId,
    required this.birthDate,
    required this.height,
    required this.gender,
    this.firstName,
    this.lastName,
    required this.createdAt,
    required this.updatedAt,
        required this.activityLevel,

  });

  // Âge calculé automatiquement
  int get age {
    final now = DateTime.now();

    int result = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month &&
            now.day < birthDate.day)) {
      result--;
    }

    return result;
  }

  // Nom complet
  String get fullName {
    return [
      firstName,
      lastName,
    ].whereType<String>().where((name) => name.isNotEmpty).join(' ');
  }
}