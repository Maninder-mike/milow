enum AnalyticsTimeframe {
  week, // Last 7 days
  month, // Last 30 days
  quarter, // Last 90 days
  year, // Last 365 days
  custom, // User-defined range
}

extension AnalyticsTimeframeExtension on AnalyticsTimeframe {
  String get label {
    switch (this) {
      case AnalyticsTimeframe.week:
        return 'Last 7 Days';
      case AnalyticsTimeframe.month:
        return 'Last 30 Days';
      case AnalyticsTimeframe.quarter:
        return 'Last 90 Days';
      case AnalyticsTimeframe.year:
        return 'Last Year';
      case AnalyticsTimeframe.custom:
        return 'Custom Range';
    }
  }

  int get days {
    switch (this) {
      case AnalyticsTimeframe.week:
        return 7;
      case AnalyticsTimeframe.month:
        return 30;
      case AnalyticsTimeframe.quarter:
        return 90;
      case AnalyticsTimeframe.year:
        return 365;
      case AnalyticsTimeframe.custom:
        return 0;
    }
  }
}
