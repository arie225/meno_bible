import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_providers.dart';
import '../theme/app_colors.dart';
import '../tag/verse_tag_formatter.dart';
import '../tag/verse_tag_notifier.dart';
import '../tag/verse_tag_state.dart';
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
  final _contentFocusNode = FocusNode();
  bool _loading = true;
  bool _hasBeenPersisted = false;
  late final String _id;
  Timer? _debounce;
  String _saveStatus = '';
  bool _isExiting = false;
  TextEditingValue? _lastContentValue;

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
    _contentController.addListener(_onContentValueChanged);

    // Annulation du tag actif si le champ de contenu perd le focus
    // (clic ailleurs, ou passage au champ titre) — étape 7 du composant de tag.
    _contentFocusNode.addListener(() {
      if (!_contentFocusNode.hasFocus) {
        final tagState = ref.read(verseTagProvider);
        if (tagState.isActive) {
          ref.read(verseTagProvider.notifier).cancel();
        }
      }
    });
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

  void _onContentValueChanged() {
    final current = _contentController.value;
    final previous = _lastContentValue;
    _lastContentValue = current;

    if (previous == null) return;

    final textUnchanged = current.text == previous.text;
    final selectionChanged = current.selection != previous.selection;

    if (textUnchanged && selectionChanged) {
      final tagState = ref.read(verseTagProvider);
      if (tagState.isActive) {
        ref.read(verseTagProvider.notifier).cancel();
      }
    }
  }

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
    _contentFocusNode.dispose();
    super.dispose();
  }

  // --- Logique du tag @verset ---

  void _onBookSelected(int bookId, String bookName) {
    final tagState = ref.read(verseTagProvider);
    final offset = tagState.tagStartOffset;
    final text = _contentController.text;
    final cursor = _contentController.selection.baseOffset;

    final before = text.substring(0, offset);
    final after = (cursor >= 0 && cursor <= text.length) ? text.substring(cursor) : '';
    final newText = '$before@$bookName $after';
    final newCursorPos = before.length + 1 + bookName.length + 1;

    _contentController.value = TextEditingValue(
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

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    ref.read(verseTagProvider.notifier).cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tagState = ref.watch(verseTagProvider);
    final refDataAsync = ref.watch(bibleReferenceDataProvider);

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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_saveStatus, style: const TextStyle(fontSize: 12, color: AppColors.grisDoux)),
            ),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
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
                  child: Stack(
                    children: [
                      TextField(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        inputFormatters: [
                          VerseTagFormatter(
                            onTagStart: (o) => ref.read(verseTagProvider.notifier).startTag(o),
                            onQueryChanged: (q) => ref.read(verseTagProvider.notifier).updateQuery(q),
                            onChapterConfirmed: (ch, off) =>
                                ref.read(verseTagProvider.notifier).confirmChapter(ch, off),
                            onVerseStartChanged: (v) =>
                                ref.read(verseTagProvider.notifier).updateVerseStart(v),
                            onVerseEndStarted: (o) =>
                                ref.read(verseTagProvider.notifier).confirmVerseEndStart(o),
                            onVerseEndChanged: (v) =>
                                ref.read(verseTagProvider.notifier).updateVerseEnd(v),
                            onCancel: () => ref.read(verseTagProvider.notifier).cancel(),
                            onRevertToChapter: () =>
                                ref.read(verseTagProvider.notifier).revertToEditingChapter(),
                            onRevertToVerseStart: () =>
                                ref.read(verseTagProvider.notifier).revertToEditingVerseStart(),
                            onRejected: _showRejection,
                            onEnterPressed: (text, cursor) => _handleEnterPressed(text, cursor),
                            getState: () => ref.read(verseTagProvider),
                            getRefData: () => refDataAsync.value,
                          ),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Écris ta note ici... (tape "@" pour insérer un verset)',
                          filled: false,
                          border: InputBorder.none,
                        ),
                      ),
                      if (tagState.state == TagState.searchingBook)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: refDataAsync.when(
                            data: (refData) {
                              final ids = refData.filterBooks(tagState.bookQuery);
                              return Container(
                                constraints: const BoxConstraints(maxHeight: 220),
                                decoration: BoxDecoration(
                                  color: AppColors.bleuCielDoux,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: ids.isEmpty
                                    ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Aucun livre trouvé',
                                      style: TextStyle(color: AppColors.grisDoux)),
                                )
                                    : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: ids.length,
                                  itemBuilder: (context, index) {
                                    final id = ids[index];
                                    final name = refData.bookNameById[id]!;
                                    return ListTile(
                                      title: Text(name,
                                          style: const TextStyle(color: AppColors.bordeauxProfond)),
                                      onTap: () => _onBookSelected(id, name),
                                    );
                                  },
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (e, _) => const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}