part of 'bloc.dart';

abstract class DetailEvent {}

class DetailInitialized extends DetailEvent {
  final SavedConfiguration? loadedConfiguration;
  final bool shouldConnect;

  DetailInitialized(this.loadedConfiguration, this.shouldConnect);
}

class DetailReconnectTriggered extends DetailEvent {}

class DetailSaveButtonPressed extends DetailEvent {
  final String mac;
  final String dataSink;
  final int dataSinkFormat;
  final int measurementRate;
  final int uploadRate;
  final String wifiSSID;
  final String wifiPassword;
  final bool subtractMeasuringTime;

  DetailSaveButtonPressed(
    this.mac,
    this.dataSink,
    this.dataSinkFormat,
    this.measurementRate,
    this.uploadRate,
    this.wifiSSID,
    this.wifiPassword,
    this.subtractMeasuringTime,
  );
}

class DetailOnInputChanged extends DetailEvent {
  final String mac;
  final String dataSink;
  final int dataSinkFormat;
  final int measurementRate;
  final int uploadRate;
  final String wifiSSID;
  final String wifiPassword;
  final bool subtractMeasuringTime;
  final bool wifiPasswordIsVisible;

  DetailOnInputChanged(
      this.mac,
      this.dataSink,
      this.dataSinkFormat,
      this.measurementRate,
      this.uploadRate,
      this.wifiSSID,
      this.wifiPassword,
      this.subtractMeasuringTime,
      this.wifiPasswordIsVisible,
      );
}

class DetailNavigateBackTriggered extends DetailEvent {}
