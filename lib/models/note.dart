// lib/models/note.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum NoteStatus { active, archived, trashed }

class Note {
  String id;
  String title;
  String content;
  String category;
  bool pinned;
  Timestamp? reminder;
  Timestamp createdAt;
  Timestamp? updatedAt;
  Color? color;
  String userId;
  NoteStatus status;
  List<String> imageUrls;
  bool isList;
  List<ListItem> listItems;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.category = "General",
    this.pinned = false,
    this.reminder,
    required this.createdAt,
    this.updatedAt,
    this.color,
    required this.userId,
    this.status = NoteStatus.active,
    this.imageUrls = const [],
    this.isList = false,
    this.listItems = const [],
  });

  int? get colorValue => color?.value;

  DateTime? get reminderDateTime => reminder?.toDate();

  Map<String, dynamic> toJson() => {
    "title": title,
    "content": content,
    "category": category,
    "pinned": pinned,
    "reminder": reminder,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "color": color?.value,
    "userId": userId,
    "status": status.toString().split('.').last,
    "imageUrls": imageUrls,
    "isList": isList,
    "listItems": listItems.map((item) => item.toJson()).toList(),
  };

  static Note fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? 'General',
      pinned: data['pinned'] ?? false,
      reminder: data['reminder'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
      color: data['color'] != null ? Color(data['color']) : null,
      userId: data['userId'] ?? '',
      status: NoteStatus.values.firstWhere(
        (e) =>
            e.toString() == 'NoteStatus.${data['status']}' ||
            (data['status'] == null && e == NoteStatus.active),
        orElse: () => NoteStatus.active,
      ),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      isList: data['isList'] ?? false,
      listItems: List<Map<String, dynamic>>.from(
        data['listItems'] ?? [],
      ).map((item) => ListItem.fromJson(item)).toList(),
    );
  }
}

class ListItem {
  String text;
  bool completed;

  ListItem({required this.text, this.completed = false});

  Map<String, dynamic> toJson() => {'text': text, 'completed': completed};

  static ListItem fromJson(Map<String, dynamic> json) =>
      ListItem(text: json['text'] ?? '', completed: json['completed'] ?? false);
}
