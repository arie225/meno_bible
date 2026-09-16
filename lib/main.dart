import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meno_bible/screens/notes_list_screen.dart';
import 'package:meno_bible/tag/verse_tag_test_screen.dart';
import 'package:sqflite/sqflite.dart';
import 'providers/database_providers.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MenoBibleApp()));
}

class MenoBibleApp extends StatelessWidget {
  const MenoBibleApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meno Bible',
      theme: AppTheme.light,
      home: const VerseTagTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DiagnosticScreen extends ConsumerWidget {
  const DiagnosticScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bibleAsync = ref.watch(bibleDatabaseProvider);
    final notesAsync = ref.watch(notesDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic Meno Bible (Riverpod)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch ((bibleAsync, notesAsync)) {
          (AsyncData(value: final bibleDb), AsyncData(value: final notesDb)) =>
              _DiagnosticContent(bibleDb: bibleDb, notesDb: notesDb),
          (AsyncError(error: final e), _) => Text('❌ Erreur bible.db: $e'),
          (_, AsyncError(error: final e)) => Text('❌ Erreur notes.db: $e'),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _DiagnosticContent extends StatefulWidget {
  final Database bibleDb;
  final Database notesDb;
  const _DiagnosticContent({required this.bibleDb, required this.notesDb});

  @override
  State<_DiagnosticContent> createState() => _DiagnosticContentState();
}

class _DiagnosticContentState extends State<_DiagnosticContent> {
  String _status = 'Requête en cours...';

  @override
  void initState() {
    super.initState();
    _runQueries();
  }

  Future<void> _runQueries() async {
    final buffer = StringBuffer();
    final verseCount = await widget.bibleDb.rawQuery('SELECT COUNT(*) as c FROM bible_verses');
    final notes = await widget.notesDb.query('notes');
    buffer.writeln('✅ Providers Riverpod opérationnels');
    buffer.writeln('Versets (via provider): ${verseCount.first['c']}');
    buffer.writeln('Notes en base (via provider): ${notes.length}');
    setState(() => _status = buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Text(_status, style: const TextStyle(fontFamily: 'monospace'));
  }
}