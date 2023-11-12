import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:weather_station_companion/shared/saved_configuration.dart';

class SavedConfigurationRepository {
  static Future<List<SavedConfiguration>> findAll() async {
    final source = File('${(await getApplicationSupportDirectory()).path}/saved_configurations.json');

    if (!await source.exists()) {
      return [];
    }

    return SavedConfiguration.fromJsonList(jsonDecode(await source.readAsString()));
  }

  static Future<SavedConfiguration?> findOne(String mac) async {
    final source = File('${(await getApplicationSupportDirectory()).path}/saved_configurations.json');

    if (!await source.exists()) {
      return null;
    }

    final configurations = SavedConfiguration.fromJsonList(jsonDecode(await source.readAsString()));
    final configurationsWithFittingMAC = configurations.where((e) => e.mac == mac).toList();

    return configurationsWithFittingMAC.isNotEmpty ? configurationsWithFittingMAC.first : null;
  }

  static Future<void> persist(SavedConfiguration savedConfiguration) async {
    final source = File('${(await getApplicationSupportDirectory()).path}/saved_configurations.json');
    final persistedSavedConfigurations = await findAll();

    persistedSavedConfigurations.removeWhere((e) => e.mac == savedConfiguration.mac);
    persistedSavedConfigurations.add(savedConfiguration);

    await source.writeAsString(jsonEncode(persistedSavedConfigurations.map((e) => e.toJson()).toList()), mode: FileMode.write);
  }

  static Future<void> remove(SavedConfiguration savedConfiguration) async {
    final source = File('${(await getApplicationSupportDirectory()).path}/saved_configurations.json');
    final persistedSavedConnections = await findAll();

    persistedSavedConnections.removeWhere((e) => e.mac == savedConfiguration.mac);

    await source.writeAsString(jsonEncode(persistedSavedConnections.map((e) => e.toJson()).toList()), mode: FileMode.write);
  }
}