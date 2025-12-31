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
import 'package:milow_core/milow_core.dart';

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
        final pdf = pw.Document();
        for (final imagePath in _scannedImages) {
          final imageFile = File(imagePath);
          final imageBytes = await imageFile.readAsBytes();
          final image = pw.MemoryImage(imageBytes);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
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

        if (tripResponse == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid Trip Number')),
            );
            setState(() => _isUploading = false);
          }
          return;
        }
        resolvedTripId = tripResponse['id'] as String;
      } catch (e) {
        if (!connectivityService.isOnline) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Cannot verify Trip Number while offline. Please try again when online.',
                ),
              ),
            );
            setState(() => _isUploading = false);
          }
          return;
        }
        unawaited(
          logger.error('ScanDocument', 'Failed to resolve trip', error: e),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to verify Trip Number')),
          );
          setState(() => _isUploading = false);
        }
        return;
      }
    }

    try {
      final userId = _client.auth.currentUser!.id;
      final shortType = _getShortDocType(_selectedDocumentType!);
      final uniqueId = const Uuid().v4();
      final fileName =
          '$shortType-${tripNumberInput}_${uniqueId.split('-').first}$extension';
      final storagePath = '$userId/$resolvedTripId/$fileName';

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

  Widget _buildDetailRow(String label, dynamic value) {
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(displayValue)),
        ],
      ),
    );
  }

  void _showDocumentDetails(TripDocument doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Document Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow('Type', doc.documentType.label),
              _buildDetailRow('File Name', doc.fileName),
              _buildDetailRow(
                'Size',
                '${((doc.fileSize ?? 0) / 1024).toStringAsFixed(1)} KB',
              ),
              _buildDetailRow('Created', doc.createdAt),
              _buildDetailRow('Notes', doc.description ?? doc.notes),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    unawaited(_previewDocument(doc));
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Document'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
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
      canPop: !_isSelectionMode, // Intercept pop if in selection mode
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedIds.clear();
          });
          return;
        }
        if (didPop && _changesMade) {
          // If changes made, we rely on the passing back flag via Navigator pop manually
        }
      },
      child: Scaffold(
        appBar: AppBar(
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
                  cursorColor: Theme.of(context).colorScheme.onSurface,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                )
              : const Text('Add documents'),
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
              : _isSearching
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = null;
                      _searchController.clear();
                    });
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context, _changesMade),
                ),
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
                      _sortBy = value.substring(5); // remove 'sort_'
                      _sortDocuments(_existingDocuments);
                    });
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'select',
                    child: Row(
                      children: [
                        Icon(Icons.checklist, color: Colors.black87),
                        SizedBox(width: 12),
                        Text('Select Documents'),
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
                  const PopupMenuItem(
                    value: 'sort_trip_desc',
                    child: Text('Sort by Trip (High-Low)'),
                  ),
                  const PopupMenuItem(
                    value: 'sort_trip_asc',
                    child: Text('Sort by Trip (Low-High)'),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: _isUploading
            ? const Center(
                child: CircularProgressIndicator(strokeCap: StrokeCap.round),
              )
            : (_scannedPdf == null && _scannedImages.isEmpty)
            ? _buildDocumentList(tokens)
            : _buildReviewState(tokens),
      ),
    );
  }

  Widget _buildDocumentList(DesignTokens tokens) {
    if (_isLoadingDocuments) {
      return const Center(
        child: CircularProgressIndicator(strokeCap: StrokeCap.round),
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

    return Column(
      children: [
        if (!_isSearching && !_isSelectionMode)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add New Document'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        Expanded(
          child: displayedDocs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSearching
                            ? Icons.search_off
                            : Icons.folder_open_outlined,
                        size: 64,
                        color: tokens.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSearching ? 'No matches found' : 'No documents yet',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: displayedDocs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = displayedDocs[index];
                    final isSelected = _selectedIds.contains(doc.id);

                    return GestureDetector(
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
                          // Preview Document
                          unawaited(_previewDocument(doc));
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
                          borderRadius: BorderRadius.circular(tokens.shapeM),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : tokens.subtleBorderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: IgnorePointer(
                          ignoring:
                              _isSelectionMode, // Consume all taps in selection mode
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: tokens.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  tokens.shapeS,
                                ),
                              ),
                              child: Icon(
                                Icons.picture_as_pdf,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              // Format: BOL - 12345
                              '${_getShortDocType(doc.documentType)} - ${doc.tripNumber}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  _formatFileSize(doc.fileSize),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: tokens.textSecondary),
                                ),
                                if (doc.notes != null && doc.notes!.isNotEmpty)
                                  Text(
                                    doc.notes!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: tokens.textTertiary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                              ],
                            ),
                            trailing: _isSelectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      if (doc.id != null) {
                                        _toggleSelection(doc.id!);
                                      }
                                    },
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () => _showDocumentDetails(doc),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReviewState(DesignTokens tokens) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: tokens.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.shapeM),
              side: BorderSide(color: tokens.subtleBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    size: 48,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _scannedPdf != null ? 'PDF Document Ready' : 'Image Ready',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_scannedPdf != null)
                    Text(
                      '$_scannedPageCount pages',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake / Add Pages'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Document Details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Trip Number Field - Editable
          TextField(
            controller: _tripNumberController,
            decoration: InputDecoration(
              labelText: 'Trip Number',
              hintText: 'e.g. 123456',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.shapeS),
              ),
              filled: true,
              fillColor: tokens.inputBackground,
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<TripDocumentType>(
            initialValue: _selectedDocumentType,
            decoration: InputDecoration(
              labelText: 'Document Type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.shapeS),
              ),
              filled: true,
              fillColor: tokens.inputBackground,
            ),
            items: _documentTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_formatDocType(type)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDocumentType = value;
              });
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.shapeS),
              ),
              filled: true,
              fillColor: tokens.inputBackground,
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: (_selectedDocumentType != null) ? _uploadDocument : null,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Save Document'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
