import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/sync_status_provider.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncStatusProvider>(
      builder: (context, provider, child) {
        if (provider.status == SyncStatus.idle && provider.lastSyncTime == null) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _backgroundColor(context, provider.status),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(provider.status),
              const SizedBox(width: 8),
              Text(
                _statusText(provider.status),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _textColor(context, provider.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _backgroundColor(BuildContext context, SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.8);
      case SyncStatus.error:
        return Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.8);
      case SyncStatus.upToDate:
        return Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.8);
      case SyncStatus.idle:
        return Colors.transparent;
    }
  }

  Color _textColor(BuildContext context, SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Theme.of(context).colorScheme.onPrimaryContainer;
      case SyncStatus.error:
        return Theme.of(context).colorScheme.onErrorContainer;
      case SyncStatus.upToDate:
        return Theme.of(context).colorScheme.onSecondaryContainer;
      case SyncStatus.idle:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildIcon(SyncStatus status) {
    if (status == SyncStatus.syncing) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      );
    }

    IconData iconData;
    switch (status) {
      case SyncStatus.error:
        iconData = Icons.sync_problem_rounded;
        break;
      case SyncStatus.upToDate:
        iconData = Icons.done_all_rounded;
        break;
      default:
        iconData = Icons.sync_rounded;
    }

    return Icon(iconData, size: 14);
  }

  String _statusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.error:
        return 'Sync Error';
      case SyncStatus.upToDate:
        return 'Updated';
      case SyncStatus.idle:
        return 'Up to date';
    }
  }
}
