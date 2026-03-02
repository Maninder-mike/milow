import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/announcements_provider.dart';
import 'package:milow/features/inbox/presentation/widgets/announcements_list_view.dart';

class MockAnnouncementsProvider extends Mock implements AnnouncementsProvider {}

void main() {
  late MockAnnouncementsProvider mockProvider;

  setUp(() {
    mockProvider = MockAnnouncementsProvider();

    // Default stubs
    when(() => mockProvider.isLoading).thenReturn(false);
    when(() => mockProvider.announcements).thenReturn([]);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: ThemeData(extensions: [DesignTokens.light]),
      home: Scaffold(
        body: ChangeNotifierProvider<AnnouncementsProvider>.value(
          value: mockProvider,
          child: const AnnouncementsListView(),
        ),
      ),
    );
  }

  group('AnnouncementsListView Tests', () {
    testWidgets('renders loading indicator when loading and empty', (
      tester,
    ) async {
      when(() => mockProvider.isLoading).thenReturn(true);
      when(() => mockProvider.announcements).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state when no announcements', (tester) async {
      when(() => mockProvider.isLoading).thenReturn(false);
      when(() => mockProvider.announcements).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('No announcements yet'), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
    });

    testWidgets('renders list of announcements when data exists', (
      tester,
    ) async {
      final mockAnnouncements = [
        Announcement(
          id: '1',
          title: 'System Maintenance',
          body: 'Scheduled maintenance this Sunday.',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        Announcement(
          id: '2',
          title: 'New Policy update',
          body: 'Please review the updated safety guidelines.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      when(() => mockProvider.isLoading).thenReturn(false);
      when(() => mockProvider.announcements).thenReturn(mockAnnouncements);

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('System Maintenance'), findsOneWidget);
      expect(find.text('Scheduled maintenance this Sunday.'), findsOneWidget);
      expect(find.text('New Policy update'), findsOneWidget);
      expect(find.text('2h ago'), findsOneWidget);
    });
  });
}
