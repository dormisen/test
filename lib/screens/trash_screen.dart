// lib/screens/trash_screen.dart
import 'package:flutter/material.dart';
import 'notes_screen.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trash')),
      body:
          const NotesScreen(), // This would be modified to show only trashed notes
    );
  }
}
