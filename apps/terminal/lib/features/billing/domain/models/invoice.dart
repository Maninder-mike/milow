/// Model representing an invoice for a completed load
class Invoice {
  final String id;
  final String loadId;
  final String? customerId;
  final String invoiceNumber;
  final String status; // draft, sent, paid, overdue, void
  final List<InvoiceLineItem> lineItems;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final DateTime issueDate;
  final DateTime dueDate;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Invoice({
    required this.id,
    required this.loadId,
    this.customerId,
    required this.invoiceNumber,
    required this.status,
    required this.lineItems,
    required this.subtotal,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    required this.totalAmount,
    required this.issueDate,
    required this.dueDate,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Invoice.empty() {
    return Invoice(
      id: '',
      loadId: '',
      invoiceNumber: '',
      status: 'draft',
      lineItems: [],
      subtotal: 0.0,
      totalAmount: 0.0,
      issueDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
    );
  }

  Invoice copyWith({
    String? id,
    String? loadId,
    String? customerId,
    String? invoiceNumber,
    String? status,
    List<InvoiceLineItem>? lineItems,
    double? subtotal,
    double? taxRate,
    double? taxAmount,
    double? totalAmount,
    DateTime? issueDate,
    DateTime? dueDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      loadId: loadId ?? this.loadId,
      customerId: customerId ?? this.customerId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      lineItems: lineItems ?? this.lineItems,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'load_id': loadId,
      'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'status': status,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'issue_date': issueDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final lineItemsJson = json['line_items'] as List<dynamic>?;

    return Invoice(
      id: json['id'] as String,
      loadId: json['load_id'] as String? ?? '',
      customerId: json['customer_id'] as String?,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      lineItems: lineItemsJson != null
          ? lineItemsJson
                .map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      issueDate: json['issue_date'] != null
          ? DateTime.parse(json['issue_date'] as String)
          : DateTime.now(),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : DateTime.now().add(const Duration(days: 30)),
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

class InvoiceLineItem {
  final String type;
  final String description;
  final double rate;
  final double quantity;
  final String unit;

  InvoiceLineItem({
    required this.type,
    required this.description,
    required this.rate,
    required this.quantity,
    required this.unit,
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

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      type: json['type'] as String? ?? 'Linehaul',
      description: json['description'] as String? ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'flat',
    );
  }
}
