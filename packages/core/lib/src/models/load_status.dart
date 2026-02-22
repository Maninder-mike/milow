enum LoadStatus {
  pending,
  booked,
  dispatched,
  assigned,
  tendered,
  enRoute,
  atPickup,
  loaded,
  atStop,
  atDelivery,
  delivered,
  completed,
  cancelled,
  delayed,
  invoiced,
  rejected,
  archived,
}

extension LoadStatusX on LoadStatus {
  String get displayName {
    switch (this) {
      case LoadStatus.pending:
        return 'Pending';
      case LoadStatus.booked:
        return 'Booked';
      case LoadStatus.dispatched:
        return 'Dispatched';
      case LoadStatus.assigned:
        return 'Assigned';
      case LoadStatus.tendered:
        return 'Tendered';
      case LoadStatus.enRoute:
        return 'En Route';
      case LoadStatus.atPickup:
        return 'At Pickup';
      case LoadStatus.loaded:
        return 'Loaded';
      case LoadStatus.atStop:
        return 'At Stop';
      case LoadStatus.atDelivery:
        return 'At Delivery';
      case LoadStatus.delivered:
        return 'Delivered';
      case LoadStatus.completed:
        return 'Completed';
      case LoadStatus.cancelled:
        return 'Cancelled';
      case LoadStatus.delayed:
        return 'Delayed';
      case LoadStatus.invoiced:
        return 'Invoiced';
      case LoadStatus.rejected:
        return 'Rejected';
      case LoadStatus.archived:
        return 'Archived';
    }
  }

  static LoadStatus fromString(String value) {
    return LoadStatus.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == value.toLowerCase() ||
          e.displayName.toLowerCase() == value.toLowerCase(),
      orElse: () => LoadStatus.pending,
    );
  }
}
