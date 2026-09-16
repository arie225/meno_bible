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

    return Scaffold(
      appBar: AppBar(title: const Text('Test — chapitre')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'État: ${tagState.state}\n'
                  'Livre id: ${tagState.selectedBookId}\n'
                  'Chapitre confirmé: ${tagState.chapterNumber}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              inputFormatters: [
                VerseTagFormatter(
                  onTagStart: (o) => ref.read(verseTagProvider.notifier).startTag(o),
                  onQueryChanged: (q) => ref.read(verseTagProvider.notifier).updateQuery(q),
                  onChapterConfirmed: (ch, off) =>
                      ref.read(verseTagProvider.notifier).confirmChapter(ch, off),
                  onCancel: () => ref.read(verseTagProvider.notifier).cancel(),
                  onRejected: _showRejection,
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
    );
  }
}