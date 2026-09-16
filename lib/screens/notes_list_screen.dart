import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_providers.dart';
import '../theme/app_colors.dart';
import 'note_edit_screen.dart';

final notesListProvider = FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
  final db = await ref.watch(notesDatabaseProvider.future);
  final refData = await ref.read(bibleReferenceDataProvider.future);
  print('Chapitres de Jean (id 43): ${refData.chapterCount(43)}'); // doit afficher 21
  print('Versets de Jean 3: ${refData.verseCount(43, 3)}'); // doit afficher 36
  print('Résolution "jn": ${refData.resolveBookId("jn")}'); // doit afficher 43
  print('Résolution "1 Corinthiens": ${refData.resolveBookId("1 Corinthiens")}'); // doit afficher 46
  return db.query('notes', orderBy: 'updated_at DESC');
});

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesListProvider);


    return Scaffold(
      appBar: AppBar(title: const Text('Meno Bible')),
      body: switch (notesAsync) {
        AsyncData(value: final notes) when notes.isEmpty =>
        const Center(
          child: Text(
            'Aucune note pour le moment.\nAppuie sur + pour commencer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDoux),
          ),
        ),
        AsyncData(value: final notes) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return Card(
              color: AppColors.bleuCielDoux,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                title: Text(
                  (note['title'] as String?)?.isNotEmpty == true
                      ? note['title'] as String
                      : 'Sans titre',
                  style: const TextStyle(color: AppColors.bordeauxProfond, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  note['content'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.grisDoux),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoteEditScreen(noteId: note['id'] as String),
                  ),
                ),

              ),
            );
          },
        ),
        AsyncError(error: final e) => Center(child: Text('Erreur: $e')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.rougePrincipal,
        foregroundColor: AppColors.ivoire,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NoteEditScreen(noteId: null)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}