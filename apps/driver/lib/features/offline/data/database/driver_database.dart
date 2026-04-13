import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:milow_core/milow_core.dart' as domain;

part 'driver_database.g.dart';

@DataClassName('TripData')
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable().named('user_id')();
  TextColumn get companyId => text().nullable().named('company_id')();
  TextColumn get vehicleId => text().nullable().named('vehicle_id')();
  TextColumn get tripNumber => text().named('trip_number')();
  TextColumn get truckNumber => text().named('truck_number')();
  TextColumn get tripsAndTrailers =>
      text().named('trips_and_trailers').nullable()(); // Legacy?

  TextColumn get trailers => text().withDefault(const Constant('[]'))();
  DateTimeColumn get tripDate => dateTime().named('trip_date')();
  TextColumn get pickupLocations =>
      text().named('pickup_locations').withDefault(const Constant('[]'))();
  TextColumn get pickupTimes =>
      text().named('pickup_times').withDefault(const Constant('[]'))();
  TextColumn get pickupCompleted =>
      text().named('pickup_completed').withDefault(const Constant('[]'))();
  TextColumn get deliveryLocations =>
      text().named('delivery_locations').withDefault(const Constant('[]'))();
  TextColumn get deliveryTimes =>
      text().named('delivery_times').withDefault(const Constant('[]'))();
  TextColumn get deliveryCompleted =>
      text().named('delivery_completed').withDefault(const Constant('[]'))();
  TextColumn get pickupDetention =>
      text().named('pickup_detention').withDefault(const Constant('[]'))();
  TextColumn get deliveryDetention =>
      text().named('delivery_detention').withDefault(const Constant('[]'))();
  RealColumn get startOdometer => real().nullable().named('start_odometer')();
  RealColumn get endOdometer => real().nullable().named('end_odometer')();
  TextColumn get distanceUnit =>
      text().named('distance_unit').withDefault(const Constant('mi'))();
  TextColumn get borderCrossing => text().nullable().named('border_crossing')();
  TextColumn get notes => text().nullable()();
  BoolColumn get isEmptyLeg =>
      boolean().named('is_empty_leg').withDefault(const Constant(false))();
  TextColumn get commodity => text().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get weightUnit =>
      text().named('weight_unit').withDefault(const Constant('lbs'))();
  IntColumn get pieces => integer().nullable()();
  TextColumn get referenceNumbers =>
      text().named('reference_numbers').withDefault(const Constant('[]'))();
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get lastUpdated =>
      dateTime().nullable().named('last_updated')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FuelEntryData')
class FuelEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable().named('user_id')();
  TextColumn get companyId => text().nullable().named('company_id')();
  TextColumn get vehicleId => text().nullable().named('vehicle_id')();
  DateTimeColumn get fuelDate => dateTime().named('fuel_date')();
  TextColumn get fuelType =>
      text().named('fuel_type').withDefault(const Constant('truck'))();
  TextColumn get truckNumber => text().nullable().named('truck_number')();
  TextColumn get reeferNumber => text().nullable().named('reefer_number')();
  TextColumn get location => text().nullable()();
  RealColumn get odometerReading =>
      real().nullable().named('odometer_reading')();
  RealColumn get reeferHours => real().nullable().named('reefer_hours')();
  RealColumn get fuelQuantity => real().named('fuel_quantity')();
  RealColumn get pricePerUnit => real().named('price_per_unit')();
  TextColumn get fuelUnit =>
      text().named('fuel_unit').withDefault(const Constant('gal'))();
  TextColumn get distanceUnit =>
      text().named('distance_unit').withDefault(const Constant('mi'))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  RealColumn get defQuantity =>
      real().named('def_quantity').withDefault(const Constant(0.0))();
  RealColumn get defPrice =>
      real().named('def_price').withDefault(const Constant(0.0))();
  BoolColumn get defFromYard =>
      boolean().named('def_from_yard').withDefault(const Constant(false))();
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get lastUpdated =>
      dateTime().nullable().named('last_updated')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DriverTruckInspectionData')
class DriverTruckInspections extends Table {
  TextColumn get id => text()();
  TextColumn get driverId => text().named('driver_id')();
  TextColumn get vehicleId => text().named('vehicle_id')();
  TextColumn get trailerId => text().nullable().named('trailer_id')();
  TextColumn get type => text()(); // 'pre-trip', 'post-trip'
  RealColumn get odometer => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get signedAt => dateTime().named('signed_at')();

  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get lastUpdated =>
      dateTime().nullable().named('last_updated')();

  TextColumn get signaturePath => text().nullable().named('signature_path')();
  TextColumn get signatureUrl => text().nullable().named('signature_url')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DriverTruckInspectionDefectData')
class DriverTruckInspectionDefects extends Table {
  TextColumn get id => text()();
  TextColumn get inspectionId =>
      text().named('inspection_id').references(DriverTruckInspections, #id)();
  TextColumn get category => text()();
  TextColumn get item => text().withDefault(const Constant(''))();
  TextColumn get comment => text().nullable()();
  BoolColumn get isRepaired =>
      boolean().named('is_repaired').withDefault(const Constant(false))();

  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();
  DateTimeColumn get lastUpdated =>
      dateTime().nullable().named('last_updated')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InspectionDefectPhotoData')
class InspectionDefectPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get defectId =>
      text().named('defect_id').references(DriverTruckInspectionDefects, #id)();
  TextColumn get localPath => text().named('local_path')();
  TextColumn get remoteUrl => text().named('remote_url').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LoadData')
class Loads extends Table {
  TextColumn get id => text()();
  TextColumn get loadReference => text().named('load_reference')();
  TextColumn get brokerId => text().nullable().named('broker_id')();
  TextColumn get brokerName => text().named('broker_name')();
  RealColumn get rate => real()();
  TextColumn get currency => text().withDefault(const Constant('CAD'))();
  TextColumn get goods => text()();
  RealColumn get weight => real().withDefault(const Constant(0.0))();
  TextColumn get quantity => text().withDefault(const Constant(''))();
  TextColumn get weightUnit =>
      text().named('weight_unit').withDefault(const Constant('lbs'))();
  TextColumn get status => text()(); // Use name from enum
  TextColumn get loadNotes => text().named('load_notes')();
  TextColumn get companyNotes => text().named('company_notes')();
  TextColumn get assignedDriverId =>
      text().nullable().named('assigned_driver_id')();
  TextColumn get assignedTruckId =>
      text().nullable().named('assigned_truck_id')();
  TextColumn get assignedTrailerId =>
      text().nullable().named('assigned_trailer_id')();
  TextColumn get tripNumber => text().named('trip_number')();
  TextColumn get poNumber => text().nullable().named('po_number')();
  TextColumn get companyId => text().nullable().named('company_id')();
  DateTimeColumn get createdAt => dateTime().nullable().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();

  // Accessorials stored as JSON for simplicity
  TextColumn get accessorials =>
      text().named('accessorials').withDefault(const Constant('[]'))();

  // Offline/Sync fields
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated =>
      dateTime().nullable().named('last_updated')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StopData')
class Stops extends Table {
  TextColumn get id => text()();
  TextColumn get loadId => text()
      .named('load_id')
      .references(Loads, #id, onDelete: KeyAction.cascade)();
  IntColumn get sequence => integer()();
  TextColumn get type => text()(); // pickup, delivery, other
  TextColumn get location => text()(); // JSON string of LoadLocation
  TextColumn get notes => text().nullable()();

  // Stop details
  TextColumn get commodity => text().nullable()();
  TextColumn get quantity => text().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get weightUnit => text().nullable().named('weight_unit')();
  TextColumn get stopReference => text().nullable().named('stop_reference')();
  TextColumn get instructions => text().nullable()();
  DateTimeColumn get appointmentTime =>
      dateTime().nullable().named('appointment_time')();
  BoolColumn get isCompleted =>
      boolean().named('is_completed').withDefault(const Constant(false))();
  DateTimeColumn get completedAt =>
      dateTime().nullable().named('completed_at')();
  DateTimeColumn get arrivedAt => dateTime().nullable().named('arrived_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DriverLocationData')
class DriverLocations extends Table {
  TextColumn get id => text()();
  TextColumn get driverId => text().named('driver_id')();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get speed => real().nullable()();
  RealColumn get heading => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageData')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().named('company_id').nullable()();
  TextColumn get loadId => text().named('load_id').nullable()();
  TextColumn get senderId => text().named('sender_id')();
  TextColumn get receiverId => text().named('receiver_id').nullable()();
  TextColumn get content => text()();
  TextColumn get messageType =>
      text().named('message_type').withDefault(const Constant('text'))();
  TextColumn get attachmentUrl => text().named('attachment_url').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  // Metadata for UI
  TextColumn get senderName => text().named('sender_name').nullable()();
  TextColumn get senderRole => text().named('sender_role').nullable()();
  TextColumn get senderAvatarUrl =>
      text().named('sender_avatar_url').nullable()();

  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AnnouncementData')
class Announcements extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text().named('company_id')();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get authorName => text().named('author_name').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  BoolColumn get isSynced =>
      boolean().named('is_synced').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Trips,
    FuelEntries,
    DriverTruckInspections,
    DriverTruckInspectionDefects,
    InspectionDefectPhotos,
    Loads,
    Stops,
    DriverLocations,
    Messages,
    Announcements,
  ],
)
class DriverDatabase extends _$DriverDatabase {
  DriverDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // We added the DriverTruckInspections and DriverTruckInspectionDefects tables in v2
          await m.createTable(driverTruckInspections);
          await m.createTable(driverTruckInspectionDefects);
        }
        if (from < 3) {
          // Schema v3: Add 'item' column to defective parts
          await m.addColumn(
            driverTruckInspectionDefects,
            driverTruckInspectionDefects.item,
          );
        }
        if (from < 4) {
          // Schema v4: Add inspection defect photos table
          await m.createTable(inspectionDefectPhotos);
        }
        if (from < 5) {
          // Schema v5: Add detention columns to trips
          await m.addColumn(
            trips,
            trips.pickupDetention as GeneratedColumn<Object>,
          );
          await m.addColumn(
            trips,
            trips.deliveryDetention as GeneratedColumn<Object>,
          );
        }
        if (from < 6) {
          await m.addColumn(
            driverTruckInspections,
            driverTruckInspections.signatureUrl,
          );
        }
        if (from < 7) {
          // Schema v7: Add notes to inspections
          await m.addColumn(
            driverTruckInspections,
            driverTruckInspections.notes as GeneratedColumn<Object>,
          );
        }
        if (from < 8) {
          // Schema v8: Add Loads and Stops tables for standardized load architecture
          await m.createTable(loads);
          await m.createTable(stops);
        }
        if (from < 10) {
          // Schema v10: Add DriverLocations table
          await m.createTable(driverLocations);
        }
        if (from < 11) {
          // Schema v11: Add Messages table
          await customStatement(
            'CREATE TABLE IF NOT EXISTS messages ('
            'id TEXT PRIMARY KEY, '
            'company_id TEXT, '
            'load_id TEXT, '
            'sender_id TEXT NOT NULL, '
            'receiver_id TEXT, '
            'content TEXT NOT NULL, '
            'message_type TEXT NOT NULL DEFAULT "text", '
            'attachment_url TEXT, '
            'created_at INTEGER NOT NULL, '
            'sender_name TEXT, '
            'sender_role TEXT, '
            'sender_avatar_url TEXT, '
            'is_synced INTEGER NOT NULL DEFAULT 0'
            ')',
          );
        }
        if (from < 12) {
          // Schema v12: Add company_id to trips and fuel_entries
          await m.addColumn(trips, trips.companyId as GeneratedColumn<Object>);
          await m.addColumn(
            fuelEntries,
            fuelEntries.companyId as GeneratedColumn<Object>,
          );
        }
        if (from < 13) {
          // Schema v13: Add Announcements table
          await customStatement(
            'CREATE TABLE IF NOT EXISTS announcements ('
            'id TEXT PRIMARY KEY, '
            'company_id TEXT NOT NULL, '
            'title TEXT NOT NULL, '
            'content TEXT NOT NULL, '
            'author_name TEXT, '
            'created_at INTEGER NOT NULL, '
            'is_synced INTEGER NOT NULL DEFAULT 0'
            ')',
          );
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      // In-memory database for tests to prevent hangs and synchronization issues
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return NativeDatabase.memory();
      }
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'driver_offline.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

// Global instance
final driverDatabase = DriverDatabase();

// Converters
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();
  @override
  List<String> fromSql(String fromDb) {
    return (json.decode(fromDb) as List).map((e) => e.toString()).toList();
  }

  @override
  String toSql(List<String> value) {
    return json.encode(value);
  }
}

class DateTimeListConverter extends TypeConverter<List<DateTime?>, String> {
  const DateTimeListConverter();
  @override
  List<DateTime?> fromSql(String fromDb) {
    return (json.decode(fromDb) as List)
        .map((e) => e == null ? null : DateTime.parse(e.toString()))
        .toList();
  }

  @override
  String toSql(List<DateTime?> value) {
    return json.encode(value.map((e) => e?.toIso8601String()).toList());
  }
}

class BoolListConverter extends TypeConverter<List<bool>, String> {
  const BoolListConverter();
  @override
  List<bool> fromSql(String fromDb) {
    return (json.decode(fromDb) as List).map((e) => e as bool).toList();
  }

  @override
  String toSql(List<bool> value) {
    return json.encode(value);
  }
}

class DetentionListConverter
    extends TypeConverter<List<domain.Detention?>, String> {
  const DetentionListConverter();

  @override
  List<domain.Detention?> fromSql(String fromDb) {
    return (json.decode(fromDb) as List)
        .map(
          (e) => e == null
              ? null
              : domain.Detention.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  String toSql(List<domain.Detention?> value) {
    return json.encode(value.map((e) => e?.toJson()).toList());
  }
}
