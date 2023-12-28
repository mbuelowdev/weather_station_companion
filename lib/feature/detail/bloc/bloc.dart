// ignore_for_file: avoid_init_to_null

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:weather_station_companion/feature/detail/data/saved_configuration_repository.dart';
import 'package:weather_station_companion/shared/data_sink_format.dart';
import 'package:weather_station_companion/shared/saved_configuration.dart';

import '../../../shared/saved_connections.dart';
import '../../../shared/snack_bar_message.dart';
import '../../discover/data/saved_connection_repository.dart';

part 'event.dart';
part 'state.dart';

class DetailBloc extends Bloc<DetailEvent, DetailState> {
  final String mac;
  final bool shouldConnect;
  BluetoothDevice? targetDevice;

  static const configurationServiceUUID = '00ff';
  static const characteristicDataSink = 'ff01';
  static const characteristicDataSinkPushFormat = 'ff02';
  static const characteristicMeasurementRate = 'ff03';
  static const characteristicUploadRate = 'ff04';
  static const characteristicWifiSSID = 'ff05';
  static const characteristicWifiPassword = 'ff06';
  static const characteristicFlushTrigger = 'ffff';

  DetailBloc(this.mac, this.shouldConnect) : super(const DetailState()) {
    on<DetailInitialized>(_onDetailInitialized);
    on<DetailReconnectTriggered>(_onDetailReconnectTriggered);
    on<DetailSaveButtonPressed>(_onDetailSaveButtonPressed);
    on<DetailNavigateBackTriggered>(_onDetailNavigateBackTriggered);
    on<DetailOnInputChanged>(_onDetailOnInputChanged);
    _initialize();
  }

  void _initialize() async {
    add(DetailInitialized(await SavedConfigurationRepository.findOne(mac), shouldConnect));
  }

  Future<void> _onDetailInitialized(DetailInitialized event, Emitter<DetailState> emit) async {
    emit(state.copyWith(
      status: _Status.standard,
      mac: mac,
      dataSink: event.loadedConfiguration?.dataSink ?? '',
      dataSinkFormat: event.loadedConfiguration?.dataSinkFormat ?? 0,
      measurementRate: event.loadedConfiguration?.measurementRate ?? -1,
      uploadRate: event.loadedConfiguration?.uploadRate ?? -1,
      wifiSSID: event.loadedConfiguration?.wifiSSID ?? '',
      wifiPassword: event.loadedConfiguration?.wifiPassword ?? '',
    ));

    if (event.shouldConnect) {
      add(DetailReconnectTriggered());
    }
  }

  Future<void> _onDetailReconnectTriggered(DetailReconnectTriggered event, Emitter<DetailState> emit) async {
    emit(state.copyWith(
      status: _Status.connecting,
      isConnected: false,
      snackBarMessage: SnackBarMessage('Searching...'),
    ));

    // If a connection already exists we disconnect first
    await targetDevice?.disconnect(timeout: 2);

    // Register a handler for the incoming ScanResults. If we find our target
    // device, we will complete a completer.
    final waitingForDeviceCompleter = Completer<ScanResult>();
    final scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      final validResults = results.where((e) => e.device.remoteId.str == mac).toList();

      if (validResults.isNotEmpty) {
        waitingForDeviceCompleter.complete(validResults.first);
      }
    }, onError: (e) {
      emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Search error: $e'),
      ));
      return;
    });

    // Start scanning for our device
    try {
      // android is slow when asking for all advertisments,
      // so instead we only ask for 1/8 of them
      int divisor = Platform.isAndroid ? 8 : 1;
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        continuousUpdates: true,
        continuousDivisor: divisor,
      );
    } catch (e) {
      GetIt.I.get<Logger>().e('Start scan error: $e');
    }

    // When the ScanResults handler finds our device, this future will be
    // completed
    final foundDevice = await waitingForDeviceCompleter.future;

    await scanResultsSubscription.cancel();

    emit(state.copyWith(
      snackBarMessage: SnackBarMessage('Establishing a connection...'),
    ));

    await foundDevice.device.connect(
      timeout: const Duration(seconds: 10),
      autoConnect: false,
    ).catchError((e) {
      emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Connect error: $e'),
      ));
      return;
    });

    targetDevice = foundDevice.device;

    await SavedConnectionRepository.persist(
      SavedConnection(foundDevice.device.remoteId.str, foundDevice.device.advName, DateTime.now()),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    // Sometimes the connection just fails under android. We ask the user to
    // connect again.
    if (targetDevice != null && !targetDevice!.isConnected) {
      return emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Failed to connect. Please retry!'),
        isConnected: false,
      ));
    }

    // We fetch the current configuration of the device
    final loadedConfiguration = await _readConfiguration(state.mac);

    // If that fails loadedConfiguration will be null
    if (loadedConfiguration == null) {
      return emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Failed to connect!'),
        isConnected: false,
      ));
    }

    // We successfully fetched the configuration, we'll now persist it
    await SavedConfigurationRepository.persist(loadedConfiguration);

    // Show a success message
    emit(state.copyWith(
      snackBarMessage: SnackBarMessage('Connected!'),
      isConnected: true,
      dataSink: loadedConfiguration.dataSink,
      dataSinkFormat: loadedConfiguration.dataSinkFormat,
      measurementRate: loadedConfiguration.measurementRate,
      uploadRate: loadedConfiguration.uploadRate,
      wifiSSID: loadedConfiguration.wifiSSID,
      wifiPassword: loadedConfiguration.wifiPassword,
    ));
  }

  Future<void> _onDetailSaveButtonPressed(DetailSaveButtonPressed event, Emitter<DetailState> emit) async {
    final possiblyNewConfiguration = SavedConfiguration(
      event.mac,
      event.dataSink,
      event.dataSinkFormat,
      event.measurementRate,
      event.uploadRate,
      event.wifiSSID,
      event.wifiPassword,
    );

    // Check for disallowed value ranges

    if (event.uploadRate > (event.measurementRate * 100)) {
      return emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Upload rate has to be shorter. Current maximum: ${event.measurementRate*100}.'),
      ));
    }

    if (event.measurementRate < 0 || event.measurementRate > 65535) {
      return emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Measurement rate has to be within 0 - 65535.'),
      ));
    }

    if (event.uploadRate < 0 || event.uploadRate > 65535) {
      return emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Upload rate has to be within 0 - 65535.'),
      ));
    }

    // Start uploading the new configuration

    emit(state.copyWith(
      snackBarMessage: SnackBarMessage('Uploading new configuration...'),
    ));

    final wasSuccessful = await _writeConfiguration(
      possiblyNewConfiguration.dataSink,
      possiblyNewConfiguration.dataSinkFormat,
      possiblyNewConfiguration.measurementRate,
      possiblyNewConfiguration.uploadRate,
      possiblyNewConfiguration.wifiSSID,
      possiblyNewConfiguration.wifiPassword,
    );

    // Only save the configuration if the write operation was successful
    if (wasSuccessful) {
      await SavedConfigurationRepository.persist(possiblyNewConfiguration);
      emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Successfully uploaded!'),
        dataSink: possiblyNewConfiguration.dataSink,
        dataSinkFormat: possiblyNewConfiguration.dataSinkFormat,
        measurementRate: possiblyNewConfiguration.measurementRate,
        uploadRate: possiblyNewConfiguration.uploadRate,
        wifiSSID: possiblyNewConfiguration.wifiSSID,
        wifiPassword: possiblyNewConfiguration.wifiPassword,
      ));
    } else {
      emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Upload failed!'),
      ));
    }
  }

  Future<void> _onDetailNavigateBackTriggered(DetailNavigateBackTriggered event, Emitter<DetailState> emit) async {
    emit(state.copyWith(
      snackBarMessage: SnackBarMessage('Disconnecting...'),
    ));

    await targetDevice?.disconnect(timeout: 5);
    targetDevice = null;

    emit(state.copyWith(
      snackBarMessage: SnackBarMessage('Disconnected!'),
    ));

    emit(state.copyWith(
      isConnected: false,
      disconnectedToLeave: true,
    ));
  }

  Future<void> _onDetailOnInputChanged(DetailOnInputChanged event, Emitter<DetailState> emit) async {
    emit(state.copyWith(
      dataSink: event.dataSink,
      dataSinkFormat: event.dataSinkFormat,
      measurementRate: event.measurementRate,
      uploadRate: event.uploadRate,
      wifiSSID: event.wifiSSID,
      wifiPassword: event.wifiPassword,
      wifiPasswordIsVisible: event.wifiPasswordIsVisible,
    ));
  }

  Future<SavedConfiguration?> _readConfiguration(String mac) async {
    // If we fail to connect to the device then targetDevice will be null
    if (targetDevice == null) {
      return null;
    }

    try {
      String? dataSink = null;
      int? dataSinkPushFormat = null;
      int? measurementRate = null;
      int? uploadRate = null;
      String? wifiSSID = null;
      String? wifiPassword = null;

      // Start looking for services advertised by the device
      await targetDevice!.discoverServices();

      // Fetch the "Configuration"-Service
      final configurationService = targetDevice!.servicesList.firstWhere((e) => e.serviceUuid.uuid == configurationServiceUUID);

      for (final characteristic in configurationService.characteristics) {
        switch (characteristic.characteristicUuid.uuid) {
          case characteristicDataSink:
            dataSink = utf8.decode((await characteristic.read()));
            break;
          case characteristicDataSinkPushFormat:
            final bytes = await characteristic.read();
            dataSinkPushFormat = bytes[0];
            break;
          case characteristicMeasurementRate:
            final bytes = await characteristic.read();
            measurementRate = (bytes[0] << 8) + bytes[1];
            break;
          case characteristicUploadRate:
            final bytes = await characteristic.read();
            uploadRate = (bytes[0] << 8) + bytes[1];
            break;
          case characteristicWifiSSID:
            wifiSSID = utf8.decode((await characteristic.read()));
            break;
          case characteristicWifiPassword:
            wifiPassword = utf8.decode((await characteristic.read()));
            break;
        }
      }

      return SavedConfiguration(
        mac,
        dataSink!,
        dataSinkPushFormat!,
        measurementRate!,
        uploadRate!,
        wifiSSID!,
        wifiPassword!,
      );
    } catch (_) {}

    return null;
  }

  Future<bool> _writeConfiguration(String dataSink, int dataSinkFormat, int measurementRate, int uploadRate, String wifiSSID, String wifiPassword) async {
    // If we fail to connect to the device then targetDevice will be null
    if (targetDevice == null) {
      return false;
    }

    try {
      // Start looking for services advertised by the device
      await targetDevice!.discoverServices();

      // Fetch the "Configuration"-Service
      final configurationService = targetDevice!.servicesList.firstWhere((e) => e.serviceUuid.uuid == configurationServiceUUID);

      for (final characteristic in configurationService.characteristics) {
        switch (characteristic.characteristicUuid.uuid) {
          case characteristicDataSink:
            await characteristic.write(utf8.encode(dataSink + '\x00'));
            break;
          case characteristicDataSinkPushFormat:
            await characteristic.write([dataSinkFormat]);
            break;
          case characteristicMeasurementRate:
            await characteristic.write([(measurementRate >> 8) & 0xFF, (measurementRate & 0x00FF) & 0xFF]);
            break;
          case characteristicUploadRate:
            await characteristic.write([(uploadRate >> 8) & 0xFF, (uploadRate & 0x00FF) & 0xFF]);
            break;
          case characteristicWifiSSID:
            await characteristic.write(utf8.encode(wifiSSID + '\x00'));
            break;
          case characteristicWifiPassword:
            await characteristic.write(utf8.encode(wifiPassword + '\x00'));
            break;
        }
      }

      // Trigger a flush to force the configuration to be saved. Without the
      // flush the configuration would only exist in the RAM until reboot.
      final charFlushTrigger = configurationService.characteristics.firstWhere((e) => e.uuid.toString() == characteristicFlushTrigger);
      await charFlushTrigger.write([0]);
    } catch (_) {
      return false;
    }

    return true;
  }
}
