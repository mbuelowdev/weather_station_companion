import 'package:equatable/equatable.dart';

class SavedConfiguration extends Equatable{
  final String mac;

  final String dataSink;
  final int dataSinkFormat;
  final int measurementRate;
  final int uploadRate;
  final String wifiSSID;
  final String wifiPassword;

  const SavedConfiguration(
    this.mac,
    this.dataSink,
    this.dataSinkFormat,
    this.measurementRate,
    this.uploadRate,
    this.wifiSSID,
    this.wifiPassword,
  );

  @override
  List<Object?> get props => [mac, dataSink, dataSinkFormat, measurementRate, uploadRate, wifiSSID, wifiPassword];

  factory SavedConfiguration.fromJson(dynamic json) {
    return SavedConfiguration(
      json['mac'],
      json['dataSink'],
      json['dataSinkFormat'],
      json['measurementRate'],
      json['uploadRate'],
      json['wifiSSID'],
      json['wifiPassword'],
    );
  }

  static List<SavedConfiguration> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((e) => SavedConfiguration.fromJson(e)).toList();
  }

  Map<String, Object> toJson() {
    return {
      'mac': mac,
      'dataSink': dataSink,
      'dataSinkFormat': dataSinkFormat,
      'measurementRate': measurementRate,
      'uploadRate': uploadRate,
      'wifiSSID': wifiSSID,
      'wifiPassword': wifiPassword,
    };
  }
}
