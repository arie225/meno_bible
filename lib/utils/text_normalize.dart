/// Normalise une chaîne pour la comparaison de noms/abréviations de livres :
/// minuscule, accents français retirés, espaces superflus supprimés.
/// Ex: "Ésaïe" -> "esaie", "1 Corinthiens" -> "1 corinthiens"
String normalizeBookText(String input) {
  var result = input.trim().toLowerCase();

  const accents = {
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'à': 'a', 'â': 'a', 'ä': 'a',
    'ù': 'u', 'û': 'u', 'ü': 'u',
    'ô': 'o', 'ö': 'o',
    'î': 'i', 'ï': 'i',
    'ç': 'c',
  };
  accents.forEach((accented, plain) {
    result = result.replaceAll(accented, plain);
  });

  result = result.replaceAll('.', ''); // "jn." -> "jn"
  result = result.replaceAll(RegExp(r'\s+'), ' '); // espaces multiples -> un seul

  return result;
}