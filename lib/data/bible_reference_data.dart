import 'package:sqflite/sqflite.dart';
import '../utils/text_normalize.dart';

class BibleReferenceData {
  final Map<int, int> maxChapterByBook;          // bookId -> nombre de chapitres
  final Map<String, int> maxVerseByBookChapter;  // "bookId:chapter" -> nombre de versets
  final Map<String, int> abbreviationToBookId;   // forme normalisée -> bookId
  final Map<int, String> bookNameById;           // bookId -> nom complet, pour l'affichage

  const BibleReferenceData({
    required this.maxChapterByBook,
    required this.maxVerseByBookChapter,
    required this.abbreviationToBookId,
    required this.bookNameById,
  });

  /// Nombre de chapitres pour un livre donné, ou null si l'id n'existe pas.
  int? chapterCount(int bookId) => maxChapterByBook[bookId];

  /// Nombre de versets pour un chapitre donné d'un livre, ou null si absent.
  int? verseCount(int bookId, int chapter) =>
      maxVerseByBookChapter['$bookId:$chapter'];

  /// Résout un texte tapé par l'utilisateur (nom complet ou abréviation)
  /// vers l'id du livre correspondant, ou null si aucune correspondance.
  int? resolveBookId(String rawInput) =>
      abbreviationToBookId[normalizeBookText(rawInput)];

  static Future<BibleReferenceData> loadFrom(Database bibleDb) async {
    final maxChapterByBook = <int, int>{};
    final maxVerseByBookChapter = <String, int>{};
    final abbreviationToBookId = <String, int>{};
    final bookNameById = <int, String>{};

    // --- Table des livres : noms complets + abréviations ---
    final bookRows = await bibleDb.query('bible_books');
    for (final row in bookRows) {
      final id = row['id'] as int;
      final livre = row['livre'] as String;
      final abreviations = row['abreviations'] as String;

      bookNameById[id] = livre;

      // Le nom complet est toujours une clé valide, en plus des abréviations.
      abbreviationToBookId[normalizeBookText(livre)] = id;

      for (final abbr in abreviations.split('/')) {
        final normalized = normalizeBookText(abbr);
        if (normalized.isEmpty) continue; // sécurité si un slash final traîne encore
        abbreviationToBookId[normalized] = id;
      }
    }

    // --- Bornes de chapitres : un livre = un maximum de chapitres ---
    final chapterRows = await bibleDb.rawQuery(
      'SELECT book_id, MAX(chapter) as max_chapter FROM bible_verses GROUP BY book_id',
    );
    for (final row in chapterRows) {
      maxChapterByBook[row['book_id'] as int] = row['max_chapter'] as int;
    }

    // --- Bornes de versets : une paire (livre, chapitre) = un maximum de versets ---
    final verseRows = await bibleDb.rawQuery(
      'SELECT book_id, chapter, MAX(verse) as max_verse FROM bible_verses GROUP BY book_id, chapter',
    );
    for (final row in verseRows) {
      final key = '${row['book_id']}:${row['chapter']}';
      maxVerseByBookChapter[key] = row['max_verse'] as int;
    }

    return BibleReferenceData(
      maxChapterByBook: maxChapterByBook,
      maxVerseByBookChapter: maxVerseByBookChapter,
      abbreviationToBookId: abbreviationToBookId,
      bookNameById: bookNameById,
    );
  }

  /// Retourne les ids de livres dont le nom complet ou une abréviation
  /// commence par la requête normalisée. Champ vide = tous les livres.
  List<int> filterBooks(String query) {
    final normalized = normalizeBookText(query);
    if (normalized.isEmpty) return bookNameById.keys.toList()..sort();

    final matches = <int>{};
    abbreviationToBookId.forEach((key, id) {
      if (key.startsWith(normalized)) matches.add(id);
    });
    return matches.toList()..sort();
  }
}