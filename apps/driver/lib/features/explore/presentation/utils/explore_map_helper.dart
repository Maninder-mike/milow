import 'package:latlong2/latlong.dart';

enum MapMarkerType { trip, fuel, document }

class ExploreMapMarker {
  final String id;
  final LatLng point;
  final String title;
  final String subtitle;
  final MapMarkerType type;
  final DateTime date;
  final dynamic data; // Original Trip or FuelEntry object

  ExploreMapMarker({
    required this.id,
    required this.point,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.date,
    this.data,
  });
}
