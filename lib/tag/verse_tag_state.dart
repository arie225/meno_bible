enum TagState { idle, searchingBook, editingChapter, editingVerseStart, editingVerseEnd }

class VerseTagState {
  final TagState state;
  final int tagStartOffset;
  final String bookQuery;
  final int? selectedBookId;
  final int? chapterNumber;
  final int segmentStartOffset; // position où commence le segment en cours (chapitre, puis verset)

  const VerseTagState({
    this.state = TagState.idle,
    this.tagStartOffset = -1,
    this.bookQuery = '',
    this.selectedBookId,
    this.chapterNumber,
    this.segmentStartOffset = -1,
  });

  VerseTagState copyWith({
    TagState? state,
    int? tagStartOffset,
    String? bookQuery,
    int? selectedBookId,
    int? chapterNumber,
    int? segmentStartOffset,
  }) {
    return VerseTagState(
      state: state ?? this.state,
      tagStartOffset: tagStartOffset ?? this.tagStartOffset,
      bookQuery: bookQuery ?? this.bookQuery,
      selectedBookId: selectedBookId ?? this.selectedBookId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      segmentStartOffset: segmentStartOffset ?? this.segmentStartOffset,
    );
  }

  bool get isActive => state != TagState.idle;
}