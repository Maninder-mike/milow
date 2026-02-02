import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:milow/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('App startup performance test', (tester) async {
    await binding.traceAction(() async {
      await app.main();
      await tester.pumpAndSettle();
    }, reportKey: 'startup_profile');
  });
}
