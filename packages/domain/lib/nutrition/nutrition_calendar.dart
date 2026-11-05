import 'daily_nutrition_day_status.dart';

/// Conserve le jour civil fourni, sans conversion de fuseau horaire.
/// L'appelant doit convertir ses horodatages dans le fuseau utilisateur avant.
DateTime calendarDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// Statut temporel d'un jour civil au regard du jour civil de référence.
DailyNutritionDayStatus dayStatusFor(DateTime day, DateTime today) {
  final normalizedDay = calendarDay(day);
  final normalizedToday = calendarDay(today);
  if (normalizedDay.isAfter(normalizedToday)) {
    return DailyNutritionDayStatus.upcoming;
  }
  if (normalizedDay.isBefore(normalizedToday)) {
    return DailyNutritionDayStatus.completed;
  }
  return DailyNutritionDayStatus.inProgress;
}

/// Libellé ISO court pour un jour civil (AAAA-MM-JJ).
String dayLabel(DateTime date) =>
    calendarDay(date).toIso8601String().substring(0, 10);
