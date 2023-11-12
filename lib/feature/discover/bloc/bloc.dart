import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/saved_connections.dart';
import '../../../shared/snack_bar_message.dart';
import '../data/saved_connection_repository.dart';

part 'event.dart';

part 'state.dart';

class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  StreamSubscription<List<ScanResult>>? scanResultsSubscription;

  DiscoverBloc() : super(const DiscoverState()) {
    on<DiscoverInitialized>(_onDiscoverInitialized);
    on<DiscoverSearchTriggered>(_onDiscoverSearchTriggered);
    on<DiscoverSearchDeviceDetected>(_onDiscoverSearchDeviceDetected);
    on<DiscoverSearchFinished>(_onDiscoverSearchFinished);
    on<DiscoverForgetSavedDeviceTriggered>(_onDiscoverForgetSavedDeviceTriggered);
    on<DiscoverDetailPageClosed>(_onDiscoverDetailPageClosed);
    _initialize();
  }

  void _initialize() async {
    checkForBluetoothPermissions();

    add(DiscoverInitialized(await SavedConnectionRepository.findAll()));
  }

  void checkForBluetoothPermissions() async {
    var status = await Permission.bluetoothScan.status;
    if (!status.isGranted) {
      [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetooth,
      ].request();
    }
  }

  Future<void> _onDiscoverInitialized(DiscoverInitialized event, Emitter<DiscoverState> emit) async {
    emit(state.copyWith(
      savedConnections: event.savedConnections,
      foundDevices: [],
      status: _Status.standard,
    ));
  }

  Future<void> _onDiscoverSearchTriggered(DiscoverSearchTriggered event, Emitter<DiscoverState> emit) async {
    emit(state.copyWith(
      status: _Status.searching,
    ));

    scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      add(DiscoverSearchDeviceDetected(results.where((e) => e.advertisementData.advName.trim().isNotEmpty).toList()));
    }, onError: (e) {
      GetIt.I.get<Logger>().e('Start scan error: $e');
    });

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

    await Future.delayed(const Duration(seconds: 10), () async {
      await scanResultsSubscription?.cancel();

      add(DiscoverSearchFinished());
    });
  }

  Future<void> _onDiscoverSearchDeviceDetected(DiscoverSearchDeviceDetected event, Emitter<DiscoverState> emit) async {
    emit(state.copyWith(
      foundDevices: event.foundDevices,
    ));
  }

  Future<void> _onDiscoverSearchFinished(DiscoverSearchFinished event, Emitter<DiscoverState> emit) async {
    emit(state.copyWith(
      status: _Status.standard,
    ));
  }

  Future<void> _onDiscoverForgetSavedDeviceTriggered(DiscoverForgetSavedDeviceTriggered event, Emitter<DiscoverState> emit) async {
    await SavedConnectionRepository.remove(event.mac);

    emit(state.copyWith(
      savedConnections: await SavedConnectionRepository.findAll(),
    ));
  }

  Future<void> _onDiscoverDetailPageClosed(DiscoverDetailPageClosed event, Emitter<DiscoverState> emit) async {
    emit(state.copyWith(
      savedConnections: await SavedConnectionRepository.findAll(),
    ));
  }
}
