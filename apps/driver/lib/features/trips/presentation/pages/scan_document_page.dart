import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow/core/services/local_document_store.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:milow_core/milow_core.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';

class ScanDocumentPage extends StatefulWidget {
  final Map<String, dynamic> extra;
  final SupabaseClient? supabaseClient;
  final DocumentScanner? documentScanner;

  const ScanDocumentPage({
    required this.extra,
    this.supabaseClient,
    this.documentScanner,
    super.key,
  });

  @override
  State<ScanDocumentPage> createState() => _ScanDocumentPageState();
}

class _ScanDocumentPageState extends State<ScanDocumentPage> {
  late final SupabaseClient _client;

  String? _tripId;
  String? _tripNumber;
  TripDocumentType? _selectedDocumentType;

  // ignore: unused_field
  DocumentScanner? _documentScanner;
  File? _scannedPdf;
  List<String> _scannedImages = [];
  int _scannedPageCount = 0;
  bool _isUploading = false;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _tripNumberController = TextEditingController();

  // Search state
  String? _searchQuery;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<TripDocument> _existingDocuments = [];
  bool _isLoadingDocuments = true;
  bool _changesMade = false;

  final List<TripDocumentType> _documentTypes = TripDocumentType.values;

  // Selection & Sorting State
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  String _sortBy = 'date_desc'; // date_desc, date_asc, trip_asc, trip_desc

  @override
  void initState() {
    super.initState();
    _client = widget.supabaseClient ?? Supabase.instance.client;
    _tripId = widget.extra['tripId'] as String?;
    // Pre-select document type if provided
    final initialTypeStr = widget.extra['initialDocumentType'] as String?;
    if (initialTypeStr != null) {
      _selectedDocumentType = TripDocumentType.values.firstWhere(
        (t) => t.name == initialTypeStr || t.value == initialTypeStr,
        orElse: () => TripDocumentType.other,
      );
    }
    _tripNumber = widget.extra['tripNumber'] as String?;
    if (_tripNumber != null) {
      _tripNumberController.text = _tripNumber!;
    }
    unawaited(_loadDocuments());
  }

  @override
  void dispose() {
    _documentScanner?.close();
    _notesController.dispose();
    _tripNumberController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Data Loading & Helpers ---

  Future<void> _loadDocuments() async {
    if (!mounted) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Load from cache first for immediate UI
    final cachedDocs = LocalDocumentStore.getAllForUser(userId);
    if (cachedDocs.isNotEmpty) {
      setState(() {
        _existingDocuments = cachedDocs;
        _sortDocuments(_existingDocuments);
        _isLoadingDocuments = false;
      });
    } else {
      setState(() {
        _isLoadingDocuments = true;
      });
    }

    try {
      // 2. Fetch from Supabase
      final response = await _client
          .from('trip_documents')
          .select('*, trips(trip_number)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<TripDocument> fetchedDocs = (response as List)
          .map((doc) => TripDocument.fromJson(doc as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _existingDocuments = fetchedDocs;
          _sortDocuments(_existingDocuments);
          _isLoadingDocuments = false;
        });

        // 3. Update cache
        unawaited(LocalDocumentStore.putAll(fetchedDocs));
      }
    } catch (e) {
      unawaited(
        logger.error('ScanDocument', 'Failed to load documents', error: e),
      );
      if (mounted) {
        setState(() {
          _isLoadingDocuments = false;
        });
        // If we have cached docs, we don't need to show an error, but maybe a "using offline data" indicator
      }
    }
  }

  void _sortDocuments(List<TripDocument> documents) {
    switch (_sortBy) {
      case 'date_desc':
        documents.sort(
          (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          ),
        );
        break;
      case 'date_asc':
        documents.sort(
          (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
            b.createdAt ?? DateTime.now(),
          ),
        );
        break;
      case 'trip_asc':
        documents.sort((a, b) => (a.tripId).compareTo(b.tripId));
        break;
      case 'trip_desc':
        documents.sort((a, b) => (b.tripId).compareTo(a.tripId));
        break;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // --- Document Scanning & Upload ---

  Future<void> _startScan() async {
    try {
      final options = DocumentScannerOptions(
        mode: ScannerMode.filter, // Filter mode lets user edit/crop
        pageLimit: 10,
        isGalleryImport: true, // Use correct parameter name
      );

      _documentScanner =
          widget.documentScanner ?? DocumentScanner(options: options);
      final result = await _documentScanner!.scanDocument();

      if (result.pdf != null || result.images.isNotEmpty) {
        setState(() {
          _scannedPdf = result.pdf != null ? File(result.pdf!.uri) : null;
          _scannedImages = result.images;
          _scannedPageCount = result.images.isNotEmpty
              ? result.images.length
              : 1;
        });
      }
    } catch (e) {
      unawaited(
        logger.error('ScanDocument', 'Failed to scan document', error: e),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to scan document: $e')));
      }
    }
  }

  Future<void> _uploadDocument() async {
    if ((_scannedPdf == null && _scannedImages.isEmpty) ||
        _selectedDocumentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan a document and select its type'),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    // 1. Prepare file to upload - Always force PDF
    final File fileToUpload;
    const String mimeType = 'application/pdf';
    const String extension = '.pdf';

    if (_scannedPdf != null) {
      fileToUpload = _scannedPdf!;
    } else if (_scannedImages.isNotEmpty) {
      try {
        // Create PDF with compression
        final pdf = pw.Document(deflate: zlib.encode);

        for (final imagePath in _scannedImages) {
          final imageFile = File(imagePath);
          var imageBytes = await FlutterImageCompress.compressWithFile(
            imagePath,
            minWidth: 1275, // US Letter width @ ~150 DPI
            minHeight: 1650,
            quality: 75, // Good balance of size/quality
          );

          // Fallback if compression fails
          imageBytes ??= await imageFile.readAsBytes();

          final image = pw.MemoryImage(imageBytes);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.letter,
              margin: pw.EdgeInsets.zero,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        }

        final outputDir = await getTemporaryDirectory();
        final outputFile = File('${outputDir.path}/${const Uuid().v4()}.pdf');
        await outputFile.writeAsBytes(await pdf.save());
        fileToUpload = outputFile;
      } catch (e) {
        unawaited(
          logger.error(
            'ScanDocument',
            'Failed to convert images to PDF',
            error: e,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process document images')),
          );
          setState(() => _isUploading = false);
        }
        return;
      }
    } else {
      setState(() => _isUploading = false);
      return;
    }

    // 2. Resolve Trip ID
    String? resolvedTripId = _tripId;
    final tripNumberInput = _tripNumberController.text.trim();

    if (resolvedTripId == null) {
      if (tripNumberInput.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a trip number')),
          );
          setState(() => _isUploading = false);
        }
        return;
      }

      try {
        final tripResponse = await _client
            .from('trips')
            .select('id')
            .eq('trip_number', tripNumberInput)
            .maybeSingle();

        if (tripResponse != null) {
          resolvedTripId = tripResponse['id'] as String;
        } else {
          // Proceed without trip ID (new trip or invalid number)
          unawaited(
            logger.warning(
              'ScanDocument',
              'Trip number $tripNumberInput not found, proceeding locally',
            ),
          );
        }
      } catch (e) {
        // Proceed locally on error
        unawaited(
          logger.warning(
            'ScanDocument',
            'Trip check failed: $e, proceeding locally',
          ),
        );
      }
    }

    try {
      final userId = _client.auth.currentUser!.id;
      final shortType = _getShortDocType(_selectedDocumentType!);
      final uniqueId = const Uuid().v4();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      // Format: BOL-TR12345-20240401.pdf
      final fileName = '$shortType-$tripNumberInput-$dateStr$extension';

      // Use trip number in path if ID is missing to avoid "null"
      final folderId = resolvedTripId ?? tripNumberInput;
      final storagePath = '$userId/$folderId/$fileName';

      if (!connectivityService.isOnline) {
        // --- OFFLINE MODE ---
        final appDocsDir = await getApplicationDocumentsDirectory();
        final pendingDir = Directory('${appDocsDir.path}/pending_uploads');
        if (!await pendingDir.exists()) {
          await pendingDir.create(recursive: true);
        }
        final localFile = File('${pendingDir.path}/$fileName');
        await fileToUpload.copy(localFile.path);

        final dbData = {
          'trip_id': resolvedTripId, // Can be null
          'user_id': userId,
          'document_type': _selectedDocumentType?.value ?? 'other',
          'file_path': storagePath,
          'file_name': fileName,
          'file_size': await fileToUpload.length(),
          'mime_type': mimeType,
          'notes': _notesController.text.trim(),
          'description': _notesController.text.trim(),
          'object_key': _getObjectKey(
            _selectedDocumentType ?? TripDocumentType.other,
          ),
        };

        await syncQueueService.enqueue(
          tableName: 'trip_documents',
          operationType: 'upload_document',
          payload: {
            'local_file_path': localFile.path,
            'storage_path': storagePath,
            'db_data': dbData,
            'mime_type': mimeType,
          },
          localId: uniqueId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved offline. Will upload when online.'),
            ),
          );
          _resetUploadState();
          unawaited(_loadDocuments());
        }
        return;
      }

      // --- ONLINE MODE ---
      await _client.storage
          .from('trip_documents')
          .upload(
            storagePath,
            fileToUpload,
            fileOptions: const FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );

      await _client.from('trip_documents').insert({
        'trip_id': resolvedTripId,
        'user_id': userId,
        'document_type': _selectedDocumentType?.value ?? 'other',
        'file_path': storagePath,
        'file_name': fileName,
        'file_size': await fileToUpload.length(),
        'mime_type': mimeType,
        'notes': _notesController.text.trim(),
        'description': _notesController.text.trim(),
        'object_key': _getObjectKey(
          _selectedDocumentType ?? TripDocumentType.other,
        ),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully')),
        );
        _resetUploadState();
        unawaited(_loadDocuments());
      }
    } catch (e) {
      unawaited(
        logger.error('ScanDocument', 'Failed to upload document', error: e),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _resetUploadState() {
    setState(() {
      _scannedPdf = null;
      _scannedImages = [];
      _scannedPageCount = 0;
      _selectedDocumentType = null;
      _notesController.clear();
      _isLoadingDocuments = true;
      _changesMade = true;
    });
  }

  // --- Selection & Actions ---

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(String? initialId) {
    setState(() {
      _isSelectionMode = true;
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  Future<void> _deleteSelectedDocuments() async {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Document${count > 1 ? 's' : ''}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tokens.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploading = true); // Use loading state

    try {
      // ... logic
      final docsToDelete = _existingDocuments.where((d) {
        final idMatch = _selectedIds.contains(d.id);
        return idMatch && d.isDeletable;
      }).toList();

      final filePaths = docsToDelete
          .map((d) => d.filePath)
          .where((path) => path.isNotEmpty)
          .toList();

      final idsToDelete = docsToDelete
          .map((d) => d.id)
          .whereType<String>()
          .toList();

      if (idsToDelete.isEmpty) return;

      // 1. Delete from Storage
      if (filePaths.isNotEmpty) {
        await _client.storage.from('trip_documents').remove(filePaths);
      }

      // 2. Delete from DB
      await _client.from('trip_documents').delete().inFilter('id', idsToDelete);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Documents deleted')));
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
          _isUploading = false;
          _changesMade = true;
          // Remove locally to avoid reload fetch
          _existingDocuments.removeWhere((d) => docsToDelete.contains(d));
        });
      }
    } catch (e) {
      unawaited(
        logger.error('ScanDocument', 'Failed to delete docs', error: e),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete documents')),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _previewDocument(TripDocument doc) async {
    setState(() => _isUploading = true);
    try {
      String? downloadUrl;
      final path = doc.filePath;
      final externalUrl = doc.url;
      final fileName = doc.fileName ?? 'document.pdf';

      if (externalUrl != null && externalUrl.isNotEmpty) {
        downloadUrl = externalUrl;
      } else if (path.isNotEmpty) {
        downloadUrl = await _client.storage
            .from('trip_documents')
            .createSignedUrl(path, 60);
      } else {
        throw Exception('No document URL or path available');
      }

      // 2. Download File
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) throw Exception('Download failed');

      // 3. Save to Temp
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(response.bodyBytes);

      // 4. Open File
      final result = await OpenFile.open(tempFile.path);
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e) {
      unawaited(logger.error('ScanDocument', 'Failed to preview', error: e));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open document: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildDetailRow(String label, dynamic value, DesignTokens tokens) {
    String displayValue = value?.toString() ?? '-';
    if (value is DateTime) {
      displayValue = DateFormat('MMM d, yyyy HH:mm').format(value);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: tokens.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(displayValue)),
        ],
      ),
    );
  }

  void _showDocumentDetails(TripDocument doc) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Document info header
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(tokens.shapeS),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getShortDocType(doc.documentType)} - ${doc.tripNumber}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _formatFileSize(doc.fileSize),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: tokens.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    // Actions
                    ListTile(
                      leading: const Icon(Icons.open_in_new),
                      title: const Text('View Document'),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_previewDocument(doc));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.share),
                      title: const Text('Share'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _shareDocument(doc);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text('Download'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _downloadDocument(doc);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Details'),
                      onTap: () {
                        Navigator.pop(context);
                        _showDocumentDetailsDialog(doc);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.delete_outline, color: tokens.error),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: tokens.error),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteDocument(doc);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Share document via system share sheet
  Future<void> _shareDocument(TripDocument doc) async {
    setState(() => _isUploading = true);
    try {
      String? downloadUrl;
      final path = doc.filePath;
      final externalUrl = doc.url;
      final fileName = doc.fileName ?? 'document.pdf';

      if (externalUrl != null && externalUrl.isNotEmpty) {
        downloadUrl = externalUrl;
      } else if (path.isNotEmpty) {
        downloadUrl = await _client.storage
            .from('trip_documents')
            .createSignedUrl(path, 3600); // 1 hour
      } else {
        throw Exception('No document URL or path available');
      }

      // Download file
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) throw Exception('Download failed');

      // Save to temp
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Share
      await SharePlus.instance.share(
        ShareParams(files: [XFile(tempFile.path)]),
      );
    } catch (e) {
      unawaited(logger.error('ScanDocument', 'Failed to share', error: e));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share document: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Download document to device
  Future<void> _downloadDocument(TripDocument doc) async {
    setState(() => _isUploading = true);
    try {
      String? downloadUrl;
      final path = doc.filePath;
      final externalUrl = doc.url;
      final fileName = doc.fileName ?? 'document.pdf';

      if (externalUrl != null && externalUrl.isNotEmpty) {
        downloadUrl = externalUrl;
      } else if (path.isNotEmpty) {
        downloadUrl = await _client.storage
            .from('trip_documents')
            .createSignedUrl(path, 3600);
      } else {
        throw Exception('No document URL or path available');
      }

      // Download file
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) throw Exception('Download failed');

      // Save to Downloads folder or app documents
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded to: ${file.path}')));
      }
    } catch (e) {
      unawaited(logger.error('ScanDocument', 'Failed to download', error: e));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Delete a single document
  Future<void> _deleteDocument(TripDocument doc) async {
    final tokens = Theme.of(context).extension<DesignTokens>()!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tokens.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || doc.id == null) return;

    setState(() => _isUploading = true);

    try {
      // Delete from Storage
      if (doc.filePath.isNotEmpty) {
        await _client.storage.from('trip_documents').remove([doc.filePath]);
      }

      // Delete from DB
      await _client.from('trip_documents').delete().eq('id', doc.id!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document deleted')));
        setState(() {
          _existingDocuments.removeWhere((d) => d.id == doc.id);
          _changesMade = true;
          _isUploading = false;
        });
      }
    } catch (e) {
      unawaited(logger.error('ScanDocument', 'Failed to delete doc', error: e));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete document')),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  /// Show document details dialog
  void _showDocumentDetailsDialog(TripDocument doc) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', doc.documentType.label, tokens),
            _buildDetailRow('File Name', doc.fileName, tokens),
            _buildDetailRow(
              'Size',
              '${((doc.fileSize ?? 0) / 1024).toStringAsFixed(1)} KB',
              tokens,
            ),
            _buildDetailRow('Created', doc.createdAt, tokens),
            _buildDetailRow('Notes', doc.description ?? doc.notes, tokens),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDocType(TripDocumentType type) {
    return type.label;
  }

  String _getShortDocType(TripDocumentType type) {
    switch (type) {
      case TripDocumentType.billOfLading:
        return 'BOL';
      case TripDocumentType.proofOfDelivery:
        return 'POD';
      case TripDocumentType.rateConfirmation:
        return 'RC';
      case TripDocumentType.other:
        return 'OTH';
      default:
        return type.name.toUpperCase().substring(0, 3);
    }
  }

  String? _getObjectKey(TripDocumentType docType) {
    switch (docType) {
      case TripDocumentType.billOfLading:
      case TripDocumentType.bill:
        return 'bill';
      case TripDocumentType.invoice:
      case TripDocumentType.commercialInvoice:
      case TripDocumentType.proofOfDelivery:
        return 'invoice';
      case TripDocumentType.payStub:
        return 'payStub';
      case TripDocumentType.preloadManifest:
      case TripDocumentType.offloadManifest:
      case TripDocumentType.ace:
      case TripDocumentType.aci:
      case TripDocumentType.paps:
        return 'manifest';
      case TripDocumentType.rateConfirmation:
        return 'order';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedIds.clear();
          });
          return;
        }
      },
      child: Scaffold(
        body: _isUploading
            ? const Center(
                child: CircularProgressIndicator(strokeCap: StrokeCap.round),
              )
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    floating: true,
                    leading: _isSelectionMode
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _isSelectionMode = false;
                                _selectedIds.clear();
                              });
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () =>
                                Navigator.pop(context, _changesMade),
                          ),
                    title: _isSelectionMode
                        ? Text('${_selectedIds.length} Selected')
                        : _isSearching
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search documents...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            cursorColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          )
                        : const Text('Documents'),
                    actions: [
                      if (_isSelectionMode)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _deleteSelectedDocuments,
                        )
                      else ...[
                        if (!_isSearching &&
                            _scannedPdf == null &&
                            _scannedImages.isEmpty)
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              setState(() {
                                _isSearching = true;
                              });
                            },
                          ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'select') {
                              setState(() => _isSelectionMode = true);
                            } else if (value.startsWith('sort_')) {
                              setState(() {
                                _sortBy = value.substring(5);
                                _sortDocuments(_existingDocuments);
                              });
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'select',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.checklist,
                                    color: tokens.textPrimary,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Select Documents'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'sort_date_desc',
                              child: Text('Sort by Date (Newest)'),
                            ),
                            const PopupMenuItem(
                              value: 'sort_date_asc',
                              child: Text('Sort by Date (Oldest)'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  _scannedPdf == null && _scannedImages.isEmpty
                      ? _buildDocumentListSlivers(tokens)
                      : SliverToBoxAdapter(child: _buildReviewState(tokens)),
                ],
              ),
        floatingActionButton:
            !_isSelectionMode &&
                !_isSearching &&
                _scannedPdf == null &&
                _scannedImages.isEmpty
            ? FloatingActionButton.extended(
                onPressed: _startScan,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Scan New'),
              )
            : null,
      ),
    );
  }

  Widget _buildDocumentListSlivers(DesignTokens tokens) {
    if (_isLoadingDocuments) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(strokeCap: StrokeCap.round),
        ),
      );
    }

    final displayedDocs = _existingDocuments.where((doc) {
      if (_searchQuery == null || _searchQuery!.isEmpty) return true;
      final query = _searchQuery!.toLowerCase();
      final type = doc.documentType.label.toLowerCase();
      final notes = (doc.notes ?? '').toLowerCase();
      final desc = (doc.description ?? '').toLowerCase();
      final tripNum = (doc.tripId)
          .toLowerCase(); // Using ID as fallback since trip number join is complex with model

      return type.contains(query) ||
          notes.contains(query) ||
          desc.contains(query) ||
          tripNum.contains(query);
    }).toList();

    if (displayedDocs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: M3ExpressiveEntrance(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSearching
                        ? Icons.search_off
                        : Icons.folder_open_outlined,
                    size: 48,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isSearching ? 'No matches found' : 'No documents yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!_isSearching) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap the camera button to scan',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        80,
      ), // Bottom padding for FAB
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final doc = displayedDocs[index];
          final isSelected = _selectedIds.contains(doc.id);

          return M3ExpressiveEntrance(
            delay: Duration(milliseconds: index * 50),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: GestureDetector(
                onLongPress: () {
                  if (doc.id == null) return;
                  if (!_isSelectionMode) {
                    _enterSelectionMode(doc.id!);
                  } else {
                    _toggleSelection(doc.id!);
                  }
                },
                onTap: () {
                  if (doc.id == null) return;
                  if (_isSelectionMode) {
                    _toggleSelection(doc.id!);
                  } else {
                    _previewDocument(doc);
                  }
                },
                child: Card(
                  elevation: 0,
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1)
                      : tokens.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent, // Minimal border
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: IgnorePointer(
                    ignoring: _isSelectionMode,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: tokens.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      title: Text(
                        doc.fileName ?? _getShortDocType(doc.documentType),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            doc.description?.isNotEmpty == true
                                ? doc.description!
                                : (doc.notes?.isNotEmpty == true
                                      ? doc.notes!
                                      : 'No notes'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: tokens.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(doc.createdAt),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: tokens.textTertiary),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.sd_storage_outlined,
                                size: 14,
                                color: tokens.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatFileSize(doc.fileSize),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: tokens.textTertiary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: _isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (v) => _toggleSelection(doc.id!),
                              shape: const CircleBorder(),
                            )
                          : IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => _showDocumentDetails(doc),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }, childCount: displayedDocs.length),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, y').format(date);
  }

  Widget _buildReviewState(DesignTokens tokens) {
    return M3ExpressiveEntrance(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: tokens.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: tokens.inputBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: tokens.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _scannedPdf != null
                          ? 'Scan Successful'
                          : 'Image Captured',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _scannedPdf != null
                          ? '$_scannedPageCount pages ready to upload'
                          : 'Review details below',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake / Add Pages'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.textSecondary,
                        side: BorderSide(color: tokens.inputBorder),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Document Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Trip Number Field - Editable
            TextField(
              controller: _tripNumberController,
              decoration: InputDecoration(
                labelText: 'Trip Number',
                hintText: 'e.g. 123456',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                filled: true,
                fillColor: tokens.inputBackground,
                prefixIcon: Icon(Icons.numbers, color: tokens.textTertiary),
              ),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<TripDocumentType>(
                  width: constraints.maxWidth,
                  initialSelection: _selectedDocumentType,
                  label: const Text('Document Type'),
                  leadingIcon: Icon(Icons.category, color: tokens.textTertiary),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: tokens.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.inputBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  dropdownMenuEntries: _documentTypes.map((type) {
                    return DropdownMenuEntry<TripDocumentType>(
                      value: type,
                      label: _formatDocType(type),
                    );
                  }).toList(),
                  onSelected: (value) {
                    setState(() {
                      _selectedDocumentType = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add description...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.inputBorder),
                ),
                filled: true,
                fillColor: tokens.inputBackground,
                prefixIcon: Icon(Icons.note, color: tokens.textTertiary),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: (_selectedDocumentType != null)
                  ? _uploadDocument
                  : null,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Save Document'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 32), // Bottom padding
          ],
        ),
      ),
    );
  }
}
