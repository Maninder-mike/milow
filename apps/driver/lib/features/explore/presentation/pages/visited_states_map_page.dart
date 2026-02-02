import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:intl/intl.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/features/explore/presentation/utils/explore_utils.dart';
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

    // 1. Try using the shared utility first (handles ST, City ST ZIP, etc)
    final code = ExploreUtils.extractStateCode(address);
    if (code != null) return code.toLowerCase();

    // 2. Fallback for full names
    final normalized = address.toLowerCase();
    for (final entry in _nameToCode.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton('USA', !_showCanada),
              _buildToggleButton('Canada', _showCanada),
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
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$_visitedCount',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          Text(
                            '/$_totalRegions',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Collected',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${((_totalRegions > 0 ? _visitedCount / _totalRegions : 0) * 100).toInt()}%',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                : _buildMapView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(BuildContext context) {
    return RepaintBoundary(
      key: _mapRepaintBoundaryKey,
      child: Stack(
        children: [
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
                  defaultColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  colors: _getMapColors(context),
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
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Visited',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
          color: isVisited
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isVisited
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            onTap: isVisited ? () => _handleRegionTap(code, name) : null,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isVisited
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVisited ? Icons.check : Icons.map_outlined,
                color: isVisited
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            title: Text(
              name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isVisited
                    ? null
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              isVisited
                  ? '${stats.visitCount} visits • Last: ${DateFormat.yMMMd().format(stats.lastVisited!)}'
                  : 'Not visited yet',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: isVisited
                ? const Icon(Icons.chevron_right, size: 20)
                : null,
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

  Widget _buildToggleButton(String label, bool isSelected) {
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
              ? Theme.of(context).colorScheme.surface
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Map<String, Color> _getMapColors(BuildContext context) {
    final Map<String, Color> colors = {};
    final colorScheme = Theme.of(context).colorScheme;

    _stateStats.forEach((code, stats) {
      Color color = colorScheme.primary;
      if (stats.visitCount > 5) {
        color = colorScheme.primary;
      } else if (stats.visitCount > 2) {
        color = colorScheme.primary.withValues(alpha: 0.85);
      } else {
        color = colorScheme.primary.withValues(alpha: 0.7);
      }

      final lowerCode = code.toLowerCase();
      final upperCode = code.toUpperCase();

      // USA Variants
      colors[lowerCode] = color;
      colors[upperCode] = color;
      colors['us-$lowerCode'] = color;
      colors['us-$upperCode'] = color;
      colors['US-$upperCode'] = color;

      // Canada Variants
      colors['ca-$lowerCode'] = color;
      colors['ca-$upperCode'] = color;
      colors['CA-$upperCode'] = color;
    });
    return colors;
  }

  void _handleRegionTap(String id, String defaultName) {
    // Map IDs usually come as 'us-ny' or 'ca-on'
    String code = id.toLowerCase();
    if (code.startsWith('us-')) {
      code = code.substring(3);
    } else if (code.startsWith('ca-')) {
      code = code.substring(3);
    }

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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.map,
                  color: stats != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    regionName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    stats != null
                        ? 'Visited ${stats!.visitCount} times'
                        : 'Not yet visited',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (stats != null) ...[
            Text(
              'RECENT ACTIVITY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
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
                  return _buildListTile(context, item);
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
                      Icons.landscape_outlined,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No visits recorded here yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
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
                      label: const Text('Add Trip Here'),
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

  Widget _buildListTile(BuildContext context, dynamic item) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (item is Trip) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.local_shipping_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text(
          'Trip ${item.tripNumber}',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat.yMMMd().format(item.tripDate),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 16,
          color: colorScheme.outline,
        ),
      );
    } else if (item is FuelEntry) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.local_gas_station_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text(
          'Fuel Stop',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat.yMMMd().format(item.fuelDate),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          '\$${item.totalCost.toStringAsFixed(0)}',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
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
