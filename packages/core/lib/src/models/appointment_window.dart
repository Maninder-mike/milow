class AppointmentWindow {
  final DateTime start;
  final DateTime end;

  const AppointmentWindow({required this.start, required this.end});

  factory AppointmentWindow.fromJson(Map<String, dynamic> json) {
    return AppointmentWindow(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {'start': start.toIso8601String(), 'end': end.toIso8601String()};
  }
}
