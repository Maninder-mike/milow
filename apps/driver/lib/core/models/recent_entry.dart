import 'package:milow_core/milow_core.dart';

/// Sealed class for recent dashboard entries.
/// Provides type-safe handling of mixed Trip and FuelEntry lists.
sealed class RecentEntry {
  /// The date of this entry, used for sorting.
  DateTime get date;

  /// The type label for display purposes.
  String get typeLabel;
}

/// A trip entry in the recent entries list.
class TripRecentEntry extends RecentEntry {
  final Trip trip;

  TripRecentEntry(this.trip);

  @override
  DateTime get date => trip.tripDate;

  @override
  String get typeLabel => 'trip';
}

/// A fuel entry in the recent entries list.
class FuelRecentEntry extends RecentEntry {
  final FuelEntry fuel;

  FuelRecentEntry(this.fuel);

  @override
  DateTime get date => fuel.fuelDate;

  @override
  String get typeLabel => 'fuel';
}
