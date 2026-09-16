import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart' show rootBundle;

class DatabaseService {
  static Database? _bibleDb;
  static Database? _notesDb;

  static const String _bibleDbName = 'bible.db';
  static const String _notesDbName = 'notes.db';

  // --- Base biblique : copiée une fois depuis les assets, lecture seule en pratique ---
  static Future<Database> get bibleDatabase async {
    if (_bibleDb != null) return _bibleDb!;
    _bibleDb = await _initBibleDatabase();
    return _bibleDb!;
  }

  static Future<Database> _initBibleDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _bibleDbName);

    final exists = await databaseExists(path);
    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}
      final data = await rootBundle.load('assets/$_bibleDbName');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(path, readOnly: true);
  }

  // --- Base des notes : créée vide sur l'appareil, jamais depuis un asset ---
  static Future<Database> get notesDatabase async {
    if (_notesDb != null) return _notesDb!;
    _notesDb = await _initNotesDatabase();
    return _notesDb!;
  }

  static Future<Database> _initNotesDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _notesDbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }
}