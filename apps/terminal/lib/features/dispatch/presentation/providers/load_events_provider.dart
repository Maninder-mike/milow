import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import '../../../../core/providers/supabase_provider.dart';

final loadEventsStreamProvider = StreamProvider.family<List<LoadEvent>, String>((ref, loadId) {
  final supabase = ref.watch(supabaseClientProvider);
  
  return supabase
      .from('load_events')
      .stream(primaryKey: ['id'])
      .eq('load_id', loadId)
      .order('created_at', ascending: false)
      .map((events) => events.map((json) => LoadEvent.fromJson(json)).toList());
});
