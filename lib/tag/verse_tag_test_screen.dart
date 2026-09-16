import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'verse_tag_formatter.dart';
import 'verse_tag_notifier.dart';
import 'verse_tag_state.dart';
import '../providers/database_providers.dart';
import '../theme/app_colors.dart';

class VerseTagTestScreen extends ConsumerStatefulWidget {
  const VerseTagTestScreen({super.key});

  @override
  ConsumerState<VerseTagTestScreen> createState() => _VerseTagTestScreenState();
}

class _VerseTagTestScreenState extends ConsumerState<VerseTagTestScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        final tagState = ref.read(verseTagProvider);
        if (tagState.isActive) {
          ref.read(verseTagProvider.notifier).cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleEnterPressed(String textSnapshot, int cursorOffset) async {
    final tagState = ref.read(verseTagProvider);
    final refData = ref.read(bibleReferenceDataProvider).value;
    if (refData == null) return;

    final bookId = tagState.selectedBookId;
    if (bookId == null) {
      _showRejection('Sélectionne un livre avant de valider.');
      return;
    }
    final bookName = refData.bookNameById[bookId]!;
    final db = await ref.read(bibleDatabaseProvider.future);

    String reference;
    String content;

    switch (tagState.state) {
      case TagState.searchingBook:
        _showRejection('Sélectionne un livre avant de valider.');
        return;

      case TagState.editingChapter:
        final start = tagState.chapterSegmentStart;
        if (start < 0 || start > cursorOffset) {
          _showRejection('Indique un numéro de chapitre.');
          return;
        }
        final digits = textSnapshot.substring(start, cursorOffset).replaceAll(' ', '');
        final chapter = int.tryParse(digits);
        if (chapter == null || chapter < 1) {
          _showRejection('Indique un numéro de chapitre valide.');
          return;
        }
        final rows = await db.query(
          'bible_verses',
          where: 'book_id = ? AND chapter = ?',
          whereArgs: [bookId, chapter],
          orderBy: 'verse ASC',
        );
        reference = '$bookName $chapter';
        content = rows.map((r) => '[${r['verse']}] ${r['text']}').join(' ');
        break;

      case TagState.editingVerseStart:
        final chapter = tagState.chapterNumber;
        final verseStart = tagState.verseStartNumber;
        if (chapter == null || verseStart == null) {
          _showRejection('Indique un numéro de verset.');
          return;
        }
        final rows = await db.query(
          'bible_verses',
          where: 'book_id = ? AND chapter = ? AND verse = ?',
          whereArgs: [bookId, chapter, verseStart],
        );
        if (rows.isEmpty) {
          _showRejection('Verset introuvable.');
          return;
        }
        reference = '$bookName $chapter:$verseStart';
        content = rows.first['text'] as String;
        break;

      case TagState.editingVerseEnd:
        final chapter = tagState.chapterNumber;
        final verseStart = tagState.verseStartNumber;
        final verseEnd = tagState.verseEndNumber;
        if (chapter == null || verseStart == null || verseEnd == null) {
          _showRejection('Indique un numéro de verset de fin.');
          return;
        }
        if (verseEnd <= verseStart) {
          _showRejection('Le verset de fin doit être supérieur à $verseStart.');
          return;
        }
        final rows = await db.query(
          'bible_verses',
          where: 'book_id = ? AND chapter = ? AND verse >= ? AND verse <= ?',
          whereArgs: [bookId, chapter, verseStart, verseEnd],
          orderBy: 'verse ASC',
        );
        reference = '$bookName $chapter:$verseStart-$verseEnd';
        content = rows.map((r) => '[${r['verse']}] ${r['text']}').join(' ');
        break;

      case TagState.idle:
        return;
    }

    final citation = '*$reference $content*';
    final before = textSnapshot.substring(0, tagState.tagStartOffset);
    final after = cursorOffset <= textSnapshot.length ? textSnapshot.substring(cursorOffset) : '';
    final newText = '$before$citation $after';
    final newCursorPos = before.length + citation.length + 1;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    ref.read(verseTagProvider.notifier).cancel();
  }

  void _onBookSelected(int bookId, String bookName) {
    final tagState = ref.read(verseTagProvider);
    final offset = tagState.tagStartOffset;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;

    final before = text.substring(0, offset);
    final after = (cursor >= 0 && cursor <= text.length) ? text.substring(cursor) : '';
    final newText = '$before@$bookName $after';
    final newCursorPos = before.length + 1 + bookName.length + 1;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    ref.read(verseTagProvider.notifier).selectBook(bookId, newCursorPos);
  }

  void _showRejection(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final tagState = ref.watch(verseTagProvider);
    final refDataAsync = ref.watch(bibleReferenceDataProvider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Test — chapitre')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'État: ${tagState.state}\n'
                    'Livre id: ${tagState.selectedBookId}\n'
                    'Chapitre confirmé: ${tagState.chapterNumber}\n'
                    'Verset de début: ${tagState.verseStartNumber}\n'
                    'Verset de fin: ${tagState.verseEndNumber}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 5,
                inputFormatters: [
                  VerseTagFormatter(
                    onTagStart: (o) => ref.read(verseTagProvider.notifier).startTag(o),
                    onQueryChanged: (q) => ref.read(verseTagProvider.notifier).updateQuery(q),
                    onChapterConfirmed: (ch, off) =>
                        ref.read(verseTagProvider.notifier).confirmChapter(ch, off),
                    onCancel: () => ref.read(verseTagProvider.notifier).cancel(),
                    onRejected: _showRejection,
                    onVerseStartChanged: (v) => ref.read(verseTagProvider.notifier).updateVerseStart(v),
                    onVerseEndStarted: (o) => ref.read(verseTagProvider.notifier).confirmVerseEndStart(o),
                    onVerseEndChanged: (v) => ref.read(verseTagProvider.notifier).updateVerseEnd(v),
                    onEnterPressed: (text, cursor) => _handleEnterPressed(text, cursor),
                    onRevertToChapter: () => ref.read(verseTagProvider.notifier).revertToEditingChapter(),
                    onRevertToVerseStart: () => ref.read(verseTagProvider.notifier).revertToEditingVerseStart(),
                    getState: () => ref.read(verseTagProvider),
                    getRefData: () => refDataAsync.value,
                  ),
                ],
                decoration: const InputDecoration(
                  hintText: 'Tape "@", choisis un livre, puis un chapitre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (tagState.state == TagState.searchingBook)
                refDataAsync.when(
                  data: (refData) {
                    final ids = refData.filterBooks(tagState.bookQuery);
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: AppColors.bleuCielDoux,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: ids.length,
                        itemBuilder: (context, index) {
                          final id = ids[index];
                          final name = refData.bookNameById[id]!;
                          return ListTile(
                            title: Text(name, style: const TextStyle(color: AppColors.bordeauxProfond)),
                            onTap: () => _onBookSelected(id, name),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Erreur: $e'),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  _controller.clear();
                  ref.read(verseTagProvider.notifier).cancel();
                },
                child: const Text('Réinitialiser (debug)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}