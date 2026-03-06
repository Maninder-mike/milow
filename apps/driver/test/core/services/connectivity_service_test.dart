import 'dart:async';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:milow/core/services/connectivity_service.dart';

class FakeConnectivity extends Fake
    with MockPlatformInterfaceMixin
    implements ConnectivityPlatform {
  List<ConnectivityResult> _currentStatus = [ConnectivityResult.wifi];
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  void setStatus(List<ConnectivityResult> results) {
    _currentStatus = results;
    _controller.add(results);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _currentStatus;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;
}

void main() {
  late FakeConnectivity fakeConnectivity;
  late ConnectivityService connectivityService;

  setUp(() {
    fakeConnectivity = FakeConnectivity();
    ConnectivityPlatform.instance = fakeConnectivity;

    // Instantiate a fresh testing instance.
    connectivityService = ConnectivityService.testing();
  });

  tearDown(() {
    connectivityService.dispose();
  });

  group('ConnectivityService Tests', () {
    test('init updates status to online via Wi-Fi', () async {
      fakeConnectivity.setStatus([ConnectivityResult.wifi]);

      expect(connectivityService.isOnline, true); // true by default

      await connectivityService.init();
      expect(connectivityService.isOnline, true);
    });

    test('init updates status to offline if no connection', () async {
      fakeConnectivity.setStatus([ConnectivityResult.none]);

      await connectivityService.init();
      expect(connectivityService.isOnline, false);
    });

    test('stream emits changes when connection changes', () async {
      // Start online
      fakeConnectivity.setStatus([ConnectivityResult.mobile]);
      await connectivityService.init();
      expect(connectivityService.isOnline, true);

      // Listen to the stream
      final events = <bool>[];
      final subscription = connectivityService.onConnectivityChanged.listen((
        online,
      ) {
        events.add(online);
      });

      // Change to offline
      fakeConnectivity.setStatus([ConnectivityResult.none]);
      // Give stream time to emit
      await Future.delayed(Duration.zero);
      expect(connectivityService.isOnline, false);

      // Change back to online
      fakeConnectivity.setStatus([ConnectivityResult.wifi]);
      await Future.delayed(Duration.zero);
      expect(connectivityService.isOnline, true);

      // Same status shouldn't emit an event again
      fakeConnectivity.setStatus([ConnectivityResult.ethernet]);
      await Future.delayed(Duration.zero);

      expect(events, [false, true]); // went offline, then went online

      await subscription.cancel();
    });

    test('checkConnectivity fetches latest status', () async {
      fakeConnectivity.setStatus([ConnectivityResult.none]);

      final isOnline = await connectivityService.checkConnectivity();
      expect(isOnline, false);
      expect(connectivityService.isOnline, false);
    });

    test('waitForConnectivity returns immediately if already online', () async {
      fakeConnectivity.setStatus([ConnectivityResult.wifi]);
      await connectivityService.init();

      // If it doesn't hang, it completed successfully
      await connectivityService.waitForConnectivity().timeout(
        const Duration(milliseconds: 100),
      );
      expect(connectivityService.isOnline, true);
    });

    test('waitForConnectivity waits until status changes to online', () async {
      fakeConnectivity.setStatus([ConnectivityResult.none]);
      await connectivityService.init();
      expect(connectivityService.isOnline, false);

      bool completed = false;
      unawaited(
        connectivityService.waitForConnectivity().then((_) {
          completed = true;
        }),
      );

      expect(completed, false); // shouldn't complete yet since it's offline

      // Change status
      fakeConnectivity.setStatus([ConnectivityResult.mobile]);
      await Future.delayed(Duration.zero); // allow stream execution

      // Need a bit more time for the Completer inside 'firstWhere' to resolve
      await Future.delayed(const Duration(milliseconds: 10));
      expect(completed, true);
    });
  });
}
