import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:milow_core/milow_core.dart';
import 'package:terminal/features/brokerage/domain/models/partner.dart';
import 'package:terminal/features/brokerage/domain/models/manifest.dart';
import 'package:terminal/features/brokerage/presentation/widgets/partner_entry_dialog.dart';
import 'package:terminal/features/brokerage/presentation/widgets/manifest_entry_dialog.dart';
import 'package:terminal/features/brokerage/presentation/providers/brokerage_providers.dart';
import 'package:terminal/features/brokerage/data/repositories/brokerage_repository.dart';
import '../helpers/mocks.mocks.dart';

void main() {
  group('PartnerEntryDialog Widget Tests', () {
    testWidgets('renders all fields and validation works', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Partner? savedPartner;

      await tester.pumpWidget(
        ProviderScope(
          child: FluentApp(
            home: ScaffoldPage(
              content: Builder(
                builder: (context) => Button(
                  child: const Text('Open'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => PartnerEntryDialog(
                        companyId: 'company-123',
                        onSave: (partner) async {
                          savedPartner = partner;
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check title
      expect(find.text('New Partner'), findsOneWidget);

      // Check fields exist
      expect(find.text('Partner Name *'), findsOneWidget);
      expect(find.text('MC Number'), findsOneWidget);
      expect(find.text('DOT Number'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextBox).first, 'Super Carrier LLC');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedPartner, isNotNull);
      expect(savedPartner!.name, 'Super Carrier LLC');
      expect(savedPartner!.companyId, 'company-123');
    });
  });

  group('ManifestEntryDialog Widget Tests', () {
    testWidgets('renders all fields and retrieves partners from provider', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Manifest? savedManifest;
      final mockPartners = [
        Partner(
          id: 'partner-id-123',
          companyId: 'company-123',
          name: 'Super Carrier LLC',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokerageRepositoryProvider.overrideWithValue(
              FakeBrokerageRepository(mockPartners: mockPartners),
            ),
          ],
          child: FluentApp(
            home: ScaffoldPage(
              content: Builder(
                builder: (context) => Button(
                  child: const Text('Open'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ManifestEntryDialog(
                        companyId: 'company-123',
                        onSave: (manifest) async {
                          savedManifest = manifest;
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check title
      expect(find.text('New Manifest'), findsOneWidget);
      expect(find.text('Agreed Cost *'), findsOneWidget);

      // Verify the partner dropdown contains loaded partner name
      expect(find.text('Super Carrier LLC'), findsOneWidget);

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedManifest, isNotNull);
      expect(savedManifest!.partnerId, 'partner-id-123');
      expect(savedManifest!.companyId, 'company-123');
    });
  });
}

class FakeBrokerageRepository extends BrokerageRepository {
  final List<Partner> mockPartners;
  final List<Manifest> mockManifests;

  FakeBrokerageRepository({
    this.mockPartners = const [],
    this.mockManifests = const [],
  }) : super(MockCoreNetworkClient());

  @override
  Future<Result<List<Partner>>> fetchPartners() async {
    return right(mockPartners);
  }

  @override
  Future<Result<List<Manifest>>> fetchManifests() async {
    return right(mockManifests);
  }
}

