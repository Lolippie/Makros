import 'package:makros_nutrition/user/body_fat_progress_service.dart';
import 'package:test/test.dart';
import 'package:makros_models/models.dart';

// Adapter cet import si l'arborescence publique du package diffère.

BodyFatHistory m(String id, int day, double value, {
  String user = 'u1', String? method = 'impedance', int month = 10,
}) => BodyFatHistory(
  id: id, userId: user, bodyFatPercentage: value,
  measuredAt: DateTime(2026, month, day), measurementMethod: method,
);

void main() {
  const service = BodyFatProgressService();
  final asOf = DateTime(2026, 11, 6);

  test('aucune mesure : données insuffisantes', () {
    final r = service.analyze(userId: 'u1', measurements: [], asOf: asOf);
    expect(r.trendStatus, BodyFatTrendStatus.insufficientData);
    expect(r.currentTrendPercentage, isNull);
    expect(r.isTrendFresh, isFalse);
  });

  test('deux fenêtres avec tendance décroissante et fraîche', () {
    final r = service.analyze(userId: 'u1', asOf: asOf, measurements: [
      m('a', 2, 26), m('b', 8, 25, month: 10),
      m('c', 25, 24, month: 10), m('d', 5, 23, month: 11),
    ]);
    expect(r.currentTrendPercentage, closeTo(23.5, 1e-9));
    expect(r.previousTrendPercentage, closeTo(25.5, 1e-9));
    expect(r.changeBetweenWindowsPercentagePoints, closeTo(-2, 1e-9));
    expect(r.trendStatus, BodyFatTrendStatus.decreasing);
    expect(r.isTrendFresh, isTrue);
    expect(r.weeklyChangePercentagePoints, isNotNull);
  });

  test('moyenne des mesures du même jour', () {
    const cfg = BodyFatProgressConfig(
      trendWindowDays: 7, minimumMeasurementDays: 1,
      minimumMeasurementSpanDays: 0, maxDaysSinceLastMeasurement: 3,
    );
    final r = const BodyFatProgressService(config: cfg).analyze(
      userId: 'u1', asOf: asOf, measurements: [
        m('a', 5, 20, month: 11), m('b', 5, 24, month: 11),
      ],
    );
    expect(r.currentTrendPercentage, 22);
    expect(r.measurementDaysInCurrentWindow, 1);
  });

  test('filtre utilisateur, dates futures et date minimale', () {
    final r = service.analyze(userId: 'u1', asOf: asOf,
      earliestMeasurementDate: DateTime(2026, 11, 1),
      measurements: [
        m('a', 1, 20, month: 10),
        m('b', 3, 22, month: 11),
        m('c', 5, 24, month: 11),
        m('d', 5, 99, user: 'u2', month: 11),
        m('e', 7, 99, month: 11),
      ],
    );
    expect(r.currentTrendPercentage, 23);
    expect(r.previousTrendPercentage, isNull);
    expect(r.earliestMeasurementDate, DateTime.utc(2026, 11, 1));
  });

  test('méthodes différentes : sélection explicite requise', () {
    final measurements = [
      m('a', 3, 24, month: 11),
      m('b', 5, 25, method: 'caliper', month: 11),
    ];
    expect(() => service.analyze(
      userId: 'u1', asOf: asOf, measurements: measurements,
    ), throwsA(isA<BodyFatProgressException>().having(
      (e) => e.code, 'code', BodyFatProgressErrorCode.mixedMeasurementMethods,
    )));
    final r = service.analyze(
      userId: 'u1', asOf: asOf, measurements: measurements,
      measurementMethod: ' IMPEDANCE ',
    );
    expect(r.measurementMethod, 'impedance');
    expect(r.measurementDaysInCurrentWindow, 1);
  });

  test('doublons dans le périmètre rejetés', () {
    expect(() => service.analyze(userId: 'u1', asOf: asOf,
      measurements: [m('x', 3, 22, month: 11), m('x', 5, 23, month: 11)]),
      throwsA(isA<BodyFatProgressException>().having(
        (e) => e.code, 'code', BodyFatProgressErrorCode.duplicateMeasurement,
      )));
  });

  test('valeur non finie rejetée', () {
    expect(() => service.analyze(userId: 'u1', asOf: asOf,
      measurements: [m('x', 5, double.nan, month: 11)]),
      throwsA(isA<BodyFatProgressException>().having(
        (e) => e.code, 'code', BodyFatProgressErrorCode.invalidMeasurement,
      )));
  });

  test('résultat valeur égale et hash identique', () {
    final a = service.analyze(userId: 'u1', asOf: asOf, measurements: []);
    final b = service.analyze(userId: 'u1', asOf: asOf, measurements: []);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains('asOfDay'));
  });
}
