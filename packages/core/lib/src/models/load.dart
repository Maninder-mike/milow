import 'load_status.dart';
import 'stop.dart';
import 'load_location.dart';
import 'accessorial_charge.dart';

class Load {
  final String id;
  final String loadReference;
  final String? brokerId;
  final String brokerName;
  final double rate;
  final String currency;
  final String goods;
  final double weight;
  final String quantity;
  final String weightUnit;
  final List<Stop> stops;
  final LoadStatus status;
  final String loadNotes;
  final String companyNotes;
  final String? assignedDriverId;
  final String? assignedTruckId;
  final String? assignedTrailerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String tripNumber;
  final String? poNumber;
  final String? companyId;
  final List<AccessorialCharge> accessorials;

  Load({
    required this.id,
    required this.loadReference,
    this.brokerId,
    required this.brokerName,
    required this.rate,
    required this.currency,
    required this.goods,
    this.weight = 0.0,
    this.quantity = '',
    this.weightUnit = 'Lbs',
    required this.stops,
    required this.status,
    required this.loadNotes,
    required this.companyNotes,
    this.assignedDriverId,
    this.assignedTruckId,
    this.assignedTrailerId,
    this.createdAt,
    this.updatedAt,
    required this.tripNumber,
    this.poNumber,
    this.companyId,
    this.accessorials = const [],
  });

  factory Load.empty() {
    return Load(
      id: '',
      loadReference: '',
      brokerName: '',
      rate: 0.0,
      currency: 'CAD',
      goods: '',
      weight: 0.0,
      quantity: '',
      stops: [
        Stop(
          id: '',
          loadId: '',
          sequence: 1,
          type: StopType.pickup,
          location: LoadLocation.empty().copyWith(date: DateTime.now()),
        ),
        Stop(
          id: '',
          loadId: '',
          sequence: 2,
          type: StopType.delivery,
          location: LoadLocation.empty().copyWith(
            date: DateTime.now().add(const Duration(days: 1)),
          ),
        ),
      ],
      status: LoadStatus.pending,
      loadNotes: '',
      companyNotes: '',
      tripNumber: '',
      poNumber: null,
      accessorials: [],
    );
  }

  // Convenience getters
  LoadLocation get pickup => stops.isNotEmpty
      ? stops
            .firstWhere(
              (s) => s.type == StopType.pickup,
              orElse: () => stops.first,
            )
            .location
      : LoadLocation.empty();

  LoadLocation get delivery => stops.isNotEmpty
      ? stops
            .lastWhere(
              (s) => s.type == StopType.delivery,
              orElse: () => stops.last,
            )
            .location
      : LoadLocation.empty();

  bool get isDelayed {
    if (status == LoadStatus.delivered || status == LoadStatus.cancelled) {
      return false;
    }
    return DateTime.now().isAfter(delivery.date);
  }

  Load copyWith({
    String? id,
    String? loadReference,
    String? brokerId,
    String? brokerName,
    double? rate,
    String? currency,
    String? goods,
    double? weight,
    String? quantity,
    String? weightUnit,
    List<Stop>? stops,
    LoadStatus? status,
    String? loadNotes,
    String? companyNotes,
    String? assignedDriverId,
    String? assignedTruckId,
    String? assignedTrailerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tripNumber,
    String? poNumber,
    String? companyId,
    List<AccessorialCharge>? accessorials,
  }) {
    return Load(
      id: id ?? this.id,
      loadReference: loadReference ?? this.loadReference,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      rate: rate ?? this.rate,
      currency: currency ?? this.currency,
      goods: goods ?? this.goods,
      weight: weight ?? this.weight,
      quantity: quantity ?? this.quantity,
      weightUnit: weightUnit ?? this.weightUnit,
      stops: stops ?? this.stops,
      status: status ?? this.status,
      loadNotes: loadNotes ?? this.loadNotes,
      companyNotes: companyNotes ?? this.companyNotes,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedTruckId: assignedTruckId ?? this.assignedTruckId,
      assignedTrailerId: assignedTrailerId ?? this.assignedTrailerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tripNumber: tripNumber ?? this.tripNumber,
      poNumber: poNumber ?? this.poNumber,
      companyId: companyId ?? this.companyId,
      accessorials: accessorials ?? this.accessorials,
    );
  }

  Map<String, dynamic> toJson() {
    double? weightDb = weight;
    if (weightUnit == 'Lbs') {
      weightDb = weight * 0.45359237;
    }

    return {
      if (id.isNotEmpty) 'id': id,
      'load_reference': loadReference,
      'broker_id': brokerId,
      'rate': rate,
      'currency': currency,
      'goods': goods,
      'weight': weightDb,
      'weight_unit': weightUnit,
      'quantity': quantity,
      'status': status.name,
      'load_notes': loadNotes,
      'company_notes': companyNotes,
      'assigned_driver_id': assignedDriverId,
      'assigned_truck_id': assignedTruckId,
      'assigned_trailer_id': assignedTrailerId,
      'trip_number': tripNumber,
      'po_number': poNumber,
      'company_id': companyId,
      'accessorials': accessorials.map((e) => e.toJson()).toList(),
    };
  }

  factory Load.fromJson(Map<String, dynamic> json) {
    List<Stop> stops = [];
    if (json['stops'] != null && (json['stops'] as List).isNotEmpty) {
      stops = (json['stops'] as List).map((e) => Stop.fromJson(e)).toList();
      stops.sort((a, b) => a.sequence.compareTo(b.sequence));
    }

    final weightUnit = json['weight_unit'] as String? ?? 'Lbs';
    double weightApp = (json['weight'] as num?)?.toDouble() ?? 0.0;

    if (weightUnit == 'Lbs') {
      weightApp = weightApp / 0.45359237;
    }

    return Load(
      id: json['id'] as String,
      loadReference: json['load_reference'] as String? ?? '',
      brokerId: json['broker_id'] as String?,
      brokerName:
          (json['customers'] as Map<String, dynamic>?)?['name'] as String? ??
          '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'CAD',
      goods: json['goods'] as String? ?? '',
      weight: weightApp,
      quantity: json['quantity'] as String? ?? '',
      weightUnit: weightUnit,
      stops: stops,
      status: LoadStatusX.fromString(json['status'] as String? ?? 'pending'),
      loadNotes: json['load_notes'] as String? ?? '',
      companyNotes: json['company_notes'] as String? ?? '',
      assignedDriverId: json['assigned_driver_id'] as String?,
      assignedTruckId: json['assigned_truck_id'] as String?,
      assignedTrailerId: json['assigned_trailer_id'] as String?,
      tripNumber: json['trip_number'] as String? ?? '',
      poNumber: json['po_number'] as String?,
      companyId: json['company_id'] as String?,
      accessorials: json['accessorials'] != null
          ? (json['accessorials'] as List)
                .map((e) => AccessorialCharge.fromJson(e))
                .toList()
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
