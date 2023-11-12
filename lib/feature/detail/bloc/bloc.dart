import 'dart:async';
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
    await this.targetDevice?.disconnect(timeout: 2);

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
    )
        .catchError((e) {
      emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Connect error: $e'),
      ));
      return;
    });

    targetDevice = foundDevice.device;

    await SavedConnectionRepository.persist(
      SavedConnection(foundDevice.device.remoteId.str, foundDevice.device.advName, DateTime.now()),
    );

    // TODO fetch configuration

    final loadedConfiguration = SavedConfiguration(
      targetDevice!.remoteId.str,
      'http://mbuelow.dev/dump/index.php',
      DataSinkFormat.json,
      60,
      600,
      '0x20',
      'password123',
    );

    await SavedConfigurationRepository.persist(loadedConfiguration);

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

    // TODO sync new configuration to device

    await Future.delayed(const Duration(seconds: 1));

    emit(state.copyWith(
        snackBarMessage: SnackBarMessage('Successfully uploaded!'),
    ));

    // TODO if successful persist config
    await SavedConfigurationRepository.persist(newConfiguration);

    print('targetDevice is not null: ${targetDevice != null}');
    if (targetDevice != null) {
      await targetDevice!.discoverServices();

      for (final service in targetDevice!.servicesList) {
        print('Service: ${service.serviceUuid}');
        for (final characteristic in service.characteristics) {
          print('Characteristic: ${characteristic.characteristicUuid}');
        }
      }
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
}
