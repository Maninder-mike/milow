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

@DriftDatabase(
  tables: [
    Trips,
    FuelEntries,
    DriverTruckInspections,
    DriverTruckInspectionDefects,
    InspectionDefectPhotos,
  ],
)
class DriverDatabase extends _$DriverDatabase {
  DriverDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7;

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
      },
    );
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'driver_offline.db'));
      return NativeDatabase(file);
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
