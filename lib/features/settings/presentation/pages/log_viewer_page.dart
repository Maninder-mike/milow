import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:share_plus/share_plus.dart';

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  List<String> _logs = [];
  bool _isLoading = true;
  String? _logFilePath;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'ERROR',
    'WARNING',
    'INFO',
    'DEBUG',
    'CRITICAL',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final logs = logger.getRecentLogs(count: 200);
      final path = await logger.getLogFilePath();

      setState(() {
        _logs = logs.reversed.toList(); // Show newest first
        _logFilePath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _logs = ['Failed to load logs: $e'];
        _isLoading = false;
      });
    }
  }

  List<String> get _filteredLogs {
    if (_selectedFilter == 'All') return _logs;
    return _logs
        .where((log) => log.contains('[${_selectedFilter.padRight(8)}]'))
        .toList();
  }

  Color _getLogColor(String log) {
    if (log.contains('[CRITICAL]')) return Colors.purple;
    if (log.contains('[ERROR')) return Colors.red;
    if (log.contains('[WARNING')) return Colors.orange;
    if (log.contains('[INFO')) return Colors.blue;
    if (log.contains('[DEBUG')) return Colors.grey;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
  }

  IconData _getLogIcon(String log) {
    if (log.contains('[CRITICAL]')) return Icons.dangerous;
    if (log.contains('[ERROR')) return Icons.error;
    if (log.contains('[WARNING')) return Icons.warning;
    if (log.contains('[INFO')) return Icons.info;
    if (log.contains('[DEBUG')) return Icons.bug_report;
    return Icons.article;
  }

  Future<void> _exportLogs() async {
    try {
      final content = await logger.exportLogs();
      await Share.share(content, subject: 'Milow App Logs');
      await logger.logUserAction('Exported logs');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export logs: $e')));
      }
    }
  }

  Future<void> _copyLogs() async {
    try {
      final content = await logger.exportLogs();
      await Clipboard.setData(ClipboardData(text: content));
      await logger.logUserAction('Copied logs to clipboard');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to copy logs: $e')));
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text(
          'Are you sure you want to clear all logs? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await logger.clearLogs();
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Logs cleared')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Activity Logs',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportLogs();
                  break;
                case 'copy':
                  _copyLogs();
                  break;
                case 'clear':
                  _clearLogs();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 12),
                    Text('Export Logs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 12),
                    Text('Copy to Clipboard'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Clear Logs', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      selectedColor: _getFilterColor(
                        filter,
                      ).withValues(alpha: 0.2),
                      checkmarkColor: _getFilterColor(filter),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? _getFilterColor(filter)
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Log file path info
          if (_logFilePath != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _logFilePath!.split('/').last,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_filteredLogs.length} entries',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Logs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No logs found',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).disabledColor,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[index];
                      final color = _getLogColor(log);
                      final icon = _getLogIcon(log);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        color: isDark
                            ? color.withValues(alpha: 0.1)
                            : color.withValues(alpha: 0.05),
                        child: InkWell(
                          onTap: () => _showLogDetails(log),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 18, color: color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    log.length > 200
                                        ? '${log.substring(0, 200)}...'
                                        : log,
                                    style: GoogleFonts.firaCode(
                                      fontSize: 11,
                                      color: color,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'CRITICAL':
        return Colors.purple;
      case 'ERROR':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
        return Colors.blue;
      case 'DEBUG':
        return Colors.grey;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  void _showLogDetails(String log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(_getLogIcon(log), color: _getLogColor(log)),
                  const SizedBox(width: 12),
                  Text(
                    'Log Details',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: log));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Log copied')),
                      );
                    },
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  log,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    height: 1.5,
                    color: _getLogColor(log),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
