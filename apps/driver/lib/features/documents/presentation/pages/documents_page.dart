import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow/core/services/local_document_store.dart';
import 'package:milow/core/services/connectivity_service.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:open_file/open_file.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:milow_core/milow_core.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/profile_provider.dart';
import 'package:go_router/go_router.dart';

import '../widgets/document_summary_header.dart';
import '../widgets/document_filter_bar.dart';
import '../widgets/document_card.dart';
import '../widgets/scan_preview_card.dart';
import '../widgets/documents_empty_state.dart';

class DocumentsPage extends StatefulWidget {
  final Map<String, dynamic> extra;
  final SupabaseClient? supabaseClient;
  final DocumentScanner? documentScanner;

  const DocumentsPage({
    required this.extra,
    this.supabaseClient,
    this.documentScanner,
    super.key,
  });

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  String? _tripId;
  String? _tripNumber;
  TripDocumentType? _selectedDocumentType;

  // ignore: unused_field
  DocumentScanner? _documentScanner;
  File? _scannedPdf;
  List<String> _scannedImages = [];
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _tripNumberController = TextEditingController();

  // Search state
  String? _searchQuery;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  TripDocumentType? _filterType;
  DocumentStatus? _filterStatus;

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

    if (_tripId == null) {
      unawaited(_fetchActiveTrip());
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

    final client = widget.supabaseClient ?? Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
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
      if (mounted) setState(() => _isLoadingDocuments = true);
    }

    if (ConnectivityService.instance.isOnline) {
      final result = await TripRepository.getDocuments(userId);

      if (!mounted) return;

      await result.fold(
        (failure) {
          unawaited(
            LoggingService.instance.error(
              'ScanDocument',
              'Failed to load documents: ${failure.message}',
            ),
          );
          if (mounted) {
            setState(() {
              _isLoadingDocuments = false;
            });
          }
        },
        (fetchedDocs) async {
          if (mounted) {
            setState(() {
              _existingDocuments = fetchedDocs;
              _sortDocuments(_existingDocuments);
              _isLoadingDocuments = false;
            });
            // 3. Update cache
            unawaited(LocalDocumentStore.putAll(fetchedDocs));
          }
        },
      );
    } else {
      if (mounted) setState(() => _isLoadingDocuments = false);
    }
  }

  Future<void> _fetchActiveTrip() async {
    final activeTripResult = await TripRepository.getActiveTrip();
    final activeTrip = activeTripResult.fold((l) => null, (r) => r);
    if (activeTrip != null && mounted) {
      setState(() {
        if (_tripId == null) {
          _tripId = activeTrip.id;
          _tripNumber = activeTrip.tripNumber;
          _tripNumberController.text = _tripNumber!;
        }
      });
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

      if (result.pdf != null || (result.images?.isNotEmpty ?? false)) {
        setState(() {
          _scannedPdf = result.pdf != null ? File(result.pdf!.uri) : null;
          _scannedImages = result.images ?? [];
        });
      }
    } catch (e) {
      unawaited(
        LoggingService.instance.error(
          'ScanDocument',
          'Failed to scan document',
          error: e,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t scan document. Please try again.'),
          ),
        );
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

    // 1. Prepare file to upload - Always force PDF
    final File fileToUpload;

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
          LoggingService.instance.error(
            'ScanDocument',
            'Failed to convert images to PDF',
            error: e,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Couldn\'t process images. Please rescan.'),
            ),
          );
        }
        return;
      }
    } else {
      return;
    }

    // 2. Resolve Trip ID
    String? resolvedTripId = _tripId;
    final tripNumberInput = _tripNumberController.text.trim();

    if (resolvedTripId == null) {
      if (tripNumberInput.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add a trip number first.')),
          );
        }
        return;
      }

      final result = await TripRepository.resolveTripId(tripNumberInput);
      result.fold(
        (_) {
          // Failure: Proceed locally without ID (log warning internally if needed)
          unawaited(
            LoggingService.instance.warning(
              'ScanDocument',
              'Trip check failed, proceeding locally',
            ),
          );
        },
        (id) {
          if (id != null) {
            resolvedTripId = id;
          } else {
            unawaited(
              LoggingService.instance.warning(
                'ScanDocument',
                'Trip number $tripNumberInput not found, proceeding locally',
              ),
            );
          }
        },
      );
    }

    // 3. Upload via Repository
    final result = await TripRepository.uploadDocument(
      file: fileToUpload,
      type: _selectedDocumentType!,
      tripId: resolvedTripId,
      tripNumber: tripNumberInput.isNotEmpty
          ? tripNumberInput
          : (_tripNumber ?? 'UNKNOWN'),
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        unawaited(
          LoggingService.instance.error(
            'ScanDocument',
            'Failed to upload: ${failure.message}',
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${failure.message}')),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document saved successfully')),
        );
        _resetUploadState();
        _loadDocuments();
      },
    );
  }

  void _resetUploadState() {
    setState(() {
      _scannedPdf = null;
      _scannedImages = [];
      _selectedDocumentType = null;
      _notesController.clear();
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

  Future<void> _deleteSelectedDocuments() async {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${count > 1 ? 'these documents' : 'this document'}?',
        ),
        content: const Text('You can\'t undo this action.'),
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

    // ... logic
    final docsToDelete = _existingDocuments.where((d) {
      final idMatch = _selectedIds.contains(d.id);
      return idMatch &&
          d.isDeletable; // Assuming isDeletable check logic exists or is implied
    }).toList();

    if (docsToDelete.isEmpty) return;

    final result = await TripRepository.deleteDocuments(docsToDelete);

    if (!mounted) return;

    result.fold(
      (failure) {
        LoggingService.instance.error(
          'ScanDocument',
          'Failed to delete docs',
          error: failure, // passing failure as error
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${failure.message}')),
          );
        }
      },
      (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Documents removed.')));
          setState(() {
            _selectedIds.clear();
            _isSelectionMode = false;
            _changesMade = true;
            _existingDocuments.removeWhere((d) => docsToDelete.contains(d));
          });
        }
      },
    );
  }

  Future<void> _previewDocument(TripDocument doc) async {
    final result = await TripRepository.downloadDocument(doc);

    if (!mounted) return;

    await result.fold(
      (failure) {
        LoggingService.instance.error(
          'ScanDocument',
          'Failed to preview',
          error: failure,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview failed: ${failure.message}')),
        );
      },
      (file) async {
        final openResult = await OpenFile.open(file.path);
        if (openResult.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open file: ${openResult.message}'),
              ),
            );
          }
        }
      },
    );
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.shapeL),
        ),
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_getShortDocType(doc.documentType)} - ${doc.tripNumber}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _buildStatusBadge(doc.status, tokens),
                                ],
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
                    if (doc.status == DocumentStatus.rejected &&
                        doc.reviewNotes != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(tokens.shapeM),
                          border: Border.all(
                            color: tokens.error.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.report_problem,
                                  size: 20,
                                  color: tokens.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Rejected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: tokens.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              doc.reviewNotes!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    // Actions
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.open_in_new),
                      title: const Text('View Document'),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_previewDocument(doc));
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.share),
                      title: const Text('Share'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _shareDocument(doc);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.download),
                      title: const Text('Download'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _downloadDocument(doc);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Details'),
                      onTap: () {
                        Navigator.pop(context);
                        _showDocumentDetailsDialog(doc);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      dense: true,
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
    final result = await TripRepository.downloadDocument(doc);

    if (!mounted) return;

    await result.fold(
      (failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: ${failure.message}')),
        );
      },
      (file) async {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      },
    );
  }

  /// Download document to device
  Future<void> _downloadDocument(TripDocument doc) async {
    final result = await TripRepository.downloadDocument(doc);

    if (!mounted) return;

    await result.fold(
      (failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: ${failure.message}')),
        );
      },
      (tempFile) async {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final fileName = doc.fileName ?? 'document.pdf';
          final finalFile = File('${directory.path}/$fileName');
          await tempFile.copy(finalFile.path);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File saved to documents.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save file locally.')),
            );
          }
        }
      },
    );
  }

  /// Delete a single document
  Future<void> _deleteDocument(TripDocument doc) async {
    final tokens = Theme.of(context).extension<DesignTokens>()!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('You can\'t undo this action.'),
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

    // Assuming we can pass doc or ID. TripRepository.deleteDocuments takes List<TripDocument>
    final result = await TripRepository.deleteDocuments([doc]);

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${failure.message}')),
        );
      },
      (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document removed.')));
        setState(() {
          _existingDocuments.removeWhere((d) => d.id == doc.id);
          _changesMade = true;
        });
      },
    );
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
            _buildDetailRow('Status', doc.status.name.toUpperCase(), tokens),
            if (doc.reviewNotes != null)
              _buildDetailRow('Review Notes', doc.reviewNotes, tokens),
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
        body: RefreshIndicator(
          onRefresh: _loadDocuments,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      onPressed: () => Navigator.pop(context, _changesMade),
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
                      cursorColor: Theme.of(context).colorScheme.onSurface,
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
                            Icon(Icons.checklist, color: tokens.textPrimary),
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
            if (_scannedPdf == null && _scannedImages.isEmpty && !_isSelectionMode && !_isSearching) ...[
              SliverToBoxAdapter(
                child: DocumentSummaryHeader(
                  documents: _existingDocuments,
                  selectedStatus: _filterStatus,
                  onStatusSelected: (status) {
                    setState(() {
                      _filterStatus = status;
                    });
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: DocumentFilterBar(
                  selectedType: _filterType,
                  onTypeSelected: (type) {
                    setState(() {
                      _filterType = type;
                    });
                  },
                ),
              ),
            ],
            _scannedPdf == null && _scannedImages.isEmpty
                ? _buildDocumentListSlivers(tokens)
                : SliverToBoxAdapter(child: _buildReviewState(tokens)),
          ],
        ),
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
      // Status filter
      if (_filterStatus != null && doc.status != _filterStatus) return false;
      
      // Type filter
      if (_filterType != null && doc.documentType != _filterType) return false;

      // Search filter
      if (_searchQuery == null || _searchQuery!.isEmpty) return true;
      final query = _searchQuery!.toLowerCase();
      final type = doc.documentType.label.toLowerCase();
      final notes = (doc.notes ?? '').toLowerCase();
      final desc = (doc.description ?? '').toLowerCase();
      final tripNum = (doc.tripId).toLowerCase();

      return type.contains(query) ||
          notes.contains(query) ||
          desc.contains(query) ||
          tripNum.contains(query);
    }).toList();

    if (displayedDocs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: M3ExpressiveEntrance(
          child: DocumentsEmptyState(
            onScanPressed: _startScan,
            isFiltered: _isSearching || _filterStatus != null || _filterType != null,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0) {
            return _buildSharedFolder(tokens);
          }
          final doc = displayedDocs[index - 1];
          final isSelected = _selectedIds.contains(doc.id);

          return M3ExpressiveEntrance(
            delay: Duration(milliseconds: (index - 1) * 50),
            child: DocumentCard(
              document: doc,
              isSelected: isSelected,
              isSelectionMode: _isSelectionMode,
              onTap: () {
                  if (doc.id == null) return;
                  if (_isSelectionMode) {
                    _toggleSelection(doc.id!);
                  } else if (doc.status == DocumentStatus.uploadFailed ||
                      doc.status == DocumentStatus.pendingUpload) {
                    if (doc.status == DocumentStatus.uploadFailed) {
                      syncQueueService.retryFailed();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Retrying document uploads...'),
                        ),
                      );
                    }
                  } else {
                    _previewDocument(doc);
                  }
              },
              onLongPress: () {
                  if (doc.id == null) return;
                  if (doc.status != DocumentStatus.pendingUpload &&
                      doc.status != DocumentStatus.uploadFailed) {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedIds.add(doc.id!);
                      });
                    } else {
                      _toggleSelection(doc.id!);
                    }
                  }
              },
              onDetailsTap: () => _showDocumentDetails(doc),
              onSelectionChanged: (v) => _toggleSelection(doc.id!),
            ),
          );
        }, childCount: displayedDocs.length + 1),
      ),
    );
  }

  Widget _buildSharedFolder(DesignTokens tokens) {
    if (_isSearching) return const SizedBox.shrink();

    final profile = context.read<ProfileProvider>().profile;
    final companyId = profile?['company_id'] as String?;

    if (companyId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: M3ExpressiveEntrance(
        child: GestureDetector(
          onTap: () => context.push('/shared-documents', extra: companyId),
          child: Card(
            elevation: 0,
            color: tokens.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.shapeM),
              side: BorderSide(color: tokens.subtleBorderColor),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.folder_shared_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              title: Text(
                'Shared with me',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Documents from your team',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildStatusBadge(DocumentStatus status, DesignTokens tokens) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case DocumentStatus.approved:
        color = tokens.success;
        icon = Icons.check_circle_outline;
        label = 'Approved';
        break;
      case DocumentStatus.rejected:
        color = tokens.error;
        icon = Icons.error_outline;
        label = 'Rejected';
        break;
      case DocumentStatus.pending:
        color = tokens.textTertiary;
        icon = Icons.access_time;
        label = 'Pending';
        break;
      case DocumentStatus.pendingUpload:
        color = tokens.textTertiary;
        icon = Icons.cloud_upload_outlined;
        label = 'Pending Upload';
        break;
      case DocumentStatus.uploadFailed:
        color = tokens.error;
        icon = Icons.cloud_off;
        label = 'Upload Failed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewState(DesignTokens tokens) {
    return M3ExpressiveEntrance(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScanPreviewCard(
              document: TripDocument(
                id: 'preview',
                tripId: _tripId ?? 'preview',
                userId: 'preview',
                documentType: _selectedDocumentType ?? TripDocumentType.other,
                status: DocumentStatus.pendingUpload,
                createdAt: DateTime.now(),
                filePath: _scannedPdf != null ? _scannedPdf!.path : (_scannedImages.isNotEmpty ? _scannedImages.first : ''),
              ),
              onTap: () {},
              onCancel: _resetUploadState,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake / Add Pages'),
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.textSecondary,
                side: BorderSide(color: tokens.inputBorder),
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
