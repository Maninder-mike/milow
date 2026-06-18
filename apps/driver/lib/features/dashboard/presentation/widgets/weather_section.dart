import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/utils/responsive_layout.dart';
import 'package:milow/core/services/weather_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveLayout.getMargin(context)),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shapeL),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onWeatherTap,
          borderRadius: BorderRadius.circular(tokens.shapeL),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacingM),
            child: isLoadingWeather
                ? const SizedBox(
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : weatherInfo == null
                    ? Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(tokens.spacingS),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(tokens.shapeM),
                            ),
                            child: Icon(
                              Icons.location_off_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: tokens.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WEATHER',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Enable location to load weather details & alerts',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: tokens.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: tokens.spacingS),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: tokens.textTertiary,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Weather Icon Container
                              Container(
                                padding: EdgeInsets.all(tokens.spacingS),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(tokens.shapeM),
                                ),
                                child: Icon(
                                  _getWeatherIcon(weatherInfo!.weatherCode),
                                  color: colorScheme.onPrimaryContainer,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: tokens.spacingM),
                              // Description & Title
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LOCAL WEATHER',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${weatherInfo!.description} • Wind: ${weatherInfo!.windSpeed.toStringAsFixed(1)} ${distanceUnit == 'mi' ? 'mph' : 'km/h'}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: tokens.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: tokens.spacingM),
                              // Temperature Display
                              Text(
                                '${weatherInfo!.temperature.toStringAsFixed(0)}°',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: tokens.textPrimary,
                                    ),
                              ),
                              SizedBox(width: tokens.spacingXS),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: tokens.textTertiary,
                              ),
                            ],
                          ),
                          if (weatherInfo!.isHighWindWarning) ...[
                            SizedBox(height: tokens.spacingM),
                            Container(
                              padding: EdgeInsets.all(tokens.spacingS),
                              decoration: BoxDecoration(
                                color: tokens.warningContainer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(tokens.shapeM),
                                border: Border.all(
                                  color: tokens.warning.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: tokens.warning,
                                    size: 20,
                                  ),
                                  SizedBox(width: tokens.spacingS),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'HIGH WIND ALERT',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: tokens.warning,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                        ),
                                        Text(
                                          'High winds detected in your area. Drive cautiously.',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: tokens.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}
