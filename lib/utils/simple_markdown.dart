import 'package:flutter/material.dart';

/// Découpe un texte contenant des segments *en italique* (notre seul usage
/// réel de Markdown : les citations de versets insérées par le tag @verset)
/// en une liste de TextSpan, pour un rendu tronquable sur une ligne — ce que
/// les widgets Markdown classiques (pensés pour des documents complets) ne
/// permettent pas facilement.
List<TextSpan> parseSimpleItalicMarkdown(String text, TextStyle baseStyle, TextStyle italicStyle) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*(.+?)\*');
  int lastEnd = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
    }
    spans.add(TextSpan(text: match.group(1), style: italicStyle));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: baseStyle));
  }
  return spans;
}