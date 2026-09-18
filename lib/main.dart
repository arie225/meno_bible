import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/notes_list_screen.dart';

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
      home: const NotesListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}