/// Webhook event types supported by the system
enum WebhookEventType {
  // Generic CRUD events
  created('created'),
  updated('updated'),
  deleted('deleted'),

  // Status change events
  statusChanged('status.changed'),
  assigned('assigned'),
  unassigned('unassigned'),

  // Load lifecycle events
  dispatched('dispatched'),
  delivered('delivered'),
  invoiced('invoiced'),

  // Document events
  documentUploaded('document.uploaded'),
  noteAdded('note.added');

  const WebhookEventType(this.value);
  final String value;

  static WebhookEventType fromString(String? value) {
    if (value == null) return WebhookEventType.updated;
    return WebhookEventType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => WebhookEventType.updated,
    );
  }
}

/// Object types that can trigger webhooks
enum WebhookObjectType {
  load('load'),
  customer('customer'),
  driver('driver'),
  truck('truck'),
  trailer('trailer'),
  document('document'),
  invoice('invoice'),
  fuelEntry('fuel_entry'),
  address('address');

  const WebhookObjectType(this.value);
  final String value;

  static WebhookObjectType fromString(String? value) {
    if (value == null) return WebhookObjectType.load;
    return WebhookObjectType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => WebhookObjectType.load,
    );
  }
}

/// Delivery status for webhook events
enum WebhookStatus {
  pending('pending'),
  processing('processing'),
  delivered('delivered'),
  failed('failed'),
  retrying('retrying');

  const WebhookStatus(this.value);
  final String value;

  bool get isTerminal => this == delivered || this == failed;

  bool get needsRetry => this == retrying;

  static WebhookStatus fromString(String? value) {
    if (value == null) return WebhookStatus.pending;
    return WebhookStatus.values.firstWhere(
      (t) => t.value == value,
      orElse: () => WebhookStatus.pending,
    );
  }
}

/// Model for logged webhook events
class WebhookEvent {
  final String id;
  final String companyId;
  final WebhookEventType eventType;
  final WebhookObjectType objectType;
  final String objectId;
  final Map<String, dynamic> payload;
  final WebhookStatus status;
  final String? endpointUrl;
  final int? responseStatus;
  final String? responseBody;
  final int retryCount;
  final int maxRetries;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? nextRetryAt;

  WebhookEvent({
    required this.id,
    required this.companyId,
    required this.eventType,
    required this.objectType,
    required this.objectId,
    required this.payload,
    required this.status,
    this.endpointUrl,
    this.responseStatus,
    this.responseBody,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.lastError,
    required this.createdAt,
    this.deliveredAt,
    this.nextRetryAt,
  });

  factory WebhookEvent.fromJson(Map<String, dynamic> json) {
    return WebhookEvent(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      eventType: WebhookEventType.fromString(json['event_type'] as String?),
      objectType: WebhookObjectType.fromString(json['object_type'] as String?),
      objectId: json['object_id'] as String,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      status: WebhookStatus.fromString(json['status'] as String?),
      endpointUrl: json['endpoint_url'] as String?,
      responseStatus: json['response_status'] as int?,
      responseBody: json['response_body'] as String?,
      retryCount: json['retry_count'] as int? ?? 0,
      maxRetries: json['max_retries'] as int? ?? 3,
      lastError: json['last_error'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      nextRetryAt: json['next_retry_at'] != null
          ? DateTime.parse(json['next_retry_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'event_type': eventType.value,
      'object_type': objectType.value,
      'object_id': objectId,
      'payload': payload,
      'status': status.value,
      if (endpointUrl != null) 'endpoint_url': endpointUrl,
      if (responseStatus != null) 'response_status': responseStatus,
      if (responseBody != null) 'response_body': responseBody,
      'retry_count': retryCount,
      'max_retries': maxRetries,
      if (lastError != null) 'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
      if (deliveredAt != null) 'delivered_at': deliveredAt!.toIso8601String(),
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt!.toIso8601String(),
    };
  }

  bool get canRetry => retryCount < maxRetries && !status.isTerminal;
}

/// Model for webhook subscription configuration
class WebhookSubscription {
  final String id;
  final String companyId;
  final String name;
  final String endpointUrl;
  final String? secretKey;
  final List<String> eventTypes;
  final List<String> objectTypes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WebhookSubscription({
    required this.id,
    required this.companyId,
    required this.name,
    required this.endpointUrl,
    this.secretKey,
    required this.eventTypes,
    required this.objectTypes,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory WebhookSubscription.fromJson(Map<String, dynamic> json) {
    return WebhookSubscription(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      endpointUrl: json['endpoint_url'] as String,
      secretKey: json['secret_key'] as String?,
      eventTypes:
          (json['event_types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      objectTypes:
          (json['object_types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'endpoint_url': endpointUrl,
      if (secretKey != null) 'secret_key': secretKey,
      'event_types': eventTypes,
      'object_types': objectTypes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Check if this subscription matches a given event
  bool matchesEvent(WebhookEventType event, WebhookObjectType object) {
    if (!isActive) return false;
    final matchesEventType =
        eventTypes.isEmpty || eventTypes.contains(event.value);
    final matchesObjectType =
        objectTypes.isEmpty || objectTypes.contains(object.value);
    return matchesEventType && matchesObjectType;
  }
}
