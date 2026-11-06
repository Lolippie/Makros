final RegExp _combiningMarks = RegExp(r'[\u0300-\u036f]');
final RegExp _whitespace = RegExp(r'\s+');

const Map<String, String> _accentFolds = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ÿ': 'y', 'ñ': 'n',
};

/// Clé de comparaison des méthodes de mesure.
///
/// Replie les principaux accents latins précomposés et décomposés.
/// Ce n’est pas une normalisation Unicode NFC universelle.
/// Conserver le libellé original séparément pour l’affichage.
String? normalizeMeasurementMethod(String? method) {
  if (method == null) return null;
  var value = method.trim().toLowerCase();
  if (value.isEmpty) return null;
  value = value.replaceAll(_combiningMarks, '');
  for (final entry in _accentFolds.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  value = value.replaceAll(_whitespace, ' ').trim();
  return value.isEmpty ? null : value;
}
