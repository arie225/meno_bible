import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../data/database_service.dart';
import '../data/bible_reference_data.dart';

final bibleDatabaseProvider = FutureProvider<Database>((ref) async {
  return DatabaseService.bibleDatabase;
});

final notesDatabaseProvider = FutureProvider<Database>((ref) async {
  return DatabaseService.notesDatabase;
});

final bibleReferenceDataProvider = FutureProvider<BibleReferenceData>((ref) async {
  final db = await ref.watch(bibleDatabaseProvider.future);
  return BibleReferenceData.loadFrom(db);
});