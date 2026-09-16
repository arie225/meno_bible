import 'package:flutter/services.dart';

class VerseTagFormatter extends TextInputFormatter {
  final void Function(int offset) onTagStart;
  final void Function(String query) onQueryChanged;
  final void Function() onCancel;
  final bool Function() isTagActive;
  final int Function() getTagStartOffset;

  VerseTagFormatter({
    required this.onTagStart,
    required this.onQueryChanged,
    required this.onCancel,
    required this.isTagActive,
    required this.getTagStartOffset,
  });

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (isTagActive()) {
      final offset = getTagStartOffset();
      final text = newValue.text;
      final cursor = newValue.selection.baseOffset;

      // Si le "@" a disparu (l'utilisateur l'a effacé) ou que le curseur est
      // revenu avant lui, le tag n'a plus de sens : on annule proprement
      // plutôt que de planter sur un substring hors limites.
      final broken = offset < 0 || offset >= text.length || text[offset] != '@' ||
          cursor < 0 || cursor <= offset;

      if (broken) {
        onCancel();
      } else {
        onQueryChanged(text.substring(offset + 1, cursor));
      }
      return newValue;
    }

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
}