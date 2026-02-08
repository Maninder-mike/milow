/// Dashboard board type classification
enum DashboardBoardType {
  dispatch('dispatch', 'Dispatch'),
  fleet('fleet', 'Fleet'),
  billing('billing', 'Billing'),
  analytics('analytics', 'Analytics'),
  custom('custom', 'Custom');

  const DashboardBoardType(this.value, this.displayName);
  final String value;
  final String displayName;

  static DashboardBoardType fromString(String? value) {
    if (value == null) return DashboardBoardType.custom;
    return DashboardBoardType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => DashboardBoardType.custom,
    );
  }
}

/// Widget types available for dashboard
enum DashboardWidgetType {
  statsCard('stats_card', 'Stats Card'),
  chart('chart', 'Chart'),
  table('table', 'Table'),
  map('map', 'Map'),
  list('list', 'List'),
  calendar('calendar', 'Calendar'),
  timeline('timeline', 'Timeline'),
  progress('progress', 'Progress'),
  quickActions('quick_actions', 'Quick Actions');

  const DashboardWidgetType(this.value, this.displayName);
  final String value;
  final String displayName;

  static DashboardWidgetType fromString(String? value) {
    if (value == null) return DashboardWidgetType.statsCard;
    return DashboardWidgetType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => DashboardWidgetType.statsCard,
    );
  }
}

/// Data sources available for widgets
enum WidgetDataSource {
  loads('loads', 'Loads'),
  drivers('drivers', 'Drivers'),
  trucks('trucks', 'Trucks'),
  trailers('trailers', 'Trailers'),
  customers('customers', 'Customers'),
  invoices('invoices', 'Invoices'),
  fuelEntries('fuel_entries', 'Fuel Entries'),
  settlements('settlements', 'Settlements'),
  trips('trips', 'Trips');

  const WidgetDataSource(this.value, this.displayName);
  final String value;
  final String displayName;

  static WidgetDataSource fromString(String? value) {
    if (value == null) return WidgetDataSource.loads;
    return WidgetDataSource.values.firstWhere(
      (t) => t.value == value,
      orElse: () => WidgetDataSource.loads,
    );
  }
}

/// View types for saved table views
enum SavedViewType {
  loads('loads', 'Loads'),
  drivers('drivers', 'Drivers'),
  customers('customers', 'Customers'),
  trucks('trucks', 'Trucks'),
  trailers('trailers', 'Trailers'),
  invoices('invoices', 'Invoices');

  const SavedViewType(this.value, this.displayName);
  final String value;
  final String displayName;

  static SavedViewType fromString(String? value) {
    if (value == null) return SavedViewType.loads;
    return SavedViewType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => SavedViewType.loads,
    );
  }
}

/// Model for customizable dashboard boards
class DashboardBoard {
  final String id;
  final String companyId;
  final String? userId;
  final String name;
  final String? description;
  final String? icon;
  final DashboardBoardType boardType;
  final Map<String, dynamic> layout;
  final int displayOrder;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<DashboardWidget> widgets;

  DashboardBoard({
    required this.id,
    required this.companyId,
    this.userId,
    required this.name,
    this.description,
    this.icon,
    required this.boardType,
    required this.layout,
    required this.displayOrder,
    required this.isDefault,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.widgets = const [],
  });

  factory DashboardBoard.fromJson(Map<String, dynamic> json) {
    return DashboardBoard(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      boardType: DashboardBoardType.fromString(json['board_type'] as String?),
      layout: json['layout'] as Map<String, dynamic>? ?? {'columns': 3},
      displayOrder: json['display_order'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      widgets:
          (json['dashboard_widgets'] as List<dynamic>?)
              ?.map((w) => DashboardWidget.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      if (userId != null) 'user_id': userId,
      'name': name,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      'board_type': boardType.value,
      'layout': layout,
      'display_order': displayOrder,
      'is_default': isDefault,
      'is_active': isActive,
    };
  }

  bool get isCompanyWide => userId == null;
}

/// Model for dashboard widgets
class DashboardWidget {
  final String id;
  final String boardId;
  final String title;
  final DashboardWidgetType widgetType;
  final WidgetDataSource dataSource;
  final Map<String, dynamic> queryConfig;
  final int gridX;
  final int gridY;
  final int gridWidth;
  final int gridHeight;
  final Map<String, dynamic> config;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DashboardWidget({
    required this.id,
    required this.boardId,
    required this.title,
    required this.widgetType,
    required this.dataSource,
    required this.queryConfig,
    required this.gridX,
    required this.gridY,
    required this.gridWidth,
    required this.gridHeight,
    required this.config,
    required this.isVisible,
    required this.createdAt,
    this.updatedAt,
  });

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    return DashboardWidget(
      id: json['id'] as String,
      boardId: json['board_id'] as String,
      title: json['title'] as String,
      widgetType: DashboardWidgetType.fromString(
        json['widget_type'] as String?,
      ),
      dataSource: WidgetDataSource.fromString(json['data_source'] as String?),
      queryConfig: json['query_config'] as Map<String, dynamic>? ?? {},
      gridX: json['grid_x'] as int? ?? 0,
      gridY: json['grid_y'] as int? ?? 0,
      gridWidth: json['grid_width'] as int? ?? 1,
      gridHeight: json['grid_height'] as int? ?? 1,
      config: json['config'] as Map<String, dynamic>? ?? {},
      isVisible: json['is_visible'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'board_id': boardId,
      'title': title,
      'widget_type': widgetType.value,
      'data_source': dataSource.value,
      'query_config': queryConfig,
      'grid_x': gridX,
      'grid_y': gridY,
      'grid_width': gridWidth,
      'grid_height': gridHeight,
      'config': config,
      'is_visible': isVisible,
    };
  }

  DashboardWidget copyWith({
    int? gridX,
    int? gridY,
    int? gridWidth,
    int? gridHeight,
    bool? isVisible,
    Map<String, dynamic>? config,
  }) {
    return DashboardWidget(
      id: id,
      boardId: boardId,
      title: title,
      widgetType: widgetType,
      dataSource: dataSource,
      queryConfig: queryConfig,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      config: config ?? this.config,
      isVisible: isVisible ?? this.isVisible,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Model for saved table view presets
class SavedView {
  final String id;
  final String companyId;
  final String? userId;
  final String name;
  final SavedViewType viewType;
  final List<Map<String, dynamic>> columns;
  final Map<String, dynamic> filters;
  final Map<String, dynamic> sortConfig;
  final bool isDefault;
  final bool isShared;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SavedView({
    required this.id,
    required this.companyId,
    this.userId,
    required this.name,
    required this.viewType,
    required this.columns,
    required this.filters,
    required this.sortConfig,
    required this.isDefault,
    required this.isShared,
    required this.createdAt,
    this.updatedAt,
  });

  factory SavedView.fromJson(Map<String, dynamic> json) {
    return SavedView(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      viewType: SavedViewType.fromString(json['view_type'] as String?),
      columns:
          (json['columns'] as List<dynamic>?)
              ?.map((c) => c as Map<String, dynamic>)
              .toList() ??
          [],
      filters: json['filters'] as Map<String, dynamic>? ?? {},
      sortConfig: json['sort_config'] as Map<String, dynamic>? ?? {},
      isDefault: json['is_default'] as bool? ?? false,
      isShared: json['is_shared'] as bool? ?? false,
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
      if (userId != null) 'user_id': userId,
      'name': name,
      'view_type': viewType.value,
      'columns': columns,
      'filters': filters,
      'sort_config': sortConfig,
      'is_default': isDefault,
      'is_shared': isShared,
    };
  }

  bool get isPersonal => userId != null;
}
