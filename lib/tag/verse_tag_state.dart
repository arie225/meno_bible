enum TagState { idle, searchingBook, editingChapter, editingVerseStart, editingVerseEnd }

class VerseTagState {
  final TagState state;
  final int tagStartOffset;
  final String bookQuery;
  final int? selectedBookId;
  final int? chapterNumber;
  final int? verseStartNumber;
  final int? verseEndNumber;

  // Position de début de chaque segment, conservées séparément (pas de champ
  // unique réécrit à chaque étape) pour pouvoir revenir en arrière proprement
  // si l'utilisateur efface un caractère structurant (":" ou "-").
  final int chapterSegmentStart;      // juste après "@NomDuLivre "
  final int? verseStartSegmentStart;  // juste après ":"
  final int? verseEndSegmentStart;    // juste après "-"

  const VerseTagState({
    this.state = TagState.idle,
    this.tagStartOffset = -1,
    this.bookQuery = '',
    this.selectedBookId,
    this.chapterNumber,
    this.verseStartNumber,
    this.verseEndNumber,
    this.chapterSegmentStart = -1,
    this.verseStartSegmentStart,
    this.verseEndSegmentStart,
  });

  VerseTagState copyWith({
    TagState? state,
    int? tagStartOffset,
    String? bookQuery,
    int? selectedBookId,
    int? chapterNumber,
    int? verseStartNumber,
    int? verseEndNumber,
    int? chapterSegmentStart,
    int? verseStartSegmentStart,
    int? verseEndSegmentStart,
    bool clearChapterNumber = false,
    bool clearVerseStartNumber = false,
    bool clearVerseEndNumber = false,
    bool clearVerseStartSegmentStart = false,
    bool clearVerseEndSegmentStart = false,
  }) {
    return VerseTagState(
      state: state ?? this.state,
      tagStartOffset: tagStartOffset ?? this.tagStartOffset,
      bookQuery: bookQuery ?? this.bookQuery,
      selectedBookId: selectedBookId ?? this.selectedBookId,
      chapterNumber: clearChapterNumber ? null : (chapterNumber ?? this.chapterNumber),
      verseStartNumber: clearVerseStartNumber ? null : (verseStartNumber ?? this.verseStartNumber),
      verseEndNumber: clearVerseEndNumber ? null : (verseEndNumber ?? this.verseEndNumber),
      chapterSegmentStart: chapterSegmentStart ?? this.chapterSegmentStart,
      verseStartSegmentStart: clearVerseStartSegmentStart
          ? null
          : (verseStartSegmentStart ?? this.verseStartSegmentStart),
      verseEndSegmentStart: clearVerseEndSegmentStart
          ? null
          : (verseEndSegmentStart ?? this.verseEndSegmentStart),
    );
  }

  bool get isActive => state != TagState.idle;
}