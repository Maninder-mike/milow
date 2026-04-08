import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow/core/services/sync_status_provider.dart';

/// Service to handle Supabase Realtime subscriptions and sync them to local Drift DB.
class RealtimeSyncService {
  RealtimeSyncService._internal();
  static final RealtimeSyncService instance = RealtimeSyncService._internal();

  SupabaseClient? _client;
  final List<RealtimeChannel> _channels = [];
  bool _isInitialized = false;
  Timer? _statusTimer;

  /// Initialize and start listening to changes
  Future<void> init({SupabaseClient? supabaseClient}) async {
    if (_isInitialized) return;
    
    _client = supabaseClient ?? Supabase.instance.client;
    final userId = _client?.auth.currentUser?.id;
    
    if (userId == null) {
      debugPrint('[RealtimeSyncService] No user session, skipping subscription');
      return;
    }

    _isInitialized = true;
    
    // Subscribe to multiple tables
    _subscribeToTable('driver_trips', 'user_id=eq.$userId', _handleTripChange);
    _subscribeToTable('fuel_entries', 'user_id=eq.$userId', _handleFuelChange);
    _subscribeToTable('messages', 'receiver_id=eq.$userId', _handleMessageChange);
    _subscribeToTable('messages', 'sender_id=eq.$userId', _handleMessageChange);
    _subscribeToTable('announcements', '*', _handleAnnouncementChange);
    
    debugPrint('[RealtimeSyncService] Initialized and subscribed to realtime changes');
  }

  Future<void> _handleAnnouncementChange(PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id'] as String;
        // Use custom statement to avoid generated delete helper issues
        await driverDatabase.customStatement('DELETE FROM announcements WHERE id = ?', [id]);
      } else {
        final rec = payload.newRecord;
        // Manual insert using customStatement to avoid AnnouncementData dependency
        await driverDatabase.customStatement(
          '''INSERT OR REPLACE INTO announcements (id, title, content, company_id, author_name, created_at) 
             VALUES (?, ?, ?, ?, ?, ?)''',
          [
            rec['id'],
            rec['title'],
            rec['content'],
            rec['company_id'],
            rec['author_name'],
            DateTime.parse(rec['created_at']).millisecondsSinceEpoch ~/ 1000,
          ],
        );
      }
    } catch (e) {
      debugPrint('[RealtimeSyncService] Announcement sync error: $e');
    }
  }

  /// Subscribe to a specific table with filters
  void _subscribeToTable(
    String table, 
    String filter, 
    Future<void> Function(PostgresChangePayload) callback
  ) {
    if (_client == null) return;

    final channel = _client!.channel('public:$table:$filter')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) async {
            debugPrint('[RealtimeSyncService] $table change: ${payload.eventType}');
            _notifySyncing();
            await callback(payload);
          },
        )
        .subscribe();
    
    _channels.add(channel);
  }

  void _notifySyncing() {
    syncStatusProvider.startSync();
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 2), () {
      syncStatusProvider.completeSync();
    });
  }

  Future<void> _handleTripChange(PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id'] as String;
        await (driverDatabase.delete(driverDatabase.trips)..where((t) => t.id.equals(id))).go();
      } else {
        final data = TripData.fromJson(payload.newRecord);
        await driverDatabase.into(driverDatabase.trips).insertOnConflictUpdate(data);
      }
    } catch (e) {
      debugPrint('[RealtimeSyncService] Trip sync error: $e');
    }
  }

  Future<void> _handleFuelChange(PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id'] as String;
        await (driverDatabase.delete(driverDatabase.fuelEntries)..where((f) => f.id.equals(id))).go();
      } else {
        final data = FuelEntryData.fromJson(payload.newRecord);
        await driverDatabase.into(driverDatabase.fuelEntries).insertOnConflictUpdate(data);
      }
    } catch (e) {
      debugPrint('[RealtimeSyncService] Fuel sync error: $e');
    }
  }

  Future<void> _handleMessageChange(PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id'] as String;
        await (driverDatabase.delete(driverDatabase.messages)..where((m) => m.id.equals(id))).go();
      } else {
        final data = MessageData.fromJson(payload.newRecord);
        await driverDatabase.into(driverDatabase.messages).insertOnConflictUpdate(data);
      }
    } catch (e) {
      debugPrint('[RealtimeSyncService] Message sync error: $e');
    }
  }

  /// Stop all subscriptions
  void dispose() {
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();
    _statusTimer?.cancel();
    _isInitialized = false;
  }
}

final realtimeSyncService = RealtimeSyncService.instance;
