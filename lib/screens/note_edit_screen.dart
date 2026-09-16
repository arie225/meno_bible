import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_providers.dart';
import '../theme/app_colors.dart';
import 'notes_list_screen.dart';

class NoteEditScreen extends ConsumerStatefulWidget {
  final String? noteId;
  const NoteEditScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _loading = true;
  bool _hasBeenPersisted = false;
  late final String _id;
  Timer? _debounce;
  String _saveStatus = '';
  bool _isExiting = false; // évite un double-traitement si _flushSave est appelé deux fois

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _id = widget.noteId ?? _generateId();
    if (widget.noteId != null) {
      _hasBeenPersisted = true;
      _loadExistingNote();
    } else {
      _loading = false;
    }
    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  String _generateId() {
    final rand = Random();
    return List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  Future<void> _loadExistingNote() async {
    final db = await ref.read(notesDatabaseProvider.future);
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [_id]);
    if (rows.isNotEmpty) {
      _titleController.text = rows.first['title'] as String? ?? '';
      _contentController.text = rows.first['content'] as String;
    }
    setState(() => _loading = false);
  }

  bool get _isEmpty =>
      _titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty;

  void _onChanged() {
    _debounce?.cancel();
    setState(() => _saveStatus = 'Enregistrement...');
    _debounce = Timer(const Duration(milliseconds: 800), _autoSaveWhileTyping);
  }

  /// Sauvegarde déclenchée par le minuteur PENDANT la frappe.
  /// Ne supprime jamais — une note vidée temporairement (ex: sélection totale
  /// avant de retaper) ne doit pas disparaître tant que l'utilisateur est encore à l'écran.
  Future<void> _autoSaveWhileTyping() async {
    if (_isEmpty) {
      setState(() => _saveStatus = '');
      return;
    }
    await _writeToDb();
    if (mounted) setState(() => _saveStatus = 'Enregistré');
  }

  Future<void> _writeToDb() async {
    final db = await ref.read(notesDatabaseProvider.future);
    final now = DateTime.now().toIso8601String();

    if (!_hasBeenPersisted) {
      await db.insert('notes', {
        'id': _id,
        'title': _titleController.text.trim(),
        'content': _contentController.text,
        'created_at': now,
        'updated_at': now,
      });
      _hasBeenPersisted = true;
    } else {
      await db.update(
        'notes',
        {
          'title': _titleController.text.trim(),
          'content': _contentController.text,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [_id],
      );
    }
    ref.invalidate(notesListProvider);
  }

  /// Appelée uniquement à la SORTIE de l'écran (retour, bouton ✓, app en arrière-plan).
  /// C'est ici, et seulement ici, que la suppression d'une note vidée a lieu.
  Future<void> _finalizeAndExit() async {
    if (_isExiting) return;
    _isExiting = true;
    _debounce?.cancel();

    if (_isEmpty) {
      if (_hasBeenPersisted) {
        final db = await ref.read(notesDatabaseProvider.future);
        await db.delete('notes', where: 'id = ?', whereArgs: [_id]);
        ref.invalidate(notesListProvider);
      }
      // Sinon : note jamais créée et toujours vide, rien à faire.
    } else {
      await _writeToDb();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _finalizeAndExit();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _finalizeAndExit();
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.noteId == null ? 'Nouvelle note' : 'Modifier la note'),
          actions: [
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.rougePrincipal),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _saveStatus,
                style: const TextStyle(fontSize: 12, color: AppColors.grisDoux),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(
                  color: AppColors.bordeauxProfond,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                decoration: const InputDecoration(
                  hintText: 'Titre',
                  filled: false,
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: AppColors.rosePoudre, height: 24),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Écris ta note ici...',
                    filled: false,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}