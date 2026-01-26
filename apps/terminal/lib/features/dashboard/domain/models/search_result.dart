import 'package:fluent_ui/fluent_ui.dart';

enum SearchResultType {
  load,
  driver,
  customer,
  vehicle,
  invoice,
  quote,
  setting,
  action,
}

class SearchResult {
  final String title;
  final String subtitle;
  final SearchResultType type;
  final dynamic data;
  final String? route;
  final IconData? icon;

  const SearchResult({
    required this.title,
    required this.subtitle,
    required this.type,
    this.data,
    this.route,
    this.icon,
  });
}
