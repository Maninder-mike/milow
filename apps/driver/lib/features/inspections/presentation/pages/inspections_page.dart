import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';

import 'package:milow_core/milow_core.dart';
import 'package:milow/features/inspections/presentation/providers/inspection_provider.dart';
import 'package:provider/provider.dart';

class InspectionsPage extends StatefulWidget {
  const InspectionsPage({super.key});

  @override
  State<InspectionsPage> createState() => _InspectionsPageState();
}

class _InspectionsPageState extends State<InspectionsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadInspections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspections'),
        centerTitle: true,
        actions: [],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/inspections/new');
        },
        label: const Text('New Inspection'),
        icon: const Icon(Icons.add),
      ),
      body: Consumer<InspectionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          if (provider.inspections.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  context.read<InspectionProvider>().syncInspections(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(context.tokens.spacingM),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  const Center(
                    child: Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: context.tokens.spacingM),
                  Center(
                    child: Text(
                      'No inspections found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(height: context.tokens.spacingXS),
                  Center(
                    child: Text(
                      'Tap + to start a new inspection',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                context.read<InspectionProvider>().syncInspections(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.tokens.spacingM),
              itemCount: provider.inspections.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: context.tokens.spacingS),
              itemBuilder: (context, index) {
                final inspection = provider.inspections[index];
                return _buildInspectionCard(context, inspection);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInspectionCard(BuildContext context, DVIRReport inspection) {
    final tokens = context.tokens;
    return Dismissible(
      key: Key(inspection.id),
      background: Container(
        margin: EdgeInsets.only(bottom: tokens.spacingS),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(tokens.radiusM),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Icon(
              Icons.edit_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Modify',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: EdgeInsets.only(bottom: tokens.spacingS),
        decoration: BoxDecoration(
          color: tokens.error,
          borderRadius: BorderRadius.circular(tokens.radiusM),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onError,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.delete_rounded,
              color: Theme.of(context).colorScheme.onError,
              size: 20,
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete action
          final confirmed = await _showDeleteConfirmationDialog(
            context,
            inspection,
          );
          if (confirmed == true) {
            if (!context.mounted) return false;
            await context.read<InspectionProvider>().deleteInspection(
              inspection.id,
            );
            return false; // List updates via provider
          }
          return false;
        } else {
          // Edit action
          await context.push('/inspections/edit/${inspection.id}');
          return false;
        }
      },
      child: Card(
        margin: EdgeInsets.only(bottom: tokens.spacingS),
        child: ListTile(
          leading: Icon(
            inspection.inspectionType == DVIRInspectionType.preTrip
                ? Icons.start_rounded
                : Icons.stop_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            DateFormat.yMMMd().add_jm().format(
              inspection.createdAt ?? DateTime.now(),
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${inspection.inspectionType.displayName.toUpperCase()} • ${inspection.vehicleId}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              inspection.defectsFound
                  ? Chip(
                      label: const Text('Defects'),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.errorContainer,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    )
                  : Icon(Icons.check_circle, color: tokens.success),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context,
    DVIRReport inspection,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        final tokens = dialogContext.tokens;
        final dialogTextColor = tokens.textPrimary;
        final dialogSecondaryColor = tokens.textSecondary;

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceContainer,
            borderRadius: BorderRadius.circular(tokens.shapeXL),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: dialogSecondaryColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Warning icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tokens.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: tokens.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Delete Inspection',
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: dialogTextColor,
                ),
              ),
              const SizedBox(height: 8),
              // Message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Are you sure you want to delete this inspection for ${inspection.vehicleId}? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: dialogSecondaryColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(tokens.shapeM),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: dialogTextColor,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Delete button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: tokens.error,
                            borderRadius: BorderRadius.circular(tokens.shapeM),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.error.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Delete',
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      dialogContext,
                                    ).colorScheme.onError,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
