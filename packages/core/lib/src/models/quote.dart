/// Model representing a quote for a load
class Quote {
  final String id;
  final String loadId;
  final String loadReference;
  final String status; // draft, sent, won, lost
  final List<QuoteLineItem> lineItems;
  final double total;
  final String notes;
  final DateTime? expiresOn;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Quote({
    required this.id,
    required this.loadId,
    required this.loadReference,
    required this.status,
    required this.lineItems,
    required this.total,
    this.notes = '',
    this.expiresOn,
    this.createdAt,
    this.updatedAt,
  });

  factory Quote.empty() {
    return Quote(
      id: '',
      loadId: '',
      loadReference: '',
      status: 'draft',
      lineItems: [],
      total: 0.0,
    );
  }

  Quote copyWith({
    String? id,
    String? loadId,
    String? loadReference,
    String? status,
    List<QuoteLineItem>? lineItems,
    double? total,
    String? notes,
    DateTime? expiresOn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Quote(
      id: id ?? this.id,
      loadId: loadId ?? this.loadId,
      loadReference: loadReference ?? this.loadReference,
      status: status ?? this.status,
      lineItems: lineItems ?? this.lineItems,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      expiresOn: expiresOn ?? this.expiresOn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'load_id': loadId,
      'status': status,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
      'total': total,
      'notes': notes,
      if (expiresOn != null) 'expires_on': expiresOn!.toIso8601String(),
    };
  }

  factory Quote.fromJson(Map<String, dynamic> json) {
    final lineItemsJson = json['line_items'] as List<dynamic>?;

    return Quote(
      id: json['id'] as String,
      loadId: json['load_id'] as String? ?? '',
      loadReference: json['load_reference'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      lineItems: lineItemsJson != null
          ? lineItemsJson
                .map((e) => QuoteLineItem.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
      expiresOn: json['expires_on'] != null
          ? DateTime.parse(json['expires_on'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

/// Line item for a quote charge
class QuoteLineItem {
  final String type;
  final String description;
  final double rate;
  final double quantity;
  final String unit; // flat, per mile, per hour, %

  QuoteLineItem({
    this.type = 'Linehaul',
    this.description = '',
    this.rate = 0.0,
    this.quantity = 1.0,
    this.unit = 'flat',
  });

  double get total => rate * quantity;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'rate': rate,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory QuoteLineItem.fromJson(Map<String, dynamic> json) {
    return QuoteLineItem(
      type: json['type'] as String? ?? 'Linehaul',
      description: json['description'] as String? ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'flat',
    );
  }
}
