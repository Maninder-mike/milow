import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';
import 'package:milow/core/services/load_document_repository.dart';
import 'package:milow_core/milow_core.dart';
import 'package:gap/gap.dart';

class LoadDocumentUploadPage extends StatefulWidget {
  final String loadId;
  final String loadReference;
  final String? stopId;
  final String? initialDocumentType;

  const LoadDocumentUploadPage({
    required this.loadId,
    required this.loadReference,
    this.stopId,
    this.initialDocumentType,
    super.key,
  });

  @override
  State<LoadDocumentUploadPage> createState() => _LoadDocumentUploadPageState();
}

class _LoadDocumentUploadPageState extends State<LoadDocumentUploadPage> {
  final _picker = ImagePicker();
  File? _selectedFile;
  TripDocumentType? _selectedType;
  final _notesController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocumentType != null) {
      _selectedType = TripDocumentType.values.firstWhere(
        (t) => t.name == widget.initialDocumentType || t.value == widget.initialDocumentType,
        orElse: () => TripDocumentType.other,
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 2000,
      );

      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null || _selectedType == null) return;

    setState(() => _isUploading = true);

    final result = await LoadDocumentRepository.uploadDocument(
      file: _selectedFile!,
      type: _selectedType!,
      loadId: widget.loadId,
      loadReference: widget.loadReference,
      stopId: widget.stopId,
      notes: _notesController.text,
    );

    if (!mounted) return;
    setState(() => _isUploading = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${failure.message}')),
        );
      },
      (_) {
        context.pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacingM),
        child: M3ExpressiveEntrance(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePreview(tokens, theme),
              const Gap(24),
              _buildForm(tokens, theme),
              const Gap(32),
              FilledButton.icon(
                onPressed: (_selectedFile != null && _selectedType != null && !_isUploading)
                    ? _handleUpload
                    : null,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? 'Uploading...' : 'Save Document'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(DesignTokens tokens, ThemeData theme) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: GestureDetector(
        onTap: () => _showPickerOptions(tokens, theme),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(tokens.shapeM),
            border: Border.all(color: tokens.inputBorder),
          ),
          child: _selectedFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.shapeM),
                  child: Image.file(_selectedFile!, fit: BoxFit.cover),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 48, color: tokens.textTertiary),
                    const Gap(8),
                    Text(
                      'Tap to take a photo or select from gallery',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildForm(DesignTokens tokens, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<TripDocumentType>(
          initialValue: _selectedType,
          decoration: InputDecoration(
            labelText: 'Document Type',
            prefixIcon: const Icon(Icons.category),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.shapeS),
            ),
          ),
          items: TripDocumentType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.name.toUpperCase()),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedType = val),
        ),
        const Gap(16),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Notes (Optional)',
            hintText: 'Add description...',
            prefixIcon: const Icon(Icons.note),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.shapeS),
            ),
          ),
        ),
      ],
    );
  }

  void _showPickerOptions(DesignTokens tokens, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.shapeXL)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(tokens.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Source',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    context.pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    context.pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const Gap(8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
