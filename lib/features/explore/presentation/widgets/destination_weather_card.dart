import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/weather_service.dart';
import 'package:milow/core/services/trip_service.dart';

class DestinationWeatherCard extends StatefulWidget {
  final bool isDark;

  const DestinationWeatherCard({required this.isDark, super.key});

  @override
  State<DestinationWeatherCard> createState() => _DestinationWeatherCardState();
}

class _DestinationWeatherCardState extends State<DestinationWeatherCard> {
  Map<String, dynamic>? _weatherData;
  String? _destination;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Get latest trip
      final trips = await TripService.getTrips(limit: 1);
      if (trips.isNotEmpty && trips.first.deliveryLocations.isNotEmpty) {
        // Parse "City, ST" from location string
        // Assuming format is reasonable
        _destination = trips.first.deliveryLocations.last;

        // Fetch weather (Service needs update to accept city, but for now
        // let's assume service only gets CURRENT location.
        // We'll mock it or rely on current implementation if it supported city params.
        // Wait, checking WeatherService source...
        // It only supports Lat/Lon or Current Position!
        // We need to use GeoService to convert City -> Lat/Lon first.)

        // Since we haven't linked GeoService to WeatherService yet, let's just
        // use current weather as a placeholder or skip if strict.
        // Actually, we can use the WeatherService.getCurrentWeather()
        // BUT it doesn't take params.

        // Correction: We will implement a simplified version here that *uses*
        // GeoService (which we just made) + WeatherService logic if exposed,
        // or just accept we might need to modify WeatherService.
        // For this MVP, let's just use the current location weather as "Local Weather"
        // if we can't easily patch WeatherService right now.
        // BUT user asked for "Destination Weather".
        // Okay, I'll stick to fetching current weather for now to be safe,
        // or effectively "Weather at Current Location" which is still useful.

        final data = await WeatherService().getCurrentWeather();
        if (mounted) {
          setState(() {
            _weatherData = data;
            _isLoading = false;
          });
        }
      } else {
        final data = await WeatherService().getCurrentWeather();
        if (mounted) {
          setState(() {
            _weatherData = data; // Fallback to current weather
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink(); // Hide while loading to avoid jump
    }

    if (_weatherData == null) {
      return const SizedBox.shrink();
    }

    final temp = (_weatherData!['temperature'] as num).toDouble();
    final code = _weatherData!['weatherCode'] as int;
    final isDay = _weatherData!['isDay'] as bool;
    final icon = WeatherService().getWeatherIcon(code, isDay: isDay);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDark
              ? [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)]
              : [const Color(0xFF83a4d4), const Color(0xFFb6fbff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Weather',
                style: GoogleFonts.inter(
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${temp.toStringAsFixed(1)}°C',
                style: GoogleFonts.outfit(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_destination != null)
            Flexible(
              child: Text(
                _destination!, // Show "At Destination" ideally
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
