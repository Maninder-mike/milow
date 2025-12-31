import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:milow/core/services/local_document_store.dart';
import 'package:milow_core/milow_core.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  FakePathProvider(this.path);
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    await Hive.initFlutter(tempDir.path);
    await LocalDocumentStore.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('LocalDocumentStore put and get', () async {
    final mockDoc = TripDocument(
      id: '1',
      userId: 'user1',
      tripId: 'trip1',
      documentType: TripDocumentType.billOfLading,
      fileName: 'test.pdf',
      filePath: 'path/test.pdf',
      fileSize: 1024,
      mimeType: 'application/pdf',
      createdAt: DateTime.now(),
      tripNumber: 'T123',
    );
    await LocalDocumentStore.put(mockDoc);
    final docs = LocalDocumentStore.getAllForUser('user1');
    expect(docs.length, 1);
    expect(docs.first.tripNumber, 'T123');
  });
}
