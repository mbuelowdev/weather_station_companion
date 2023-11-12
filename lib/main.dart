import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:weather_station_companion/core/services.dart';

import 'app.dart';

void main() {
  runZonedGuarded(() async {
    await Services.init();

    FlutterError.onError = (FlutterErrorDetails details) {
      GetIt.I.get<Logger>().e('Unhandled flutter exception: ${details.exception.toString()}\n${details.stack}');
    };

    runApp(const WeatherStation());
  }, (exception, stack) {
    GetIt.I.get<Logger>().e('Unhandled async exception: $exception\n$stack');
  });
}