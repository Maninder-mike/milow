import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/models/border_wait_time.dart';
import 'package:milow/core/services/border_wait_time_service.dart';

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
      filtered = filtered.where((p) => p.border == _filterBorder).toList();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF667085);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Border Crossings',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_savedCrossings.length}/5 selected',
                style: GoogleFonts.inter(fontSize: 14, color: subtextColor),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF007AFF)),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: GoogleFonts.inter(fontSize: 15, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search border crossings...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15,
                        color: subtextColor,
                      ),
                      prefixIcon: Icon(Icons.search, color: subtextColor),
                      filled: true,
                      fillColor: cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                // Filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('All', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Canadian', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Mexican', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Saved crossings section
                if (_savedCrossings.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark,
                          size: 18,
                          color: const Color(0xFF007AFF),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Crossings',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _savedCrossings.length,
                      itemBuilder: (context, index) {
                        final saved = _savedCrossings[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(
                              saved.portName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: const Color(0xFF007AFF),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
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
                  const SizedBox(height: 16),
                ],
                // Available ports list
                Expanded(
                  child: _filteredPorts.isEmpty
                      ? Center(
                          child: Text(
                            'No border crossings found',
                            style: GoogleFonts.inter(color: subtextColor),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredPorts.length,
                          itemBuilder: (context, index) {
                            final port = _filteredPorts[index];
                            final isSaved = _isSaved(port);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: isSaved
                                    ? Border.all(
                                        color: const Color(0xFF007AFF),
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: port.border == 'Canadian'
                                        ? const Color(
                                            0xFFDC2626,
                                          ).withValues(alpha: 0.1)
                                        : const Color(
                                            0xFF16A34A,
                                          ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      port.border == 'Canadian'
                                          ? '🇨🇦'
                                          : '🇲🇽',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  port.portName,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      port.crossingName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: subtextColor,
                                      ),
                                    ),
                                    Text(
                                      port.location,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: subtextColor.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    color: isSaved
                                        ? const Color(0xFF007AFF)
                                        : subtextColor,
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

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _filterBorder == label;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : const Color(0xFF667085)),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterBorder = label);
      },
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      selectedColor: const Color(0xFF007AFF),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
