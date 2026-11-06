/// Clé de jour civil. Les valeurs doivent déjà être exprimées dans le
/// calendrier/fuseau de l'utilisateur. Ne convertit pas les instants UTC.
DateTime civilDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
