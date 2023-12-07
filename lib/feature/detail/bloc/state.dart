part of 'bloc.dart';

enum _Status {
  initializing,
  standard,
  connecting,
}

class DetailState {
  final _Status status;
  final SnackBarMessage? snackBarMessage;
  final String mac;
  final String dataSink;
  final int dataSinkFormat;
  final int measurementRate;
  final int uploadRate;
  final String wifiSSID;
  final String wifiPassword;
  final bool wifiPasswordIsVisible;
  final bool isConnected;
  final bool disconnectedToLeave;

  const DetailState([
    this.status = _Status.initializing,
    this.snackBarMessage,
    this.mac = '',
    this.dataSink = '',
    this.dataSinkFormat = DataSinkFormat.json,
    this.measurementRate = 0,
    this.uploadRate = 0,
    this.wifiSSID = '',
    this.wifiPassword = '',
    this.wifiPasswordIsVisible = false,
    this.isConnected = false,
    this.disconnectedToLeave = false,
  ]);

  DetailState copyWith({
    _Status? status,
    SnackBarMessage? snackBarMessage,
    String? mac,
    String? dataSink,
    int? dataSinkFormat,
    int? measurementRate,
    int? uploadRate,
    String? wifiSSID,
    String? wifiPassword,
    bool? wifiPasswordIsVisible,
    bool? isConnected,
    bool? disconnectedToLeave,
  }) {
    return DetailState(
      status ?? this.status,
      snackBarMessage,
      mac ?? this.mac,
      dataSink ?? this.dataSink,
      dataSinkFormat ?? this.dataSinkFormat,
      measurementRate ?? this.measurementRate,
      uploadRate ?? this.uploadRate,
      wifiSSID ?? this.wifiSSID,
      wifiPassword ?? this.wifiPassword,
      wifiPasswordIsVisible ?? this.wifiPasswordIsVisible,
      isConnected ?? this.isConnected,
      disconnectedToLeave ?? this.disconnectedToLeave,
    );
  }

  bool get isConnecting => status == _Status.connecting;

  bool get isInitializing => status == _Status.initializing;
}
