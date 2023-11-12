import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:weather_station_companion/shared/saved_connections.dart';

class SavedConnectionRepository {
  static Future<List<SavedConnection>> findAll() async {
    final source = File('${(await getApplicationSupportDirectory()).path}/saved_connections.json');

    if (!await source.exists()) {
      return [];
    }

    return SavedConnection.fromJsonList(jsonDecode(await source.readAsString()));
  }

  static Future<void> persist(SavedConnection savedConnection) async {
    final source = File('${(await getApplicationSupportDirectory()).path}/saved_connections.json');
    final persistedSavedConnections = await findAll();

    persistedSavedConnections.removeWhere((e) => e.mac == savedConnection.mac);
    persistedSavedConnections.add(savedConnection);

    await source.writeAsString(jsonEncode(persistedSavedConnections.map((e) => e.toJson()).toList()), mode: FileMode.write);
  }

  static Future<void> remove(String mac) async {
    final source = File('${(await getApplicationSupportDirectory()).path}/saved_connections.json');
    final persistedSavedConnections = await findAll();

    persistedSavedConnections.removeWhere((e) => e.mac == mac);

    await source.writeAsString(jsonEncode(persistedSavedConnections.map((e) => e.toJson()).toList()), mode: FileMode.write);
  }
}