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
  final _contentScrollController = ScrollController();
  final _contentFieldKey = GlobalKey();
  final _tagLayerLink = LayerLink();

  // Style EXACT du TextField de contenu — doit rester synchronisé avec la
  // décoration/texte du champ ci-dessous, sinon le calcul de position du
  // curseur (TextPainter) sera décalé par rapport à l'affichage réel.
  static const _contentTextStyle = TextStyle(fontSize: 16, color: Colors.black87);

  bool _loading = true;
  bool _hasBeenPersisted = false;
  late final String _id;
  Timer? _debounce;
  String _saveStatus = '';
  bool _isExiting = false;
  TextEditingValue? _lastContentValue;

  OverlayEntry? _tagOverlayEntry;
  Offset _caretOverlayOffset = Offset.zero;

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

  /// Distinct de _onChanged : gère l'annulation du tag sur simple
  /// repositionnement du curseur (texte inchangé), et repositionne la liste
  /// de suggestions à chaque frappe pendant la recherche d'un livre.
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
      return;
    }

    final tagState = ref.read(verseTagProvider);
    if (tagState.state == TagState.searchingBook) {
      _updateCaretOverlayPosition();
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

  // --- Positionnement précis de l'overlay au curseur ---

  Offset _computeCaretLocalOffset() {
    final renderBox = _contentFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return Offset.zero;

    final text = _contentController.text;
    final cursor = _contentController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return Offset.zero;

    final upToCursor = text.substring(0, cursor);
    final fieldWidth = renderBox.size.width;

    final painter = TextPainter(
      text: TextSpan(text: upToCursor, style: _contentTextStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: fieldWidth);

    final caretOffset = painter.getOffsetForCaret(
      TextPosition(offset: upToCursor.length),
      Rect.zero,
    );

    final scrollOffset = _contentScrollController.hasClients ? _contentScrollController.offset : 0.0;
    final lineHeight = painter.preferredLineHeight;

    const overlayWidth = 260.0;
    final maxDx = fieldWidth - overlayWidth;
    final dx = caretOffset.dx.clamp(0.0, maxDx < 0 ? 0.0 : maxDx);

    return Offset(dx, caretOffset.dy - scrollOffset + lineHeight + 4);
  }

  void _updateCaretOverlayPosition() {
    _caretOverlayOffset = _computeCaretLocalOffset();
    _tagOverlayEntry?.markNeedsBuild();
  }

  void _showBookOverlay() {
    _caretOverlayOffset = _computeCaretLocalOffset();
    _tagOverlayEntry = OverlayEntry(
      builder: (context) {
        return CompositedTransformFollower(
            link: _tagLayerLink,
            showWhenUnlinked: false,
            offset: _caretOverlayOffset,
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                color: AppColors.bleuCielDoux,
                child: Consumer(
                  builder: (context, ref, _) {
                    // ... reste identique, inchangé
                final tagState = ref.watch(verseTagProvider);
                final refDataAsync = ref.watch(bibleReferenceDataProvider);
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 260, minWidth: 260),
                  child: refDataAsync.when(
                    data: (refData) {
                      final ids = refData.filterBooks(tagState.bookQuery);
                      if (ids.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Aucun livre trouvé', style: TextStyle(color: AppColors.grisDoux)),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: ids.length,
                        itemBuilder: (context, index) {
                          final id = ids[index];
                          final name = refData.bookNameById[id]!;
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            title: Text(name, style: const TextStyle(color: AppColors.bordeauxProfond, fontSize: 20)),
                            onTap: () => _onBookSelected(id, name),
                          );
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        )
        );
      },
    );
    Overlay.of(context).insert(_tagOverlayEntry!);
  }

  void _removeBookOverlay() {
    _tagOverlayEntry?.remove();
    _tagOverlayEntry = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _removeBookOverlay();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _contentScrollController.dispose();
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

    // Gère l'ouverture/fermeture de l'overlay en réaction aux transitions
    // d'état — pas dans _onContentValueChanged, pour couvrir aussi les
    // transitions déclenchées sans frappe (ex: sélection d'un livre au tap).
    ref.listen<VerseTagState>(verseTagProvider, (previous, next) {
      final wasSearching = previous?.state == TagState.searchingBook;
      final isSearching = next.state == TagState.searchingBook;
      if (isSearching && !wasSearching) {
        _showBookOverlay();
      } else if (!isSearching && wasSearching) {
        _removeBookOverlay();
      }
    });

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
                  child: CompositedTransformTarget(
                    link: _tagLayerLink,
                    child: TextField(
                      key: _contentFieldKey,
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      scrollController: _contentScrollController,
                      style: _contentTextStyle,
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
                          getRefData: () => ref.read(bibleReferenceDataProvider).value,
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Écris ta note ici... (tape "@" pour insérer un verset)',
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
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