import 'package:flutter/material.dart';
import 'package:milow/core/models/border_wait_time.dart';
import 'package:milow/core/services/border_wait_time_service.dart';
import 'package:milow/core/constants/design_tokens.dart';

class BorderCrossingSelector extends StatefulWidget {
  const BorderCrossingSelector({super.key});

  @override
  State<BorderCrossingSelector> createState() => _BorderCrossingSelectorState();
}

class _BorderCrossingSelectorState extends State<BorderCrossingSelector> {
  List<BorderWaitTime> _availablePorts = [];
  List<SavedBorderCrossing> _savedCrossings = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filterBorder = 'All'; // All, Canadian, Mexican

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final ports = await BorderWaitTimeService.getAvailablePorts();
      final saved = await BorderWaitTimeService.getSavedBorderCrossings();
      setState(() {
        _availablePorts = ports;
        _savedCrossings = saved;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<BorderWaitTime> get _filteredPorts {
    var filtered = _availablePorts;

    // Filter by border type
    if (_filterBorder != 'All') {
      filtered = filtered.where((p) => p.borderType == _filterBorder).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (p) =>
                p.portName.toLowerCase().contains(query) ||
                p.crossingName.toLowerCase().contains(query) ||
                p.location.toLowerCase().contains(query),
          )
          .toList();
    }

    return filtered;
  }

  bool _isSaved(BorderWaitTime port) {
    return _savedCrossings.any((s) => s.uniqueId == port.uniqueId);
  }

  Future<void> _toggleSaved(BorderWaitTime port) async {
    if (_isSaved(port)) {
      await BorderWaitTimeService.removeBorderCrossing(port.uniqueId);
    } else {
      if (_savedCrossings.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 border crossings allowed')),
        );
        return;
      }
      await BorderWaitTimeService.addBorderCrossing(port);
    }
    final saved = await BorderWaitTimeService.getSavedBorderCrossings();
    setState(() => _savedCrossings = saved);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      appBar: AppBar(
        backgroundColor: tokens.scaffoldAltBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tokens.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Border Crossings',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: tokens.spacingM),
              child: Text(
                '${_savedCrossings.length}/5 selected',
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
                strokeWidth: 3.0,
                strokeCap: StrokeCap.round,
              ),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: EdgeInsets.all(tokens.spacingM),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: textTheme.bodyMedium?.copyWith(
                      color: tokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search border crossings...',
                      hintStyle: textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: tokens.textSecondary,
                      ),
                      filled: true,
                      fillColor: tokens.surfaceContainer,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: tokens.spacingM,
                        vertical: tokens.spacingM - 2,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.shapeM),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                // Filter chips
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      SizedBox(width: tokens.spacingS),
                      _buildFilterChip('Canadian'),
                      SizedBox(width: tokens.spacingS),
                      _buildFilterChip('Mexican'),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spacingM),
                // Saved crossings section
                if (_savedCrossings.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        SizedBox(width: tokens.spacingS),
                        Text(
                          'Selected Crossings',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.spacingS),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacingM,
                      ),
                      itemCount: _savedCrossings.length,
                      itemBuilder: (context, index) {
                        final saved = _savedCrossings[index];
                        return Container(
                          margin: EdgeInsets.only(right: tokens.spacingS),
                          child: Chip(
                            label: Text(
                              saved.portName,
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            backgroundColor: colorScheme.primary,
                            deleteIcon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: colorScheme.onPrimary,
                            ),
                            onDeleted: () async {
                              await BorderWaitTimeService.removeBorderCrossing(
                                saved.uniqueId,
                              );
                              final savedList =
                                  await BorderWaitTimeService.getSavedBorderCrossings();
                              setState(() => _savedCrossings = savedList);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: tokens.spacingM),
                ],
                // Available ports list
                Expanded(
                  child: _filteredPorts.isEmpty
                      ? Center(
                          child: Text(
                            'No border crossings found',
                            style: textTheme.bodyMedium?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacingM,
                          ),
                          itemCount: _filteredPorts.length,
                          itemBuilder: (context, index) {
                            final port = _filteredPorts[index];
                            final isSaved = _isSaved(port);

                            return Container(
                              margin: EdgeInsets.only(bottom: tokens.spacingS),
                              decoration: BoxDecoration(
                                color: tokens.surfaceContainer,
                                borderRadius: BorderRadius.circular(
                                  tokens.shapeM,
                                ),
                                border: isSaved
                                    ? Border.all(
                                        color: colorScheme.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: tokens.spacingM,
                                  vertical: tokens.spacingS,
                                ),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: port.borderType == 'Canadian'
                                        ? tokens.error.withValues(alpha: 0.1)
                                        : port.borderType == 'Mexican'
                                        ? tokens.success.withValues(alpha: 0.1)
                                        : tokens.textSecondary.withValues(
                                            alpha: 0.2,
                                          ),
                                    borderRadius: BorderRadius.circular(
                                      tokens.shapeS + 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      port.borderType == 'Canadian'
                                          ? '🇨🇦'
                                          : port.borderType == 'Mexican'
                                          ? '🇲🇽'
                                          : '🇺🇸',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  port.portName,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      port.crossingName,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      port.location,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: tokens.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isSaved
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    color: isSaved
                                        ? colorScheme.primary
                                        : tokens.textSecondary,
                                  ),
                                  onPressed: () => _toggleSaved(port),
                                ),
                                onTap: () => _toggleSaved(port),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterBorder == label;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return FilterChip(
      label: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: isSelected ? colorScheme.onPrimary : tokens.textSecondary,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterBorder = label);
      },
      backgroundColor: tokens.surfaceContainer,
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.shapeL + tokens.spacingXS),
      ),
    );
  }
}
