import 'package:makros_models/models.dart';
import 'package:makros_nutrition/progress/body_fat_progress_service.dart';
import 'package:test/test.dart';

BodyFatHistory m(
  String id,
  int day,
  double value, {
  String user = 'u1',
  String? method = 'impedance',
  int month = 10,
}) => BodyFatHistory(
  id: id,
  userId: user,
  bodyFatPercentage: value,
  measuredAt: DateTime(2026, month, day),
  measurementMethod: method,
);

void main() {
  const service = BodyFatProgressService();
  final asOf = DateTime(2026, 11, 6);

  group('Disponibilité des données', () {
    test('aucune mesure : données insuffisantes', () {
      final r = service.analyze(userId: 'u1', measurements: [], asOf: asOf);

      expect(r.trendStatus, BodyFatTrendStatus.insufficientData);
      expect(r.currentTrendPercentage, isNull);
      expect(r.previousTrendPercentage, isNull);
      expect(r.isTrendFresh, isFalse);
      expect(r.measurementDaysInCurrentWindow, 0);
    });

    test('une seule mesure insuffisante avec la config par défaut', () {
      final r = service.analyze(
        userId: 'u1',
        asOf: asOf,
        measurements: [m('a', 5, 24, month: 11)],
      );

      expect(r.trendStatus, BodyFatTrendStatus.insufficientData);
      expect(r.currentTrendPercentage, isNull);
      expect(r.isTrendFresh, isFalse);
    });

    test('aucune mesure récente : analyse non fraîche', () {
      const cfg = BodyFatProgressConfig(
        trendWindowDays: 14,
        minimumMeasurementDays: 2,
        minimumMeasurementSpanDays: 1,
        maxDaysSinceLastMeasurement: 3,
      );

      final r = const BodyFatProgressService(config: cfg).analyze(
        userId: 'u1',
        asOf: asOf,
        measurements: [m('a', 24, 25, month: 10), m('b', 26, 24, month: 10)],
      );

      expect(r.isTrendFresh, isFalse);
      expect(r.trendStatus, isNot(BodyFatTrendStatus.increasing));
    });
  });

  group('Calcul des tendances', () {
    test('deux fenêtres avec tendance décroissante et fraîche', () {
      const cfg = BodyFatProgressConfig(
        trendWindowDays: 14,
        minimumMeasurementDays: 2,
        minimumMeasurementSpanDays: 1,
        maxDaysSinceLastMeasurement: 7,
      );

      final r = const BodyFatProgressService(config: cfg).analyze(
        userId: 'u1',
        asOf: asOf,
        measurements: [
          m('a', 12, 26, month: 10),
          m('b', 20, 25, month: 10),
          m('c', 25, 24, month: 10),
          m('d', 5, 23, month: 11),
        ],
      );

      expect(r.currentTrendPercentage, closeTo(23.5, 1e-9));

      expect(r.previousTrendPercentage, closeTo(25.5, 1e-9));

      expect(r.changeBetweenWindowsPercentagePoints, closeTo(-2, 1e-9));

      expect(r.trendStatus, BodyFatTrendStatus.decreasing);

      expect(r.isTrendFresh, isTrue);
      expect(r.weeklyChangePercentagePoints, isNotNull);
    });

    test('moyenne des mesures du même jour', () {
      const cfg = BodyFatProgressConfig(
        trendWindowDays: 7,
        minimumMeasurementDays: 1,
        minimumMeasurementSpanDays: 0,
        maxDaysSinceLastMeasurement: 3,
      );

      final r = const BodyFatProgressService(config: cfg).analyze(
        userId: 'u1',
        asOf: asOf,
        measurements: [m('a', 5, 20, month: 11), m('b', 5, 24, month: 11)],
      );

      expect(r.currentTrendPercentage, 22);
      expect(r.measurementDaysInCurrentWindow, 1);
      expect(r.isTrendFresh, isTrue);
    });

    test('moyenne calculée sur les jours et non les mesures', () {
      const cfg = BodyFatProgressConfig(
        trendWindowDays: 7,
        minimumMeasurementDays: 2,
        minimumMeasurementSpanDays: 1,
        maxDaysSinceLastMeasurement: 3,
      );

      final r = const BodyFatProgressService(config: cfg).analyze(
        userId: 'u1',
        asOf: asOf,
        measurements: [
          m('a', 3, 20, month: 11),
          m('b', 3, 24, month: 11),
          m('c', 5, 26, month: 11),
        ],
      );

      // Jour 3 : moyenne 22.
      // Jour 5 : moyenne 26.
      // Tendance : (22 + 26) / 2 = 24.
      expect(r.currentTrendPercentage, closeTo(24, 1e-9));
      expect(r.measurementDaysInCurrentWindow, 2);
    });
  });

  group('Filtrage des mesures', () {
    test('filtre utilisateur, dates futures et date minimale', () {
      const cfg = BodyFatProgressConfig(
        trendWindowDays: 14,
        minimumMeasurementDays: 2,
        minimumMeasurementSpanDays: 1,
        maxDaysSinceLastMeasurement: 7,
      );

      final r = const BodyFatProgressService(config: cfg).analyze(
        userId: 'u1',
        asOf: asOf,
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
      expect(r.measurementDaysInCurrentWindow, 2);
    });

    test('ignore les mesures antérieures à earliestMeasurementDate', () {
      const cfg = BodyFatProgressConfig(
        trendWindowDays: 7,
        minimumMeasurementDays: 1,
        minimumMeasurementSpanDays: 0,
        maxDaysSinceLastMeasurement: 3,
      );

      final r = const BodyFatProgressService(config: cfg).analyze(
        userId: 'u1',
        asOf: asOf,
        earliestMeasurementDate: DateTime(2026, 11, 4),
        measurements: [m('a', 2, 20, month: 11), m('b', 5, 26, month: 11)],
      );

      expect(r.currentTrendPercentage, 26);
      expect(r.measurementDaysInCurrentWindow, 1);
    });
  });

  group('Méthodes de mesure', () {
    test('méthodes différentes : sélection explicite requise', () {
      final measurements = [
        m('a', 3, 24, month: 11),
        m('b', 5, 25, method: 'caliper', month: 11),
      ];

      expect(
        () => service.analyze(
          userId: 'u1',
          asOf: asOf,
          measurements: measurements,
        ),
        throwsA(
          isA<BodyFatProgressException>().having(
            (e) => e.code,
            'code',
            BodyFatProgressErrorCode.mixedMeasurementMethods,
          ),
        ),
      );
    });

    test('sélection explicite de la méthode impedance', () {
      final measurements = [
        m('a', 3, 24, month: 11),
        m('b', 5, 25, method: 'caliper', month: 11),
      ];

      final r = service.analyze(
        userId: 'u1',
        asOf: asOf,
        measurements: measurements,
        measurementMethod: ' IMPEDANCE ',
      );

      expect(r.measurementMethod, 'impedance');
      expect(r.hasSelectedMethod, isTrue);
      expect(r.measurementDaysInCurrentWindow, 1);
    });

    test('normalise les variantes de casse et espaces', () {
      const cfg = BodyFatProgressConfig(
        trendWindowDays: 7,
        minimumMeasurementDays: 1,
        minimumMeasurementSpanDays: 0,
        maxDaysSinceLastMeasurement: 3,
      );

      final r = const BodyFatProgressService(config: cfg).analyze(
        userId: 'u1',
        asOf: asOf,
        measurementMethod: ' IMPEDANCE ',
        measurements: [
          m('a', 5, 24, method: 'impedance', month: 11),
          m('b', 5, 26, method: ' IMPEDANCE ', month: 11),
        ],
      );

      expect(r.measurementMethod, 'impedance');
      expect(r.currentTrendPercentage, 25);
      expect(r.measurementDaysInCurrentWindow, 1);
    });
  });

  group('Validation des mesures', () {
    test('doublons dans le périmètre rejetés', () {
      expect(
        () => service.analyze(
          userId: 'u1',
          asOf: asOf,
          measurements: [m('x', 3, 22, month: 11), m('x', 5, 23, month: 11)],
        ),
        throwsA(
          isA<BodyFatProgressException>().having(
            (e) => e.code,
            'code',
            BodyFatProgressErrorCode.duplicateMeasurement,
          ),
        ),
      );
    });

    test('valeur non finie rejetée', () {
      expect(
        () => service.analyze(
          userId: 'u1',
          asOf: asOf,
          measurements: [m('x', 5, double.nan, month: 11)],
        ),
        throwsA(
          isA<BodyFatProgressException>().having(
            (e) => e.code,
            'code',
            BodyFatProgressErrorCode.invalidMeasurement,
          ),
        ),
      );
    });

    test('valeur hors bornes plausibles rejetée', () {
      expect(
        () => service.analyze(
          userId: 'u1',
          asOf: asOf,
          measurements: [m('x', 5, 90, month: 11)],
        ),
        throwsA(
          isA<BodyFatProgressException>().having(
            (e) => e.code,
            'code',
            BodyFatProgressErrorCode.invalidMeasurement,
          ),
        ),
      );
    });
  });

  group('Configuration', () {
    test('configuration par défaut valide', () {
      const config = BodyFatProgressConfig();

      expect(() => config.validate(), returnsNormally);
    });

    test('limite de fraîcheur trop grande rejetée', () {
      const config = BodyFatProgressConfig(
        trendWindowDays: 28,
        maxDaysSinceLastMeasurement: 27,
      );

      expect(() => config.validate(), throwsArgumentError);
    });
  });

  group('Égalité des résultats', () {
    test('résultats égaux et hash identique', () {
      final a = service.analyze(userId: 'u1', asOf: asOf, measurements: []);

      final b = service.analyze(userId: 'u1', asOf: asOf, measurements: []);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('asOfDay'));
    });
  });
}
