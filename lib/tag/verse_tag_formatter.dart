import 'package:flutter/services.dart';
import '../data/bible_reference_data.dart';
import 'verse_tag_state.dart';

class VerseTagFormatter extends TextInputFormatter {
  final void Function(int offset) onTagStart;
  final void Function(String textSnapshot, int cursorOffset) onEnterPressed;
  final void Function(String query) onQueryChanged;
  final void Function(int chapterNumber, int verseStartOffset) onChapterConfirmed;
  final void Function(int? verseNumber) onVerseStartChanged;
  final void Function(int offset) onVerseEndStarted;
  final void Function(int? verseNumber) onVerseEndChanged;
  final void Function() onCancel;
  final void Function() onRevertToChapter;
  final void Function() onRevertToVerseStart;
  final void Function(String message) onRejected;
  final VerseTagState Function() getState;
  final BibleReferenceData? Function() getRefData;

  VerseTagFormatter({
    required this.onTagStart,
    required this.onQueryChanged,
    required this.onChapterConfirmed,
    required this.onVerseStartChanged,
    required this.onVerseEndStarted,
    required this.onVerseEndChanged,
    required this.onCancel,
    required this.onRevertToChapter,
    required this.onRevertToVerseStart,
    required this.onRejected,
    required this.getState,
    required this.getRefData,
    required this.onEnterPressed,
  });

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final state = getState();

    if (state.isActive) {
      final isSingleCharInsertion = newValue.text.length == oldValue.text.length + 1;
      if (isSingleCharInsertion) {
        final cursorPos = newValue.selection.baseOffset;
        final insertedIndex = cursorPos - 1;
        if (insertedIndex >= 0 && newValue.text[insertedIndex] == '\n') {
          onEnterPressed(oldValue.text, oldValue.selection.baseOffset);
          return oldValue;
        }
      }
    }

    if (state.state == TagState.searchingBook) {
      return _handleSearchingBook(state, oldValue, newValue);
    }
    if (state.state == TagState.editingChapter) {
      return _handleEditingChapter(state, oldValue, newValue);
    }
    if (state.state == TagState.editingVerseStart) {
      return _handleEditingVerseStart(state, oldValue, newValue);
    }
    if (state.state == TagState.editingVerseEnd) {
      return _handleEditingVerseEnd(state, oldValue, newValue);
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

  TextEditingValue _handleSearchingBook(
      VerseTagState state,
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final offset = state.tagStartOffset;
    final text = newValue.text;
    final cursor = newValue.selection.baseOffset;

    final broken = offset < 0 || offset >= text.length || text[offset] != '@' ||
        cursor < 0 || cursor <= offset;
    if (broken) {
      onCancel();
      return newValue;
    }

    // Blocage du collage : plus d'un caractère ajouté d'un coup pendant la recherche.
    final isGrowth = newValue.text.length > oldValue.text.length;
    if (isGrowth && newValue.text.length - oldValue.text.length > 1) {
      onRejected('Le collage n\'est pas autorisé ici.');
      return oldValue;
    }

    onQueryChanged(text.substring(offset + 1, cursor));
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

    final start = state.chapterSegmentStart;

    if (newValue.text.length < oldValue.text.length) {
      final cursor = newValue.selection.baseOffset;
      if (cursor < start) {
        // Effacement remonté jusque dans le nom du livre : on annule tout le
        // tag plutôt que de tenter un retour vers la recherche de livre —
        // simplification assumée, pas encore de "retour" jusqu'à cette étape.
        onCancel();
      }
      return newValue;
    }

    final isSingleCharInsertion = newValue.text.length == oldValue.text.length + 1;
    if (!isSingleCharInsertion) {
      onRejected('Le collage n\'est pas autorisé ici.');
      return oldValue;
    }

    final cursor = newValue.selection.baseOffset;
    final insertedChar = newValue.text[cursor - 1];
    if (start < 0 || start > newValue.text.length) return newValue;

    final rawSuffix = newValue.text.substring(start, cursor);

    if (insertedChar == ' ') return newValue;

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

  TextEditingValue _handleEditingVerseStart(
      VerseTagState state,
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final refData = getRefData();
    final bookId = state.selectedBookId;
    final chapter = state.chapterNumber;
    final start = state.verseStartSegmentStart;
    if (refData == null || bookId == null || chapter == null || start == null) return newValue;

    if (newValue.text.length < oldValue.text.length) {
      final cursor = newValue.selection.baseOffset;
      final colonPos = start - 1;
      final colonStillThere = colonPos >= 0 &&
          colonPos < newValue.text.length &&
          newValue.text[colonPos] == ':';

      if (!colonStillThere || cursor <= colonPos) {
        onRevertToChapter();
        return newValue;
      }

      final remaining = newValue.text.substring(start, cursor).replaceAll(' ', '');
      onVerseStartChanged(remaining.isEmpty ? null : int.tryParse(remaining));
      return newValue;
    }

    final isSingleCharInsertion = newValue.text.length == oldValue.text.length + 1;
    if (!isSingleCharInsertion) {
      onRejected('Le collage n\'est pas autorisé ici.');
      return oldValue;
    }

    final cursor = newValue.selection.baseOffset;
    final insertedChar = newValue.text[cursor - 1];
    if (start < 0 || start > newValue.text.length) return newValue;

    final rawSuffix = newValue.text.substring(start, cursor);

    if (insertedChar == ' ') return newValue;

    if (insertedChar == '-') {
      if (state.verseStartNumber == null) {
        onRejected('Indique d\'abord un verset de début valide.');
        return oldValue;
      }
      onVerseEndStarted(cursor);
      return newValue;
    }

    final isDigit = RegExp(r'^[0-9]$').hasMatch(insertedChar);
    if (!isDigit) {
      onRejected('Seuls des chiffres sont attendus ici.');
      return oldValue;
    }

    final digitsOnly = rawSuffix.replaceAll(' ', '');
    final candidateVerse = int.tryParse(digitsOnly);
    final maxVerse = refData.verseCount(bookId, chapter);

    if (candidateVerse == null || candidateVerse == 0) {
      onRejected('Le verset doit commencer par un chiffre autre que 0.');
      return oldValue;
    }
    if (maxVerse == null || candidateVerse > maxVerse) {
      onRejected('Ce chapitre n\'a que $maxVerse verset(s).');
      return oldValue;
    }

    onVerseStartChanged(candidateVerse);
    return newValue;
  }

  TextEditingValue _handleEditingVerseEnd(
      VerseTagState state,
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final refData = getRefData();
    final bookId = state.selectedBookId;
    final chapter = state.chapterNumber;
    final verseStart = state.verseStartNumber;
    final start = state.verseEndSegmentStart;
    if (refData == null || bookId == null || chapter == null || verseStart == null || start == null) {
      return newValue;
    }

    if (newValue.text.length < oldValue.text.length) {
      final cursor = newValue.selection.baseOffset;
      final dashPos = start - 1;
      final dashStillThere = dashPos >= 0 &&
          dashPos < newValue.text.length &&
          newValue.text[dashPos] == '-';

      if (!dashStillThere || cursor <= dashPos) {
        onRevertToVerseStart();
        return newValue;
      }

      final remaining = newValue.text.substring(start, cursor).replaceAll(' ', '');
      onVerseEndChanged(remaining.isEmpty ? null : int.tryParse(remaining));
      return newValue;
    }

    final isSingleCharInsertion = newValue.text.length == oldValue.text.length + 1;
    if (!isSingleCharInsertion) {
      onRejected('Le collage n\'est pas autorisé ici.');
      return oldValue;
    }

    final cursor = newValue.selection.baseOffset;
    final insertedChar = newValue.text[cursor - 1];
    if (start < 0 || start > newValue.text.length) return newValue;

    final rawSuffix = newValue.text.substring(start, cursor);

    if (insertedChar == ' ') return newValue;

    final isDigit = RegExp(r'^[0-9]$').hasMatch(insertedChar);
    if (!isDigit) {
      onRejected('Seuls des chiffres sont attendus ici.');
      return oldValue;
    }

    final digitsOnly = rawSuffix.replaceAll(' ', '');
    final candidateEnd = int.tryParse(digitsOnly);
    final maxVerse = refData.verseCount(bookId, chapter);

    if (candidateEnd == null || candidateEnd == 0) {
      onRejected('Le verset de fin doit commencer par un chiffre autre que 0.');
      return oldValue;
    }
    if (maxVerse == null || candidateEnd > maxVerse) {
      onRejected('Ce chapitre n\'a que $maxVerse verset(s).');
      return oldValue;
    }

    onVerseEndChanged(candidateEnd);
    return newValue;
  }
}