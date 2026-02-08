/// Load status enum with RoseRocket parity
///
/// Matches RoseRocket's Order statuses for enterprise TMS compatibility.
enum LoadStatus {
  /// Order created but not yet confirmed/dispatched
  pending('Pending'),

  /// Order confirmed and ready for pickup
  booked('Booked'),

  /// Load assigned to driver and truck
  dispatched('Dispatched'),

  /// Order sent to external carrier (brokerage)
  tendered('Tendered'),

  /// Goods in transit between stops
  inTransit('In Transit'),

  /// All stops completed successfully
  delivered('Delivered'),

  /// Invoice generated for this load
  invoiced('Invoiced'),

  /// Order rejected by driver or carrier
  rejected('Rejected'),

  /// Order cancelled before completion
  cancelled('Cancelled'),

  /// Historical record, no longer active
  archived('Archived');

  const LoadStatus(this.displayName);

  /// Human-readable display name for UI
  final String displayName;

  /// Parse status from string (database value)
  static LoadStatus fromString(String value) {
    return LoadStatus.values.firstWhere(
      (s) =>
          s.name.toLowerCase() == value.toLowerCase() ||
          s.displayName.toLowerCase() == value.toLowerCase(),
      orElse: () => LoadStatus.pending,
    );
  }

  /// Convert to database value (snake_case)
  String toJson() => name;

  /// Color code for UI badges
  String get colorHex {
    switch (this) {
      case LoadStatus.pending:
        return '#6B7280'; // Gray
      case LoadStatus.booked:
        return '#3B82F6'; // Blue
      case LoadStatus.dispatched:
        return '#8B5CF6'; // Purple
      case LoadStatus.tendered:
        return '#F59E0B'; // Amber
      case LoadStatus.inTransit:
        return '#10B981'; // Green
      case LoadStatus.delivered:
        return '#059669'; // Emerald
      case LoadStatus.invoiced:
        return '#14B8A6'; // Teal
      case LoadStatus.rejected:
        return '#EF4444'; // Red
      case LoadStatus.cancelled:
        return '#DC2626'; // Dark Red
      case LoadStatus.archived:
        return '#9CA3AF'; // Light Gray
    }
  }

  /// Check if load is in a "completed" state
  bool get isComplete =>
      this == LoadStatus.delivered ||
      this == LoadStatus.invoiced ||
      this == LoadStatus.archived;

  /// Check if load is in an "active" state
  bool get isActive =>
      this == LoadStatus.dispatched ||
      this == LoadStatus.inTransit ||
      this == LoadStatus.tendered;

  /// Check if load can be edited
  bool get isEditable =>
      this == LoadStatus.pending || this == LoadStatus.booked;
}
