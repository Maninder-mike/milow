/// Model representing a driver expense entry.
///
/// Supports categories: toll, meal, scale, lumper, parking, lodging,
/// maintenance, permits, fines, other.
class Expense {
  final String? id;
  final String? userId;
  final String? tripId;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final String currency;
  final String? description;
  final String? vendor;
  final String? location;
  final String? receiptUrl;
  final String? paymentMethod;
  final bool isReimbursable;
  final bool isReimbursed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Valid expense categories
  static const List<String> categories = [
    'toll',
    'meal',
    'scale',
    'lumper',
    'parking',
    'lodging',
    'maintenance',
    'permits',
    'fines',
    'other',
  ];

  /// Category display names
  static const Map<String, String> categoryLabels = {
    'toll': 'Toll',
    'meal': 'Meal',
    'scale': 'Scale/Weigh',
    'lumper': 'Lumper',
    'parking': 'Parking',
    'lodging': 'Lodging',
    'maintenance': 'Maintenance',
    'permits': 'Permits',
    'fines': 'Fines',
    'other': 'Other',
  };

  /// Category icons (Material Icons names)
  static const Map<String, String> categoryIcons = {
    'toll': 'toll',
    'meal': 'restaurant',
    'scale': 'scale',
    'lumper': 'inventory',
    'parking': 'local_parking',
    'lodging': 'hotel',
    'maintenance': 'build',
    'permits': 'description',
    'fines': 'warning',
    'other': 'receipt_long',
  };

  Expense({
    required this.expenseDate,
    required this.category,
    required this.amount,
    this.id,
    this.userId,
    this.tripId,
    this.currency = 'USD',
    this.description,
    this.vendor,
    this.location,
    this.receiptUrl,
    this.paymentMethod,
    this.isReimbursable = false,
    this.isReimbursed = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Get currency symbol
  String get currencySymbol {
    switch (currency) {
      case 'CAD':
        return 'C\$';
      case 'USD':
      default:
        return '\$';
    }
  }

  /// Get formatted amount with currency
  String get formattedAmount => '$currencySymbol${amount.toStringAsFixed(2)}';

  /// Get category display label
  String get categoryLabel => categoryLabels[category] ?? category;

  /// Create Expense from JSON (Supabase response)
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      tripId: json['trip_id'] as String?,
      expenseDate:
          DateTime.tryParse(json['expense_date']?.toString() ?? '') ??
          DateTime.now(),
      category: json['category'] as String? ?? 'other',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      description: json['description'] as String?,
      vendor: json['vendor'] as String?,
      location: json['location'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      paymentMethod: json['payment_method'] as String?,
      isReimbursable: json['is_reimbursable'] as bool? ?? false,
      isReimbursed: json['is_reimbursed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert Expense to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (tripId != null) 'trip_id': tripId,
      'expense_date': expenseDate.toIso8601String(),
      'category': category,
      'amount': amount,
      'currency': currency,
      'description': description,
      'vendor': vendor,
      'location': location,
      'receipt_url': receiptUrl,
      'payment_method': paymentMethod,
      'is_reimbursable': isReimbursable,
      'is_reimbursed': isReimbursed,
    };
  }

  /// Create a copy with updated fields
  Expense copyWith({
    String? id,
    String? userId,
    String? tripId,
    DateTime? expenseDate,
    String? category,
    double? amount,
    String? currency,
    String? description,
    String? vendor,
    String? location,
    String? receiptUrl,
    String? paymentMethod,
    bool? isReimbursable,
    bool? isReimbursed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tripId: tripId ?? this.tripId,
      expenseDate: expenseDate ?? this.expenseDate,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      vendor: vendor ?? this.vendor,
      location: location ?? this.location,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isReimbursable: isReimbursable ?? this.isReimbursable,
      isReimbursed: isReimbursed ?? this.isReimbursed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Expense(id: $id, category: $category, amount: $formattedAmount, '
        'vendor: $vendor, date: $expenseDate)';
  }
}
