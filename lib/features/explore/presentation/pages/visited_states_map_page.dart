import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';

class VisitedStatesMapPage extends StatelessWidget {
  final Set<String> visitedStates;

  const VisitedStatesMapPage({super.key, required this.visitedStates});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visited States Analysis'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
        titleTextStyle: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 75.0,
          child: SimpleMap(
            instructions: SMapUnitedStates.instructions,
            defaultColor: Colors.grey[300]!,
            colors: _getColors(context),
            callback: (id, name, tapDetails) {
              // Debug helper
              print("Tapped State: $id ($name)");
            },
          ),
        ),
      ),
    );
  }

  Map<String, Color> _getColors(BuildContext context) {
    final Map<String, Color> colors = {};
    for (var state in visitedStates) {
      final code = state.trim().toLowerCase();
      // Add multiple formats to be safe
      colors[code] = Colors.blueAccent;
      colors['us$code'] = Colors.blueAccent; // usny
      colors['us-$code'] = Colors.blueAccent; // us-ny
    }
    return colors;
  }
}
