import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'verse_tag_state.dart';

class VerseTagNotifier extends Notifier<VerseTagState> {
  @override
  VerseTagState build() => const VerseTagState();

  void startTag(int offset) {
    state = VerseTagState(state: TagState.searchingBook, tagStartOffset: offset);
  }

  void updateQuery(String query) {
    if (state.state != TagState.searchingBook) return;
    state = state.copyWith(bookQuery: query);
  }

  void selectBook(int bookId, int chapterStartOffset) {
    state = state.copyWith(
      state: TagState.editingChapter,
      selectedBookId: bookId,
      bookQuery: '',
      segmentStartOffset: chapterStartOffset,
    );
  }

  void confirmChapter(int chapterNumber, int verseStartOffset) {
    state = state.copyWith(
      state: TagState.editingVerseStart,
      chapterNumber: chapterNumber,
      segmentStartOffset: verseStartOffset,
    );
  }

  void updateVerseStart(int? verseNumber) {
    state = state.copyWith(verseStartNumber: verseNumber);
  }

  void confirmVerseEndStart(int rangeSegmentOffset) {
    state = state.copyWith(state: TagState.editingVerseEnd, segmentStartOffset: rangeSegmentOffset);
  }

  void updateVerseEnd(int? verseNumber) {
    state = state.copyWith(verseEndNumber: verseNumber);
  }

  void cancel() {
    state = const VerseTagState();
  }
}

final verseTagProvider = NotifierProvider<VerseTagNotifier, VerseTagState>(
  VerseTagNotifier.new,
);