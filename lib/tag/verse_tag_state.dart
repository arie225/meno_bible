enum TagState { idle, searchingBook, editingChapter, editingVerseStart, editingVerseEnd }

class VerseTagState {
  final TagState state;
  final int tagStartOffset;
  final String bookQuery; // texte tapé après le "@", sert à filtrer la liste

  const VerseTagState({
    this.state = TagState.idle,
    this.tagStartOffset = -1,
    this.bookQuery = '',
  });

  VerseTagState copyWith({TagState? state, int? tagStartOffset, String? bookQuery}) {
    return VerseTagState(
      state: state ?? this.state,
      tagStartOffset: tagStartOffset ?? this.tagStartOffset,
      bookQuery: bookQuery ?? this.bookQuery,
    );
  }

  bool get isActive => state != TagState.idle;
}