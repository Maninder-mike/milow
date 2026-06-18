import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/utils/responsive_layout.dart';
import 'package:milow/core/services/weather_service.dart';
import 'package:milow/core/widgets/shimmer_loading.dart';

class WeatherSection extends StatelessWidget {
  final WeatherInfo? weatherInfo;
  final bool isLoadingWeather;
  final String distanceUnit;
  final VoidCallback onWeatherTap;

  const WeatherSection({
    required this.weatherInfo,
    required this.isLoadingWeather,
    required this.distanceUnit,
    required this.onWeatherTap,
    super.key,
  });

  IconData _getWeatherIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
      case 3:
        return Icons.wb_cloudy_rounded;
      case 45:
      case 48:
        return Icons.cloud_rounded;
      case 51:
      case 53:
      case 55:
        return Icons.grain_rounded;
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.umbrella_rounded;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.cloud_rounded;
    }
  }

  Color _getWeatherColor(int code) {
    switch (code) {
      case 0: // Sunny
        return Colors.orange;
      case 1:
      case 2:
      case 3: // Cloudy
      case 45:
      case 48:
        return Colors.blueGrey;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82: // Rainy
        return Colors.blue;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86: // Snow
        return Colors.cyan;
      case 95:
      case 96:
      case 99: // Thunderstorm
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveLayout.getMargin(context)),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shapeL),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onWeatherTap,
          borderRadius: BorderRadius.circular(tokens.shapeL),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacingM),
            child: isLoadingWeather
                ? _buildLoadingSkeleton(context, tokens, colorScheme)
                : weatherInfo == null
                    ? _buildNoLocationContent(context, tokens, colorScheme)
                    : _buildWeatherContent(context, weatherInfo!, tokens, colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context, DesignTokens tokens, ColorScheme colorScheme) {
    return ShimmerLoading(
      isLoading: true,
      child: Row(
        children: [
          // Icon placeholder
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.inputBorder,
              borderRadius: BorderRadius.circular(tokens.shapeM),
            ),
          ),
          SizedBox(width: tokens.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title placeholder
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tokens.inputBorder,
                    borderRadius: BorderRadius.circular(tokens.shapeXS),
                  ),
                ),
                const SizedBox(height: 6),
                // Subtitle placeholder
                Container(
                  width: 160,
                  height: 14,
                  decoration: BoxDecoration(
                    color: tokens.inputBorder,
                    borderRadius: BorderRadius.circular(tokens.shapeXS),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacingM),
          // Temp placeholder
          Container(
            width: 40,
            height: 32,
            decoration: BoxDecoration(
              color: tokens.inputBorder,
              borderRadius: BorderRadius.circular(tokens.shapeS),
            ),
          ),
          SizedBox(width: tokens.spacingXS),
          Icon(
            Icons.chevron_right_rounded,
            color: tokens.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildNoLocationContent(
    BuildContext context,
    DesignTokens tokens,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(tokens.spacingS + 2),
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(tokens.shapeM),
            border: Border.all(
              color: colorScheme.error.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.location_off_rounded,
            color: colorScheme.error,
            size: 24,
          ),
        ),
        SizedBox(width: tokens.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WEATHER',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enable location to load weather details & alerts',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.spacingS),
        Icon(
          Icons.chevron_right_rounded,
          color: tokens.textTertiary,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildWeatherContent(
    BuildContext context,
    WeatherInfo info,
    DesignTokens tokens,
    ColorScheme colorScheme,
  ) {
    final weatherColor = _getWeatherColor(info.weatherCode);
    final iconColor = weatherColor;
    final iconBgColor = weatherColor.withValues(alpha: 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Weather Icon Container
            Container(
              padding: EdgeInsets.all(tokens.spacingS + 2),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(tokens.shapeM),
                border: Border.all(
                  color: weatherColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                _getWeatherIcon(info.weatherCode),
                color: iconColor,
                size: 26,
              ),
            ),
            SizedBox(width: tokens.spacingM),
            // Description & Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LOCAL WEATHER',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.description,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacingM),
            // Temperature Display
            Text(
              '${info.temperature.toStringAsFixed(0)}°',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
            ),
            SizedBox(width: tokens.spacingXS),
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.textTertiary,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          thickness: 0.5,
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.air_rounded,
              color: tokens.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Wind: ${info.windSpeed.toStringAsFixed(1)} ${distanceUnit == 'mi' ? 'mph' : 'km/h'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (info.isHighWindWarning) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.warningContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens.shapeXS),
                  border: Border.all(
                    color: tokens.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: tokens.warning,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'HIGH WIND ALERT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: tokens.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (info.isHighWindWarning) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacingM,
              vertical: tokens.spacingS,
            ),
            decoration: BoxDecoration(
              color: tokens.warningContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(tokens.shapeM),
              border: Border.all(
                color: tokens.warning.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              'High winds detected in your area. Drive cautiously.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
