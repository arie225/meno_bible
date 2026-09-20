import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_providers.dart';
import '../theme/app_colors.dart';
import '../utils/simple_markdown.dart';
import 'note_edit_screen.dart';

final notesListProvider = FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
  final db = await ref.watch(notesDatabaseProvider.future);
  return db.query('notes', orderBy: 'updated_at DESC');
});

String formatRelativeDate(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final noteDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(noteDay).inDays;

  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Hier';

  const mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  return '${date.day} ${mois[date.month - 1]} ${date.year}';
}

const _moisComplets = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

/// Détermine l'en-tête de section d'une note selon son ancienneté :
/// Aujourd'hui / Hier / 7 jours / 30 jours / nom du mois (+ année si différente
/// de l'année en cours). Les notes arrivent déjà triées par date décroissante
/// (requête SQL), donc ce calcul suffit à produire des groupes dans le bon ordre.
String _sectionLabelFor(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final noteDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(noteDay).inDays;

  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Hier';
  if (diff <= 7) return 'Les 7 jours précédents';
  if (diff <= 30) return 'Les 30 jours précédents';

  final monthName = _moisComplets[date.month - 1];
  return date.year == now.year ? monthName : '$monthName ${date.year}';
}

/// Transforme la liste plate de notes en une liste mixte
/// [String en-tête, Map note, Map note, String en-tête, ...] prête à être
/// affichée directement dans un ListView.builder par index.
List<Object> _groupNotesByPeriod(List<Map<String, Object?>> notes) {
  final now = DateTime.now();
  final result = <Object>[];
  String? currentSection;

  for (final note in notes) {
    final date = DateTime.tryParse(note['updated_at'] as String);
    final section = date == null ? 'Sans date' : _sectionLabelFor(date, now);
    if (section != currentSection) {
      result.add(section);
      currentSection = section;
    }
    result.add(note);
  }
  return result;
}

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, Object?>> _filterNotes(List<Map<String, Object?>> notes) {
    if (_searchQuery.isEmpty) return notes;
    return notes.where((note) {
      final title = (note['title'] as String? ?? '').toLowerCase();
      final content = (note['content'] as String).toLowerCase();
      return title.contains(_searchQuery) || content.contains(_searchQuery);
    }).toList();
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ivoire,
        title: const Text('Supprimer cette note ?', style: TextStyle(color: AppColors.bordeauxProfond)),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.rougePrincipal)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteNote(String noteId) async {
    final db = await ref.read(notesDatabaseProvider.future);
    await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    ref.invalidate(notesListProvider);
  }

  Widget _buildNoteCard(BuildContext context, Map<String, Object?> note) {
    final noteId = note['id'] as String;
    return Dismissible(
      key: ValueKey(noteId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteNote(noteId),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: AppColors.rougePrincipal, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        color: AppColors.bleuCielDoux,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          title: Text(
            (note['title'] as String?)?.isNotEmpty == true ? note['title'] as String : 'Sans titre',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.bordeauxProfond, fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: parseSimpleItalicMarkdown(
                    note['content'] as String,
                    const TextStyle(color: AppColors.grisDoux),
                    const TextStyle(color: AppColors.grisDoux, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatRelativeDate(note['updated_at'] as String),
                style: const TextStyle(color: AppColors.grisDoux, fontSize: 12),
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NoteEditScreen(noteId: noteId)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meno Bible'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher dans mes notes...',
                prefixIcon: const Icon(Icons.search, color: AppColors.grisDoux),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.grisDoux),
                  onPressed: _searchController.clear,
                ),
                filled: true,
                fillColor: AppColors.bleuCielDoux,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: switch (notesAsync) {
        AsyncData(value: final allNotes) => Builder(
          builder: (context) {
            final notes = _filterNotes(allNotes);

            if (allNotes.isEmpty) {
              return const Center(
                child: Text(
                  'Aucune note pour le moment.\nAppuie sur + pour commencer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grisDoux),
                ),
              );
            }
            if (notes.isEmpty) {
              return const Center(
                child: Text('Aucune note ne correspond à ta recherche.', style: TextStyle(color: AppColors.grisDoux)),
              );
            }

            // Pendant une recherche : liste plate, sans en-têtes de période.
            if (isSearching) {
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: notes.length,
                itemBuilder: (context, index) => _buildNoteCard(context, notes[index]),
              );
            }

            final grouped = _groupNotesByPeriod(notes);
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final item = grouped[index];
                if (item is String) {
                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 8, left: 4),
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.bordeauxProfond,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  );
                }
                return _buildNoteCard(context, item as Map<String, Object?>);
              },
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