import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:drift/drift.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final String? companyId;
  final String? authorName;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.companyId,
    this.authorName,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Announcement',
      content: json['content'] as String? ?? '',
      companyId: json['company_id'] as String?,
      authorName: json['author_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory Announcement.fromData(QueryRow row) {
    return Announcement(
      id: row.read<String>('id'),
      title: row.read<String>('title'),
      content: row.read<String>('content'),
      companyId: row.read<String?>('company_id'),
      authorName: row.read<String?>('author_name'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at') * 1000,
      ),
    );
  }
}

class AnnouncementsProvider extends ChangeNotifier {
  final DriverDatabase _db;
  List<Announcement> _announcements = [];
  StreamSubscription? _subscription;
  bool _isLoading = true;

  AnnouncementsProvider(this._db);

  List<Announcement> get announcements => _announcements;
  bool get isLoading => _isLoading;
  Announcement? get latestAnnouncement =>
      _announcements.isNotEmpty ? _announcements.first : null;

  void init(String? companyId) {
    if (companyId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _subscription?.cancel();
    _subscription = watchAnnouncements(companyId).listen((data) {
      _announcements = data;
      _isLoading = false;
      notifyListeners();
    });
  }

  Stream<List<Announcement>> watchAnnouncements(String companyId) {
    return _db
        .customSelect(
          'SELECT * FROM announcements WHERE company_id = ? ORDER BY created_at DESC',
          variables: [Variable(companyId)],
          readsFrom: {_db.messages}, // Hack: Messages exists, so it triggers watch
        )
        .watch()
        .map((rows) => rows.map((r) => Announcement.fromData(r)).toList());
  }


  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
