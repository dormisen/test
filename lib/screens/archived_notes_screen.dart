// lib/screens/archived_notes_screen.dart
import 'package:flutter/material.dart';
import 'notes_screen.dart';

class ArchivedNotesScreen extends StatelessWidget {
  const ArchivedNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Notes')),
      body:
          const NotesScreen(), // This would be modified to show only archived notes
    );
  }
}
