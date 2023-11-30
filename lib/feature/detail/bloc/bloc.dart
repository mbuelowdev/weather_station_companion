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

  DetailBloc(this.mac, this.shouldConnect) : super(const DetailState()) {
    on<DetailInitialized>(_onDetailInitialized);
    on<DetailReconnectTriggered>(_onDetailReconnectTriggered);
    on<DetailSaveButtonPressed>(_onDetailSaveButtonPressed);
    on<DetailNavigateBackTriggered>(_onDetailNavigateBackTriggered);
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

    if (targetDevice != null && !targetDevice!.isConnected) {
      return emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Failed to connect. Please retry!'),
        isConnected: false,
      ));
    }

    if (targetDevice != null) {
      await targetDevice!.discoverServices();

      final configurationService = targetDevice!.servicesList.firstWhere((e) => e.serviceUuid.uuid == configurationServiceUUID);

      for (final characteristic in configurationService.characteristics) {
        switch (characteristic.characteristicUuid.uuid) {
          case characteristicDataSink:
            emit(state.copyWith(
              dataSink: utf8.decode((await characteristic.read())),
            ));
            break;
          case characteristicDataSinkPushFormat:
            final bytes = await characteristic.read();
            emit(state.copyWith(
              dataSinkFormat: bytes[0] ,
            ));
            break;
          case characteristicMeasurementRate:
            final bytes = await characteristic.read();
            emit(state.copyWith(
              measurementRate: (bytes[0] << 8) + bytes[1] ,
            ));
            break;
          case characteristicUploadRate:
            final bytes = await characteristic.read();
            emit(state.copyWith(
              uploadRate: (bytes[0] << 8) + bytes[1] ,
            ));
            break;
          case characteristicWifiSSID:
            emit(state.copyWith(
              wifiSSID: utf8.decode((await characteristic.read())),
            ));
            break;
          case characteristicWifiPassword:
            emit(state.copyWith(
              wifiPassword: utf8.decode((await characteristic.read())),
            ));
            break;
            // TODO: persist characteristic
        }
      }
    }

    final loadedConfiguration = SavedConfiguration(
      state.mac,
      state.dataSink,
      state.dataSinkFormat,
      state.measurementRate,
      state.uploadRate,
      state.wifiSSID,
      state.wifiPassword,
    );

    await SavedConfigurationRepository.persist(loadedConfiguration);

    emit(state.copyWith(
      snackBarMessage: SnackBarMessage('Connected!'),
      isConnected: true,
    ));
  }

  Future<void> _onDetailSaveButtonPressed(DetailSaveButtonPressed event, Emitter<DetailState> emit) async {
    emit(state.copyWith());

    final newConfiguration = SavedConfiguration(
      event.mac,
      event.dataSink,
      event.dataSinkFormat,
      event.measurementRate,
      event.uploadRate,
      event.wifiSSID,
      event.wifiPassword,
    );

    emit(state.copyWith(
      snackBarMessage: SnackBarMessage('Upload new configuration...'),
    ));

    if (targetDevice != null) {
      await targetDevice!.discoverServices();

      final configurationService = targetDevice!.servicesList.firstWhere((e) => e.serviceUuid.uuid == configurationServiceUUID);

      for (final characteristic in configurationService.characteristics) {
        switch (characteristic.characteristicUuid.uuid) {
          case characteristicDataSink:
            await characteristic.write(utf8.encode(event.dataSink));
            break;
          case characteristicDataSinkPushFormat:
            await characteristic.write([event.dataSinkFormat]);
            break;
          case characteristicMeasurementRate:
            await characteristic.write([(event.measurementRate >> 8) & 0xFF, (event.measurementRate & 0x00FF) & 0xFF]);
            break;
          case characteristicUploadRate:
            await characteristic.write([(event.uploadRate >> 8) & 0xFF, (event.uploadRate & 0x00FF) & 0xFF]);
            break;
          case characteristicWifiSSID:
            await characteristic.write(utf8.encode(event.wifiSSID));
            break;
          case characteristicWifiPassword:
            await characteristic.write(utf8.encode(event.wifiPassword));
            break;
        }
      }
    }

    // TODO only if successful persist config
    await SavedConfigurationRepository.persist(newConfiguration);

    emit(state.copyWith(
      snackBarMessage: SnackBarMessage('Successfully uploaded!'),
      dataSink: event.dataSink,
      dataSinkFormat: event.dataSinkFormat,
      measurementRate: event.measurementRate,
      uploadRate: event.uploadRate,
      wifiSSID: event.wifiSSID,
      wifiPassword: event.wifiPassword,
    ));
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
}
