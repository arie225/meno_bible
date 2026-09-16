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

  void selectBook(int bookId, int chapterSegmentStart) {
    state = state.copyWith(
      state: TagState.editingChapter,
      selectedBookId: bookId,
      bookQuery: '',
      chapterSegmentStart: chapterSegmentStart,
    );
  }

  void confirmChapter(int chapterNumber, int verseStartSegmentStart) {
    state = state.copyWith(
      state: TagState.editingVerseStart,
      chapterNumber: chapterNumber,
      verseStartSegmentStart: verseStartSegmentStart,
    );
  }

  void updateVerseStart(int? verseNumber) {
    state = state.copyWith(verseStartNumber: verseNumber, clearVerseStartNumber: verseNumber == null);
  }

  void confirmVerseEndStart(int verseEndSegmentStart) {
    state = state.copyWith(
      state: TagState.editingVerseEnd,
      verseEndSegmentStart: verseEndSegmentStart,
    );
  }

  void updateVerseEnd(int? verseNumber) {
    state = state.copyWith(verseEndNumber: verseNumber, clearVerseEndNumber: verseNumber == null);
  }

  /// Le ":" a été effacé pendant la saisie du verset de début :
  /// on redescend vers l'étape chapitre, proprement.
  void revertToEditingChapter() {
    state = state.copyWith(
      state: TagState.editingChapter,
      clearChapterNumber: true,
      clearVerseStartNumber: true,
      clearVerseEndNumber: true,
      clearVerseStartSegmentStart: true,
      clearVerseEndSegmentStart: true,
    );
  }

  /// Le "-" a été effacé pendant la saisie du verset de fin :
  /// on redescend vers l'étape verset de début, proprement.
  void revertToEditingVerseStart() {
    state = state.copyWith(
      state: TagState.editingVerseStart,
      clearVerseEndNumber: true,
      clearVerseEndSegmentStart: true,
    );
  }

  void cancel() {
    state = const VerseTagState();
  }
}

final verseTagProvider = NotifierProvider<VerseTagNotifier, VerseTagState>(
  VerseTagNotifier.new,
);