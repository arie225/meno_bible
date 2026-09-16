import 'package:flutter/services.dart';
import '../data/bible_reference_data.dart';
import 'verse_tag_state.dart';

class VerseTagFormatter extends TextInputFormatter {
  final void Function(int offset) onTagStart;
  final void Function(String query) onQueryChanged;
  final void Function(int chapterNumber, int verseStartOffset) onChapterConfirmed;
  final void Function() onCancel;
  final void Function(String message) onRejected;
  final VerseTagState Function() getState;
  final BibleReferenceData? Function() getRefData;

  VerseTagFormatter({
    required this.onTagStart,
    required this.onQueryChanged,
    required this.onChapterConfirmed,
    required this.onCancel,
    required this.onRejected,
    required this.getState,
    required this.getRefData,
  });

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final state = getState();

    if (state.state == TagState.searchingBook) {
      return _handleSearchingBook(state, newValue);
    }
    if (state.state == TagState.editingChapter) {
      return _handleEditingChapter(state, oldValue, newValue);
    }
    if (state.isActive) {
      return newValue; // étapes verset/plage pas encore codées
    }
    return _handleIdle(oldValue, newValue);
  }

  TextEditingValue _handleIdle(TextEditingValue oldValue, TextEditingValue newValue) {
    final isSingleCharInsertion = newValue.text.length == oldValue.text.length + 1;
    if (isSingleCharInsertion) {
      final cursorPos = newValue.selection.baseOffset;
      final insertedIndex = cursorPos - 1;
      if (insertedIndex >= 0 && newValue.text[insertedIndex] == '@') {
        final isAtWordBoundary = insertedIndex == 0 ||
            newValue.text[insertedIndex - 1] == ' ' ||
            newValue.text[insertedIndex - 1] == '\n';
        if (isAtWordBoundary) onTagStart(insertedIndex);
      }
    }
    return newValue;
  }

  TextEditingValue _handleSearchingBook(VerseTagState state, TextEditingValue newValue) {
    final offset = state.tagStartOffset;
    final text = newValue.text;
    final cursor = newValue.selection.baseOffset;

    final broken = offset < 0 || offset >= text.length || text[offset] != '@' ||
        cursor < 0 || cursor <= offset;

    if (broken) {
      onCancel();
    } else {
      onQueryChanged(text.substring(offset + 1, cursor));
    }
    return newValue;
  }

  TextEditingValue _handleEditingChapter(
      VerseTagState state,
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final refData = getRefData();
    final bookId = state.selectedBookId;
    if (refData == null || bookId == null) return newValue;

    if (newValue.text.length < oldValue.text.length) {
      return newValue; // suppression : toujours autorisée, pas de blocage
    }

    final isSingleCharInsertion = newValue.text.length == oldValue.text.length + 1;
    if (!isSingleCharInsertion) {
      onRejected('Le collage n\'est pas autorisé ici.');
      return oldValue;
    }

    final cursor = newValue.selection.baseOffset;
    final insertedChar = newValue.text[cursor - 1];
    final start = state.segmentStartOffset;
    if (start < 0 || start > newValue.text.length) return newValue;

    final rawSuffix = newValue.text.substring(start, cursor);

    if (insertedChar == ' ') {
      return newValue; // espace toléré autour du ":"
    }

    if (insertedChar == ':') {
      final digitsBeforeColon = rawSuffix.substring(0, rawSuffix.length - 1).replaceAll(' ', '');
      final chapterNumber = int.tryParse(digitsBeforeColon);

      if (chapterNumber == null || chapterNumber < 1) {
        onRejected('Indique un numéro de chapitre valide avant ":".');
        return oldValue;
      }
      onChapterConfirmed(chapterNumber, cursor);
      return newValue;
    }

    final isDigit = RegExp(r'^[0-9]$').hasMatch(insertedChar);
    if (!isDigit) {
      onRejected('Seuls des chiffres ou ":" sont attendus ici.');
      return oldValue;
    }

    final digitsOnly = rawSuffix.replaceAll(' ', '');
    final candidateChapter = int.tryParse(digitsOnly);
    final maxChapter = refData.chapterCount(bookId);

    if (candidateChapter == null || candidateChapter == 0) {
      onRejected('Le chapitre doit commencer par un chiffre autre que 0.');
      return oldValue;
    }
    if (maxChapter == null || candidateChapter > maxChapter) {
      onRejected('Ce livre n\'a que $maxChapter chapitre(s).');
      return oldValue;
    }

    return newValue;
  }
}