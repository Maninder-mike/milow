import 'load_location.dart';
import 'appointment_window.dart';

enum StopType {
  pickup,
  delivery,
  other;

  String get value => name;

  static StopType? fromValue(String? value) {
    if (value == 'pickup') return StopType.pickup;
    if (value == 'delivery') return StopType.delivery;
    if (value == 'other') return StopType.other;
    return null;
  }
}

class Stop {
  final String id;
  final String loadId;
  final int sequence;
  final StopType type;
  final LoadLocation location;
  final String? notes;

  // Enhanced Details
  final String? commodity;
  final String? quantity;
  final double? weight;
  final String? weightUnit; // 'Lbs' or 'Kgs'
  final String? stopReference; // PO#, Pickup#, etc.
  final String? instructions; // Driver instructions
  final DateTime? appointmentTime;
  final AppointmentWindow? appointmentWindow;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? arrivedAt;

  Stop({
    required this.id,
    required this.loadId,
    required this.sequence,
    required this.type,
    required this.location,
    this.notes,
    this.commodity,
    this.quantity,
    this.weight,
    this.weightUnit,
    this.stopReference,
    this.instructions,
    this.appointmentTime,
    this.appointmentWindow,
    this.isCompleted = false,
    this.completedAt,
    this.arrivedAt,
  });

  factory Stop.empty() {
    return Stop(
      id: '',
      loadId: '',
      sequence: 1,
      type: StopType.pickup,
      location: LoadLocation.empty(),
    );
  }

  Stop copyWith({
    String? id,
    String? loadId,
    int? sequence,
    StopType? type,
    LoadLocation? location,
    String? notes,
    String? commodity,
    String? quantity,
    double? weight,
    String? weightUnit,
    String? stopReference,
    String? instructions,
    DateTime? appointmentTime,
    AppointmentWindow? appointmentWindow,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return Stop(
      id: id ?? this.id,
      loadId: loadId ?? this.loadId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      commodity: commodity ?? this.commodity,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      stopReference: stopReference ?? this.stopReference,
      instructions: instructions ?? this.instructions,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      appointmentWindow: appointmentWindow ?? this.appointmentWindow,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final locMap = location.toJson();
    locMap.remove('date'); // 'date' is not a column in 'stops' table

    // Database normalization: Store weight as Kgs
    double? weightDb = weight;
    if (weight != null && weightUnit == 'Lbs') {
      weightDb = weight! * 0.45359237;
    }

    return {
      if (id.isNotEmpty) 'id': id,
      'load_id': loadId,
      'sequence': sequence,
      'type': type.name,
      'notes': notes,
      'commodity': commodity,
      'quantity': quantity,
      'weight': weightDb,
      'weight_unit': weightUnit,
      'stop_reference': stopReference,
      'instructions': instructions,
      'appointment_time':
          appointmentTime?.toIso8601String() ?? location.date.toIso8601String(),
      'appointment_window': appointmentWindow?.toJson(),
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      ...locMap,
    };
  }

  factory Stop.fromJson(Map<String, dynamic> json) {
    final unit = json['weight_unit'] as String? ?? 'Kgs';
    double? weightApp = (json['weight'] as num?)?.toDouble();

    // Database normalization: Load as Lbs if unit was Lbs
    if (weightApp != null && unit == 'Lbs') {
      weightApp = weightApp / 0.45359237;
    }

    return Stop(
      id: json['id'] as String? ?? '',
      loadId: json['load_id'] as String? ?? '',
      sequence: json['sequence'] as int? ?? 1,
      type: StopType.values.byName(json['type'] as String? ?? 'pickup'),
      location: LoadLocation.fromMap(
        json,
        json['appointment_time'] ?? json['scheduled_time'],
      ),
      notes: json['notes'] as String?,
      commodity: json['commodity'] as String?,
      quantity: json['quantity'] as String?,
      weight: weightApp,
      weightUnit: unit,
      stopReference: json['stop_reference'] as String?,
      instructions: json['instructions'] as String?,
      appointmentTime: json['appointment_time'] != null
          ? DateTime.parse(json['appointment_time'] as String)
          : null,
      appointmentWindow: json['appointment_window'] != null
          ? AppointmentWindow.fromJson(
              json['appointment_window'] as Map<String, dynamic>,
            )
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
    );
  }
}
