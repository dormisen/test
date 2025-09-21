// lib/screens/note_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final AuthService _auth = AuthService();
  final ImageService _imageService = ImageService();
  String _selectedCategory = 'General';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Color _selectedColor = Colors.white;
  List<String> _imageUrls = [];
  bool _isList = false;
  List<ListItem> _listItems = [];
  final TextEditingController _listItemController = TextEditingController();

  final List<String> _categories = [
    'General',
    'Work',
    'Personal',
    'Ideas',
    'Tasks',
  ];

  final List<Color> _colorOptions = [
    Colors.white,
    Colors.red.shade100,
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.yellow.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _selectedCategory = widget.note!.category;
      _selectedColor = widget.note!.color ?? Colors.white;
      _imageUrls = widget.note!.imageUrls;
      _isList = widget.note!.isList;
      _listItems = widget.note!.listItems;

      if (widget.note!.reminder != null) {
        final reminderDate = widget.note!.reminderDateTime!;
        _selectedDate = reminderDate;
        _selectedTime = TimeOfDay.fromDateTime(reminderDate);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _selectTime(context);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    final images = await _imageService.pickImages();
    if (images.isNotEmpty) {
      final user = _auth.currentUser;
      if (user != null) {
        final urls = await _imageService.uploadImages(images, user.uid);
        setState(() {
          _imageUrls.addAll(urls);
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageService.deleteImage(_imageUrls[index]);
      _imageUrls.removeAt(index);
    });
  }

  void _addListItem() {
    if (_listItemController.text.isNotEmpty) {
      setState(() {
        _listItems.add(ListItem(text: _listItemController.text));
        _listItemController.clear();
      });
    }
  }

  void _toggleListItem(int index) {
    setState(() {
      _listItems[index] = ListItem(
        text: _listItems[index].text,
        completed: !_listItems[index].completed,
      );
    });
  }

  void _removeListItem(int index) {
    setState(() {
      _listItems.removeAt(index);
    });
  }

  void _saveNote() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    Timestamp? reminder;
    if (_selectedDate != null && _selectedTime != null) {
      final reminderDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      reminder = Timestamp.fromDate(reminderDateTime);
    }

    final note = Note(
      id: widget.note?.id ?? '',
      title: _titleController.text,
      content: _contentController.text,
      category: _selectedCategory,
      pinned: widget.note?.pinned ?? false,
      reminder: reminder,
      createdAt: widget.note?.createdAt ?? Timestamp.now(),
      color: _selectedColor,
      userId: user.uid,
      status: widget.note?.status ?? NoteStatus.active,
      imageUrls: _imageUrls,
      isList: _isList,
      listItems: _listItems,
    );

    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveNote),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: "Title",
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // Toggle between text and list
            Row(
              children: [
                const Text('List Mode:'),
                const SizedBox(width: 8),
                Switch(
                  value: _isList,
                  onChanged: (value) => setState(() => _isList = value),
                ),
              ],
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            if (!_isList) ...[
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: "Start typing...",
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16),
            ] else ...[
              // List items
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('List Items:'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _listItemController,
                          decoration: const InputDecoration(
                            hintText: 'Add list item...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addListItem(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addListItem,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._listItems.asMap().entries.map(
                    (entry) => ListTile(
                      leading: Checkbox(
                        value: entry.value.completed,
                        onChanged: (_) => _toggleListItem(entry.key),
                      ),
                      title: Text(
                        entry.value.text,
                        style: entry.value.completed
                            ? TextStyle(decoration: TextDecoration.lineThrough)
                            : null,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _removeListItem(entry.key),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Image upload section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Images:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ..._imageUrls.asMap().entries.map(
                      (entry) => Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(entry.value),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => _removeImage(entry.key),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, size: 30),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context),
                    child: Text(
                      _selectedDate == null
                          ? "Set Reminder"
                          : "Date: ${_selectedDate!.toString().substring(0, 10)}",
                    ),
                  ),
                ),
                if (_selectedDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                        _selectedTime = null;
                      });
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Note Color:'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colorOptions.length,
                    itemBuilder: (context, index) {
                      final color = _colorOptions[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == color
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final note = Note(
                        id: widget.note?.id ?? '',
                        title: _titleController.text,
                        content: _contentController.text,
                        category: _selectedCategory,
                        pinned: widget.note?.pinned ?? false,
                        reminder: _selectedDate != null && _selectedTime != null
                            ? Timestamp.fromDate(
                                DateTime(
                                  _selectedDate!.year,
                                  _selectedDate!.month,
                                  _selectedDate!.day,
                                  _selectedTime!.hour,
                                  _selectedTime!.minute,
                                ),
                              )
                            : null,
                        createdAt: widget.note?.createdAt ?? Timestamp.now(),
                        color: _selectedColor,
                        userId: _auth.currentUser?.uid ?? '',
                        status: NoteStatus.archived,
                        imageUrls: _imageUrls,
                        isList: _isList,
                        listItems: _listItems,
                      );
                      Navigator.pop(context, note);
                    },
                    child: const Text('Archive'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final note = Note(
                        id: widget.note?.id ?? '',
                        title: _titleController.text,
                        content: _contentController.text,
                        category: _selectedCategory,
                        pinned: widget.note?.pinned ?? false,
                        reminder: _selectedDate != null && _selectedTime != null
                            ? Timestamp.fromDate(
                                DateTime(
                                  _selectedDate!.year,
                                  _selectedDate!.month,
                                  _selectedDate!.day,
                                  _selectedTime!.hour,
                                  _selectedTime!.minute,
                                ),
                              )
                            : null,
                        createdAt: widget.note?.createdAt ?? Timestamp.now(),
                        color: _selectedColor,
                        userId: _auth.currentUser?.uid ?? '',
                        status: NoteStatus.trashed,
                        imageUrls: _imageUrls,
                        isList: _isList,
                        listItems: _listItems,
                      );
                      Navigator.pop(context, note);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Move to Trash'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
