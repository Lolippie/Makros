import 'package:makros_models/models.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1);
  final asOf = DateTime.utc(2026, 2, 1);

  UserGoal goal({
    double? weight = 65,
    double? bodyFat = 25,
    String? method = 'DEXA',
    bool weightAchieved = false,
    bool bodyFatAchieved = false,
    DateTime? weightAt,
    DateTime? bodyFatAt,
    DateTime? endDate,
  }) => UserGoal(
        id: 'g1',
        userId: 'u1',
        type: GoalType.cut,
        startDate: start,
        endDate: endDate,
        targetWeight: weight,
        targetBodyFatPercentage: bodyFat,
        targetBodyFatMeasurementMethod: method,
        targetWeightAchieved: weightAchieved,
        targetBodyFatPercentageAchieved: bodyFatAchieved,
        targetWeightAchievedAt: weightAt,
        targetBodyFatPercentageAchievedAt: bodyFatAt,
      );

  test('répare une cible historique invalide sans valider l’entrée', () {
    final legacy = goal(weight: -2);
    expect(legacy.isValid, isFalse);
    final fixed = legacy.withUpdatedTargets(
      targetWeight: const SetField<double?>(60),
    );
    expect(fixed.targetWeight, 60);
    expect(fixed.isValid, isTrue);
  });

  test('DEXA et dexa ne réinitialisent pas une atteinte', () {
    final achieved = goal(bodyFatAchieved: true, bodyFatAt: asOf);
    final updated = achieved.withUpdatedTargets(
      targetBodyFatMeasurementMethod: const SetField<String?>(' dexa '),
    );
    expect(updated.targetBodyFatPercentageAchieved, isTrue);
    expect(updated.targetBodyFatPercentageAchievedAt, asOf);
    expect(updated.targetBodyFatMeasurementMethod, 'dexa');
    expect(updated, achieved);
    expect(updated.hashCode, achieved.hashCode);
  });

  test('modification réelle efface uniquement l’atteinte correspondante', () {
    final achieved = goal(
      weightAchieved: true,
      weightAt: asOf,
      bodyFatAchieved: true,
      bodyFatAt: asOf,
    );
    final updated = achieved.withUpdatedTargets(
      targetWeight: const SetField<double?>(60),
    );
    expect(updated.targetWeightAchieved, isFalse);
    expect(updated.targetWeightAchievedAt, isNull);
    expect(updated.targetBodyFatPercentageAchieved, isTrue);
  });

  test('suppression de cible efface méthode et historique', () {
    final achieved = goal(bodyFatAchieved: true, bodyFatAt: asOf);
    final updated = achieved.withUpdatedTargets(
      targetBodyFatPercentage: const SetField<double?>(null),
    );
    expect(updated.targetBodyFatMeasurementMethod, isNull);
    expect(updated.targetBodyFatPercentageAchieved, isFalse);
    expect(updated.isValid, isTrue);
  });

  test('méthode blanche explicite refusée', () {
    expect(
      () => goal().withUpdatedTargets(
        targetBodyFatMeasurementMethod: const SetField<String?>('  '),
      ),
      throwsArgumentError,
    );
    expect(
      () => goal().copyWith(
        targetBodyFatMeasurementMethod: const SetField<String?>('  '),
      ),
      throwsArgumentError,
    );
  });

  test('marquage idempotent et date civile d’analyse', () {
    final marked = goal().markAchieved(weight: true, achievedAt: asOf);
    expect(marked.targetWeightAchievedAt, asOf);
    expect(identical(marked.markAchieved(weight: true, achievedAt: asOf), marked), isTrue);
  });

  test('clôture unique et date d’atteinte respectée', () {
    final marked = goal().markAchieved(weight: true, achievedAt: asOf);
    expect(() => marked.close(endDate: start), throwsA(isA<UserGoalValidationException>()));
    final closed = marked.close(endDate: asOf);
    expect(() => closed.close(endDate: asOf), throwsStateError);
  });

  test('exception de validation compatible ArgumentError', () {
    final legacy = goal(weight: -1);
    expect(() => legacy.validate(), throwsArgumentError);
    expect(legacy.validationIssues, contains(UserGoalValidationIssue.invalidTargetWeight));
  });

  test('anomalie historique classée sans empêcher diagnostic', () {
    final legacy = goal(weightAchieved: true, weightAt: start.subtract(const Duration(days: 1)));
    expect(legacy.validationIssues, contains(UserGoalValidationIssue.weightAchievementOutsidePeriod));
    expect(UserGoalValidationIssue.weightAchievementOutsidePeriod.isHistorical, isTrue);
  });

  test('accent NFC/NFD de base normalisé identiquement', () {
    expect(normalizeMeasurementMethod('Bioimpédance'),
        normalizeMeasurementMethod('Bioimpe\u0301dance'));
  });
  test('legacy méthode blanche inchangée : diagnostic, pas erreur de saisie', () {
    final legacy = goal(method: '  ');
    expect(
      () => legacy.withUpdatedTargets(
        targetWeight: const SetField<double?>(60.0),
      ),
      throwsA(isA<UserGoalValidationException>().having(
        (e) => e.issues,
        'issues',
        contains(UserGoalValidationIssue.emptyMeasurementMethod),
      )),
    );
    final repaired = legacy.withUpdatedTargets(
      targetBodyFatMeasurementMethod:
          const SetField<String?>('bioimpedance'),
    );
    expect(repaired.isValid, isTrue);
    expect(legacy.withUpdatedTargets(
      targetBodyFatPercentage: const SetField<double?>(null),
    ).isValid, isTrue);
  });

  test('méthode explicitement définie sans cible : refus', () {
    expect(
      () => goal(bodyFat: null, method: null).withUpdatedTargets(
        targetBodyFatMeasurementMethod: const SetField<String?>('DEXA'),
      ),
      throwsArgumentError,
    );
  });

  test('normaliseur ne produit pas de chaîne vide', () {
    expect(normalizeMeasurementMethod('\u0301'), isNull);
  });

  test('réparation explicite de l’historique incohérent', () {
    final legacy = goal(
      weightAchieved: true,
      weightAt: start.subtract(const Duration(days: 2)),
    );
    final repaired = legacy.repairHistory();
    expect(repaired.isValid, isTrue);
    expect(repaired.targetWeightAchieved, isTrue);
    expect(repaired.targetWeightAchievedAt, isNull);
  });

  test('réparation : date sans atteinte effacée', () {
    final repaired = goal(weightAt: asOf).repairHistory();
    expect(repaired.targetWeightAchieved, isFalse);
    expect(repaired.targetWeightAchievedAt, isNull);
  });

  test('réparation : atteinte sans cible effacée', () {
    final repaired = goal(
      weight: null,
      weightAchieved: true,
      weightAt: asOf,
    ).repairHistory();
    expect(repaired.targetWeightAchieved, isFalse);
    expect(repaired.targetWeightAchievedAt, isNull);
  });

  test('réparation historique ne masque pas une cible invalide', () {
    final legacy = goal(weight: -5, weightAt: asOf);
    expect(
      () => legacy.repairHistory(),
      throwsA(isA<UserGoalValidationException>()),
    );
  });

  test('chaque anomalie a une portée et une classification', () {
    for (final issue in UserGoalValidationIssue.values) {
      expect(issue.isHistorical != issue.isBlocking, isTrue);
      expect(
        issue.affectsWeight ||
            issue.affectsBodyFat ||
            issue.affectsNutritionConfig ||
            issue.affectsIdentityOrPeriod,
        isTrue,
        reason: '$issue doit avoir une portée',
      );
    }
  });

  test('marquage enregistre uniquement le jour civil', () {
    final timestamp = DateTime.utc(2026, 2, 1, 17, 42);
    final marked = goal().markAchieved(weight: true, achievedAt: timestamp);
    expect(marked.targetWeightAchievedAt, DateTime.utc(2026, 2, 1));
  });

  test('marquage sans cible de poids : erreur métier explicite', () {
    expect(
      () => goal(weight: null).markAchieved(
        weight: true,
        achievedAt: asOf,
      ),
      throwsStateError,
    );
  });

  test('ancien historique atteint sans date reste valide', () {
    final legacy = goal(weightAchieved: true, weightAt: null);
    expect(legacy.isValid, isTrue);
    expect(legacy.targetWeightAchievedAt, isNull);
  });

  test('classification des anomalies par cible', () {
    expect(UserGoalValidationIssue.invalidTargetWeight.affectsWeight, isTrue);
    expect(UserGoalValidationIssue.invalidTargetWeight.affectsBodyFat, isFalse);
    expect(UserGoalValidationIssue.invalidTargetWeight.affectsNutritionConfig, isFalse);
    expect(UserGoalValidationIssue.invalidCalorieAdjustment.affectsNutritionConfig, isTrue);
  });

}
