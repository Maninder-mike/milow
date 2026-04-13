import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow/core/services/notification_service.dart';

class CheckCallService extends ChangeNotifier {
  final SupabaseClient _supabase;
  StreamSubscription? _realtimeSubscription;
  
  List<CheckCall> _pendingCheckCalls = [];
  List<CheckCall> get pendingCheckCalls => _pendingCheckCalls;

  CheckCallService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client {
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _subscribeToRealtime();
        _fetchInitialPending();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _realtimeSubscription?.cancel();
        _pendingCheckCalls = [];
        notifyListeners();
      }
    });
  }

  Future<void> _fetchInitialPending() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final response = await _supabase
          .from('check_calls')
          .select()
          .eq('driver_id', myId)
          .eq('status', 'pending');

      _pendingCheckCalls = (response as List)
          .map((json) => CheckCall.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching pending check-calls: $e');
    }
  }

  void _subscribeToRealtime() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    _realtimeSubscription?.cancel();
    _realtimeSubscription = _supabase
        .from('check_calls')
        .stream(primaryKey: ['id'])
        .eq('driver_id', myId)
        .listen(
          (data) async {
            final calls = data.map((json) => CheckCall.fromJson(json)).where((c) => c.status == CheckCallStatus.pending).toList();
            
            // Check for new calls to notify
            for (final call in calls) {
              if (!_pendingCheckCalls.any((p) => p.id == call.id)) {
                unawaited(notificationService.showNotification(
                  id: call.id.hashCode,
                  title: 'Check-Call Request',
                  body: call.prompt,
                  type: NotificationType.loadStatusChanged,
                  payload: 'loadId: ${call.loadId}',
                ));
              }
            }

            _pendingCheckCalls = calls;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('CheckCall Realtime Error: $error');
          },
        );
  }

  Future<Either<Failure, CheckCall>> submitResponse(String checkCallId, Map<String, dynamic> responseData) async {
    try {
      final response = await _supabase.from('check_calls').update({
        'status': 'completed',
        'response_data': responseData,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', checkCallId).select().single();
      
      _pendingCheckCalls.removeWhere((c) => c.id == checkCallId);
      notifyListeners();
      
      return right(CheckCall.fromJson(response));
    } catch (e, stack) {
      await logger.error('CheckCallService', 'Error submitting response', error: e, stackTrace: stack);
      return left(const ServerFailure(
        'Failed to submit check-call response',
      ));
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
