enum TagState { idle, searchingBook, editingChapter, editingVerseStart, editingVerseEnd }

class VerseTagState {
  final TagState state;
  final int tagStartOffset;
  final String bookQuery;
  final int? selectedBookId;
  final int? chapterNumber;
  final int? verseStartNumber;
  final int segmentStartOffset;
  final int? verseEndNumber;

  const VerseTagState({
    this.state = TagState.idle,
    this.tagStartOffset = -1,
    this.bookQuery = '',
    this.selectedBookId,
    this.chapterNumber,
    this.verseStartNumber,
    this.segmentStartOffset = -1,
    this.verseEndNumber
  });

  VerseTagState copyWith({
    TagState? state,
    int? tagStartOffset,
    String? bookQuery,
    int? selectedBookId,
    int? chapterNumber,
    int? verseStartNumber,
    int? segmentStartOffset,
    int? verseEndNumber,
  }) {
    return VerseTagState(
      state: state ?? this.state,
      tagStartOffset: tagStartOffset ?? this.tagStartOffset,
      bookQuery: bookQuery ?? this.bookQuery,
      selectedBookId: selectedBookId ?? this.selectedBookId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      verseStartNumber: verseStartNumber ?? this.verseStartNumber,
      segmentStartOffset: segmentStartOffset ?? this.segmentStartOffset,
      verseEndNumber: verseEndNumber ?? this.verseEndNumber,
    );
  }

  bool get isActive => state != TagState.idle;
}