/// Model representing an invoice for a completed load
class Invoice {
  final String id;
  final String loadId;
  final String? customerId;
  final String? customerName;
  final String? customerAddress;
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

  // Shipment/Load details for professional invoices
  final String? loadReference;
  final String? poNumber;
  final String? commodity;
  final double? weight;
  final String? weightUnit;

  // Pickup details
  final String? pickupCompany;
  final String? pickupAddress;
  final String? pickupCity;
  final String? pickupState;
  final String? pickupZip;
  final DateTime? pickupDate;

  // Delivery details
  final String? deliveryCompany;
  final String? deliveryAddress;
  final String? deliveryCity;
  final String? deliveryState;
  final String? deliveryZip;
  final DateTime? deliveryDate;

  Invoice({
    required this.id,
    required this.loadId,
    this.customerId,
    this.customerName,
    this.customerAddress,
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
    // Shipment details
    this.loadReference,
    this.poNumber,
    this.commodity,
    this.weight,
    this.weightUnit,
    // Pickup
    this.pickupCompany,
    this.pickupAddress,
    this.pickupCity,
    this.pickupState,
    this.pickupZip,
    this.pickupDate,
    // Delivery
    this.deliveryCompany,
    this.deliveryAddress,
    this.deliveryCity,
    this.deliveryState,
    this.deliveryZip,
    this.deliveryDate,
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

  /// Helper to get formatted pickup address
  String get formattedPickupAddress {
    final parts = [
      pickupAddress,
      pickupCity,
      pickupState,
      pickupZip,
    ].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }

  /// Helper to get formatted delivery address
  String get formattedDeliveryAddress {
    final parts = [
      deliveryAddress,
      deliveryCity,
      deliveryState,
      deliveryZip,
    ].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }

  Invoice copyWith({
    String? id,
    String? loadId,
    String? customerId,
    String? customerName,
    String? customerAddress,
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
    String? loadReference,
    String? poNumber,
    String? commodity,
    double? weight,
    String? weightUnit,
    String? pickupCompany,
    String? pickupAddress,
    String? pickupCity,
    String? pickupState,
    String? pickupZip,
    DateTime? pickupDate,
    String? deliveryCompany,
    String? deliveryAddress,
    String? deliveryCity,
    String? deliveryState,
    String? deliveryZip,
    DateTime? deliveryDate,
  }) {
    return Invoice(
      id: id ?? this.id,
      loadId: loadId ?? this.loadId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
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
      loadReference: loadReference ?? this.loadReference,
      poNumber: poNumber ?? this.poNumber,
      commodity: commodity ?? this.commodity,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      pickupCompany: pickupCompany ?? this.pickupCompany,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupCity: pickupCity ?? this.pickupCity,
      pickupState: pickupState ?? this.pickupState,
      pickupZip: pickupZip ?? this.pickupZip,
      pickupDate: pickupDate ?? this.pickupDate,
      deliveryCompany: deliveryCompany ?? this.deliveryCompany,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      deliveryState: deliveryState ?? this.deliveryState,
      deliveryZip: deliveryZip ?? this.deliveryZip,
      deliveryDate: deliveryDate ?? this.deliveryDate,
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

    // Parse customer data from join
    final customerData = json['customers'] as Map<String, dynamic>?;

    // Parse customer data from query (prioritize loads -> customer if available as per request)
    // The query will return loads -> customers as well.
    final loadDataRaw = json['loads'] as Map<String, dynamic>?;
    final loadCustomerData = loadDataRaw?['customer'] as Map<String, dynamic>?;

    final effectiveCustomerData = loadCustomerData ?? customerData;

    String? customerName;
    String? customerAddress;

    if (effectiveCustomerData != null) {
      customerName = effectiveCustomerData['name'] as String?;
      final address = effectiveCustomerData['address_line1'] as String?;
      final city = effectiveCustomerData['city'] as String?;
      final state = effectiveCustomerData['state_province'] as String?;
      final zip = effectiveCustomerData['postal_code'] as String?;
      final parts = [
        address,
        city,
        state,
        zip,
      ].where((p) => p != null && p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        customerAddress = parts.join(', ');
      }
    }

    // Parse load data from join
    final loadData = json['loads'] as Map<String, dynamic>?;
    String? loadReference;
    String? poNumber;
    String? commodity;
    double? weight;
    String? weightUnit;
    DateTime? pickupDate;
    DateTime? deliveryDate;

    // Pickup location from nested join
    String? pickupCompany;
    String? pickupAddress;
    String? pickupCity;
    String? pickupState;
    String? pickupZip;

    // Delivery location from nested join
    String? deliveryCompany;
    String? deliveryAddress;
    String? deliveryCity;
    String? deliveryState;
    String? deliveryZip;

    if (loadData != null) {
      loadReference = loadData['load_reference'] as String?;
      poNumber = loadData['po_number'] as String?;
      commodity = loadData['goods'] as String?;
      weight = (loadData['weight'] as num?)?.toDouble();
      weightUnit = loadData['weight_unit'] as String?;
      pickupDate = loadData['pickup_date'] != null
          ? DateTime.tryParse(loadData['pickup_date'] as String)
          : null;
      deliveryDate = loadData['delivery_date'] != null
          ? DateTime.tryParse(loadData['delivery_date'] as String)
          : null;

      // Parse pickup location
      final pickupDataRaw = loadData['pickups'];
      Map<String, dynamic>? pickupData;
      if (pickupDataRaw is List && pickupDataRaw.isNotEmpty) {
        pickupData = pickupDataRaw.first as Map<String, dynamic>;
      } else if (pickupDataRaw is Map<String, dynamic>) {
        pickupData = pickupDataRaw;
      }

      if (pickupData != null) {
        pickupCompany = pickupData['shipper_name'] as String?;
        pickupAddress = pickupData['address'] as String?;
        pickupCity = pickupData['city'] as String?;
        pickupState = pickupData['state_province'] as String?;
        pickupZip = pickupData['postal_code'] as String?;
      }

      // Parse delivery location
      final deliveryDataRaw = loadData['receivers'];
      Map<String, dynamic>? deliveryData;
      if (deliveryDataRaw is List && deliveryDataRaw.isNotEmpty) {
        deliveryData = deliveryDataRaw.first as Map<String, dynamic>;
      } else if (deliveryDataRaw is Map<String, dynamic>) {
        deliveryData = deliveryDataRaw;
      }

      if (deliveryData != null) {
        deliveryCompany = deliveryData['receiver_name'] as String?;
        deliveryAddress = deliveryData['address'] as String?;
        deliveryCity = deliveryData['city'] as String?;
        deliveryState = deliveryData['state_province'] as String?;
        deliveryZip = deliveryData['postal_code'] as String?;
      }
    }

    return Invoice(
      id: json['id'] as String,
      loadId: json['load_id'] as String? ?? '',
      customerId: json['customer_id'] as String?,
      customerName: customerName,
      customerAddress: customerAddress,
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
      // Shipment details
      loadReference: loadReference,
      poNumber: poNumber,
      commodity: commodity,
      weight: weight,
      weightUnit: weightUnit,
      // Pickup
      pickupCompany: pickupCompany,
      pickupAddress: pickupAddress,
      pickupCity: pickupCity,
      pickupState: pickupState,
      pickupZip: pickupZip,
      pickupDate: pickupDate,
      // Delivery
      deliveryCompany: deliveryCompany,
      deliveryAddress: deliveryAddress,
      deliveryCity: deliveryCity,
      deliveryState: deliveryState,
      deliveryZip: deliveryZip,
      deliveryDate: deliveryDate,
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
