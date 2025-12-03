/// Model for CBP Border Wait Time API response - Commercial Trucks Only
class BorderWaitTime {
  final int portNumber;
  final String portName;
  final String crossingName;
  final String portStatus;
  final int maxLanes;
  final int lanesOpen;
  final int? commercialDelay; // Commercial truck delay in minutes
  final int? fastLanesDelay; // FAST lanes delay
  final int commercialLanesOpen;
  final int fastLanesOpen;
  final int fastMaxLanes;
  final String? hours;
  final String? border;
  final DateTime? lastUpdated;
  final String? updateTime; // When the data was last updated
  final String? operationalStatus; // e.g., "delay", "no delay", "Lanes Closed"
  final String? fastOperationalStatus;
  final String? constructionNotice;
  final String? time; // Current time from API

  BorderWaitTime({
    required this.portNumber,
    required this.portName,
    required this.crossingName,
    required this.portStatus,
    required this.maxLanes,
    required this.lanesOpen,
    this.commercialDelay,
    this.fastLanesDelay,
    required this.commercialLanesOpen,
    required this.fastLanesOpen,
    this.fastMaxLanes = 0,
    this.hours,
    this.border,
    this.lastUpdated,
    this.updateTime,
    this.operationalStatus,
    this.fastOperationalStatus,
    this.constructionNotice,
    this.time,
  });

  factory BorderWaitTime.fromJson(Map<String, dynamic> json) {
    int? parseDelay(dynamic value) {
      if (value == null ||
          value == 'N/A' ||
          value == 'no delay' ||
          value == 'Lanes Closed' ||
          value == '' ||
          value == 'Update Pending') {
        return null;
      }
      if (value is int) return value;
      if (value is String) {
        // Handle "X" format or numeric strings
        final parsed = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), ''));
        return parsed;
      }
      return null;
    }

    int parseInt(dynamic value) {
      if (value == null || value == '' || value == 'N/A') return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Extract commercial truck data - nested under standard_lanes and FAST_lanes
    final commercialVehicles = json['commercial_vehicle_lanes'] ?? {};
    final standardLanes = commercialVehicles['standard_lanes'] ?? {};
    final fastLanes = commercialVehicles['FAST_lanes'] ?? {};

    return BorderWaitTime(
      portNumber: parseInt(json['port_number']),
      portName: json['port_name'] ?? '',
      crossingName: json['crossing_name'] ?? '',
      portStatus: json['port_status'] ?? 'Closed',
      maxLanes: parseInt(commercialVehicles['maximum_lanes']),
      lanesOpen: parseInt(standardLanes['lanes_open']),
      commercialDelay: parseDelay(standardLanes['delay_minutes']),
      fastLanesDelay: parseDelay(fastLanes['delay_minutes']),
      commercialLanesOpen: parseInt(standardLanes['lanes_open']),
      fastLanesOpen: parseInt(fastLanes['lanes_open']),
      fastMaxLanes: parseInt(fastLanes['maximum_lanes']),
      hours: json['hours'],
      border: json['border'],
      lastUpdated: json['date'] != null
          ? DateTime.tryParse(json['date'])
          : null,
      updateTime: standardLanes['update_time']?.toString(),
      operationalStatus: standardLanes['operational_status']?.toString(),
      fastOperationalStatus: fastLanes['operational_status']?.toString(),
      constructionNotice: json['construction_notice']?.toString(),
      time: json['time']?.toString(),
    );
  }

  /// Check if this port has commercial truck operations
  bool get hasCommercialOperations =>
      commercialLanesOpen > 0 || fastLanesOpen > 0 || maxLanes > 0;

  /// Get display delay in hours/minutes format
  String get delayDisplay {
    final delay = commercialDelay;
    if (delay == null || delay == 0) {
      // Check operational status for "no delay" vs "Lanes Closed"
      if (operationalStatus == 'no delay') return 'No delay';
      if (operationalStatus == 'Lanes Closed') return 'Closed';
      if (operationalStatus == 'Update Pending') return 'Pending';
      return 'No delay';
    }
    if (delay < 60) return '$delay min';
    final hours = delay ~/ 60;
    final mins = delay % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'Hour' : 'Hours'}';
    return '${hours}h ${mins}m';
  }

  /// Get FAST lanes display delay
  String get fastDelayDisplay {
    final delay = fastLanesDelay;
    if (delay == null || delay == 0) {
      if (fastOperationalStatus == 'no delay') return 'No delay';
      if (fastOperationalStatus == 'Lanes Closed') return 'Closed';
      if (fastOperationalStatus == 'N/A') return 'N/A';
      if (fastOperationalStatus == 'Update Pending') return 'Pending';
      return 'No delay';
    }
    if (delay < 60) return '$delay min';
    final hours = delay ~/ 60;
    final mins = delay % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'Hour' : 'Hours'}';
    return '${hours}h ${mins}m';
  }

  /// Get total lanes open for display
  String get lanesOpenDisplay => '$lanesOpen lanes open';

  /// Location based on port name (simplified)
  String get location {
    // Common state/country mappings
    final portLower = portName.toLowerCase();
    if (portLower.contains('san ysidro') ||
        portLower.contains('otay') ||
        portLower.contains('tecate')) {
      return 'California, USA';
    }
    if (portLower.contains('laredo') ||
        portLower.contains('hidalgo') ||
        portLower.contains('brownsville') ||
        portLower.contains('el paso')) {
      return 'Texas, USA';
    }
    if (portLower.contains('nogales') || portLower.contains('douglas')) {
      return 'Arizona, USA';
    }
    if (portLower.contains('buffalo') || portLower.contains('champlain')) {
      return 'New York, USA';
    }
    if (portLower.contains('detroit') || portLower.contains('port huron')) {
      return 'Michigan, USA';
    }
    if (portLower.contains('blaine') || portLower.contains('seattle')) {
      return 'Washington, USA';
    }
    if (portLower.contains('sweetgrass')) {
      return 'Montana, USA';
    }
    // Default
    return borderType == 'Canadian' ? 'Canada Border' : 'Mexico Border';
  }

  /// Normalized border type from API string
  /// Returns 'Canadian' for US-Canada crossings, 'Mexican' for US-Mexico.
  String get borderType {
    final b = (border ?? '').toLowerCase();
    if (b.contains('canada')) return 'Canadian';
    if (b.contains('mexico')) return 'Mexican';
    return 'Unknown';
  }

  /// Unique identifier for saving
  String get uniqueId => '${portNumber}_$crossingName';
}

/// Saved border crossing preference
class SavedBorderCrossing {
  final int portNumber;
  final String crossingName;
  final String portName;

  SavedBorderCrossing({
    required this.portNumber,
    required this.crossingName,
    required this.portName,
  });

  factory SavedBorderCrossing.fromJson(Map<String, dynamic> json) {
    return SavedBorderCrossing(
      portNumber: json['port_number'] ?? 0,
      crossingName: json['crossing_name'] ?? '',
      portName: json['port_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'port_number': portNumber,
    'crossing_name': crossingName,
    'port_name': portName,
  };

  String get uniqueId => '${portNumber}_$crossingName';
}
