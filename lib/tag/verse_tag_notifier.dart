import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'verse_tag_state.dart';

class VerseTagNotifier extends Notifier<VerseTagState> {
  @override
  VerseTagState build() => const VerseTagState();

  void startTag(int offset) {
    state = VerseTagState(state: TagState.searchingBook, tagStartOffset: offset);
  }

  void updateQuery(String query) {
    if (state.state != TagState.searchingBook) return; // ignore hors de cette étape
    state = state.copyWith(bookQuery: query);
  }

  void selectBook() {
    state = state.copyWith(state: TagState.editingChapter, bookQuery: '');
  }
  void cancel() {
    state = const VerseTagState();
  }
}

final verseTagProvider = NotifierProvider<VerseTagNotifier, VerseTagState>(
  VerseTagNotifier.new,
);