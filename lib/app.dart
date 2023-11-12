import 'package:flutter/material.dart';
import 'package:weather_station_companion/route_generator.dart';

import 'core/theme/color_schemes.g.dart';

class WeatherStation extends StatefulWidget {
  const WeatherStation({super.key});

  @override
  State<WeatherStation> createState() => _WeatherStationState();
}

class _WeatherStationState extends State<WeatherStation> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Station Companion',
      theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
      initialRoute: '/',
      onGenerateRoute: RouteGenerator.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}