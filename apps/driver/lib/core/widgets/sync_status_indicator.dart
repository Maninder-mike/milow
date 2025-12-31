import 'dart:async';

import 'package:flutter/material.dart';
import 'package:milow/core/models/sync_status.dart';
import 'package:milow/core/services/sync_queue_service.dart';
import 'package:milow/core/constants/design_tokens.dart';

/// A compact sync status indicator widget.
///
/// Shows sync status with an icon and optional count badge.
/// Tapping opens a bottom sheet with more details.
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<SyncStatusInfo> _subscription;
  SyncStatusInfo _status = SyncStatusInfo.synced();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _subscription = syncQueueService.syncStatus.listen((status) {
      if (mounted) {
        setState(() => _status = status);

        // Animate during syncing
        if (status.status == SyncStatus.syncing) {
          _animationController.repeat();
        } else {
          _animationController.stop();
          _animationController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    // Don't show anything if synced
    if (_status.status == SyncStatus.synced) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showSyncDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getBackgroundColor(colorScheme),
          borderRadius: BorderRadius.circular(tokens.shapeM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(colorScheme),
            if (_status.pendingCount > 0 || _status.failedCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                _getCountText(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _getTextColor(colorScheme),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    final iconColor = _getIconColor(colorScheme);
    const iconSize = 18.0;

    switch (_status.status) {
      case SyncStatus.offline:
        return Icon(Icons.cloud_off_outlined, size: iconSize, color: iconColor);
      case SyncStatus.pending:
        return Icon(
          Icons.cloud_upload_outlined,
          size: iconSize,
          color: iconColor,
        );
      case SyncStatus.syncing:
        return RotationTransition(
          turns: _animationController,
          child: Icon(Icons.sync_rounded, size: iconSize, color: iconColor),
        );
      case SyncStatus.error:
        return Icon(Icons.cloud_off_rounded, size: iconSize, color: iconColor);
      case SyncStatus.synced:
        return Icon(
          Icons.cloud_done_outlined,
          size: iconSize,
          color: iconColor,
        );
    }
  }

  Color _getBackgroundColor(ColorScheme colorScheme) {
    switch (_status.status) {
      case SyncStatus.offline:
        return colorScheme.surfaceContainerHighest;
      case SyncStatus.pending:
      case SyncStatus.syncing:
        return colorScheme.primaryContainer.withValues(alpha: 0.5);
      case SyncStatus.error:
        return colorScheme.errorContainer;
      case SyncStatus.synced:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Color _getIconColor(ColorScheme colorScheme) {
    switch (_status.status) {
      case SyncStatus.offline:
        return colorScheme.onSurfaceVariant;
      case SyncStatus.pending:
      case SyncStatus.syncing:
        return colorScheme.primary;
      case SyncStatus.error:
        return colorScheme.error;
      case SyncStatus.synced:
        return colorScheme.primary;
    }
  }

  Color _getTextColor(ColorScheme colorScheme) {
    switch (_status.status) {
      case SyncStatus.offline:
        return colorScheme.onSurfaceVariant;
      case SyncStatus.pending:
      case SyncStatus.syncing:
        return colorScheme.onPrimaryContainer;
      case SyncStatus.error:
        return colorScheme.onErrorContainer;
      case SyncStatus.synced:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _getCountText() {
    if (_status.failedCount > 0) {
      return '${_status.failedCount} failed';
    }
    if (_status.pendingCount > 0) {
      return '${_status.pendingCount} pending';
    }
    return '';
  }

  void _showSyncDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SyncDetailsSheet(status: _status),
    );
  }
}

/// Bottom sheet showing detailed sync status
class SyncDetailsSheet extends StatelessWidget {
  const SyncDetailsSheet({required this.status, super.key});

  final SyncStatusInfo status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildStatusIcon(colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (status.message != null)
                        Text(
                          status.message!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats
            if (status.pendingCount > 0 || status.failedCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(tokens.shapeM),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(context, 'Pending', status.pendingCount),
                    _buildStat(context, 'Failed', status.failedCount),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Failed Operations Details
            if (syncQueueService.failedOperations.isNotEmpty) ...[
              Text(
                'Failures',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(tokens.shapeM),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: syncQueueService.failedOperations.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: colorScheme.outlineVariant, height: 16),
                  itemBuilder: (context, index) {
                    final op = syncQueueService.failedOperations[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 16,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${op.operationType.toUpperCase()} ${op.tableName}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          op.errorMessage ?? 'Unknown error',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontFamily: 'monospace',
                                color: colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Actions
            if (status.failedCount > 0)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    syncQueueService.retryFailed();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Failed'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ColorScheme colorScheme) {
    IconData icon;
    Color color;

    switch (status.status) {
      case SyncStatus.offline:
        icon = Icons.cloud_off_outlined;
        color = colorScheme.onSurfaceVariant;
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_upload_outlined;
        color = colorScheme.primary;
        break;
      case SyncStatus.syncing:
        icon = Icons.sync_rounded;
        color = colorScheme.primary;
        break;
      case SyncStatus.error:
        icon = Icons.error_outline_rounded;
        color = colorScheme.error;
        break;
      case SyncStatus.synced:
        icon = Icons.cloud_done_outlined;
        color = colorScheme.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  String _getStatusTitle() {
    switch (status.status) {
      case SyncStatus.offline:
        return 'You\'re Offline';
      case SyncStatus.pending:
        return 'Changes Pending';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.error:
        return 'Sync Error';
      case SyncStatus.synced:
        return 'All Synced';
    }
  }

  Widget _buildStat(BuildContext context, String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
