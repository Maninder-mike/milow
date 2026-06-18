import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/trip_repository.dart';
import 'package:milow/core/services/local_document_store.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:milow/core/services/connectivity_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_file/open_file.dart';

import 'dart:async';

import 'package:milow/features/documents/presentation/widgets/document_card.dart';
import 'package:milow/features/documents/presentation/widgets/documents_empty_state.dart';

class SharedDocumentsPage extends StatefulWidget {
  final String companyId;

  const SharedDocumentsPage({required this.companyId, super.key});

  @override
  State<SharedDocumentsPage> createState() => _SharedDocumentsPageState();
}

class _SharedDocumentsPageState extends State<SharedDocumentsPage> {
  List<TripDocument> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Load from cache first
    final cached = LocalDocumentStore.getSharedDocumentsForCompany(
      widget.companyId,
      userId,
    );
    if (cached.isNotEmpty) {
      setState(() {
        _documents = cached;
        _isLoading = false;
      });
    }

    if (ConnectivityService.instance.isOnline) {
      final result = await TripRepository.getSharedDocuments(widget.companyId);

      if (!mounted) return;

      await result.fold(
        (failure) {
          unawaited(
            LoggingService.instance.error(
              'SharedDocs',
              'Failed to load: ${failure.message}',
            ),
          );
        },
        (fetched) async {
          setState(() {
            _documents = fetched;
            _isLoading = false;
          });
          // Update cache
          await LocalDocumentStore.putAll(fetched);
        },
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _previewDocument(TripDocument doc) async {
    try {
      final result = await TripRepository.downloadDocument(doc);

      if (!mounted) return;

      await result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download: ${failure.message}')),
          );
        },
        (file) async {
          final openResult = await OpenFile.open(file.path);
          if (openResult.type != ResultType.done) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(openResult.message)));
            }
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open document')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      appBar: AppBar(
        title: const Text('Shared with me'),
        backgroundColor: tokens.scaffoldAltBackground,
      ),
      body: _isLoading && _documents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
          ? _buildEmptyState(tokens)
          : _buildDocumentList(tokens),
    );
  }

  Widget _buildEmptyState(DesignTokens tokens) {
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const DocumentsEmptyState(
            icon: Icons.folder_open,
            title: 'No shared documents yet',
            subtitle: 'Documents shared with you will appear here.',
            isFiltered: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(DesignTokens tokens) {
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final doc = _documents[index];
          return DocumentCard(
            document: doc,
            onTap: () => _previewDocument(doc),
            isSelected: false,
            isSelectionMode: false,
            onLongPress: () {},
            onDetailsTap: () => _previewDocument(doc),
          );
        },
      ),
    );
  }
}
