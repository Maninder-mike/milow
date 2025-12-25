import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:milow_core/milow_core.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:io';

class VisitedStatesMapPage extends StatefulWidget {
  final List<Trip> trips;
  final List<FuelEntry> fuelEntries;

  const VisitedStatesMapPage({
    required this.trips,
    required this.fuelEntries,
    super.key,
  });

  @override
  State<VisitedStatesMapPage> createState() => _VisitedStatesMapPageState();
}

class _VisitedStatesMapPageState extends State<VisitedStatesMapPage> {
  // Map of region code (lowercase, 2 letters) to stats
  Map<String, _StateStats> _stateStats = {};

  // Toggle State
  bool _showCanada = false;

  // Region Sets
  static const Set<String> _usCodes = {
    'al',
    'ak',
    'az',
    'ar',
    'ca',
    'co',
    'ct',
    'de',
    'fl',
    'ga',
    'hi',
    'id',
    'il',
    'in',
    'ia',
    'ks',
    'ky',
    'la',
    'me',
    'md',
    'ma',
    'mi',
    'mn',
    'ms',
    'mo',
    'mt',
    'ne',
    'nv',
    'nh',
    'nj',
    'nm',
    'ny',
    'nc',
    'nd',
    'oh',
    'ok',
    'or',
    'pa',
    'ri',
    'sc',
    'sd',
    'tn',
    'tx',
    'ut',
    'vt',
    'va',
    'wa',
    'wv',
    'wi',
    'wy',
    'dc',
  };

  static const Set<String> _caCodes = {
    'ab',
    'bc',
    'mb',
    'nb',
    'nl',
    'ns',
    'nt',
    'nu',
    'on',
    'pe',
    'qc',
    'sk',
    'yt',
  };

  @override
  void initState() {
    super.initState();
    _processData();
  }

  void _processData() {
    final stats = <String, _StateStats>{};

    void processLocation(String location, DateTime date, dynamic source) {
      final code = _extractRegionCode(location);
      if (code != null) {
        if (!stats.containsKey(code)) {
          stats[code] = _StateStats(code: code, name: _getRegionName(code));
        }
        stats[code]!.visitCount++;
        if (stats[code]!.lastVisited == null ||
            date.isAfter(stats[code]!.lastVisited!)) {
          stats[code]!.lastVisited = date;
        }
        stats[code]!.recentActivity.add(source);
      }
    }

    for (final trip in widget.trips) {
      for (final loc in trip.deliveryLocations) {
        processLocation(loc, trip.tripDate, trip);
      }
      for (final loc in trip.pickupLocations) {
        processLocation(loc, trip.tripDate, trip);
      }
    }

    for (final fuel in widget.fuelEntries) {
      if (fuel.location != null) {
        processLocation(fuel.location!, fuel.fuelDate, fuel);
      }
    }

    // Sort recent activity
    for (final stat in stats.values) {
      stat.recentActivity.sort((a, b) {
        DateTime dateA = DateTime.now();
        if (a is Trip) dateA = a.tripDate;
        if (a is FuelEntry) dateA = a.fuelDate;

        DateTime dateB = DateTime.now();
        if (b is Trip) dateB = b.tripDate;
        if (b is FuelEntry) dateB = b.fuelDate;

        // Descending date
        return dateB.compareTo(dateA);
      });
    }

    setState(() {
      _stateStats = stats;
    });
  }

  int get _visitedCount {
    if (_showCanada) {
      return _stateStats.keys.where((code) => _caCodes.contains(code)).length;
    } else {
      return _stateStats.keys.where((code) => _usCodes.contains(code)).length;
    }
  }

  int get _totalRegions =>
      _showCanada ? 13 : 51; // 50 states + DC, 13 provinces/territories

  static const Map<String, String> _nameToCode = {
    // US
    'alabama': 'al', 'alaska': 'ak', 'arizona': 'az', 'arkansas': 'ar',
    'california': 'ca', 'colorado': 'co', 'connecticut': 'ct', 'delaware': 'de',
    'florida': 'fl', 'georgia': 'ga', 'hawaii': 'hi', 'idaho': 'id',
    'illinois': 'il', 'indiana': 'in', 'iowa': 'ia', 'kansas': 'ks',
    'kentucky': 'ky', 'louisiana': 'la', 'maine': 'me', 'maryland': 'md',
    'massachusetts': 'ma',
    'michigan': 'mi',
    'minnesota': 'mn',
    'mississippi': 'ms',
    'missouri': 'mo', 'montana': 'mt', 'nebraska': 'ne', 'nevada': 'nv',
    'new hampshire': 'nh',
    'new jersey': 'nj',
    'new mexico': 'nm',
    'new york': 'ny',
    'north carolina': 'nc',
    'north dakota': 'nd',
    'ohio': 'oh',
    'oklahoma': 'ok',
    'oregon': 'or',
    'pennsylvania': 'pa',
    'rhode island': 'ri',
    'south carolina': 'sc',
    'south dakota': 'sd', 'tennessee': 'tn', 'texas': 'tx', 'utah': 'ut',
    'vermont': 'vt',
    'virginia': 'va',
    'washington': 'wa',
    'west virginia': 'wv',
    'wisconsin': 'wi', 'wyoming': 'wy', 'district of columbia': 'dc',
    // CA
    'alberta': 'ab',
    'british columbia': 'bc',
    'manitoba': 'mb',
    'new brunswick': 'nb',
    'newfoundland and labrador': 'nl',
    'newfoundland': 'nl',
    'nova scotia': 'ns',
    'northwest territories': 'nt', 'nunavut': 'nu', 'ontario': 'on',
    'prince edward island': 'pe',
    'quebec': 'qc',
    'saskatchewan': 'sk',
    'yukon': 'yt',
  };

  String? _extractRegionCode(String address) {
    if (address.isEmpty) return null;
    final normalized = address.replaceAll('\n', ' ').toLowerCase();

    // 1. Direct match with full names
    for (final entry in _nameToCode.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    // 2. Check for 2-letter codes
    final allCodes = {..._usCodes, ..._caCodes};
    // Split by comma, space, period to isolate words
    final parts = normalized.split(RegExp(r'[\s,\.]+'));

    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      if (allCodes.contains(part)) {
        return part;
      }
    }

    return null;
  }

  String _getRegionName(String code) {
    const names = {
      // US
      'al': 'Alabama', 'ak': 'Alaska', 'az': 'Arizona', 'ar': 'Arkansas',
      'ca': 'California',
      'co': 'Colorado',
      'ct': 'Connecticut',
      'de': 'Delaware',
      'fl': 'Florida', 'ga': 'Georgia', 'hi': 'Hawaii', 'id': 'Idaho',
      'il': 'Illinois', 'in': 'Indiana', 'ia': 'Iowa', 'ks': 'Kansas',
      'ky': 'Kentucky', 'la': 'Louisiana', 'me': 'Maine', 'md': 'Maryland',
      'ma': 'Massachusetts',
      'mi': 'Michigan',
      'mn': 'Minnesota',
      'ms': 'Mississippi',
      'mo': 'Missouri', 'mt': 'Montana', 'ne': 'Nebraska', 'nv': 'Nevada',
      'nh': 'New Hampshire',
      'nj': 'New Jersey',
      'nm': 'New Mexico',
      'ny': 'New York',
      'nc': 'North Carolina',
      'nd': 'North Dakota',
      'oh': 'Ohio',
      'ok': 'Oklahoma',
      'or': 'Oregon',
      'pa': 'Pennsylvania',
      'ri': 'Rhode Island',
      'sc': 'South Carolina',
      'sd': 'South Dakota', 'tn': 'Tennessee', 'tx': 'Texas', 'ut': 'Utah',
      'vt': 'Vermont',
      'va': 'Virginia',
      'wa': 'Washington',
      'wv': 'West Virginia',
      'wi': 'Wisconsin', 'wy': 'Wyoming', 'dc': 'District of Columbia',
      // CA
      'ab': 'Alberta',
      'bc': 'British Columbia',
      'mb': 'Manitoba',
      'nb': 'New Brunswick',
      'nl': 'Newfoundland and Labrador',
      'ns': 'Nova Scotia',
      'nt': 'Northwest Territories',
      'nu': 'Nunavut',
      'on': 'Ontario',
      'pe': 'Prince Edward Island',
      'qc': 'Quebec',
      'sk': 'Saskatchewan', 'yt': 'Yukon',
    };
    return names[code] ?? code.toUpperCase();
  }

  final GlobalKey _mapRepaintBoundaryKey = GlobalKey();
  bool _isListView = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
        title: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton('USA', !_showCanada, isDark),
              _buildToggleButton('Canada', _showCanada, isDark),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isListView ? Icons.map_outlined : Icons.list_alt),
            onPressed: () => setState(() => _isListView = !_isListView),
            tooltip: _isListView ? 'Show Map' : 'Show List',
          ),
          if (!_isListView)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _captureAndShare,
              tooltip: 'Share Map',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _showCanada ? 'Provinces Visited' : 'States Visited',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$_visitedCount',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                          Text(
                            '/$_totalRegions',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showCanada ? 'Collected' : 'Collected',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Circular Progress
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            value: _totalRegions > 0
                                ? _visitedCount / _totalRegions
                                : 0,
                            strokeWidth: 5,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF007AFF),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${((_totalRegions > 0 ? _visitedCount / _totalRegions : 0) * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content Area (Map or List)
          Expanded(
            child: _isListView
                ? _buildListView(context)
                : _buildMapView(isDark, textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(bool isDark, Color textColor) {
    return RepaintBoundary(
      key: _mapRepaintBoundaryKey,
      child: Stack(
        children: [
          // Map Background (for sharing)
          Container(color: isDark ? const Color(0xFF121212) : Colors.white),
          InteractiveViewer(
            maxScale: 10.0,
            minScale: 1.0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SimpleMap(
                  key: ValueKey(_showCanada ? 'canada' : 'usa'),
                  instructions: _showCanada
                      ? SMapCanada.instructions
                      : SMapUnitedStates.instructions,
                  defaultColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F4F7),
                  colors: _getMapColors(isDark),
                  callback: (id, name, tapDetails) {
                    _handleRegionTap(id, name);
                  },
                ),
              ),
            ),
          ),
          // Simple Legend
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF007AFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Visited',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    final activeCodes = _showCanada ? _caCodes : _usCodes;
    final sortedCodes = activeCodes.toList()
      ..sort((a, b) => _getRegionName(a).compareTo(_getRegionName(b)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCodes.length,
      itemBuilder: (context, index) {
        final code = sortedCodes[index];
        final stats = _stateStats[code];
        final isVisited = stats != null && stats.visitCount > 0;
        final name = _getRegionName(code);

        return Card(
          elevation: 0,
          color: Colors.transparent,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isVisited
                    ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            tileColor: isVisited
                ? const Color(0xFF007AFF).withValues(alpha: 0.05)
                : null,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isVisited
                    ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVisited ? Icons.check : Icons.map_outlined,
                color: isVisited ? const Color(0xFF007AFF) : Colors.grey,
                size: 20,
              ),
            ),
            title: Text(
              name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: isVisited ? null : Colors.grey,
              ),
            ),
            subtitle: isVisited
                ? Text(
                    '${stats.visitCount} visits • Last: ${DateFormat.yMMMd().format(stats.lastVisited!)}',
                    style: GoogleFonts.inter(fontSize: 12),
                  )
                : Text(
                    'Not visited yet',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
            trailing: isVisited
                ? const Icon(Icons.chevron_right, color: Colors.grey)
                : null,
            onTap: isVisited ? () => _handleRegionTap(code, name) : null,
          ),
        );
      },
    );
  }

  Future<void> _captureAndShare() async {
    try {
      // Find the render object
      final boundary =
          _mapRepaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture image
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/milow_map_share.png').create();
      await file.writeAsBytes(pngBytes);

      // Share
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Check out my visited states on Milow! 🚛💨');
    } catch (e) {
      debugPrint('Error sharing map: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share map image')),
        );
      }
    }
  }

  Widget _buildToggleButton(String label, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCanada = label == 'Canada';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.grey[700] : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : Colors.grey,
          ),
        ),
      ),
    );
  }

  Map<String, Color> _getMapColors(bool isDark) {
    final Map<String, Color> colors = {};

    // Iterate over our collected stats
    _stateStats.forEach((code, stats) {
      // Code is our normalized 2-letter code (e.g. 'ny', 'on')

      Color color = const Color(0xFF007AFF);
      if (stats.visitCount > 5) {
        color = const Color(0xFF003366);
      } else if (stats.visitCount > 2) {
        color = const Color(0xFF0056B3);
      } else {
        color = const Color(0xFF007AFF);
      }

      // SMap packages can be inconsistent.
      // Some versions use 'us-ny', some 'ny'.
      // We set ALL possible variants to be safe.

      // 1. Raw code
      colors[code] = color;

      // 2. Prefixed code (US)
      colors['us-$code'] = color;

      // 3. Prefixed code (Canada)
      colors['ca-$code'] = color;
    });

    return colors;
  }

  void _handleRegionTap(String id, String defaultName) {
    // Map IDs usually come as 'us-ny' or 'ca-on'
    String code = id;
    if (code.startsWith('us-')) {
      code = code.substring(3);
    } else if (code.startsWith('ca-')) {
      code = code.substring(3);
    }

    code = code.toLowerCase();

    final stats = _stateStats[code];
    // Only show sheet if we have stats or if it's a valid region tap
    final name = stats?.name ?? _getRegionName(code);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _RegionDetailsSheet(regionName: name, stats: stats),
    );
  }
}

class _RegionDetailsSheet extends StatelessWidget {
  final String regionName;
  final _StateStats? stats;

  const _RegionDetailsSheet({required this.regionName, this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: stats != null
                      ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.map,
                  color: stats != null ? const Color(0xFF007AFF) : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    regionName,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Text(
                    stats != null
                        ? 'Visited ${stats!.visitCount} times'
                        : 'Not yet visited',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (stats != null) ...[
            Text(
              'RECENT ACTIVITY',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stats!.recentActivity.take(5).length,
                itemBuilder: (context, index) {
                  final item = stats!.recentActivity[index];
                  return _buildListTile(context, item, isDark);
                },
              ),
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.terrain,
                      size: 48,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No visits recorded here yet.',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.pop(); // Close sheet
                        context.go(
                          '/add_entry',
                          extra: {'startLocation': regionName},
                        );
                      },
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 18,
                      ),
                      label: Text(
                        'Add Trip Here',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, dynamic item, bool isDark) {
    if (item is Trip) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.local_shipping_outlined,
          color: isDark ? Colors.white70 : Colors.black54,
          size: 20,
        ),
        title: Text(
          'Trip ${item.tripNumber}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          DateFormat.yMMMd().format(item.tripDate),
          style: GoogleFonts.inter(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      );
    } else if (item is FuelEntry) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.local_gas_station_outlined,
          color: isDark ? Colors.white70 : Colors.black54,
          size: 20,
        ),
        title: Text(
          'Fuel Stop',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          DateFormat.yMMMd().format(item.fuelDate),
          style: GoogleFonts.inter(fontSize: 12),
        ),
        trailing: Text(
          '\$${item.totalCost.toStringAsFixed(0)}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: const Color(0xFF007AFF),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _StateStats {
  final String code;
  final String name;
  int visitCount = 0;
  DateTime? lastVisited;
  final List<dynamic> recentActivity = [];

  _StateStats({required this.code, required this.name});
}
