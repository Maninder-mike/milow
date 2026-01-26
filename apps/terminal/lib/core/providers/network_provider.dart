import 'package:milow_core/milow_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'supabase_provider.dart';

part 'network_provider.g.dart';

@Riverpod(keepAlive: true)
CoreNetworkClient coreNetworkClient(Ref ref) {
  return CoreNetworkClient(ref.watch(supabaseClientProvider));
}
