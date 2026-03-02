import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Announcement {
  final String id;
  final String title;
  final String body;
  final String? companyId;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.companyId,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Announcement',
      body: json['body'] as String? ?? '',
      companyId: json['company_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AnnouncementsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Announcement> _announcements = [];
  StreamSubscription? _subscription;
  bool _isLoading = true;

  List<Announcement> get announcements => _announcements;
  bool get isLoading => _isLoading;
  Announcement? get latestAnnouncement => _announcements.isNotEmpty ? _announcements.first : null;

  void init(String? companyId) {
    if (companyId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _subscription?.cancel();

    // 1. Initial fetch
    _fetchAnnouncements(companyId);

    // 2. Realtime subscription
    _subscription = _supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .listen((data) {
          _announcements = data.map((json) => Announcement.fromJson(json)).toList();
          _isLoading = false;
          notifyListeners();
        }, onError: (error) {
          debugPrint('Error in announcements stream: $error');
          _isLoading = false;
          notifyListeners();
        });
  }

  Future<void> _fetchAnnouncements(String companyId) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false);

      _announcements = (response as List).map((json) => Announcement.fromJson(json)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
