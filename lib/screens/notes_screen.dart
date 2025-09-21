// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/avatar_service.dart';
import '../models/note.dart';
import '../models/user_profile.dart';
import 'note_editor_screen.dart';
import 'profile_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final AuthService _auth = AuthService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  UserProfile? _userProfile;
  bool _loadingProfile = true;
  NoteStatus _currentView = NoteStatus.active;

  @override
  void initState() {
    super.initState();
    _notificationService.init();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final profile = await _auth.getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _loadingProfile = false;
        });
      }
    }
  }

  Future<void> _addOrUpdateNote(Note note) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = note.toJson();
    data['updatedAt'] = Timestamp.now();
    data['userId'] = user.uid;

    if (note.id.isEmpty) {
      await _firestore.collection('notes').add(data);
    } else {
      await _firestore.collection('notes').doc(note.id).update(data);
    }

    await _notificationService.cancelAllNotifications();

    if (note.reminder != null) {
      final reminderDateTime = note.reminder!.toDate();
      if (reminderDateTime.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotification(
          note.title,
          note.content,
          reminderDateTime,
        );
      }
    }
  }

  Future<void> _deleteNotePermanently(Note note) async {
    if (note.id.isNotEmpty) {
      // Delete associated images first
      for (final imageUrl in note.imageUrls) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          // Use debugPrint instead of print
          debugPrint('Error deleting image: $e');
        }
      }
      
      await _firestore.collection('notes').doc(note.id).delete();
      await _notificationService.cancelAllNotifications();
    }
  }

  Future<void> _moveToTrash(Note note) async {
    final updatedNote = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      category: note.category,
      pinned: note.pinned,
      reminder: note.reminder,
      createdAt: note.createdAt,
      updatedAt: Timestamp.now(),
      color: note.color,
      userId: note.userId,
      status: NoteStatus.trashed,
      imageUrls: note.imageUrls,
      isList: note.isList,
      listItems: note.listItems,
    );
    
    await _addOrUpdateNote(updatedNote);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Moved '${note.title}' to trash")),
      );
    }
  }

  Future<void> _archiveNote(Note note) async {
    final updatedNote = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      category: note.category,
      pinned: note.pinned,
      reminder: note.reminder,
      createdAt: note.createdAt,
      updatedAt: Timestamp.now(),
      color: note.color,
      userId: note.userId,
      status: NoteStatus.archived,
      imageUrls: note.imageUrls,
      isList: note.isList,
      listItems: note.listItems,
    );
    
    await _addOrUpdateNote(updatedNote);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Archived '${note.title}'")),
      );
    }
  }

  Future<void> _restoreNote(Note note) async {
    final updatedNote = Note(
      id: note.id,
      title: note.title,
      content: note.content,
      category: note.category,
      pinned: note.pinned,
      reminder: note.reminder,
      createdAt: note.createdAt,
      updatedAt: Timestamp.now(),
      color: note.color,
      userId: note.userId,
      status: NoteStatus.active,
      imageUrls: note.imageUrls,
      isList: note.isList,
      listItems: note.listItems,
    );
    
    await _addOrUpdateNote(updatedNote);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Restored '${note.title}'")),
      );
    }
  }

  void _openNoteEditor({Note? note}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorScreen(note: note)),
    );

    if (result != null && result is Note && mounted) {
      await _addOrUpdateNote(result);
    }
  }

  void _showNoteOptions(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _openNoteEditor(note: note);
                },
              ),
              if (note.status == NoteStatus.active) ...[
                ListTile(
                  leading: const Icon(Icons.archive),
                  title: const Text('Archive'),
                  onTap: () {
                    Navigator.pop(context);
                    _archiveNote(note);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Move to Trash'),
                  onTap: () {
                    Navigator.pop(context);
                    _moveToTrash(note);
                  },
                ),
              ],
              if (note.status == NoteStatus.archived) ...[
                ListTile(
                  leading: const Icon(Icons.unarchive),
                  title: const Text('Unarchive'),
                  onTap: () {
                    Navigator.pop(context);
                    _restoreNote(note);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Move to Trash'),
                  onTap: () {
                    Navigator.pop(context);
                    _moveToTrash(note);
                  },
                ),
              ],
              if (note.status == NoteStatus.trashed) ...[
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore'),
                  onTap: () {
                    Navigator.pop(context);
                    _restoreNote(note);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('Delete Permanently'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context, note);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permanently Delete Note"),
          content: const Text("Are you sure you want to permanently delete this note? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteNotePermanently(note);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Permanently deleted '${note.title}'")),
                  );
                }
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoteCard(Note note) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: note.color ?? Colors.white,
      child: InkWell(
        onTap: () => _openNoteEditor(note: note),
        onLongPress: () => _showNoteOptions(context, note),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        decoration: note.pinned
                            ? TextDecoration.underline
                            : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.pinned)
                    const Icon(Icons.push_pin, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              
              if (note.isList && note.listItems.isNotEmpty)
                _buildListPreview(note.listItems),
              else
                Text(
                  note.content.length > 100
                      ? '${note.content.substring(0, 100)}...'
                      : note.content,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              
              if (note.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: note.imageUrls.length,
                    itemBuilder: (context, index) => Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(note.imageUrls[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (note.reminder != null)
                    Chip(
                      label: Text(
                        "Reminder: ${note.reminderDateTime!.toString().substring(0, 16)}",
                      ),
                      backgroundColor: Colors.blue[50],
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                  if (note.category.isNotEmpty && note.category != 'General')
                    Chip(
                      label: Text(note.category),
                      backgroundColor: Colors.deepPurple.withOpacity(0.1),
                    ),
                  if (note.status == NoteStatus.archived)
                    Chip(
                      label: const Text('Archived'),
                      backgroundColor: Colors.orange[100],
                    ),
                  if (note.status == NoteStatus.trashed)
                    Chip(
                      label: const Text('Trash'),
                      backgroundColor: Colors.red[100],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListPreview(List<ListItem> listItems) {
    final visibleItems = listItems.take(3).toList();
    final remainingCount = listItems.length - 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleItems.map((item) => Row(
          children: [
            Icon(
              item.completed ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.text,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  decoration: item.completed ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        )),
        if (remainingCount > 0)
          Text(
            '+ $remainingCount more items',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildViewSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<NoteStatus>(
        segments: const [
          ButtonSegment<NoteStatus>(
            value: NoteStatus.active,
            label: Text('Active'),
            icon: Icon(Icons.note, size: 16),
          ),
          ButtonSegment<NoteStatus>(
            value: NoteStatus.archived,
            label: Text('Archived'),
            icon: Icon(Icons.archive, size: 16),
          ),
          ButtonSegment<NoteStatus>(
            value: NoteStatus.trashed,
            label: Text('Trash'),
            icon: Icon(Icons.delete, size: 16),
          ),
        ],
        selected: {_currentView},
        onSelectionChanged: (Set<NoteStatus> newSelection) {
          setState(() {
            _currentView = newSelection.first;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final avatarUrl = _userProfile?.photoUrl ?? 
        AvatarService.generateAvatarUrl(_userProfile?.email ?? 'user', size: 120);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Notes"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Search Notes"),
                  content: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: "Search notes...",
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _loadingProfile
                  ? const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16))
                  : CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(avatarUrl),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // View Selector
          _buildViewSelector(),
          
          // Search and Filter Row
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search notes...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'All', child: Text('All Categories')),
                    const PopupMenuItem(value: 'Work', child: Text('Work')),
                    const PopupMenuItem(value: 'Personal', child: Text('Personal')),
                    const PopupMenuItem(value: 'Ideas', child: Text('Ideas')),
                    const PopupMenuItem(value: 'Tasks', child: Text('Tasks')),
                  ],
                  child: Chip(
                    label: Text(_selectedCategory),
                    avatar: const Icon(Icons.filter_list, size: 16),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notes')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final notes = snapshot.data!.docs
                    .map((doc) => Note.fromDoc(doc))
                    .where((note) {
                      // Filter by current view status
                      if (note.status != _currentView) {
                        return false;
                      }

                      // Filter by search query
                      if (_searchQuery.isNotEmpty &&
                          !note.title.toLowerCase().contains(_searchQuery) &&
                          !note.content.toLowerCase().contains(_searchQuery)) {
                        return false;
                      }

                      // Filter by category
                      if (_selectedCategory != 'All' &&
                          note.category != _selectedCategory) {
                        return false;
                      }

                      return true;
                    })
                    .toList();

                if (notes.isEmpty) {
                  return _buildEmptySearchState();
                }

                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Dismissible(
                      key: Key('${note.id}-${note.status}'),
                      background: _buildDismissibleBackground(note.status),
                      secondaryBackground: _buildDismissibleSecondaryBackground(note.status),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          return await _showDismissConfirmation(context, note, direction);
                        }
                        return await _showDismissConfirmation(context, note, direction);
                      },
                      onDismissed: (direction) {
                        _handleDismissAction(direction, note);
                      },
                      child: _buildNoteCard(note),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _currentView == NoteStatus.active
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => _openNoteEditor(),
            )
          : null,
    );
  }

  Widget _buildDismissibleBackground(NoteStatus status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case NoteStatus.active:
        color = Colors.orange;
        icon = Icons.archive;
        break;
      case NoteStatus.archived:
        color = Colors.green;
        icon = Icons.unarchive;
        break;
      case NoteStatus.trashed:
        color = Colors.green;
        icon = Icons.restore;
        break;
    }
    
    return Container(
      color: color,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _buildDismissibleSecondaryBackground(NoteStatus status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case NoteStatus.active:
      case NoteStatus.archived:
        color = Colors.red;
        icon = Icons.delete;
        break;
      case NoteStatus.trashed:
        color = Colors.red;
        icon = Icons.delete_forever;
        break;
    }
    
    return Container(
      color: color,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }

  Future<bool?> _showDismissConfirmation(BuildContext context, Note note, DismissDirection direction) {
    String message;
    String confirmText;
    
    if (direction == DismissDirection.startToEnd) {
      if (note.status == NoteStatus.active) {
        message = "Archive this note?";
        confirmText = "Archive";
      } else if (note.status == NoteStatus.archived) {
        message = "Restore this note?";
        confirmText = "Restore";
      } else {
        message = "Restore this note from trash?";
        confirmText = "Restore";
      }
    } else {
      if (note.status == NoteStatus.trashed) {
        message = "Permanently delete this note?";
        confirmText = "Delete";
      } else {
        message = "Move this note to trash?";
        confirmText = "Move to Trash";
      }
    }
    
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Action"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: direction == DismissDirection.endToStart ? Colors.red : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleDismissAction(DismissDirection direction, Note note) {
    if (direction == DismissDirection.startToEnd) {
      // Swipe left to right
      if (note.status == NoteStatus.active) {
        _archiveNote(note);
      } else if (note.status == NoteStatus.archived || note.status == NoteStatus.trashed) {
        _restoreNote(note);
      }
    } else {
      // Swipe right to left
      if (note.status == NoteStatus.trashed) {
        _deleteNotePermanently(note);
      } else {
        _moveToTrash(note);
      }
    }
  }

  Widget _buildEmptyState() {
    String message;
    String subtitle;
    IconData icon;
    
    switch (_currentView) {
      case NoteStatus.active:
        message = "No notes yet";
        subtitle = "Tap the + button to create your first note";
        icon = Icons.note_add;
        break;
      case NoteStatus.archived:
        message = "No archived notes";
        subtitle = "Archive notes to see them here";
        icon = Icons.archive;
        break;
      case NoteStatus.trashed:
        message = "Trash is empty";
        subtitle = "Deleted notes will appear here";
        icon = Icons.delete;
        break;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No notes found",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const Text(
            "Try adjusting your search or filter",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}